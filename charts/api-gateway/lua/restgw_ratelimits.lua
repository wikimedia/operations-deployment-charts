-- Note: HelmValues is defined in _rest_hooks.lua.tpl

function envoy_on_request(request_handle)
    wmf_ratelimit_info(request_handle)
    wmf_stash_headers_to_expose(request_handle)
end

function envoy_on_response(response_handle)
    wmf_expose_headers(response_handle)
    wmf_set_retry_after(response_handle)
end

-- -----------------------------------------------------------------------
-- wmf_ratelimit_info determins the rate limit class to be applied for the
-- current request, and the user ID to use as the key for the rate limit
-- counter.
--
-- Limits for each rate limit class are defined in main_app.ratelimiter.policies.
-- For available rate limit classes and their meaning,
-- see <https://wikitech.wikimedia.org/wiki/REST_Gateway/Rate_limiting>.
--- -----------------------------------------------------------------------
function wmf_ratelimit_info(request_handle)
    local browser_threshold = HelmValues.main_app.ratelimiter.browser_threshold
    local headers = request_handle:headers()
    local streamInfo = request_handle:streamInfo()
    local ratelimit_class = nil

    -- The x-client-ip header is set in the edge tier of the WMF network.
    -- If it not present, the request is internal and should not be limited.
    local client_ip = headers:get("x-client-ip")
    if not client_ip then
        -- The early exit keeps "x-wmf-" headers intact, which allows rate limit behavior
        -- to be tested from an internal network by setting the headers explicitly.
        request_handle:logDebug("WMF rate_limit: no x-client-ip, exit early")
        return
    end

    -- no rate limit for OPTIONS requests (T418969)
    if headers:get(":method") == "OPTIONS" then
        -- instead of exiting early, we could allow a policy to be configured for use with OPTIONS.
        request_handle:logDebug("WMF rate_limit: OPTIONS request, exit early")
        return
    end

    -- strip all headers related to rate limiting from external requests
    headers:remove("x-wmf-ratelimit-class")
    headers:remove("x-wmf-user-id")
    for i, _ in ipairs(HelmValues.main_app.ratelimiter.default_policies) do
        headers:remove("x-wmf-ratelimit-policy-" .. tostring(i))
    end

    -- Use the client IP as the fallback use ID.
    local user_id = nil

    -- Determine policies to apply, based on route meta data
    local routeMeta = request_handle:metadata()
    local routeMeta_ratelimit = routeMeta:get("wmf_ratelimit") or {}

    local ratelimit_policies = routeMeta_ratelimit["policies"] or {}
    for i, p in ipairs(ratelimit_policies) do
        -- No header for the "BYPASS" policy, so rate limiting is bypassed entirely.
        -- This works because the "request_headers" directive of the rate_limits filter
        -- will not construct a descriptor if the header is missing.
        if p ~= "BYPASS" then
            headers:replace("x-wmf-ratelimit-policy-" .. tostring(i), p)
        end
    end

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
    local userAgent = headers:get("user-agent") or ""

    -- -----------------------------------------------------------------------------------
    -- Request classification, assigns ratelimit_class and user_id.
    -- Use test cases in tests/test.lua to protect the logic in this file.
    -- NOTE: Update the documentation on Wikitech when making changes, see
    --       <https://wikitech.wikimedia.org/wiki/REST_Gateway/Rate_limiting>.
    -- NOTE: When making major changes to the classification, it can be useful to
    --       use a new policy name at the same time, to keep the metrics separate.
    -- -----------------------------------------------------------------------------------
    if trust == "A" then
        -- This is mostly WMCS but could include stray requests from MW, see T410198 and T411503.
        -- NOTE: this currently includes WME. We could look into x-provenance to check.
        -- Identify by user agent. Clients using a generic agents will share a counter.
        ratelimit_class = "known-network"

    elseif trust == "B" then
        -- Known bots (e.g. googlebot), see https://wikitech.wikimedia.org/wiki/Bot_traffic
        -- Identified by provenance. We could probably pick out the "client" or "id" field.
        ratelimit_class = "known-client"

    elseif jwtPayload.rlc then
        -- We trust that long-lived tokens don't have an rlc field.
       -- TODO: Ignore stale rlc field if the token is older than a day (check iat field).
        -- That shouldn't happen, since long-lived tokens shouldn't have an rlc field.
        -- But if they do, we shouldn't use it, we should use the cookie's rlc instead.
        ratelimit_class = jwtPayload.rlc

    elseif cookiePayload.rlc then
        -- T418042: Use the rlc field from a session cookie if it is present.
        ratelimit_class = cookiePayload.rlc

    elseif jwtPayload.sub then
        -- Fallback class for clients using API keys (owner-only tokens) without
        -- session cookies.
        ratelimit_class = "authed-bot"

    elseif cookiePayload.sub and browserScore and browserScore >= browser_threshold then
        ratelimit_class = "authed-browser"

    elseif cookiePayload.sub then
        ratelimit_class = "authed-bot"

    elseif userAgent:find("^MediaWiki/") or userAgent:find("^QuickInstantCommons/") then
        -- We have a MediaWiki User-Agent string
        ratelimit_class = "unauthed-mediawiki"

    elseif ( trust == "C" or trust == "D" ) and headers:get("x-ua-contact") then
        -- We have a well-formed User-Agent string

        -- NOTE: For trust == C we only get here if we DON'T have a valid token,
        -- contrary to the expectations for C (T420106). This can happen if the token validation
        -- at the CDN layer is less struct than Envoy's (e.g. more lenient about clock skew).
        -- In that case, treat the request as if it had trust == D rather than E or F.
        ratelimit_class = "unauthed-bot"

    elseif browserScore and browserScore >= browser_threshold then
        -- Looks like organic browser traffic (requests from interactive UI or Gadgets)
        -- This is typically trust level E, but we allow level F as well (untile that gets abused)
        -- TODO: Use JA3N + JA4H as the user ID when available
        ratelimit_class = wmf_ratelimit_class_for_address(client_ip, "anon-browser")

    else
        local anon_class = HelmValues.main_app.ratelimiter.fallback_class -- defaults to "anon"
        ratelimit_class = wmf_ratelimit_class_for_address(client_ip, anon_class)
    end

    if jwtPayload.sub then
        user_id = "bearer-sub:" .. jwtPayload.sub
    elseif cookiePayload.sub then
        user_id = "cookie-sub:" .. cookiePayload.sub
    elseif trust == "A" and userAgent ~= "" then
        user_id = "user-agent:" .. userAgent
    elseif trust == "B" and headers:get("x-provenance") then
        user_id = "x-provenance:" .. headers:get("x-provenance")
    elseif ( trust == "C" or trust == "D" ) and headers:get("x-ua-contact") then
        -- NOTE: Easy to spoof/mutate. Temporarily useful for visibility. Go back to IP later.
        user_id = "x-ua-contact:" .. headers:get("x-ua-contact")
    else
        -- Use the client IP as the fallback use ID.
        user_id = "x-client-ip:" .. client_ip
    end

    request_handle:logDebug("WMF rate_limit: class=" .. ( ratelimit_class or "~" )
            .. ", user=" .. ( user_id or "~" ) .. ", policy=" ..  ( ratelimit_policy or "~" )
    )

    headers:replace("x-wmf-user-id", user_id)

    -- No header for the "BYPASS" policy, so rate limiting is bypassed entirely.
    -- This works because the "request_headers" directive of the rate_limits filter
    -- will not construct a descriptor if the header is missing.
    if ratelimit_class ~= "BYPASS" then
        headers:replace("x-wmf-ratelimit-class", ratelimit_class)
    end
