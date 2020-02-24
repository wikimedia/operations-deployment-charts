{{/* standard boilerplate safe names for kubernetes:
 - wmf.chartname is the chart name safely truncated to 63 chars
 - wmf.releasename is the current main_app.name + release name truncated to 63 chars
 - wmf.chartid is the full chart identifier
 The reason to limit ourselves to 63 chars is that the DNS spec in kubernetes
 limits names to that.
 We also allow overriding the chart name via the chart.name value
*/}}

{{- define "wmf.chartname" -}}
{{- default .Chart.Name .Values.chartName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "wmf.releasename" -}}
{{- printf "%s-%s" .Values.main_app.name .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "wmf.chartid" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "wmf.appbaseurl" -}}
http://{{ template "wmf.releasename" . }}:{{ .Values.main_app.port }}
{{- end -}}
