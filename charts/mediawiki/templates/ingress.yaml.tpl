{{- if .Values.mw.httpd.enabled }}
{{ include "ingress.istio.default" . }}
{{- end }}
