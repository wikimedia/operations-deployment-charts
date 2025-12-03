-- -----------------------------------------------------------------------
-- Use test cases in tests/test.lua to protect the logic in this file!
-- -----------------------------------------------------------------------

-- Note: HelmValues is defined in _rest_hooks.lua.tpl

function envoy_on_request(request_handle)
    wmf_ratelimit_info(request_handle)
    wmf_ratelimit_cleanup(request_handle)
end

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
    local user_id = client_ip

    -- Determine policy to apply, based on route meta data
    local routeMeta = request_handle:metadata()
    local routeMeta_ratelimit = routeMeta:get("wmf_ratelimit") or {}
    local ratelimit_policy = routeMeta_ratelimit["policy"] or "MISSING"
    headers:replace("x-wmf-ratelimit-policy", ratelimit_policy)

    -- relevant cookies have been copied to dynamic metadata using envoy.filters.http.header_to_metadata
    local streamMeta = streamInfo:dynamicMetadata()
    local cookies = streamMeta:get("envoy.wmf_cookies") or {}
    if cookies[trusted_identity_cookie] and cookies[trusted_identity_cookie] ~= "#NONE#" then
        -- NOTE: This is totally unsafe. We will get the user ID from jwt_authn soon.
        user_id = cookies[trusted_identity_cookie]
        ratelimit_class = "cookie-user"
    end

    request_handle:logDebug("WMF rate_limit: class=" .. ( ratelimit_class or "~" )
            .. ", user=" .. ( user_id or "~" ) .. ", policy=" ..  ( ratelimit_policy or "~" )
    )

    headers:replace("x-wmf-user-id", user_id)
    headers:replace("x-wmf-ratelimit-class", ratelimit_class)
end

function wmf_ratelimit_cleanup(request_handle)
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
