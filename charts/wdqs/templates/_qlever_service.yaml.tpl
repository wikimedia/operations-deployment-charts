{{- define "app.qlever.service" }}
apiVersion: v1
kind: Service
metadata:
{{- include "base.meta.metadata" (dict "Root" . "Name" "qlever-service") | indent 2 }}
    component: backend
spec:
  selector:
    app: {{ template "base.name.chart" . }}
    component: backend
    release: {{ .Release.Name }}
  ports:
    - name: {{ .Values.qlever.service.port.name }}
      targetPort: {{ .Values.qlever.service.port.targetPort }}
      port: {{ .Values.qlever.service.port.port }}
  clusterIP: None
{{- end }}
