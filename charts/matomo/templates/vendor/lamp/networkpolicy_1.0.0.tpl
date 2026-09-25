{{- define "lamp.networkpolicy.ingress" }}
- port: {{ .Values.app.port }}
  protocol: TCP
{{- if .Values.monitoring.enabled }}
# httpd-exporter
- port: 9117
  protocol: TCP
# php-fpm-exporter
- port: 9118
  protocol: TCP
# php-level monitoring
- port: 9181
  protocol: TCP
{{- end }}
{{- end }}