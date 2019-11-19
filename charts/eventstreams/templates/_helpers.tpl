{{/* standard boilerplate safe names for kubernetes:
 - eventstreams.chartname is the chart name safely truncated to 63 chars
 - eventstreams.releasename is the current release name truncated to 63 chars
 - eventstreams.chartid is the full chart identifier
 The reason to limit ourselves to 63 chars is that the DNS spec in kubernetes
 limits names to that.
 We also allow overriding the chart name via the chart.name value
*/}}

{{- define "eventstreams.chartname" -}}
{{- default .Chart.Name .Values.chartName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "eventstreams.releasename" -}}
{{- $name := default .Chart.Name .Values.chartName -}}
{{- printf "%s-%s" $name .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "eventstreams.chartid" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "eventstreams.appbaseurl" -}}
http://{{ template "eventstreams.releasename" . }}:{{ .Values.main_app.appbase_url_port }}
{{- end -}}
