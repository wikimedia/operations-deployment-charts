{{/* copy of generic app for the consumer */}}
{{- define "app.consumer.container" }}
- name: {{ template "base.name.release" . }}-consumer
  image: {{ template "app.consumer._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- with .Values.consumer.metricsPort }}
  ports:
    - containerPort: {{ . }}
      name: app-metrics
  {{- end }}
  {{- if .Values.debug.enabled }}
  {{- range .Values.debug.ports }}
    - containerPort: {{ . }}
  {{- end }}{{ end }}
  {{- if .Values.consumer.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.consumer.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.consumer.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.consumer.readiness_probe | nindent 4 }}
  {{- end }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "base.name.release" . }}-consumer
    - name: WDQS_NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: K8S_POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: K8S_POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
  {{- range $k, $v := .Values.consumer.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- if .Values.consumer.env_from }}
  envFrom:
  {{- toYaml .Values.consumer.env_from | nindent 4 }}
  {{- end}}
{{ include "base.helper.resources" .Values.consumer | indent 2 }}
{{ include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- with .Values.consumer.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}


{{- define "app.consumer._image" -}}
"{{ .Values.docker.registry }}/{{ .Values.consumer.image }}:{{ .Values.consumer.version }}"
{{- end -}}
