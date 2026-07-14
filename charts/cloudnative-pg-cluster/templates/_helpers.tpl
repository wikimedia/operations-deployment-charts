{{/*
Expand the name of the chart.
*/}}
{{- define "cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cluster.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cluster.labels" -}}
helm.sh/chart: {{ include "cluster.chart" . }}
{{ include "cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: cloudnative-pg
{{- end }}

{{- define "cluster.imagecatalog.name" -}}
{{ include "cluster.fullname" . }}-catalog
{{- end }}

{{/*
Name of the service that ingress traffic is forwarded to: the PgBouncer pooler
service when the pooler is enabled, the cluster rw service otherwise.
*/}}
{{- define "cluster.ingress.destinationService" -}}
{{- if .Values.ingress.destinationService -}}
{{- .Values.ingress.destinationService -}}
{{- else if .Values.pooler.enabled -}}
{{- include "cluster.fullname" . }}-pooler-rw
{{- else -}}
{{- include "cluster.fullname" . }}-rw
{{- end -}}
{{- end -}}

{{/*
The Cluster certificates configuration. When ingress is enabled and the server
certificate is operator-managed, the ingress FQDNs are merged into
serverAltDNSNames, so that the issued certificate is valid for the
externally-visible hostnames and clients can use sslmode=verify-full.
*/}}
{{- define "cluster.certificates" -}}
{{- $certificates := deepCopy (.Values.cluster.certificates | default dict) -}}
{{- if and .Values.ingress.enabled (not $certificates.serverTLSSecret) -}}
{{- $serverAltDNSNames := concat ($certificates.serverAltDNSNames | default list) .Values.ingress.hosts | uniq -}}
{{- $_ := set $certificates "serverAltDNSNames" $serverAltDNSNames -}}
{{- end -}}
{{- with $certificates }}
certificates:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "base.helper.restrictedSecurityContext" }}
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
     drop:
     - ALL
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
{{- end -}}

{{/*
  Recursively evaluate a value until it is no longer if the form of a helm template.
  We need this template to be recursive because we could have a setup of the following form

  x: "hi"
  y: "{{ $.Values.x }}"
  z: "{{ $.Valuez.y }}"

  z would first be evaluated to "{{ $.Values.x }}", and when recursively evaluated once more,
  it would finally be evaluated to "hi".

*/}}
{{- define "evalValue" -}}
{{- if and (kindIs "string" .value ) (and (contains "{{" .value) (contains "}}" .value)) }}
{{- /* We're dealing with a value itself containing a helm template expression that we evaluate at runtime */}}
{{- $evaluatedValue := tpl .value .Root -}}
{{- include "evalValue" (dict "value" $evaluatedValue "Root" .Root) -}}
{{- else }}
{{- .value -}}
{{- end -}}
{{- end -}}
