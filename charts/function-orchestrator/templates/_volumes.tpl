{{ define "wmf.volumes" }}
{{- $has_volumes := 0 -}}
{{ if (.Values.tls.enabled) }}
  {{- $has_volumes = 1 -}}
{{ else if .Values.main_app.volumes }}
  {{- $has_volumes = 1 -}}
{{ else if and (eq .Values.main_app.type "php") (eq (dig "php" "fcgi_mode" "" (.Values | merge (dict))) "FCGI_UNIX")}}
  {{- $has_volumes = 1 -}}
{{ else }}
  {{/*Yes this is redundant but it's more readable*/}}
  {{- $has_volumes = 0 -}}
{{end}}
{{ if eq $has_volumes 1 }}
  {{- if eq .Values.main_app.type "php" }}
# Shared unix socket for php apps
- name: shared-socket
  emptyDir: {}
  {{- end -}}
# TLS configurations
{{- include "tls.volume" . }}
# Additional app-specific volumes.
{{ with .Values.main_app.volumes }}
    {{- toYaml . }}
{{- end }}
{{ else }}
[]
{{- end }}
{{ end }}
