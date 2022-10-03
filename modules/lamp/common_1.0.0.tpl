{{- define "lamp.common.socket" }}
  {{- if eq .Values.lamp.fcgi_mode "FCGI_UNIX" }}
# Shared unix socket for php apps
- name: shared-socket
  emptyDir: {}
  {{- end -}}
{{- end }}
{{- define "lamp.common.baseurl" -}}
http://{{ template "base.name.release" . }}:{{ .Values.app.port }}
{{- end -}}
