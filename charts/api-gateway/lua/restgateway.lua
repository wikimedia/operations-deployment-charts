-- -----------------------------------------------------------------------
-- Use test cases in tests/test.lua to protect the logic in this file!
-- -----------------------------------------------------------------------

-- Note: HelmValues is defined in _rest_hooks.lua.tpl

function envoy_on_request(request_handle)
    wmf_ratelimit_info(request_handle)
    wmf_request_cleanup(request_handle)
end

function envoy_on_response(response_handle)
    wmf_set_retry_after(response_handle)
end

-- -----------------------------------------------------------------------
-- wmf_ratelimit_info determins the rate limit class to be applied for the
-- current request, and the user ID to use as the key for the rate limit
-- counter.
--
-- Limits for each rate limit class are defined in main_app.ratelimiter.policies.
-- The following classes are currently assigned by wmf_ratelimit_info:
--
-- * approved-bot indicates that the request is coming from a vetted bot.
--   The user-agent header is used as the rate limit key.
--   This is currently applied to requests with x-trusted-request: A, which is for
--   requests from networks controlled by WMF (including WMCS an WME).
--   In the future, this class may also be assigned based on privileges of an
--   authenticated users (such as the global bot flag).
--
-- * known-clients indicates that the request is coming from a well known source.
--   The x-provenance header is used as the rate limit key.
--   This is currently applied to requests with x-trusted-request: B, which is for
--   things like googlebot, bingbot, internet archive, etc.
--
-- * cookie-user indicates an authenticated request from a browser.
--   This is equivalent to x-trusted-request: C.
--   It is assigned to requests that have a user ID cookie set. In the future,
--   this cookie will be required to contain a valid JWT.
--   The ID from the cookie is used as the rate limit key.
--
-- * ua-bot indicates a bot using a compliant user-agent header.
--   It is applied to requests with x-trusted-request: D.
--   The x-ua-contact header is used as the rate limit key.
--
-- * anon-browser indicates a organic browser traffic from interactive UI
--   elements and Gadgets.
--   It is applied to requests with x-is-browser >= 80 and is will cover
--   part of the requests with x-trusted-request: E.
--   The client's IP address is used as the rate limit key.
--
-- * anon-sus indicates that the origin of the request is suspect.
--   It is applied to requests with x-trusted-request: F.
--   The client's IP address is used as the rate limit key.
--
-- * anon: Anything else, especially non-compliant bots.
--   This will apply requests with x-trusted-request: E but a low score
--   in x-is-browser.
--   The client's IP address is used as the rate limit key.
--- -----------------------------------------------------------------------
function wmf_ratelimit_info(request_handle)
    local headers = request_handle:headers()
    local streamInfo = request_handle:streamInfo()
    local ratelimit_class = HelmValues.main_app.ratelimiter.fallback_class
    local trusted_identity_cookie = HelmValues.main_app.ratelimiter.user_id_cookie

    -- The x-client-ip header is set in the edge tier of the WMF network.
    -- If it not present, the request is internal and should not be limited.
    local client_ip = headers:get("x-client-ip")
    if not client_ip then
        -- The early exit keeps "x-wmf-" headers intact, which allows rate limit behavior
        -- to be tested from an internal network by setting the headers explicitly.
        request_handle:logDebug("WMF rate_limit: no x-client-ip, exit early")
        return
    end

    -- strip all readers related to rate limiting from external requests
    headers:remove("x-wmf-ratelimit-policy")
    headers:remove("x-wmf-ratelimit-class")
    headers:remove("x-wmf-user-id")

    -- Use the client IP as the fallback use ID.
    local user_id = "x-client-ip:" .. client_ip

    -- Determine policy to apply, based on route meta data
    local routeMeta = request_handle:metadata()
    local routeMeta_ratelimit = routeMeta:get("wmf_ratelimit") or {}
    local ratelimit_policy = routeMeta_ratelimit["policy"] or "MISSING"
    headers:replace("x-wmf-ratelimit-policy", ratelimit_policy)

    -- relevant cookies have been copied to dynamic metadata using envoy.filters.http.header_to_metadata
    local streamMeta = streamInfo:dynamicMetadata()
    local cookies = streamMeta:get("envoy.wmf_cookies") or {}

    -- bearer token payload from envoy.filters.http.jwt_authn
    local jwtMeta = streamMeta:get("envoy.filters.http.jwt_authn") or {}
    local jwtPayload = jwtMeta.jwt_payload or {}
    local cookiePayload = jwtMeta.cookie_payload or {}

    -- see https://wikitech.wikimedia.org/wiki/CDN/Backend_api
    local trust = headers:get("x-trusted-request")
    local browserScore = headers:get("x-is-browser") and tonumber( headers:get("x-is-browser") )

    if jwtPayload.sub then
        user_id = "bearer-sub:" .. jwtPayload.sub

        if jwtPayload.rlc then
            ratelimit_class = jwtPayload.rlc
        else
            -- fallback class for clients using API keys
            ratelimit_class = "jwt-user"
        end
    elseif cookiePayload.sub then
        user_id = "cookie-sub:" .. cookiePayload.sub

        if cookiePayload.rlc then
            ratelimit_class = cookiePayload.rlc
        else
            -- fallback class for clients using cookie auth
            ratelimit_class = "cookie-user"
        end
    elseif cookies[trusted_identity_cookie] and cookies[trusted_identity_cookie] ~= "#NONE#" then
        -- NOTE: This is totally unsafe. It should only be used for testing.
        user_id = trusted_identity_cookie .. ":" .. cookies[trusted_identity_cookie]
        ratelimit_class = "cookie-user"
    elseif trust == "A" and headers:get("user-agent") then
        -- This is mostly WMCS but could include stray requests from MW, see T410198 and T411503.
        -- NOTE: this currently includes WME. We could look into x-provenance to check.
        -- Identify by user agent. Clients using a generic agents will share a counter.
        user_id = "user-agent:" .. headers:get("user-agent")

        -- Assign "approved-bot" class. Ideally we'd only do that for "good" user agent strings.
        ratelimit_class = "approved-bot"
    elseif trust == "B" and headers:get("x-provenance") then
        -- Known bots (e.g. googlebot), see https://wikitech.wikimedia.org/wiki/Bot_traffic
        -- Identified by provenance. We could probably pick out the "client" or "id" field.
        user_id = "x-provenance:" .. headers:get("x-provenance")
        ratelimit_class = "known-client"
    elseif trust == "D" and headers:get("x-ua-contact") then
        -- Unidentified traffic from suspicious sources
        ratelimit_class = "ua-bot"

        -- NOTE: Easy to spoof/mutate. Temporarily useful for visibility. Go back to IP later.
        user_id = "x-ua-contact:" .. headers:get("x-ua-contact")
    elseif browserScore and browserScore >= 80 then
        -- Looks like organic browser traffic (requests from interactive UI or Gadgets)
        -- This is typically trust level E, but we allow level F as well (untile that gets abused)
        -- TODO: Use JA3N + JA4H as the user ID when available
        ratelimit_class = "anon-browser"
    elseif trust == "F" then
        -- Unidentified traffic from suspicious sources
        -- TODO: Use JA3N + JA4H as the user ID when available
        ratelimit_class = "anon-sus"
    end

    request_handle:logDebug("WMF rate_limit: class=" .. ( ratelimit_class or "~" )
            .. ", user=" .. ( user_id or "~" ) .. ", policy=" ..  ( ratelimit_policy or "~" )
    )

    headers:replace("x-wmf-user-id", user_id)
    headers:replace("x-wmf-ratelimit-class", ratelimit_class)
