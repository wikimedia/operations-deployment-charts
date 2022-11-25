{{- define "wmf.volumes" -}}
{{- $has_volumes := 0 -}}
{{- if (.Values.mesh.enabled) -}}
  {{- $has_volumes = 1 -}}
{{- else if .Values.main_app.volumes -}}
  {{- $has_volumes = 1 -}}
{{- else if .Values.mcrouter.enabled -}}
  {{/* Ugh. Needed here because of the way this collection is guarded. */}}
  {{- $has_volumes = 1 -}}
{{- else -}}
  {{/* Yes this is redundant but it's more readable */}}
  {{- $has_volumes = 0 -}}
{{- end }}
{{- if eq $has_volumes 1 -}}
{{- include "mesh.deployment.volume" . }}
{{- include "mcrouter.volume" . }}
  {{- with .Values.main_app.volumes }}
    {{- toYaml . }}
  {{- end }}
{{ else }}
[]
{{- end }}
{{- end }}{{/* "wmf.volumes" */}}
