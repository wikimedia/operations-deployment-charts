{{- define "thumbor.limits" }}
resources:
  requests:
{{ toYaml .Values.main_app.requests | indent 4 }}
  limits:
{{ toYaml .Values.main_app.limits | indent 4 }}
{{ end -}}

{{- define "haproxy.limits" }}
resources:
  requests:
{{ toYaml .Values.haproxy.requests | indent 4 }}
  limits:
{{ toYaml .Values.haproxy.limits | indent 4 }}
{{ end -}}

{{- define "nutcracker.limits" }}
resources:
  requests:
{{ toYaml .Values.nutcracker.requests | indent 4 }}
  limits:
{{ toYaml .Values.nutcracker.limits | indent 4 }}
{{ end -}}

{{- define "statsd.limits" }}
resources:
  requests:
{{ toYaml .Values.statsd.requests | indent 4 }}
  limits:
{{ toYaml .Values.statsd.limits | indent 4 }}
{{ end -}}

{{/* default scaffolding for containers */}}
{{- define "default.containers" }}
# The exposed haproxy container
- name: {{ template "wmf.releasename" . }}-haproxy
  image: "{{ .Values.docker.registry }}/{{ .Values.haproxy.image }}:{{ .Values.haproxy.version }}"
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  command:
    - "/usr/sbin/haproxy"
    - "-f"
    - "/etc/haproxy/haproxy.d"
  ports:
    - name: haproxy-main
      containerPort: {{ .Values.haproxy.port }}
    - name: haproxy-metrics
      containerPort: {{ .Values.haproxy.stats_port }}
  {{- if .Values.haproxy.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.haproxy.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.haproxy.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.haproxy.readiness_probe | nindent 4 }}
  {{- end }}
  {{- include "haproxy.limits" . | indent 2 }}
  volumeMounts:
    - name: haproxy-config
      mountPath: /etc/haproxy/haproxy.d
{{- end }}

# Thumbor worker containers
{{- define "thumbor.containers" }}
{{- $public_values := .Values.config.public }}
{{- $private_values := .Values.config.private }}
{{- range $thumbor_worker := ( int .Values.main_app.thumbor_workers | until) }}
{{- $thumbor_port := (add 8080 $thumbor_worker) }}
- name: thumbor-{{ $thumbor_port }}
  image: "{{ $.Values.docker.registry }}/{{ $.Values.main_app.image }}:{{ $.Values.main_app.version }}"
  imagePullPolicy: {{ $.Values.docker.pull_policy }}
  command:
    - "/opt/lib/python/site-packages/bin/thumbor"
    - "--port"
    - "{{ $thumbor_port }}"
    - "--keyfile"
    - "/etc/thumbor.key"
    - "--conf"
    - "/etc/thumbor.d/"
  {{- if $.Values.main_app.args }}
  args:
    {{- range $.Values.main_app.args }}
    - {{ . }}
    {{- end }}
  {{- end }}
  ports:
    - containerPort: {{ $thumbor_port }}
  # no livenessProbe is configured for this container as we are expecting haproxy to manage this
  env:
  {{- range $k, $v := $public_values }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- range $k, $v := $private_values }}
    - name: {{ $k | upper }}
      valueFrom:
        secretKeyRef:
          name: {{ template "wmf.releasename" $ }}-secret-config
          key: {{ $k }}
  {{- end }}
  {{- include "thumbor.limits" $ | indent 2 }}
  volumeMounts:
    - name: thumbor-config
      mountPath: /etc/thumbor.d
    - name: thumbor-key
      mountPath: /etc/thumbor.key
      subPath: thumbor.key
{{- end }}

{{- if .Values.monitoring.enabled }}
- name: statsd-exporter
  image: {{ .Values.docker.registry }}/{{ .Values.statsd.image }}:{{ .Values.statsd.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- include "statsd.limits" . | indent 2 }}
  volumeMounts:
    - name: statsd-config
      mountPath: /etc/monitoring
      readOnly: true
  ports:
  - name: statsd-metrics
    containerPort: {{ .Values.main_app.prometheus_port }}
  livenessProbe:
    tcpSocket:
      port: statsd-metrics
- name: nutcracker-exporter
  image: {{ .Values.docker.registry }}/{{ .Values.nutcracker.exporter }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- include "nutcracker.limits" . | indent 2 }}
  ports:
  - name: nc-metrics
    containerPort: 9191
  livenessProbe:
    tcpSocket:
      port: nc-metrics
{{- end }}
- name: nutcracker
  image: {{ .Values.docker.registry }}/{{ .Values.nutcracker.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- include "nutcracker.limits" . | indent 2 }}
  args:
    - "-o"
    - "/dev/stdout"
  volumeMounts:
    - name: nutcracker-config
      mountPath: /etc/nutcracker
      readOnly: true
{{- end }}
