

{{- define "app.initcontainer" }}
- name: {{ template "base.name.release" . }}-init
  image: {{ template "app.generic._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  command:
{{ toYaml .Values.app.initcontainer.command | indent 2 }}
  args:
{{ toYaml .Values.app.initcontainer.args | indent 2 }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "base.name.release" . }}
  {{- range $k, $v := .Values.config.initcontainer.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- range $k, $v := .Values.config.initcontainer.private }}
    - name: {{ $k | upper }}
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: {{ $k }}
  {{- end }}
  {{- if .Values.app.initcontainer.env_from }}
  envFrom:
  {{- toYaml .Values.app.initcontainer.env_from | nindent 4 }}
  {{- end}}
{{ include "base.helper.resources" .Values.app.initcontainer | indent 2 }}
{{ include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- with .Values.app.initcontainer.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}