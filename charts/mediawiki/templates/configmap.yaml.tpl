{{- $can_run := include "mw.can_run" . | include "mw.str2bool" }}
{{- if $can_run }}
{{ include "mesh.configuration.configmap" . }}
{{ include "base.statsd.configmap" . }}
{{ include "mw.lamp.configmap" . }}
{{ include "mw.mercurius.configmap" . }}
{{ include "mw.cron.configmap" . }}
{{ end }}
