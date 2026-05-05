{{/* copy of generic app for the init container */}}
{{- define "app.init.container" }}
- name: {{ template "base.name.release" . }}-init
  image: {{ template "app.init._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- with .Values.init.metricsPort }}
  ports:
    - containerPort: {{ . }}
      name: app-metrics
  {{- end }}
  {{- if .Values.debug.enabled }}
  {{- range .Values.debug.ports }}
    - containerPort: {{ . }}
  {{- end }}{{ end }}
  {{- if .Values.init.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.init.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.init.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.init.readiness_probe | nindent 4 }}
  {{- end }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "base.name.release" . }}-init
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
  {{- range $k, $v := .Values.init.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- range $k, $v := .Values.init.config.private }}
    - name: {{ $k | upper }}
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-init-secret-config
          key: {{ $k }}
  {{- end }}
  {{- if .Values.init.env_from }}
  envFrom:
  {{- toYaml .Values.init.env_from | nindent 4 }}
  {{- end}}
{{- include "base.helper.resources" .Values.init | indent 2 }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- with .Values.init.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}


{{- define "app.init._image" -}}
"{{ .Values.docker.registry }}/{{ .Values.init.image }}:{{ .Values.init.version }}"
{{- end -}}
