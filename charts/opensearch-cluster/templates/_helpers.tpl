{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "opensearch-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "opensearch-cluster.fullname" -}}
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
{{- define "opensearch-cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "opensearch-cluster.labels" -}}
helm.sh/chart: {{ include "opensearch-cluster.chart" . }}
{{ include "opensearch-cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "opensearch-cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opensearch-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "opensearch-cluster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "opensearch-cluster.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "opensearch.destinationRuleTrafficPolicy" -}}
trafficPolicy:
  connectionPool:
    tcp:
      maxConnections: 100
      connectTimeout: 5s
    http:
      # allow persistent HTTP/1.1 connections and control reuse
      http1MaxPendingRequests: 1024
      http2MaxRequests: 1024
      # 0 means "unlimited" (keep-alive allowed). Setting to 1 disables keep-alive.
      maxRequestsPerConnection: 0
      # keep upstream connections idle for up to 1 minute before closing
      idleTimeout: 1m
  tls:
    mode: SIMPLE
    sni: {{ .Release.Namespace }}.discovery.wmnet
    caCertificates: /etc/ssl/certs/wmf-ca-certificates.crt
    subjectAltNames:
    # Default tls-service certificates
    - {{ .Release.Namespace }}.discovery.wmnet
    - {{ $.Values.opensearchCluster.general.serviceName }}.{{ $.Release.Namespace }}.svc.cluster.local
    - {{ $.Values.opensearchCluster.general.serviceName }}-bulk.{{ $.Release.Namespace }}.svc.cluster.local
    {{- range $fqdn := $.Values.certificate.extraFQDNs }}
    - {{ $fqdn }}
    {{- end }}
{{- end }}

{{/*
Define permissions
*/}}
{{- define "opensearch-cluster.anonymous_users_permissions" -}}
cluster_permissions:
  - "cluster:monitor/*"  # read-only cluster-level ops
  - "cluster_monitor"         # allow monitoring endpoints (optional)
index_permissions:
  - index_patterns:
      - "*"           # allow alias listing across all indices
    allowed_actions:
      - "read"
      - "indices:admin/get"
      - "indices_monitor" # use the "indices_monitor" built-in action group, ref https://docs.opensearch.org/latest/security/access-control/default-action-groups/#index-level
{{- end -}}

{{- define "opensearch-cluster.authenticated_users_permissions" -}}
cluster_permissions:
  - "cluster_composite_ops_ro"  # read-only cluster-level ops
  - "cluster_monitor"         # allow monitoring endpoints (optional)
  - "indices:data/write/bulk*"
index_permissions:
    - index_patterns:
        - "*"
      allowed_actions:
        - "indices_all" # use the "indices_all" built-in action group, ref https://docs.opensearch.org/latest/security/access-control/default-action-groups/#index-level
        - "indices:data/write/bulk*"
{{- end -}}