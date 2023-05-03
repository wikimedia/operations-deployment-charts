{{/*
== Functions for metadata management

 - base.meta.metadata: returns the standard set of medatada we add to basically
   any object we define.
   Usage:
   {{- include "base.meta.metadata" (dict "Root" . "Name" "object-name" ) | indent 2 }}
 - base.meta.routing: labels for traffic routing between service and deployments.
*/}}
{{- define "base.meta.metadata" }}
name: {{ template "base.name.release" .Root }}{{- if .Name }}-{{ .Name }}{{ end }}
{{- include "base.meta.labels" .Root }}
{{- end -}}

{{- define "base.meta.labels" }}
labels:
  app: {{ template "base.name.chart" . }}
  chart: {{ template "base.name.chartid" . }}
  release: {{ .Release.Name }}
  heritage: {{ .Release.Service }}
{{- end }}

{{- define "base.meta.pod_labels" }}
app: {{ template "base.name.chart" . }}
release: {{ .Release.Name }}
routed_via: {{ .Values.routed_via | default .Release.Name }}
{{- end }}

{{- define "base.meta.selector" }}
matchLabels:
  app: {{ template "base.name.chart" . }}
  release: {{ .Release.Name }}
{{- end }}

{{- define "base.meta.pod_annotations" }}
checksum/secrets: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
{{- if .Values.monitoring.enabled }}
prometheus.io/scrape: "true"
{{- end }}
{{- include "mesh.name.annotations" . }}
{{- end }}
