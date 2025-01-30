{{- $can_run := include "mw.can_run" . | include "mw.str2bool" }}
{{- if $can_run }}
{{ include "cache.mcrouter.configmap" . }}
{{- end }}
