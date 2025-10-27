{{- define "restgateway.lua" }}
function envoy_on_request(request_handle)
    wmf_ratelimit_info(request_handle)
end

function wmf_ratelimit_info(request_handle)
    local headers = request_handle:headers()
    local streamInfo = request_handle:streamInfo()
    local user_id = "unknown"
    local user_class = "anon"

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
        if cookies["centralauth_User"] and cookies["centralauth_User"] ~= "#NONE#" then
          user_id = cookies["centralauth_User"]
          user_class = "cookie-user"
        end
    end

    request_handle:logDebug("WMF rate_limit subject: " .. user_class
            .. ", user id: " ..  user_id
    )

    meta:set( "wmf.rest_gateway.rate_limit", "user_class", user_class )
    meta:set( "wmf.rest_gateway.rate_limit", "user_id", user_id )
end

function envoy_on_response(response_handle)
    wmf_csp_header(response_handle)
end

function wmf_csp_header(response_handle)
   local headers = response_handle:headers()
   local csp

   if headers:get("content-security-policy") ~=nil then
      csp = headers:get("content-security-policy")
   else
      csp = "default-src 'none'; frame-ancestors 'none'"
   end

   headers:replace('content-security-policy', csp)
end
{{- end }}
