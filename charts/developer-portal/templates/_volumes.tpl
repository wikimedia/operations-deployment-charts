{{ define "wmf.volumes" }}
{{- $has_volumes := 0 -}}
{{ if (.Values.mesh.enabled) }}
  {{- $has_volumes = 1 -}}
{{ else if .Values.main_app.volumes }}
  {{- $has_volumes = 1 -}}
{{ else if (and .Values.monitoring.enabled .Values.monitoring.uses_statsd) }}
  {{- $has_volumes = 1 -}}
{{ else if (and (eq .Values.main_app.type "php") (eq .Values.php.fcgi_mode "FCGI_UNIX") )}}
  {{- $has_volumes = 1 -}}
{{ else }}
  {{/*Yes this is redundant but it's more readable*/}}
  {{- $has_volumes = 0 -}}
{{end}}
{{ if eq $has_volumes 1 }}
  {{- if eq .Values.main_app.type "php" }}
# Shared unix socket for php apps
- name: shared-socket
  emptydir: {}
  {{- end -}}
  {{- if and .Values.monitoring.enabled .Values.monitoring.uses_statsd }}
# Prometheus statsd exporter configuration
- name: {{ .Release.Name }}-metrics-exporter
  configMap:
      name: {{ template "base.name.release" . }}-metrics-config
  {{- end }}
# TLS configurations
{{- include "mesh.deployment.volume" . }}
# Additional app-specific volumes.
  {{- with .Values.main_app.volumes }}
    {{- toYaml . }}
  {{- end }}
{{ else }}
[]
{{- end }}
{{end}}
