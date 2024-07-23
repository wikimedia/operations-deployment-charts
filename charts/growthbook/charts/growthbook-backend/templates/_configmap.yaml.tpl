{{/*
  This configmap is used to define the gunicorn and superset configuration
*/}}
{{- define "configmap.growthbook-backend" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: growthbook-backend-config
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  config.yml: |
    {{- $.Values.config.growthbook | toYaml | nindent 4 }}
{{- end }}