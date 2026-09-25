{{- define "liftwing-studio.app.container" }}
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
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "base.name.release" . }}
    - name: PORT
      value: {{ .Values.app.port | quote }}
    - name: CONFIG_PATH
      value: "{{ .Values.app.config_dir }}/librechat.yaml"
  {{- with .Values.app.database }}
  {{- if and .existingSecret (not (hasKey $.Values.config.private "MONGO_URI")) }}
    - name: MONGO_USER
      valueFrom:
        secretKeyRef:
          name: {{ .existingSecret }}
          key: {{ .user_key | default "username" }}
    - name: MONGO_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ .existingSecret }}
          key: {{ .password_key | default "password" }}
    - name: MONGO_URI
      value: "mongodb://$(MONGO_USER):$(MONGO_PASSWORD)@{{ .host }}:{{ .port }}/{{ .name }}"
  {{- end }}
  {{- end }}
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
{{ include "base.helper.resources" .Values.app | indent 2 }}
{{ include "base.helper.restrictedSecurityContext" . | indent 2 }}
  volumeMounts:
    - name: data
      mountPath: /app/uploads
      subPath: uploads
    - name: data
      mountPath: /app/client/public/images
      subPath: images
    - name: logs
      mountPath: /app/logs
    - name: librechat-config
      mountPath: {{ .Values.app.config_dir }}
      readOnly: true
  {{- with .Values.app.volumeMounts }}
{{ toYaml . | indent 4 }}
  {{- end }}
{{- end }}

{{- define "liftwing-studio.litellm.container" }}
{{- if .Values.litellm.enabled }}
- name: {{ template "base.name.release" . }}-litellm
  image: "{{ .Values.docker.registry }}/{{ .Values.litellm.image }}:{{ .Values.litellm.version }}"
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- with .Values.litellm.command }}
  command:
{{ toYaml . | indent 4 }}
  {{- end }}
  {{- if .Values.litellm.args }}
  args:
{{ toYaml .Values.litellm.args | indent 4 }}
  {{- else }}
  args:
    - "--config"
    - "{{ .Values.litellm.config_dir }}/config.yaml"
    - "--port"
    - {{ .Values.litellm.port | quote }}
  {{- end }}
  ports:
    - containerPort: {{ .Values.litellm.port }}
  {{- if .Values.litellm.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.litellm.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.litellm.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.litellm.readiness_probe | nindent 4 }}
  {{- end }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "base.name.release" . }}-litellm
  {{- if hasKey .Values.config.private "LITELLM_MASTER_KEY" }}
    - name: LITELLM_MASTER_KEY
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" . }}-secret-config
          key: LITELLM_MASTER_KEY
  {{- end }}
  {{- range $k, $v := .Values.litellm.env }}
    - name: {{ $k }}
      value: {{ $v | quote }}
  {{- end }}
{{ include "base.helper.resources" .Values.litellm | indent 2 }}
{{ include "base.helper.restrictedSecurityContext" . | indent 2 }}
  volumeMounts:
    - name: litellm-config
      mountPath: {{ .Values.litellm.config_dir }}
      readOnly: true
{{- end }}
{{- end }}

{{- define "liftwing-studio.pvc_name" -}}
{{ .Values.app.persistence.claim_name | default (printf "%s-data" (include "base.name.release" .)) }}
{{- end -}}

{{- define "liftwing-studio.volumes" }}
- name: data
{{- if .Values.app.persistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ include "liftwing-studio.pvc_name" . }}
{{- else }}
  emptyDir:
    {{- toYaml .Values.app.data_volume | nindent 4 }}
{{- end }}
- name: logs
  emptyDir:
    {{- toYaml .Values.app.logs_volume | nindent 4 }}
- name: librechat-config
  configMap:
    name: {{ include "base.meta.name" (dict "Root" . "Name" "librechat-config") }}
{{- if .Values.litellm.enabled }}
- name: litellm-config
  configMap:
    name: {{ include "base.meta.name" (dict "Root" . "Name" "litellm-config") }}
{{- end }}
{{- with .Values.app.volumes }}
{{ toYaml . }}
{{- end }}
{{- end }}
