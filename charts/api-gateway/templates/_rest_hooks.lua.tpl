{{- define "restgateway.lua" }}
{{/*
 Generate a Lua table containing the relevant bits from .Values.
 This code runs once, in global scope.
 If needed we could replicate the entire .Values structure recursively.
*/}}

-- Relevant bits from Helm's .Values structure.
HelmValues = {
    main_app = {
        ratelimiter = {
            fallback_class = "{{ .Values.main_app.ratelimiter.fallback_class }}",
            user_id_cookie = "{{ .Values.main_app.ratelimiter.user_id_cookie }}",
        }
    }
}

-- From lua/restgateway.lua:

{{ .Files.Get "lua/restgateway.lua" }}
{{- end }}
