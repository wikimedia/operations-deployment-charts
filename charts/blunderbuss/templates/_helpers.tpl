{{/* Represents a Go variable as a literal Python value */}}
{{- define "toPython" -}}
{{- if kindIs "string" .value -}}
{{- .value | quote }}
{{- else if kindIs "float64" .value -}}
{{- .value }}
{{- else if kindIs "int64" .value -}}
{{- .value }}
{{- else if kindIs "bool" .value -}}
{{- .value | toString | camelcase }}
{{- else if kindIs "slice" .value -}}
[{{- range $i, $item := .value -}}{{- template "toPython" (dict "value" $item) -}}{{- if lt  $i (sub (len $.value) 1) }}, {{- else -}}]{{- end -}}{{- end -}}
{{- else if kindIs "map" .value -}}
{ {{- range $key, $val := .value }}{{ $key | quote }}: {{ template "toPython" (dict "value" $val) }},{{- end -}} }
{{- end -}}
{{- end -}}
