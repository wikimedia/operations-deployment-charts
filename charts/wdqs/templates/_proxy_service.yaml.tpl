{{- define "app.proxy.service" }}
apiVersion: v1
kind: Service
metadata:
{{- include "base.meta.metadata" (dict "Root" . "Name" "proxy-service") | indent 2 }}
spec:
  type: {{ template "base.helper.serviceType" . }}
  selector:
    app: {{ template "base.name.chart" . }}
    component: proxy
    release: {{ .Release.Name }}
  ports:
    - name: {{ .Values.proxy.port.name }}
      targetPort: {{ .Values.proxy.port.targetPort }}
      port: {{ .Values.proxy.port.port }}
{{- end }}
