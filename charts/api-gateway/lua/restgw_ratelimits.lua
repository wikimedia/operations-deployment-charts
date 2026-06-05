-- Note: HelmValues is defined in _rest_hooks.lua.tpl

-- Turn class_overrides into a lookup structure per class and header
overrides_by_class = {}
for _, entry in ipairs(HelmValues.main_app.ratelimiter.class_overrides) do
    for cls, _ in pairs(entry.mappings) do
        if overrides_by_class[cls] == nil then
            overrides_by_class[cls] = {}
        end
        overrides_by_class[cls][entry.header] = entry
    end
end

function envoy_on_request(request_handle)
    wmf_run_hooks(request_handle, "request")
    wmf_extract_debug_flags(request_handle)
    wmf_ratelimit_info(request_handle)
    wmf_stash_headers_to_expose(request_handle)
end

function envoy_on_response(response_handle)
    wmf_expose_headers(response_handle)
    wmf_set_status(response_handle)
    wmf_set_retry_after(response_handle)
    wmf_run_hooks(response_handle, "response")
end

function wmf_run_hooks(handle, phase)
    local hooks_meta = handle:metadata():get("wmf_hooks")
    if not hooks_meta then return end
    local hooks = hooks_meta[phase] or {}
    for _, hook_name in ipairs(hooks) do
        local hook_fn = _G[hook_name]
        if type(hook_fn) == "function" then
            -- NOTE: hook errors are not caught. A hook that raises a Lua error will abort
            -- the filter and may result in a 500 or an unmodified pass-through, depending
            -- on Envoy's error handling. This is intentional: hooks used for security-
            -- sensitive logic (e.g. auth checks) should fail closed rather than silently.
            hook_fn(handle)
        else
            handle:logWarn("WMF lua hooks: unknown hook function: " .. tostring(hook_name))
        end
    end
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
        headers:remove("x-wmf-timelimit-policy-" .. tostring(i))
        headers:remove("x-wmf-ratelimit-cost-" .. tostring(i))
    end

    -- Use the client IP as the fallback use ID.
    local user_id = nil

    -- Determine policies to apply, based on route meta data
    local routeMeta = request_handle:metadata()
    local routeMeta_ratelimit = routeMeta:get("wmf_ratelimit") or {}

    local ratelimit_policies = routeMeta_ratelimit["policies"] or {}
    for i, p in ipairs(ratelimit_policies) do
        -- Determine the header name for the measure being limited (requests, time, etc)
        -- Different rate-limit descriptors are defined for different headers.
        -- Which header is set here controls which descriptors will be sent to the
        -- ratelimit service.
        local policy = HelmValues.main_app.ratelimiter.policies[p]

        -- We take the per-request upfront cost from the policy for now, but we could take
        -- a multiplier from routeMeta in the future.
        local cost = policy and policy.upfront_cost or 1

        local policy_header = "x-wmf-ratelimit-policy"
        if policy and policy.measure then
            if policy.measure == "time" then
                -- setting this header causes cost-based
                policy_header = "x-wmf-timelimit-policy"
            end
        end

        -- No header for the "BYPASS" policy, so rate limiting is bypassed entirely.
        if p == "BYPASS" then
            policy_header = nil
        end

        if policy_header then
            request_handle:logDebug("WMF rate_limit: policy-" .. tostring(i) .. "=" .. p)
            headers:replace(policy_header .. "-" .. tostring(i), p)
            headers:replace("x-wmf-ratelimit-cost-" .. tostring(i), tostring(cost))
        end
    end

    -- relevant cookies have been copied to dynamic metadata using envoy.filters.http.header_to_metadata
    local streamMeta = streamInfo:dynamicMetadata()
    local cookies = streamMeta:get("envoy.wmf_cookies") or {}

    -- Payload from sessionJwt cookie from envoy.filters.http.jwt_authn.
    local jwtMeta = streamMeta:get("envoy.filters.http.jwt_authn") or {}
    local cookiePayload = jwtMeta.cookie_payload or {}

    -- Authorization header payload (Bearer or CentralAuthToken) from envoy.filters.http.jwt_authn.
    -- Only one of them should be present, see https://github.com/httpwg/http-core/issues/180
    -- and https://community.auth0.com/t/authorization-headers-on-request-with-multiple-schemes/8349.
    local bearerPayload = jwtMeta.bearer_payload or {}
    local centralauthPayload = jwtMeta.centralauth_payload or {}

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

    elseif centralauthPayload.rlc then
        -- T420280: Use rate limit class from centralauth token
        ratelimit_class = centralauthPayload.rlc

    elseif bearerPayload.rlc then
        -- We trust that long-lived tokens don't have an rlc field.
       -- TODO: Ignore stale rlc field if the token is older than a day (check iat field).
        -- That shouldn't happen, since long-lived tokens shouldn't have an rlc field.
        -- But if they do, we shouldn't use it, we should use the cookie's rlc instead.
        ratelimit_class = bearerPayload.rlc

    elseif cookiePayload.rlc then
        -- T418042: Use the rlc field from a session cookie if it is present.
        ratelimit_class = cookiePayload.rlc

    elseif bearerPayload.sub or cookiePayload.sub or centralauthPayload.sub then
        -- Fallback class for authenticated users with no explicit rlc claim.
        ratelimit_class = "authed-user"

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
        ratelimit_class = "anon-browser"

    else
        local anon_class = HelmValues.main_app.ratelimiter.fallback_class -- defaults to "anon"
        ratelimit_class = anon_class
    end

    if centralauthPayload.sub then
        user_id = "jwt-sub:" .. centralauthPayload.sub
    elseif bearerPayload.sub and bearerPayload.rlc then -- has rlc field, it's an access token
        user_id = "jwt-sub:" .. bearerPayload.sub
    elseif cookiePayload.sub then -- preferred to owner-only
        user_id = "jwt-sub:" .. cookiePayload.sub
    elseif bearerPayload.sub then -- no rlc field, probably owner-only
        user_id = "jwt-sub:" .. bearerPayload.sub
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

    ratelimit_class = wmf_apply_class_overrides( request_handle, ratelimit_class )

    request_handle:logDebug("WMF rate_limit: class=" .. ( ratelimit_class or "~" )
            .. ", user=" .. ( user_id or "~" )
    )

    headers:replace("x-wmf-user-id", user_id)

    -- No header for the "BYPASS" policy, so rate limiting is bypassed entirely.
    -- This works because the "request_headers" directive of the rate_limits filter
    -- will not construct a descriptor if the header is missing.
    if ratelimit_class ~= "BYPASS" then
        headers:replace("x-wmf-ratelimit-class", ratelimit_class)
    end

    wmf_run_hooks(request_handle, "ratelimit")
