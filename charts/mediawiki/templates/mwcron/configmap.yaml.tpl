{{ define "mw.cron.configmap" }}
{{ $flags := fromJson ( include "mw.helpers.feature_flags" . ) }}
{{- if $flags.cron -}}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" $ }}-cron-captcha
  {{- include "mw.helpers.labels" $ | indent 2}}
data:
  badwords: |
    {{- .Values.mw.fancycaptcha.badwords | nindent 4 }}
  words: |
    {{- .Values.mw.fancycaptcha.words | nindent 4 }}
{{- end }}
{{- end }}