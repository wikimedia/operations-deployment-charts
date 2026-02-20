{{- define "mesh.service" -}}
{{ if and .Values.mesh.enabled .Values.mesh.public_port }}
---
apiVersion: v1
kind: Service
metadata:
  {{- include "base.meta.metadata" (dict "Root" . "Name" "tls-service") | indent 2 }}
spec:
  type: {{ template "base.helper.serviceType" . }}
  selector:
    app: {{ template "base.name.chart" . }}
    routed_via: {{ .Release.Name }}
  ports:
    - name: {{ template "base.name.release" . }}-https
      protocol: TCP
      port: {{ .Values.mesh.public_port }}
      {{- if eq (include "base.helper.serviceType" .) "NodePort" }}
      nodePort: {{ .Values.mesh.public_port }}
      {{- end }}
{{- end }}
{{- end -}}
