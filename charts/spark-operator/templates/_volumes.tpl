{{ define "wmf.volumes" }}
{{- $has_volumes := 0 -}}
{{- if .Values.app.volumes }}
  {{- $has_volumes = 1 -}}
{{- else }}
  {{/*Yes this is redundant but it's more readable*/}}
  {{- $has_volumes = 0 -}}
{{- end}}
{{- if eq $has_volumes 1 }}
{{- with .Values.app.volumes }}
    {{- toYaml . }}
{{- end }}
{{- else }}
[]
{{- end }}
{{ end }}
