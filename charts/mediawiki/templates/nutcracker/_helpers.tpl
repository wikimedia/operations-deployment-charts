{{/*
  Nutcracker configuration template
*/}}
{{- define "nutcracker.config" }}
{{- $pwd := .Values.mw.nutcracker.redis_password -}}
{{- range .Values.mw.nutcracker.pools }}
redis_{{ .name }}:
  auto_eject_hosts: true
  distribution: ketama
  hash: md5
  # We use TCP here because:
  # 1 - performance for nutcracker is not fundamental
  # 2 - Using a  unix socket would force us to define
  #     a securityContext and run this container as www-data.
  listen: 127.0.0.1:{{ .port }}
  redis: true
  redis_auth: {{ $pwd }}
  server_connections: 1
  server_failure_limit: 3
  server_retry_timeout: 30000
  servers:
  {{- range .servers }}
  - {{.host }}:{{ .port }}:1 "{{ .shard }}"
  {{- end -}}
{{- end -}}
{{- end -}}
{{- define "nutcracker.annotations" -}}
{{- if .Values.mw.nutcracker.enabled }}
checksum/nutcracker: {{ include "nutcracker.config" . | sha256sum }}
{{- end }}
{{- end -}}