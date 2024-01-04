{{/*
== Templates to allow installing prometheus-statsd-exporter in a chart


 - base.statsd.deployment_annotations - provides the annotation to autorestart a deployment
 - base.statsd.container - provides the deployment of the exporter
 - base.statsd.volume - provides the volume to attach to the exporter
 - base.statsd.configmap - provides the configmap for the exporter

*/}}
{{- define "base.statsd.deployment_annotations" }}
{{- if and .Values.monitoring.enabled .Values.monitoring.statsd }}
checksum/prometheus-statsd: {{ include "base.statsd.configmap" . | sha256sum }}
{{- end }}
{{- end -}}

{{- define "base.statsd.container" }}
{{- if and .Values.monitoring.enabled .Values.monitoring.statsd }}
- name: statsd-exporter
  image: {{ .Values.docker.registry }}/{{ .Values.common_images.statsd.exporter }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- with .Values.monitoring.statsd.prestop_sleep }}
  {{ include "base.helper.prestop" . | nindent 2}}
  {{- end }}
  resources:
    requests:
    {{- with .Values.monitoring.statsd.requests }}
{{ toYaml . | indent 6 }}
    {{- else }}
      cpu: 100m
      memory: 200M
    {{- end }}
    limits:
    {{- with .Values.monitoring.statsd.limits }}
{{ toYaml . | indent 6 }}
    {{- else }}
      cpu: 200m
      memory: 400M
    {{- end }}
  volumeMounts:
    - name: statsd-config
      mountPath: /etc/monitoring
      readOnly: true
  ports:
  - name: statsd-metrics
    containerPort: 9102
  livenessProbe:
    tcpSocket:
      port: statsd-metrics
{{- end }}
{{- end -}}

{{- define "base.statsd.volume" }}
{{- if and .Values.monitoring.enabled .Values.monitoring.statsd }}
- name: statsd-config
  configMap:
    name: {{ template "base.name.release" . }}-statsd-configmap
{{- end }}
{{- end -}}

{{- define "base.statsd.configmap" }}
{{- if and .Values.monitoring.enabled .Values.monitoring.statsd }}
---
apiVersion: v1
kind: ConfigMap
metadata:
{{- include "base.meta.metadata" (dict "Root" . "Name" "statsd-configmap" ) | indent 2 }}
data:
  prometheus-statsd.conf: |-
{{- if .Values.monitoring.statsd.filename }}
{{ .Files.Get .Values.monitoring.statsd.filename | indent 4 }}
{{- else if .Values.monitoring.statsd.config  }}
{{ .Values.monitoring.statsd.config | indent 4 }}
{{- else }}
  {{ fail "You need to define either an inline 'config' or a 'filename' where to source it." }}
{{- end }}
{{- end }}
{{- end }}
