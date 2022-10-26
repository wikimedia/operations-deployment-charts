{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "coredns.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "coredns.labels" -}}
helm.sh/chart: {{ include "coredns.chart" . }}
{{ include "coredns.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "coredns.selectorLabels" -}}
app.kubernetes.io/name: "CoreDNS"
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}