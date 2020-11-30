{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "calico.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "calico.labels" -}}
helm.sh/chart: {{ include "calico.chart" . }}
{{ include "calico.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "calico.selectorLabels" -}}
app.kubernetes.io/name: calico
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
