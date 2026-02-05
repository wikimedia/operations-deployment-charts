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
            default_policies = {
                {{ range $policy := .Values.main_app.ratelimiter.default_policies -}}
                "{{ $policy }}",
                {{- end }}
            },
            ratelimit_notice_text = "{{ replace "\n" "\\\n" .Values.main_app.ratelimiter.ratelimit_notice_text }}"
        }
    }
}

-- From lua/restgateway.lua:

{{ .Files.Get "lua/restgateway.lua" }}
{{- end }}
