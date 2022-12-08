{{/*
Modulename: base.name
Version: 1.0
Depends-

== Standard boilerplate safe names for kubernetes

The DNS spec in k8s limits names to 63 chars,
so we do the same for names here.

 - base.name.chart
   The chart name safely truncated to 63 chars.
   We allow overriding this via .Values.chartName.

 - base.name.release
   The chart + release name truncated to 63 chars.

 - base.name.chartid
   chart name + chart version.

 - base.name.baseurl
   URL for the app port.  Uses base.name.release as the hostname.


NOTE: The app name is not used in any of these templates.
Because we isolate our applications within k8s namespaces,
these template variables should be unique within any given namespace.
*/}}

{{- define "base.name.chart" -}}
{{- default .Chart.Name .Values.chartName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "base.name.release" -}}
{{- $name := default .Chart.Name .Values.chartName -}}
{{- printf "%s-%s" $name .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "base.name.chartid" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "base.name.baseurl" -}}
http://{{ template "base.name.release" . }}:{{ .Values.app.port }}
{{- end -}}