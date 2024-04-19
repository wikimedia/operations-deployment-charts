{{/*
== configuration for apache httpd for a LAMP stack

 - lamp.httpd.container(.docker, .lamp): the container running apache.
    For details about its behaviour, please refer to the module README.
 - lamp.httpd.exporter(.docker, .lamp): the container for the httpd prometheus exporter.
   It will listen for requests on port 9117
 - lamp.httpd.volume(.lamp): the volumes potentially attached to the httpd container
 - lamp.httpd.configmap(.lamp): the additional configuration for the httpd container
 - lamp.httpd.annotation(.lamp): the annotation to use to redeploy the software if
   the httpd configmap changes.

*/}}
{{- define "lamp.httpd.container" }}
# The apache httpd container
# TODO: set up logging. See T265876
- name: {{ template "base.name.release" . }}-httpd
  image: {{.Values.docker.registry }}/httpd-fcgi:{{ .Values.lamp.httpd.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
    - name: FCGI_MODE
      value: {{ .Values.lamp.fcgi_mode }}
    - name: SERVERGROUP
      value: {{ .Values.lamp.servergroup }}
    - name: APACHE_RUN_PORT
      value: "{{ .Values.app.port }}"
  ports:
    - name: httpd
      containerPort: {{ .Values.app.port }}
    # PHP monitoring port
    - name: php-metrics
      containerPort: 9181
  livenessProbe:
    tcpSocket:
      port: {{ .Values.app.port }}
  readinessProbe:
    httpGet:
      path: /healthz
      port: php-metrics
  resources:
    requests:
{{ toYaml .Values.lamp.httpd.requests | indent 6 }}
    limits:
{{ toYaml .Values.lamp.httpd.limits | indent 6 }}
  volumeMounts:
  {{- if .Values.lamp.httpd.custom_config }}
  - name: {{ template "base.name.release" . }}-httpd-config
    mountPath: "/etc/apache2/conf-enabled/90-custom.conf"
    subPath: 90-custom.conf
    readOnly: true
  {{- end }}
  {{- if eq .Values.lamp.fcgi_mode "FCGI_UNIX" }}
  # Mount the shared socket volume
  - name: shared-socket
    mountPath: /run/shared
  {{- end }}
{{- end -}}

{{- define "lamp.httpd.exporter" }}
- name: {{ template "base.name.release" . }}-httpd-exporter
  image: {{ .Values.docker.registry }}/prometheus-apache-exporter:{{ .Values.lamp.httpd.exporter_version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  args: ["-scrape_uri", "http://127.0.0.1:9181/server-status?auto"]
  ports:
    - name: httpd-metrics
      containerPort: 9117
  livenessProbe:
    tcpSocket:
      port: 9117
{{- end }}


{{- define "lamp.httpd.volume" }}
{{- if .Values.lamp.httpd.custom_config }}
- name: {{ template "base.name.release" . }}-httpd-config
  configMap:
      name: {{ template "base.name.release" . }}-httpd-config-map
{{- end }}
{{- end }}

{{- define "lamp.httpd.configmap" -}}
{{- if .Values.lamp.httpd.custom_config }}
---
apiVersion: v1
kind: ConfigMap
metadata:
{{- include "base.meta.metadata" (dict "Root" . "Name" "httpd-config-map" ) | indent 2 }}
data:
  90-custom.conf: |-
{{ tpl .Values.lamp.httpd.custom_config . | indent 4 }}
{{- end }}
{{- end -}}


{{- define "lamp.httpd.annotation" }}
checksum/apache: {{ include "lamp.httpd.configmap" . | sha256sum }}
{{- end }}