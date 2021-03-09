{{ if not (hasSuffix "canary" .Release.Name) }}
{{ include "tls.service" . }}
{{ if not .Values.tls.enabled }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ template "wmf.releasename" . }}
  labels:
  {{- include "mw.labels" . | indent 2 }}
spec:
  type: NodePort
  selector:
    app: {{ template "wmf.chartname" . }}
    routed_via: {{ .Release.Name }}
  ports:
    - name: {{ .Values.service.port.name }}
      targetPort: {{ .Values.service.port.targetPort }}
      port: {{ .Values.service.port.port }}
      {{- if .Values.service.port.nodePort }}
      nodePort: {{ .Values.service.port.nodePort }}
      {{- end }}
{{- end }}
{{- end }}
