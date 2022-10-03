{{- define "containers.lamp" }}
{{- include "lamp.httpd.container" . }}
## Add any additional volumes for apache configuration here.
## Indentation level: 2
{{- include "lamp.phpfpm.container" . }}
{{- if .Values.monitoring.enabled }}
{{- include "lamp.httpd.exporter" . }}
{{- include "lamp.phpfpm.exporter" . }}
{{- end }}
{{- include "mesh.deployment.container" . }}
{{ end -}}
