{{- $flags := fromJson (include "mw.helpers.feature_flags" . ) }}
{{- if $flags.web }}
{{ include "ingress.istio.default" . }}
{{- end }}
