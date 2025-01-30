{{- $flags := fromJson (include "mw.feature_flags" . ) }}
{{- if $flags.web }}
{{ include "ingress.istio.default" . }}
{{- end }}