end

function wmf_ratelimit_class_for_address( address, fallback )
    for prefix, class in pairs( HelmValues.main_app.ratelimiter.anon_class_by_address ) do
        -- NOTE: Use naive prefix matching for now. If we need proper range matching,
        -- we could use <https://github.com/api7/lua-resty-ipmatcher> or similar.
        if string.find( address, prefix, 1, true ) == 1 then
            return class
        end
    end

    return fallback
end

function wmf_stash_headers_to_expose(request_handle)
    local req_headers = request_handle:headers()
    local streamMeta = request_handle:streamInfo():dynamicMetadata()
    local exposed_headers = HelmValues.main_app.ratelimiter.exposed_headers

    for _, hname in ipairs(exposed_headers) do
        local hvalue = req_headers:get(hname)
        if hvalue then
            streamMeta:set("envoy.wmf_expose_headers", hname, hvalue)
        end
    end
end

function wmf_expose_headers(response_handle)
    local streamMeta = response_handle:streamInfo():dynamicMetadata()
    local req_headers = streamMeta:get("envoy.wmf_expose_headers")
    local exposed_headers = HelmValues.main_app.ratelimiter.exposed_headers

    if not req_headers then
        return
    end

    local resp_headers = response_handle:headers()
    for _, hname in ipairs(exposed_headers) do
        local hvalue = req_headers[hname]
        if hvalue then
            resp_headers:replace(hname, hvalue)
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

