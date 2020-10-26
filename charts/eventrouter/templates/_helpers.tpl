{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "eventrouter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "eventrouter.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "eventrouter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Generate basic labels */}}
{{- define "eventrouter.labels" }}
app: {{ template "eventrouter.name" . }}
heritage: {{.Release.Service }}
release: {{.Release.Name }}
chart: {{ template "eventrouter.chart" . }}
{{- if .Values.podLabels}}
{{ toYaml .Values.podLabels }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "eventrouter.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "eventrouter.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create kubernetes master/api environment variables
*/}}
{{- define "kubernetesApiEnv" -}}
- name: KUBERNETES_PORT_443_TCP_ADDR
  value: "{{ .Values.kubernetesApi.host }}"
- name: KUBERNETES_SERVICE_HOST
  value: "{{ .Values.kubernetesApi.host }}"
- name: KUBERNETES_SERVICE_PORT
  value: "{{ .Values.kubernetesApi.port }}"
- name: KUBERNETES_SERVICE_PORT_HTTPS
  value: "{{ .Values.kubernetesApi.port }}"
- name: KUBERNETES_PORT
  value: "{{ printf "tcp://%s:%s" .Values.kubernetesApi.host .Values.kubernetesApi.port}}"
- name: KUBERNETES_PORT_443_TCP
  value: "{{ printf "tcp://%s:%s" .Values.kubernetesApi.host .Values.kubernetesApi.port}}"
- name: KUBERNETES_PORT_443_TCP_PORT
  value: "{{ .Values.kubernetesApi.port }}"
{{- end -}}
