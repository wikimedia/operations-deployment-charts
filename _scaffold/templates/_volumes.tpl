{{- define "volumes.lamp" -}}
# httpd custom configuration.
{{- include "lamp.httpd.volume" . }}
# Shared unix socket
{{- include "lamp.common.socket" . }}
# Application configuration, in /srv/app/config.json
{{- include "lamp.phpfpm.volume" . }}
{{- end }}

{{- define "volumes.generic" }}
{{- if (or .Values.app.volumes .Values.mesh.enabled) }}
{{ include "app.generic.volume" . }}
{{ include "mesh.deployment.volume" . }}
{{- else }}
[]
{{- end }}
{{- end }}