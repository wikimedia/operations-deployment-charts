{{- define "limits" }}
resources:
  requests:
{{ toYaml .Values.main_app.requests | indent 4 }}
  limits:
{{ toYaml .Values.main_app.limits | indent 4 }}
{{ end -}}

{{/* default scaffolding for containers */}}
{{- define "default.containers" }}
# The main application container
- name: {{ template "wmf.releasename" . }}
  image: "{{ .Values.docker.registry }}/{{ .Values.main_app.image }}:{{ .Values.main_app.version }}"
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- if .Values.main_app.command }}
  command:
    {{- range .Values.main_app.command }}
    - {{ . }}
    {{- end }}
  {{- end }}
  {{- if .Values.main_app.args }}
  args:
    {{- range .Values.main_app.args }}
    - {{ . }}
    {{- end }}
  {{- end }}
  ports:
    - containerPort: {{ .Values.main_app.port }}
  {{- if .Values.debug.enabled }}
  {{- range .Values.debug.ports }}
    - containerPort: {{ . }}
  {{- end }}{{ end }}
  {{- if .Values.main_app.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.main_app.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.main_app.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.main_app.readiness_probe | nindent 4 }}
  {{- end }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "wmf.releasename" . }}
  {{- range $k, $v := .Values.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- range $k, $v := .Values.config.private }}
    - name: {{ $k | upper }}
      valueFrom:
        secretKeyRef:
          name: {{ template "wmf.releasename" $ }}-secret-config
          key: {{ $k }}
  {{- end }}
{{ include "limits" . | indent 2}}
{{- with .Values.main_app.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}

{{- if and .Values.monitoring.enabled .Values.monitoring.uses_statsd }}
- name: {{ .Release.Name }}-metrics-exporter
  image: {{ .Values.docker.registry }}/prometheus-statsd-exporter:{{ .Values.monitoring.image_version | default "latest" }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  ports:
  - name: statsd-metrics
    containerPort: 9102
  volumeMounts:
    - name: {{ .Release.Name }}-metrics-exporter
      mountPath: /etc/monitoring
{{- end }}
{{- end }}


{{- define "php.containers" }}
# The apache httpd container
# TODO: set up logging. See T265876
- name: {{ template "wmf.releasename" . }}-httpd
  image: {{.Values.docker.registry }}/httpd-fcgi:{{ .Values.php.httpd.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
    - name: FCGI_MODE
      value: {{ .Values.php.fcgi_mode }}
    - name: SERVERGROUP
      value: {{ .Values.php.servergroup }}
    - name: APACHE_RUN_PORT
      value: {{ .Values.php.httpd.port }}
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
      port: {{ .Values.php.httpd.port }}
  resources:
    requests:
      {{- toYaml .Values.php.httpd.requests | indent 6 }}
    limits:
      {{- toYaml .Values.php.httpd.limits | indent 6 }}
  {{- if eq .Values.php.fcgi_mode "FCGI_UNIX" }}
  # Mount the shared socket volume
  volumeMounts:
  - name: shared-socket
    mountPath: /run/shared
  {{- end -}}
- name: {{ template "wmf.releasename" . }}-app
  image: {{ .Values.docker.registry }}/{{ .Values.main_app.image }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
  - name: SERVERGROUP
    value: {{ .Values.php.servergroup }}
  - name: FCGI_MODE
    value: {{ .Values.php.fcgi_mode }}
  - name: PHP__opcache__memory_consumption
    value: {{ .Values.php.opcache.size }}
  - name: PHP__opcache__max_accelerated_files
    value: {{ .Values.php.opcache.nofiles }}
  - name: FPM__request_terminate_timeout
    value: {{ .Values.php.timeout }}
  - name: PHP__apc__shm_size
    value: {{ .Values.php.apc.size }}
  - name: FPM__pm__max_children
    value: {{ .Values.php.workers }}
  {{- range $k, $v := .Values.config.public }}
  - name: {{ $k | upper }}
    value: {{ $v | quote }}
  {{- end }}
  livenessProbe:
  {{- if eq .Values.php.fcgi_mode "FCGI_TCP" }}
    tcpSocket:
      port: 9000
  {{- else }}
    # TODO: livenessProbe
    # The problem is that in FCGI_UNIX mode we won't have an open port to check
  {{- end }}
  {{- include "limits" . | indent 2}}
  {{- if eq .Values.php.fcgi_mode "FCGI_UNIX" }}
  # Mount the shared socket volume
  volumeMounts:
  - name: shared-socket
    mountPath: /run/shared
    {{- with .Values.main_app.volumeMounts }}
    {{- toYaml . | indent 4 }}
    {{- end }}
  {{- else }}
    {{- with .Values.main_app.volumeMounts }}
  volumeMounts:
    {{- toYaml . | indent 4 }}
    {{- end }}
  {{ end -}}
{{ if .Values.monitoring.enabled }}
# Add the following exporters:
# php-fpm exporter
# apache exporter on port 9117
- name: {{ template "wmf.releasename" . }}-httpd-exporter
  image: {{ .Values.docker.registry }}/prometheus-apache-exporter:{{ .Values.php.httpd.exporter_version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  args: ["-scrape_uri", "http://127.0.0.1:9181/server-status?auto"]
  ports:
    - name: httpd-metrics
      containerPort: 9117
  livenessProbe:
    tcpSocket:
      port: 9117
- name: {{ template "wmf.releasename" . }}-php-fpm-exporter
  image: {{ .Values.docker.registry }}/prometheus-php-fpm-exporter:{{ .Values.php.exporter_version }}
  args: ["--endpoint=http://127.0.0.1:9181/fpm-status", --addr="0.0.0.0:9118"]
  ports:
    - name: fpm-metrics
      containerPort: 9118
  livenessProbe:
    tcpSocket:
      port: 9118
{{- end }}
{{ end -}}
{{/* end php.containers */}}