end

function wmf_request_cleanup(request_handle)
    local headers = request_handle:headers()

    -- These headers are required for rate limiting. We remove them below if their value is
    -- "no-limit", because removing them disables rate limiting entirely.
    -- This works because the "request_headers" directive of the rate_limits filter
    -- will fail to construct a descriptor if the header is missing.
    local names = { "x-wmf-ratelimit-class", "x-wmf-ratelimit-policy" }

    for _, hname in ipairs(names) do
        if headers:get(hname) == "no-limit" then
            headers:remove(hname)
        end
    end
end

function wmf_set_retry_after(response_handle)
    local headers = response_handle:headers()

    if headers:get("retry-after") then
        return
    end

    local s = headers:get(":status")
    local status = s and tonumber(s) or -1

    local retryable = {
        [429]=true, -- RFC 6585, section 4
        [503]=true, -- RFC 7231, section 6.6.4
    }

    if retryable[status] then
        -- Use time to reset supplied by the ratelimit service, or fall back to one minute.
        local reset = headers:get("x-ratelimit-reset") or "60"
        headers:replace("retry-after", reset)

        if headers:get("x-ratelimit-remaining") == "0" then
            headers:replace("content-type", "text/plain")
            response_handle:body():setBytes( HelmValues.main_app.ratelimiter.ratelimit_notice_text )
        end
    end
end
