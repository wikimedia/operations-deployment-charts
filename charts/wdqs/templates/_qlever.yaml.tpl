{{/* copy of generic app for the qlever */}}
{{- define "app.qlever.container" }}
- name: {{ template "base.name.release" . }}-qlever
  image: {{ template "app.qlever._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- with .Values.qlever.metricsPort }}
  ports:
    - containerPort: {{ . }}
      name: app-metrics
  {{- end }}
  {{- with .Values.qlever.workingDir}}
  workingDir: {{ . }}
  {{- end }}
  {{- if .Values.debug.enabled }}
  {{- range .Values.debug.ports }}
    - containerPort: {{ . }}
  {{- end }}{{ end }}
  {{- if .Values.qlever.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.qlever.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.qlever.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.qlever.readiness_probe | nindent 4 }}
  {{- end }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "base.name.release" . }}-qlever
  {{- range $k, $v := .Values.qlever.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- range $k, $v := .Values.qlever.config.private }}
    - name: {{ $k | upper }}
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: {{ $k }}
  {{- end }}
  {{- if .Values.qlever.env_from }}
  envFrom:
  {{- toYaml .Values.qlever.env_from | nindent 4 }}
  {{- end}}
{{- include "base.helper.resources" .Values.qlever | indent 2 }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- with .Values.qlever.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}


{{- define "app.qlever._image" -}}
"{{ .Values.docker.registry }}/{{ .Values.qlever.image }}:{{ .Values.qlever.version }}"
{{- end -}}
