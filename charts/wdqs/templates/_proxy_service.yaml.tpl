{{- define "app.proxy.service" }}
apiVersion: v1
kind: Service
metadata:
{{- include "base.meta.metadata" (dict "Root" . "Name" "proxy-service") | indent 2 }}
    component: proxy
spec:
  type: {{ template "base.helper.serviceType" . }}
  selector:
    app: {{ template "base.name.chart" . }}
    component: proxy
    release: {{ .Release.Name }}
  ports:
    - name: {{ .Values.service.port.name }}
      targetPort: {{ .Values.service.port.targetPort }}
      port: {{ .Values.service.port.port }}
{{- end }}
