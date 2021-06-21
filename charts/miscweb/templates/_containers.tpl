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

{{- define "httpd-exporter" }}
# apache exporter on port 9117
- name: {{ template "wmf.releasename" . }}-httpd-exporter
  image: {{ .Values.docker.registry }}/prometheus-apache-exporter:{{ .Values.httpd.exporter_version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  args: ["-scrape_uri=http://127.0.0.1:9181/server-status"]
  ports:
    - name: httpd-metrics
      containerPort: 9117
  livenessProbe:
    tcpSocket:
      port: 9117
{{ end -}}
{{/* end httpd-exporter */}}
