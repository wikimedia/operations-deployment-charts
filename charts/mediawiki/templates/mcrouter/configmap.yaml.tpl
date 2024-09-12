{{- $can_run_maintenance := include "mw.maintenance.can_run" . | include "mw.str2bool" }}
{{- if and (not $can_run_maintenance) (not .Values.mw.httpd.enabled) (not .Values.mercurius.enabled) }}
{{/*
  Maintenance scripts are disabled, we're not serving traffic, and we're not running mercurius.
*/}}
{{- else }}
{{ include "cache.mcrouter.configmap" . }}
{{- end }}
