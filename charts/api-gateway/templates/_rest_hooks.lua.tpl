{{- define "restgateway.lua" }}
function envoy_on_request(request_handle)
    wmf_ratelimit_info(request_handle)
    wmf_ratelimit_cleanup(request_handle)
end

function wmf_ratelimit_info(request_handle)
    local headers = request_handle:headers()
    local streamInfo = request_handle:streamInfo()
    local ratelimit_class = "{{ .Values.main_app.ratelimiter.fallback_class }}"
    local trusted_identity_cookie = "{{ .Values.main_app.ratelimiter.user_id_cookie }}"

    -- The x-client-ip header is set in the edge tier of the WMF network.
    -- If it not present, the request is internal and should not be limited.
    local client_ip = headers:get("x-client-ip")
    if not client_ip then
        return
    end

    -- Use the client IP as the fallback use ID.
    local user_id = client_ip

    if headers:get("x-wmf-user-id") then
        -- Proxy strips x-wmf-user-id and x-wmf-ratelimit-class passed from the client
        -- This code reinjects the appropriate rate-limiter headers.
        -- When ratelimit.allow_client_headers is enabled, clients may pass their own disabling this logic
        if not headers:get("x-wmf-ratelimit-class") then
            headers:add("x-wmf-ratelimit-class", ratelimit_class)
        end
        return
    end

    -- relevant cookies have been copied to dynamic metadata using envoy.filters.http.header_to_metadata
    local streamMeta = streamInfo:dynamicMetadata()
    local cookies = streamMeta:get("envoy.wmf_cookies")
    if cookies then
        -- NOTE: This is totally unsafe. We will get the user ID from jwt_authn soon.
        if cookies[trusted_identity_cookie] and cookies[trusted_identity_cookie] ~= "#NONE#" then
          user_id = cookies[trusted_identity_cookie]
          ratelimit_class = "cookie-user"
        end
    end

    -- Determine policy to apply, based on route meta data
    local routeMeta = request_handle:metadata()
    local ratelimit_policy = routeMeta:get("wmf_ratelimit")["policy"]

    request_handle:logDebug("WMF rate_limit: class=" .. ( ratelimit_class or "~" )
            .. ", user=" .. ( user_id or "~" ) .. ", policy=" ..  ( ratelimit_policy or "~" )
    )

    headers:replace("x-wmf-user-id", user_id)
    headers:replace("x-wmf-ratelimit-class", ratelimit_class)
    headers:replace("x-wmf-ratelimit-policy", ratelimit_policy)
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
{{- end }}
