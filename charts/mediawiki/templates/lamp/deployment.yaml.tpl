{{ define "lamp.deployment" }}
{{ $release := include "wmf.releasename" . }}
### The apache httpd container
# TODO: set up logging. See T265876
# TODO: fix virtualhosts in puppet so that the port is set to APACHE_RUN_PORT
- name: {{ $release }}-httpd
  image: {{.Values.docker.registry }}/{{ .Values.mw.httpd.image_tag }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
  - name: FCGI_MODE
    value: {{ .Values.php.fcgi_mode }}
  - name: SERVERGROUP
    value: {{ .Values.php.servergroup }}
  - name: APACHE_RUN_PORT
    value: "{{ .Values.php.httpd.port }}"
  # Set the pod name as the value of the Server: header.
  - name: SERVER_SIGNATURE
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  ports:
  - name: httpd
    containerPort: {{ .Values.php.httpd.port }}
  # PHP monitoring port
  - name: php-metrics
    containerPort: 9181
  livenessProbe:
    tcpSocket:
      port: httpd
  readinessProbe:
    httpGet:
      # this is the simplest php script you can think of - it just returns OK.
      # This way, we're just testing that apache + php-fpm are ready.
      # mcrouter, if enabled, should have its own readiness probe probably.
      path: /healthz
      port: php-metrics
  resources:
    requests:
{{ toYaml .Values.php.httpd.requests | indent 6 }}
    limits:
{{ toYaml .Values.php.httpd.limits | indent 6 }}
  volumeMounts:
  {{- if eq .Values.php.fcgi_mode "FCGI_UNIX" }}
    # Mount the shared socket volume
  - name: shared-socket
    mountPath: /run/shared
  {{- end }}
  # Note: we use subpaths here. Given subpaths are implemented with bind mounts,
  # they won't be updated when the configmap is updated.
  # This is ok because we're re-deploying the pods when that happens.
  {{- range .Values.mw.sites }}
  - name: {{ $release }}-httpd-sites
    mountPath: /etc/apache2/sites-enabled/{{ template "mw-vhost-filename" . }}
    subPath: {{ template "mw-vhost-filename" . }}
  {{- end }}
### The MediaWiki container
- name: {{ $release }}-app
  image: {{ .Values.docker.registry }}/{{ .Values.main_app.image }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- if .Values.php.slowlog_timeout }}
  securityContext:
    capabilities:
      add: ["SYS_PTRACE"] # This is needed to produce a slow log
  {{- end }}
  env:
  - name: SERVERGROUP
    value: {{ .Values.php.servergroup }}
  - name: FCGI_MODE
    value: {{ .Values.php.fcgi_mode }}
  - name: FCGI_URL
    {{- if eq .Values.php.fcgi_mode "FCGI_TCP" }}
    value: "127.0.0.1:9000"
    {{- else }}
    value: "unix:///run/shared/fpm-www.sock"
    {{- end }}
  - name: PHP__opcache__memory_consumption
    value: "{{ .Values.php.opcache.size }}"
  - name: PHP__opcache__max_accelerated_files
    value: "{{ .Values.php.opcache.nofiles }}"
  - name: FPM__request_terminate_timeout
    value: "{{ .Values.php.timeout }}"
  - name: PHP__apc__shm_size
    value: {{ .Values.php.apc.size }}
  - name: FPM__pm__max_children
    value: "{{ .Values.php.workers }}"
  - name: FPM__request_slowlog_timeout
    value: "{{ .Values.php.slowlog_timeout }}"
  - name: FCGI_URL
    value: "0.0.0.0:9000"
  - name: FCGI_ALLOW
    value: "127.0.0.1"
  {{- range $k, $v := .Values.config.public }}
  - name: {{ $k | upper }}
    value: {{ $v | quote }}
  {{- end }}
  # See T276908
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
  resources:
    requests:
{{ toYaml .Values.main_app.requests | indent 6 }}
    limits:
{{ toYaml .Values.main_app.limits | indent 6 }}
  volumeMounts:
  # TODO: use an env variable for this.
  - name: {{ $release }}-wikimedia-cluster
    mountPath: /etc/wikimedia-cluster
    subPath: wikimedia-cluster
  {{- if eq .Values.php.fcgi_mode "FCGI_UNIX" }}
  # Mount the shared socket volume
  - name: shared-socket
    mountPath: /run/shared
  {{ end -}}
{{- if .Values.monitoring.enabled }}
# Add the following exporters:
# php-fpm exporter
# apache exporter on port 9117
- name: {{ $release }}-httpd-exporter
  image: {{ .Values.docker.registry }}/prometheus-apache-exporter:{{ .Values.php.httpd.exporter_version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  args: ["-scrape_uri", "http://127.0.0.1:9181/server-status?auto"]
  ports:
    - name: httpd-metrics
      containerPort: 9117
  livenessProbe:
    tcpSocket:
      port: 9117
- name: {{ $release }}-php-fpm-exporter
  image: {{ .Values.docker.registry }}/prometheus-php-fpm-exporter:{{ .Values.php.exporter_version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  args: ["--endpoint=http://127.0.0.1:9181/fpm-status", "--addr=0.0.0.0:9118"]
  ports:
    - name: fpm-metrics
      containerPort: 9118
  livenessProbe:
    tcpSocket:
      port: 9118
{{- end }}
{{ end }}