{{/*
  toLua: recursively converts a Helm value (map, slice, string, number, bool, nil)
  into a Lua literal. Usage: {{ include "toLua" .someValue }}
  For maps, string keys are quoted; numeric-looking keys use [n] syntax.
*/}}
{{- define "toLua" -}}
  {{- if kindIs "map" . -}}
    {
    {{- range $k, $v := . }}
        ["{{ $k }}"] = {{ include "toLua" $v | indent 4 | trim }},
    {{- end }}
    }
  {{- else if kindIs "slice" . -}}
    {
    {{- range . }}
        {{ include "toLua" . }},
    {{- end }}
    }
  {{- else if kindIs "string" . -}}
      {{ . | replace "\\" "\\\\" | replace "\"" "\\\"" | replace "\n" "\\n" | quote }}
  {{- else if kindIs "bool" . -}}
      {{ if . }}true{{ else }}false{{ end }}
  {{- else if kindIs "invalid" . -}}
      nil
  {{- else -}}
      {{ . }}
  {{- end -}}
{{- end -}}

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
            ratelimit_notice_text = "{{ replace "\n" "\\\n" .Values.main_app.ratelimiter.ratelimit_notice_text }}",
            class_overrides = {{ include "toLua" .Values.main_app.ratelimiter.class_overrides | indent 8 | trim }},
            default_policies = {{ include "toLua" .Values.main_app.ratelimiter.default_policies | indent 8 | trim }},
            exposed_headers = {{ include "toLua" .Values.main_app.ratelimiter.exposed_headers | indent 8 | trim }},
        }
    }
}

-- From lua/restgw_ratelimits.lua:
{{ .Files.Get "lua/restgw_ratelimits.lua" }}
{{- end }}
