{{- define "fluent-bit-parsers.config" }}
[PARSER]
    Name json
    Format json
{{ end }}