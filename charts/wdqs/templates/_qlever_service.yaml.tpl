{{- define "app.qlever.service" }}
apiVersion: v1
kind: Service
metadata:
{{- include "base.meta.metadata" (dict "Root" . "Name" "qlever-service") | indent 2 }}
spec:
  selector:
    app: {{ template "base.name.chart" . }}
    component: backend
    release: {{ .Release.Name }}
  ports:
    - name: {{ .Values.service.port.name }}
      targetPort: {{ .Values.service.port.targetPort }}
      port: {{ .Values.service.port.port }}
  clusterIP: None
{{- end }}
