{{/*
== Functions for metadata management

 - base.meta-name: returns the standard object name for objects we define.
   Usage:
   {{- include "base.meta.name" (dict "Root" . "Name" "object-name" ) | indent 2 }}
 - base.meta.metadata: returns the standard set of metadata we add to basically
   any object we define.
   Usage:
   {{- include "base.meta.metadata" (dict "Root" . "Name" "object-name" ) | indent 2 }}
 - base.meta.routing: labels for traffic routing between service and deployments.
*/}}
{{- define "base.meta.name" -}}
{{ template "base.name.release" .Root }}{{- if .Name }}-{{ .Name }}{{ end }}
{{- end -}}

{{- define "base.meta.metadata" }}
name: {{ template "base.meta.name" . }}
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
checksum/secrets: {{ include "base.helper.resourcesDataChecksum" (dict "resourceFilePath" "/secret.yaml" "Root" $) }}
checksum/configuration: {{ include "base.helper.resourcesDataChecksum" (dict "resourceFilePath" "/configmap.yaml" "Root" $) }}
{{- if .Values.monitoring.enabled }}
{{- if .Values.monitoring.named_ports }}
prometheus.io/scrape_by_name: "true"
{{- else }}
prometheus.io/scrape: "true"
{{- end }}
{{- end }}
{{- end }}