{{/* copy of generic app for the reindex container */}}
{{- define "app.reindex.container" }}
- name: {{ template "base.name.release" . }}-reindex
  image: {{ template "app.reindex._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  restartPolicy: Always
  {{- include "app.reindex._command" . | indent 2 }}
  {{- with .Values.reindex.metricsPort }}
  ports:
    - containerPort: {{ . }}
      name: app-metrics
  {{- end }}
  {{- if .Values.debug.enabled }}
  {{- range .Values.debug.ports }}
    - containerPort: {{ . }}
  {{- end }}{{ end }}
  {{- if .Values.reindex.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.reindex.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.reindex.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.reindex.readiness_probe | nindent 4 }}
  {{- end }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "base.name.release" . }}-reindex
  {{- range $k, $v := .Values.reindex.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- range $k, $v := .Values.reindex.config.private }}
    - name: {{ $k | upper }}
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-reindex-secret-config
          key: {{ $k }}
  {{- end }}
  {{- if .Values.reindex.env_from }}
  envFrom:
  {{- toYaml .Values.reindex.env_from | nindent 4 }}
  {{- end}}
{{- include "base.helper.resources" .Values.reindex | indent 2 }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- with .Values.reindex.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}


{{- define "app.reindex._image" -}}
"{{ .Values.docker.registry }}/{{ .Values.reindex.image }}:{{ .Values.reindex.version }}"
{{- end -}}

{{- define "app.reindex._command" -}}
{{- if .Values.reindex.command }}
command:
  {{- range .Values.reindex.command }}
  - {{ . }}
  {{- end }}
{{- end }}
{{- if .Values.reindex.args }}
args:
  {{- range .Values.reindex.args }}
  - {{ . | quote }}
  {{- end }}
{{- end }}
{{- end -}}
