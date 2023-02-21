{{- define "restgateway.lua" }}
function envoy_on_response(response_handle)

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
