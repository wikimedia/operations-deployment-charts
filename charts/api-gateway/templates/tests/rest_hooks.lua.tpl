{{/* Hack for generating a Lua file. */}}
{{/* Used by tests/get-lua.sh */}}
{{- if .Values.offline_test_mode -}}
LUA: |-
{{ include "restgateway.lua" . | indent 4}}
{{- end -}}