{{- define "service.kyuubi" }}
{{- range $name, $frontend := .Values.kyuubi.server }}
{{- if $frontend.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: kyuubi-{{ $name | kebabcase }}
  labels:
  {{- include "base.meta.labels" $ | indent 2 }}
  {{- with $frontend.service.annotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $frontend.service.type }}
  ports:
    - name: {{ $name | kebabcase }}
      port: {{ tpl $frontend.service.port $ }}
      targetPort: {{ $frontend.port }}
      {{- if and (eq $frontend.service.type "NodePort") ($frontend.service.nodePort) }}
      nodePort: {{ $frontend.service.nodePort }}
      {{- end }}
  selector:
    {{- include "kyuubi.selectorLabels" $ | nindent 4 }}
  {{- if ($frontend.service.sessionAffinity) }}
  sessionAffinity: {{ $frontend.service.sessionAffinity }}
  {{- end }}
  {{- with $frontend.service.sessionAffinityConfig }}
  sessionAffinityConfig: {{- toYaml . | nindent 4 }}
  {{- end }}
---
{{- end }}
{{- end }}
{{- end }}

{{- define "headless-service.kyuubi" }}
---
apiVersion: v1
kind: Service
metadata:
  name: kyuubi-headless
  {{- include "base.meta.labels" $ | indent 2 }}
  {{- with .Values.kyuubi.service.headless.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    {{- range $name, $frontend := .Values.kyuubi.server }}
    {{- if $frontend.enabled }}
    - name: {{ $name | kebabcase }}
      port: {{ tpl $frontend.service.port $ }}
      targetPort: {{ $frontend.port }}
    {{- end }}
    {{- end }}
    {{- if and .Values.kyuubi.metrics.enabled (.Values.kyuubi.metrics.reporters | nospace | splitList "," | has "PROMETHEUS") }}
    - name: prometheus
      port: {{ .Values.kyuubi.metrics.prometheusPort }}
      targetPort: prometheus
    {{- end }}
  selector:
    {{- include "kyuubi.selectorLabels" $ | nindent 4 }}
{{- end }}
