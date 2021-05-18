{{- define "fluent-bit.config" }}
[SERVICE]
    Daemon Off
    Log_Level debug
    Parsers_File /etc/td-agent-bit/td-agent-parsers.conf

[INPUT]
    Name tail
    Path /var/log/access.log
    Parser json

{{ if .Values.main_app.access_log.debug -}}
[OUTPUT]
    Name stdout
    Match *
    Format json
{{- end }}

[OUTPUT]
    Name http
    Match *
    Format json
    Host {{ .Values.main_app.access_log.event_service.host }}
    Port {{ .Values.main_app.access_log.event_service.port }}
    URI {{ .Values.main_app.access_log.event_service.path }}
{{- if .Values.main_app.access_log.tls }}
    tls On
{{- if .Values.puppet_ca_crt }}
    tls.verify On
    tls.ca_file /etc/td-agent-bit/puppetca.crt.pem
{{- else }}
    tls.verify Off
{{- end }}
{{- end }}

{{ end }}