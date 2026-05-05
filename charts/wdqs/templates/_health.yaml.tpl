{{/* copy of generic app for the health container */}}
{{- define "app.health.container" }}
- name: {{ template "base.name.release" . }}-health
  image: {{ template "app.health._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- with .Values.health.metricsPort }}
  ports:
    - containerPort: {{ . }}
      name: app-metrics
  {{- end }}
  {{- if .Values.debug.enabled }}
  {{- range .Values.debug.ports }}
    - containerPort: {{ . }}
  {{- end }}{{ end }}
  {{- if .Values.health.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.health.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.health.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.health.readiness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.health.startup_probe }}
  startupProbe:
  {{- toYaml .Values.health.startup_probe | nindent 4 }}
  {{- end }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "base.name.release" . }}-health
    - name: WDQS_NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
  {{- range $k, $v := .Values.health.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- range $k, $v := .Values.health.config.private }}
    - name: {{ $k | upper }}
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: {{ $k }}
  {{- end }}
  {{- if .Values.health.env_from }}
  envFrom:
  {{- toYaml .Values.health.env_from | nindent 4 }}
  {{- end}}
{{- include "base.helper.resources" .Values.health | indent 2 }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- with .Values.health.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}


{{- define "app.health._image" -}}
"{{ .Values.docker.registry }}/{{ .Values.health.image }}:{{ .Values.health.version }}"
{{- end -}}
