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
- name: {{ template "base.name.release" . }}
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
    - containerPort: {{ .Values.app.port }}
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
      value: {{ template "base.name.release" . }}
  {{- range $k, $v := .Values.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- range $k, $v := .Values.config.private }}
    - name: {{ $k | upper }}
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: {{ $k }}
  {{- end }}
{{ include "limits" . | indent 2}}
{{- with .Values.main_app.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}

{{- if .Values.sidecar.enabled }}
- name: {{ .Release.Name }}-sidecar
  image: "{{ .Values.docker.registry }}/{{ .Values.main_app.image }}:{{ .Values.main_app.version }}"
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  command:
    {{- range .Values.sidecar.command }}
    - {{ . }}
    {{- end}}
  resources:
    requests:
{{ toYaml .Values.sidecar.requests | indent 6 }}
    limits:
{{ toYaml .Values.sidecar.limits | indent 6 }}
{{- with .Values.sidecar.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
  env:
  {{- range $k, $v := .Values.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- end}}

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
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- end }}
{{- end }}

{{- define "httpd-exporter" }}
# apache exporter on port 9117
- name: {{ template "base.name.release" . }}-httpd-exporter
  image: {{ .Values.docker.registry }}/{{ .Values.common_images.httpd.exporter }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  args: ["--scrape_uri=http://127.0.0.1:9181/server-status"]
  ports:
    - name: httpd-metrics
      containerPort: 9117
  livenessProbe:
    tcpSocket:
      port: 9117
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{ end -}}
{{/* end httpd-exporter */}}
