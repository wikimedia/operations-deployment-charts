{{/* copy of generic app for the proxy */}}
{{- define "app.proxy.container" }}
- name: {{ template "base.name.release" . }}-proxy
  image: {{ template "app.proxy._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- with .Values.proxy.metricsPort }}
  ports:
    - containerPort: {{ . }}
      name: app-metrics
  {{- end }}
  {{- if .Values.debug.enabled }}
  {{- range .Values.debug.ports }}
    - containerPort: {{ . }}
  {{- end }}{{ end }}
  {{- if .Values.proxy.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.proxy.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.proxy.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.proxy.readiness_probe | nindent 4 }}
  {{- end }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "base.name.release" . }}-proxy
  {{- range $k, $v := .Values.proxy.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- if .Values.proxy.env_from }}
  envFrom:
  {{- toYaml .Values.proxy.env_from | nindent 4 }}
  {{- end}}
{{- include "base.helper.resources" .Values.proxy | indent 2 }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- with .Values.proxy.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}


{{- define "app.proxy.volume" -}}
{{- with .Values.proxy.volumes }}
{{ toYaml . }}
{{- end }}
{{- end -}}


{{- define "app.proxy._image" -}}
"{{ .Values.docker.registry }}/{{ .Values.proxy.image }}:{{ .Values.proxy.version }}"
{{- end -}}
