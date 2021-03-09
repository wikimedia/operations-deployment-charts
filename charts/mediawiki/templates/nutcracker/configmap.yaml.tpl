{{- if .Values.mw.nutcracker.enabled -}}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-nutcracker-config
  {{- include "mw.labels" . | indent 2 }}
data:
  nutcracker.yml: |-
{{ include "nutcracker.config" . | indent 4 }}
{{ end }}
