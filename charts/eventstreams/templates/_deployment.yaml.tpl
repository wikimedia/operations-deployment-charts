

{{/* default scaffolding for containers */}}
{{- define "eventstreams.container" }}
# The main application container
- name: {{ template "base.name.release" . }}
  image: {{ template "app.generic._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- include "eventstreams._command" . | indent 2 }}
  ports:
    - containerPort: {{ .Values.app.port }}
  {{- with .Values.app.metricsPort }}
    - containerPort: {{ . }}
      name: app-metrics
  {{- end }}
  {{- if .Values.debug.enabled }}
  {{- range .Values.debug.ports }}
    - containerPort: {{ . }}
  {{- end }}{{ end }}
  {{- if .Values.app.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.app.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.app.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.app.readiness_probe | nindent 4 }}
  {{- end }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ .Values.config.name }}
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
  {{- if .Values.app.env_from }}
  envFrom:
  {{- toYaml .Values.app.env_from | nindent 4 }}
  {{- end}}
{{ include "base.helper.resources" .Values.app | indent 2 }}
{{ include "base.helper.restrictedSecurityContext" . | indent 2 }}
  volumeMounts:
    - name: "{{ .Values.config.name }}-config-volume"
      mountPath: /etc/eventstreams
{{- with .Values.app.volumeMounts }}
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}

{{/* default scaffolding for containers */}}
{{- define "eventstreams.debug_container" }}
{{- if .Values.debug.enabled | default false }}
# The main application container
- name: {{ .Values.app.name }}-wmfdebug
  image: {{ .Values.docker.registry }}/wmfdebug:latest
  command: ["/bin/bash"]
  args: ["-c", "echo 'Sleeping infinitely...'; sleep infinity;"]
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  securityContext:
    capabilities:
      add:
      - SYS_PTRACE
  stdin: true
  tty: true
{{- end }}
{{- end }}

{{- define "eventstreams.volume" -}}
{{- with .Values.app.volumes }}
{{ toYaml . }}
{{- end }}
- name: "{{ .Values.config.name }}-config-volume"
  configMap:
    name: "{{ template "base.name.release" . }}-config"
{{- end -}}

{{- define "eventstreams._command" -}}
{{- if .Values.app.command }}
command:
  {{- range .Values.app.command }}
  - {{ . }}
  {{- end }}
{{- end }}
{{- if .Values.app.args }}
args:
{{- if .Values.debug.enabled | default false }}
# If debug_mode, then enable the NodeJS Inspector and save v8 profiling data.
# service-runner master inspector port will be .Values.debug.ports[0],
# and worker will be .Values.debug.ports[1].
# (Assume the first port in .Values.debug.ports is to be the node inspect port.)
  - "--inspect=0.0.0.0:{{ index .Values.debug.ports 0 }}"
  - "--expose-gc"
  - "--prof"
  - "--logfile=/tmp/{{ .Values.main_app.name }}-v8.log"
  - "--no-logfile-per-isolate"
{{- end }}
  {{- range .Values.app.args }}
  - {{ . | quote }}
  {{- end }}
{{- end }}
{{- end -}}