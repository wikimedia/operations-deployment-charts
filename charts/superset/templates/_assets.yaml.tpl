{{- define "assets.container" }}
{{- $release := include "base.name.release" . }}
- name: {{ $release }}-assets
  image: {{ .Values.docker.registry }}/{{ .Values.assets.image }}:{{ .Values.assets.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  ports:
  - containerPort: {{ .Values.app.port }}
    protocol: TCP
  {{- include "base.helper.resources" .Values.assets.resources | indent 2 }}
  {{- if .Values.assets.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.assets.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.assets.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.assets.readiness_probe | nindent 4 }}
  {{- end }}
  volumeMounts:
    {{- toYaml .Values.assets.volumeMounts | nindent 4 }}
{{- end }}

{{- define "assets.volume" }}
{{- with .Values.assets.volumes }}
{{ toYaml . }}
{{- end }}
{{- end -}}