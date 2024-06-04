{{/*
== Public mcrouter service

This service should be used only when we are aiming for a standalone
mcrouter deployment/daemonset. If mcrouter is used as a sidecar, this
will simply not work. If such a case appears, some refactoring will
be needed.

*/}}
{{- define "cache.service" -}}
{{ if .Values.cache.mcrouter.service.enabled | default false }}
---
apiVersion: v1
kind: Service
metadata:
{{- include "base.meta.metadata" (dict "Root" . ) | indent 2 }}
spec:
  type: ClusterIP
  {{- if .Values.cache.mcrouter.service.clusterIP }}
  clusterIP: {{ .Values.cache.mcrouter.service.clusterIP }}
  {{- end }}
  selector:
    app: {{ template "base.name.chart" . }}
  ports:
    - name: {{ .Values.service.port.name }}
      targetPort: {{ .Values.service.port.targetPort }}
      port: {{ .Values.service.port.port | default .Values.cache.mcrouter.port }}
  {{- /* internalTrafficPolicy is quite a unique setting, "Local" instructs
    kube-proxy to send internal traffic for this service
    only if there is a local endpoint in the same Node as the requester  */}}
  {{- if  .Values.service.use_node_local_endpoints | default false }}
  internalTrafficPolicy: Local
  {{- end }}
{{- end }}
{{- end -}}


{{/*
Sample service.yaml:
{{- template "cache.service" . }}


*/}}
