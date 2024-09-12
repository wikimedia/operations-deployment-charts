{{- $can_run_maintenance := include "mw.maintenance.can_run" . | include "mw.str2bool" }}
{{- if and (not $can_run_maintenance) (not .Values.mw.httpd.enabled) (not .Values.mercurius.enabled) }}
{{/*
  Maintenance scripts are disabled, we're not serving traffic, and we're not running mercurius.
*/}}
{{- else }}
{{ include "mesh.configuration.configmap" . }}
{{ include "base.statsd.configmap" . }}
{{ include "mw.lamp.configmap" . }}
{{ include "mw.mercurius.configmap" . }}
{{ end }}
