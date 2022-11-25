{{- define "limits" }}
resources:
  requests:
{{ toYaml .Values.main_app.requests | indent 4 }}
  limits:
{{ toYaml .Values.main_app.limits | indent 4 }}
{{ end -}}


{{- define "php.containers" }}
# The apache httpd container
# TODO: set up logging. See T265876
- name: {{ template "base.name.release" . }}-httpd
  image: {{.Values.docker.registry }}/httpd-fcgi:{{ .Values.php.httpd.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
    - name: FCGI_MODE
      value: {{ .Values.php.fcgi_mode }}
    - name: SERVERGROUP
      value: {{ .Values.php.servergroup }}
    - name: APACHE_RUN_PORT
      value: "{{ .Values.php.httpd.port }}"
    {{- with .Values.php.httpd.log }}
    # If set to "ecs", the pod will log in ecs format
    - name: LOG_FORMAT
      value: "{{ .format | default "wmfjson" }}"
    # If set to 1, it will skip logging metrics/alerting/k8s requests
    # that we don't really care about.
    - name: LOG_SKIP_SYSTEM
      value: "{{ .skip_system | default "0" }}"
    {{- end }}
  ports:
    - name: httpd
      containerPort: {{ .Values.php.httpd.port }}
    # PHP monitoring port
    - name: php-metrics
      containerPort: 9181
  livenessProbe:
    tcpSocket:
      port: {{ .Values.php.httpd.port }}
  readinessProbe:
    httpGet:
      path: /healthz
      port: php-metrics
  resources:
    requests:
{{ toYaml .Values.php.httpd.requests | indent 6 }}
    limits:
{{ toYaml .Values.php.httpd.limits | indent 6 }}
  volumeMounts:
  - name: shellbox-httpd-config
    mountPath: "/etc/apache2/conf-enabled/90-shellbox.conf"
    subPath: 90-shellbox.conf
    readOnly: true
  {{- if eq .Values.php.fcgi_mode "FCGI_UNIX" }}
  # Mount the shared socket volume
  - name: shared-socket
    mountPath: /run/shared
  {{- end }}
- name: {{ template "base.name.release" . }}-app
  image: {{ .Values.docker.registry }}/wikimedia/mediawiki-libs-shellbox:{{ if .Values.shellbox.version }}{{ .Values.shellbox.version }}-{{ end }}{{ .Values.shellbox.flavour }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
  - name: SERVERGROUP
    value: {{ .Values.php.servergroup }}
  - name: FCGI_MODE
    value: {{ .Values.php.fcgi_mode }}
  - name: PHP__opcache__memory_consumption
    value: "{{ .Values.php.opcache.size }}"
  - name: PHP__opcache__max_accelerated_files
    value: "{{ .Values.php.opcache.nofiles }}"
  - name: FPM__request_slowlog_timeout
    value: "{{ .Values.php.slowlog_timeout }}"
  - name: FPM__request_terminate_timeout
    value: "{{ .Values.php.timeout }}"
  - name: PHP__apc__shm_size
    value: "{{ .Values.php.apc.size }}"
  - name: FPM__pm__max_children
    value: "{{ .Values.php.workers }}"
  - name: FCGI_URL
    value: "0.0.0.0:9000"
  - name: FCGI_ALLOW
    value: "127.0.0.1"
  {{- range $k, $v := .Values.config.public }}
  - name: {{ $k | upper }}
    value: {{ $v | quote }}
  {{- end }}
  livenessProbe:
  {{- if eq .Values.php.fcgi_mode "FCGI_TCP" }}
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
  {{- include "limits" . | indent 2}}
  volumeMounts:
    - name: shellbox-config
      mountPath: "/srv/app/config"
      readOnly: true
  {{- with .Values.main_app.volumeMounts }}
{{  toYaml . | indent 4 }}
  {{- end }}
  {{- if eq .Values.php.fcgi_mode "FCGI_UNIX" }}
    # Mount the shared socket volume
    - name: shared-socket
      mountPath: /run/shared
  {{- end }}

{{ if .Values.monitoring.enabled }}
# Add the following exporters:
# php-fpm exporter
# apache exporter on port 9117
- name: {{ template "base.name.release" . }}-httpd-exporter
  image: {{ .Values.docker.registry }}/prometheus-apache-exporter:{{ .Values.php.httpd.exporter_version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  args: ["-scrape_uri", "http://127.0.0.1:9181/server-status?auto"]
  ports:
    - name: httpd-metrics
      containerPort: 9117
  livenessProbe:
    tcpSocket:
      port: 9117
- name: {{ template "base.name.release" . }}-php-fpm-exporter
  image: {{ .Values.docker.registry }}/prometheus-php-fpm-exporter:{{ .Values.php.exporter_version }}
  args: ["--endpoint=http://127.0.0.1:9181/fpm-status", "--addr=0.0.0.0:9118"]
  ports:
    - name: fpm-metrics
      containerPort: 9118
  livenessProbe:
    tcpSocket:
      port: 9118
{{- end }}
{{ end -}}
{{/* end php.containers */}}
