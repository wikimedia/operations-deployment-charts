{{- define "fluent-bit.config" }}
[SERVICE]
    Daemon Off
    Log_Level debug
    Parsers_File /etc/td-agent-bit/td-agent-parsers.conf

[INPUT]
    Name tail
    Path /var/log/access.log
    Parser json

# TODO: workaround for T260820
[FILTER]
    Name lua
    Match *
    Script /etc/td-agent-bit/td-agent-filter.lua
    Call replace_client_id

[FILTER]
    Name nest
    Match *
    Operation nest
    Wildcard meta.*
    Nest_under meta
    Remove_prefix meta.

[FILTER]
    Name nest
    Match *
    Operation nest
    Wildcard http.request_headers.*
    Nest_under http.request_headers
    Remove_prefix http.request_headers.

[FILTER]
    Name nest
    Match *
    Operation nest
    Wildcard http*
    Nest_under http
    Remove_prefix http.

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
    Header Content-Type application/json

{{ end }}