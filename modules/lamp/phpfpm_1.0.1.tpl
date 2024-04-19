{{/*
== configuration for phpfpm for a LAMP stack

 - lamp.phpfpm.container(.docker, .lamp): the container running php-fpm.
    For details about its behaviour, please refer to the module README.
 - lamp.phpfpm.exporter(.docker, .lamp): the container for the phpfpm prometheus exporter.
   It will listen for requests on port 9118
 - lamp.phpfpm.volume(.lamp): the volumes potentially attached to the fpm container
 - lamp.phpfpm.configmap(.lamp): the additional configuration for the fpm container

*/}}
{{- define "lamp.phpfpm.container" }}
- name: {{ template "base.name.release" . }}-app
  image: {{ .Values.docker.registry }}/{{ .Values.lamp.phpfpm.image.name }}:{{ .Values.lamp.phpfpm.image.version }}{{ if .Values.lamp.phpfpm.image.flavour }}-{{ .Values.lamp.phpfpm.image.flavour }}{{- end }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
  - name: SERVERGROUP
    value: {{ .Values.lamp.servergroup }}
  - name: FCGI_MODE
    value: {{ .Values.lamp.fcgi_mode }}
  - name: PHP__opcache__memory_consumption
    value: "{{ .Values.lamp.phpfpm.opcache.size }}"
  - name: PHP__opcache__max_accelerated_files
    value: "{{ .Values.lamp.phpfpm.opcache.nofiles }}"
  - name: FPM__request_slowlog_timeout
    value: "{{ .Values.lamp.phpfpm.slowlog_timeout }}"
  - name: FPM__request_terminate_timeout
    value: "{{ .Values.lamp.phpfpm.timeout }}"
  - name: PHP__apc__shm_size
    value: "{{ .Values.lamp.phpfpm.apc.size }}"
  - name: FPM__pm__max_children
    value: "{{ .Values.lamp.phpfpm.workers }}"
  - name: FCGI_URL
    value: "0.0.0.0:9000"
  - name: FCGI_ALLOW
    value: "127.0.0.1"
  livenessProbe:
  {{- if eq .Values.lamp.fcgi_mode "FCGI_TCP" }}
    tcpSocket:
      port: 9000
  {{- else }}
{{/* TODO: add netcat-openbsd to the php image and run nc -U -z /run/shared/fpm-www.sock instead*/}}
    exec:
      command:
      - /usr/bin/test
      - -S
      - /run/shared/fpm-www.sock
  {{- end }}
    initialDelaySeconds: 1
    periodSeconds: 5
  {{- include "base.helper.resources" .Values.lamp.phpfpm | indent 2}}
  volumeMounts:
    - name: {{ template "base.name.release" . }}-app-config
      mountPath: "/srv/app/config"
      readOnly: true
  {{- if eq .Values.lamp.fcgi_mode "FCGI_UNIX" }}
    # Mount the shared socket volume
    - name: shared-socket
      mountPath: /run/shared
  {{- end }}
{{- end }}

{{- define "lamp.phpfpm.exporter" }}
- name: {{ template "base.name.release" . }}-php-fpm-exporter
  image: {{ .Values.docker.registry }}/prometheus-php-fpm-exporter:{{ .Values.lamp.phpfpm.exporter_version }}
  args: ["--endpoint=http://127.0.0.1:9181/fpm-status", "--addr=0.0.0.0:9118"]
  ports:
    - name: fpm-metrics
      containerPort: 9118
  livenessProbe:
    tcpSocket:
      port: 9118
{{- end }}


{{- define "lamp.phpfpm.volume" }}
- name: {{ template "base.name.release" . }}-app-config
  configMap:
    name: {{ template "base.name.release" . }}-app-configmap
{{- end }}

{{- define "lamp.phpfpm.configmap" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
   {{- include "base.meta.metadata" (dict "Root" . "Name" "app-configmap" ) | indent 2 }}
data:
  config.json: |-
{{ .Files.Get "config/app-config.json" | indent 4 }}
{{- end }}