end

function wmf_apply_class_overrides( request_handle, ratelimit_class )
    local overrides = overrides_by_class[ratelimit_class] or {}
    local headers = request_handle:headers()

    for header, entry in pairs( overrides ) do
        local value = headers:get(header)
        local found = false

        if not found and value and entry.values then
            for _, expected in ipairs( entry.values or {} ) do
                if value == expected then
                    found = true
                    break
                end
            end
        end

        if not found and value and entry.patterns then
            for _, ptrn in ipairs( entry.patterns or {} ) do
                if value:find(ptrn) then
                    found = true
                    break
                end
            end
        end

        if found then
            return entry.mappings[ratelimit_class] or ratelimit_class
        end
    end

    -- If we didn't find any match, try for class '*'.
    if ratelimit_class ~= '*' then
        local cls = wmf_apply_class_overrides( request_handle, '*' )
        if cls ~= '*' then
            ratelimit_class = cls
        end
    end

    return ratelimit_class
end

-- extract flags from x-wmf-debug-flags header
function wmf_extract_debug_flags(request_handle)
    local headers = request_handle:headers()
    local flags_str = headers:get("x-wmf-debug-flags")

    -- If the header is not set, exit. This is the usual case.
    if not flags_str then
        return
    end

    -- Strip the header in all cases, even if we do not act on it.
    headers:remove("x-wmf-debug-flags")

    -- Debug flags must be enabled in config
    if not HelmValues.main_app.ratelimiter.honor_debug_flags then
        return
    end

    -- Debug flags are not allowed on external requests
    if headers:get("x-client-ip") then
        return
    end

    local flags = {}
    for flag in string.gmatch(flags_str, "[^%s,]+") do
        flags[flag] = true
    end

    request_handle:streamInfo():dynamicMetadata():set( "envoy.wmf_debug_flags", "flags", flags )
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
        local reqid = headers:get("x-request-id")
        headers:replace("retry-after", reset)

        if headers:get("x-ratelimit-remaining") == "0" then
            headers:replace("content-type", "text/plain")
            local text = HelmValues.main_app.ratelimiter.ratelimit_notice_text

            if reqid then
                text = text .. "\n\nrequest-id: " .. reqid
            end

            response_handle:body():setBytes( text )
        end
    end
end

