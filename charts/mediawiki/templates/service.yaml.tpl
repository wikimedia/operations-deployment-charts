{{ if not (hasSuffix "canary" .Release.Name) }}
{{ include "mesh.service" . }}
{{ if or .Values.service.expose_http (not .Values.mesh.enabled) }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ template "base.name.release" . }}
  labels:
  {{- include "mw.labels" . | indent 2 }}
spec:
  type: NodePort
  selector:
    app: {{ template "base.name.chart" . }}
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
