{{- define "restgateway.lua" }}
function envoy_on_request(request_handle)
    wmf_ratelimit_info(request_handle)
    wmf_ratelimit_cleanup(request_handle)
end

function wmf_ratelimit_info(request_handle)
    local headers = request_handle:headers()
    local streamInfo = request_handle:streamInfo()
    local user_id = "unknown"
    local user_class = "{{ .Values.main_app.ratelimiter.fallback_policy }}"
    local trusted_identity_cookie = "{{ .Values.main_app.ratelimiter.user_id_cookie }}"

    if headers:get("x-wmf-user-id") then
        -- Proxy strips x-wmf-user-id and x-wmf-user-class passed from the client
        -- This code reinjects the appropriate rate-limiter headers.
        -- When ratelimit.allow_client_headers is enabled, clients may pass their own disabling this logic
        if not headers:get("x-wmf-user-class") then
            headers:add("x-wmf-user-class", user_class)
        end
        return
    end

    if headers:get("x-client-ip") then
        -- The x-client-ip header is set in the edge tier of the WMF network.
        user_id = headers:get("x-client-ip")
    elseif streamInfo.downstreamRemoteAddress then
        -- downstreamRemoteAddress() was not available in older versions of Envoy.
        -- In that case, just keep user_id = "unknown".
        local addr = streamInfo:downstreamRemoteAddress()
        user_id = string.match(addr, "([^:]+)")
    end

    -- relevant cookies have been copied to metadata using envoy.filters.http.header_to_metadata
    local meta = streamInfo:dynamicMetadata()
    local cookies = meta:get("envoy.wmf_cookies")
    if cookies then
        -- NOTE: This is totally unsafe. We will get the user ID from jwt_authn soon.
        if cookies[trusted_identity_cookie] and cookies[trusted_identity_cookie] ~= "#NONE#" then
          user_id = cookies[trusted_identity_cookie]
          user_class = "cookie-user"
        end
    end

    request_handle:logDebug("WMF rate_limit subject: " .. user_class
            .. ", user id: " ..  user_id
    )

    headers:replace("x-wmf-user-id", user_id)
    headers:replace("x-wmf-user-class", user_class)
end

function wmf_ratelimit_cleanup(request_handle)
    local headers = request_handle:headers()

    if headers:get("x-wmf-user-class") == "no-limit" then
        -- removing the header completely disables rate limiting, because
        -- the "request_headers" directive of the rate_limits section will
        -- fail to construct a rate limit descriptor if the header is missing.
        headers:remove("x-wmf-user-class")
    end
end
{{- end }}
