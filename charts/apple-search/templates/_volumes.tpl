{{ define "wmf.volumes" }}
  {{- if eq .Values.main_app.type "php" }}
# Shared unix socket for php apps
- name: shared-socket
  emptyDir: {}
  {{- end -}}
  {{- if and .Values.monitoring.enabled .Values.monitoring.uses_statsd }}
# Prometheus statsd exporter configuration
- name: {{ .Release.Name }}-metrics-exporter
  configMap:
      name: {{ template "wmf.releasename" . }}-metrics-config
  {{- end }}
# TLS configurations
{{- include "tls.volume" . }}
# Additional app-specific volumes.
- name: apple-search-config
  configMap:
      name: apple-search-config
  {{ with .Values.main_app.volumes }}
    {{- toYaml . }}
  {{- end }}
{{end}}
