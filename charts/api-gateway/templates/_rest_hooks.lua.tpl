{{- define "restgw_headers.lua" }}
-- From lua/restgw_headers.lua:
{{ .Files.Get "lua/restgw_headers.lua" }}
{{- end }}

{{- define "restgw_ratelimits.lua" }}
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
            browser_threshold = {{ .Values.main_app.ratelimiter.browser_threshold }},
            anon_class_by_address = {
                {{- range $addr, $class := .Values.main_app.ratelimiter.anon_class_by_address }}
                ["{{ $addr }}"] = "{{ $class }}",
                {{- end}}
            },
            default_policies = {
                {{ range $policy := .Values.main_app.ratelimiter.default_policies -}}
                "{{ $policy }}",
                {{- end }}
            },
            exposed_headers = {
                {{ range $header := .Values.main_app.ratelimiter.exposed_headers -}}
                "{{ $header }}",
                {{- end }}
            },
            ratelimit_notice_text = "{{ replace "\n" "\\\n" .Values.main_app.ratelimiter.ratelimit_notice_text }}"
        }
    }
}

-- From lua/restgw_ratelimits.lua:
{{ .Files.Get "lua/restgw_ratelimits.lua" }}
{{- end }}