function wmf_set_status(response_handle)
    local headers = response_handle:headers()

    local status_header = headers:get(":status")

    if status_header ~= "429" then
        return
    end

    -- Some tests want to force a 429 response using the DENY policy.
    -- So don't override the status if the keep-429-on-zero-limit flag is set.
    local debug_flags = response_handle:streamInfo():dynamicMetadata():get( "envoy.wmf_debug_flags" )
    if debug_flags and debug_flags.flags and debug_flags.flags["keep-429-on-zero-limit"]
    then
        return
    end

    local limit_header = headers:get("x-ratelimit-limit")
    local limit = limit_header and tonumber(limit_header:match("^(%d+)"))

    -- If the limit was configured to be 0, that means the request is denied completely,
    -- not just exceeding limits.
    if limit == 0 then
        -- Note: We use 401 because we assume that the use case is to allow
        -- authenticated clients but reject unauthenticated clients. Other
        -- use cases may call for a 403 response. We could make this configurable
        -- per policy.
        headers:replace(":status", "401")

        local realm = HelmValues.main_app.jwt and HelmValues.main_app.jwt.issuer
        local challenge = realm and ('Bearer realm="' .. realm .. '"') or 'Bearer'
        headers:replace("WWW-Authenticate", challenge)

        headers:replace("content-type", "text/plain")
        response_handle:body():setBytes("Unauthorized")
    end
end

-- Decode a percent-encoded string.
-- See https://datatracker.ietf.org/doc/html/rfc3986#section-2.1
function wmf_url_decode(str)
    str = string.gsub(str, "+", " ")
    str = string.gsub(str, "%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
    return str
end

-- Parse a query string into a key→value table.
-- On duplicate keys the last value wins.
-- See https://datatracker.ietf.org/doc/html/rfc3986#section-3.4
function wmf_parse_query_params(str)
    local params = {}
    for chunk in string.gmatch(str, "([^&]+)") do
        if chunk ~= "" then
            local key, value = string.match(chunk, "^([^=]+)=(.*)$")
            if key then
                params[wmf_url_decode(key)] = wmf_url_decode(value)
            else
                params[wmf_url_decode(chunk)] = ""
            end
        end
    end
    return params
end

-- Get query parameters from the request.
-- Query parameters are stashed in dynamic metadata, so they will be parsed only once.
function wmf_get_query_params(request_handle)
    local streamMeta = request_handle:streamInfo():dynamicMetadata()
    local params = streamMeta:get("envoy.wmf_query_params")

    if params ~= nil then
        return params
    end

    local headers = request_handle:headers()
    local path = headers:get(":path") or ""
    local query_string = string.match(path, "%?(.*)$") or ""
    local params = wmf_parse_query_params(query_string)

    for key, value in pairs(params) do
        streamMeta:set("envoy.wmf_query_params", key, value)
    end

    return params
end

-- Split a pipe-separated string into a table, where the table keys are
-- the names from the string, and all values are true.
-- Note that MediaWiki also supports U+001F as a separator.
-- This is not supported here.
function wmf_split_multi_value_param(str)
    if str == nil then
        return nil
    end

    local set = {}
    for value in string.gmatch(str, "([^|]+)") do
        if value ~= "" then
            set[value] = true
        end
    end
    return set
end

-- hook handler for bypassing rate limits for certain action API calls
function wmf_handle_action_api_nolimit(request_handle)
    local headers = request_handle:headers()
    local method = headers:get(":method")
    local query_params = wmf_get_query_params(request_handle)

    local action = query_params["action"]

    if action == "cspreport" or action == "login" or action == "clientlogin" then
        -- bypass rate limiting for certain actions (regardless of method)
        headers:remove("x-wmf-ratelimit-class")
        return
    end

    if action ~= "query" or method ~= "GET" then
        -- keep rate limit if this isn't a GET request with action=query
        return
    end

    local meta = wmf_split_multi_value_param( query_params["meta"] )
    if not meta then
        -- keep rate limit if this isn't a meta query
       return
    end

    -- Unset allowed meta modules, check that no unallowed modules are left.
    -- Note that all modules that are defined in the route config to this hook
    -- should be listed here, but not all modules listed here need to trigger
    -- exemption from rate limits. E.g. userinfo is not exempt from rate limits,
    -- but should not cancel the exemption when present alongside a module that
    -- is exempt.
    meta["tokens"] = nil
    meta["userinfo"] = nil
    meta["authmanagerinfo"] = nil
    if next(meta) then
        -- keep rate limit because additional meta modules were requested
       return
    end

    if query_params["list"] or query_params["generator"] or query_params["prop"] then
        -- keep rate limit if there are expensive parameters in addition to the meta query
        return
    end

    if query_params["titles"] or query_params["pageids"] or query_params["revids"] then
        -- keep rate limit if there are expensive parameters in addition to the meta query
        return
    end

    -- bypass rate limiting
    headers:remove("x-wmf-ratelimit-class")
end
