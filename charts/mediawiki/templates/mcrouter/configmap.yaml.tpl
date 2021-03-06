{{- if .Values.mw.mcrouter.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-mcrouter-config
  {{- include "mw.labels" . | indent 2 }}
data:
  config.json: |-
{{ include "mcrouter.config" . | indent 4 }}
{{- end }}
