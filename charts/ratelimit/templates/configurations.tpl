{{- define "nutcracker.config" }}
redis:
  auto_eject_hosts: true
  distribution: ketama
  hash: md5
  listen: /var/run/nutcracker/ratelimit.sock
  redis: true
  redis_auth: {{ get .Values.config.private "REDIS_AUTH" }}
  server_connections: 1
  server_failure_limit: 3
  server_retry_timeout: 10000
  timeout: 1000
  servers:
  {{- range .Values.nutcracker.servers }}
    - {{ . }}
  {{- end }}
{{- end }}

{{- define "ratelimit.config" }}
{{- range $domain, $descriptors := .Values.app.configuration }}
{{ $domain }}.yaml: |-
  domain: {{ $domain }}
  descriptors:
    {{- toYaml $descriptors | nindent 4 }}
{{- end }}
{{- end }}