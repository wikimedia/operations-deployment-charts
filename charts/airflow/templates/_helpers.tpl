
{{/*
    copy of the app.generic.container template, with support for fetching
    PG connection details from the PG secrets
*/}}
{{- define "app.airflow.container" }}
# The main application container
- name: {{ template "base.name.release" . }}
  image: {{ template "app.generic._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- include "app.generic._command" . | indent 2 }}
  ports:
    - containerPort: {{ .Values.app.port }}
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
  {{- include "app.airflow.env" . | indent 2 }}
{{ include "base.helper.resources" .Values.app | indent 2 }}
{{ include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- with .Values.app.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}


{{ define "app.airflow.env" }}
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
  {{- if .Values.postgresql.cloudnative }}
  {{- range $secret_data_name, $env_var := .Values.postgresql.secrets }}
  - name: {{ $env_var }}
    valueFrom:
      secretKeyRef:
        name: {{ $.Values.pgServiceName }}-app
        key: {{ $secret_data_name }}
  {{- end }}
  - name: POOLER_NAME
    value: {{ $.Values.pgServiceName }}-pooler-rw
  {{- end }}
{{- end }}


{{/* Represents a Go variable as an INI value */}}
{{- define "toIni" -}}
{{- if kindIs "bool" .value -}}
{{- .value | toString | camelcase }}
{{- else -}}
{{ .value }}
{{- end -}}
{{- end -}}
