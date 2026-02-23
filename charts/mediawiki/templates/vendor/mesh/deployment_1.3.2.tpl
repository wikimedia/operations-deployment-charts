{{- define "mesh.deployment.container" -}}
{{- if .Values.mesh.enabled }}
- name: {{ template "base.name.release" . }}-tls-proxy
  image: {{ .Values.docker.registry }}/{{ .Values.mesh.image_name | default "envoy" }}:{{ .Values.mesh.image_version | default "latest" }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
    - name: SERVICE_NAME
      value: {{ .Release.Name }}
    - name: SERVICE_ZONE
      value: "default"
    {{- if .Values.mesh.concurrency }}
    - name: CONCURRENCY
      value: "{{ .Values.mesh.concurrency }}"
    {{- end }}
    {{- with .Values.mesh.admin }}
    - name: ADMIN_PORT
      value: "{{ .port | default 1666 }}"
    - name: DRAIN_TIME_S
      value: "{{ .drain_time_s | default 600 }}"
    - name: DRAIN_STRATEGY
      value: {{ .drain_strategy | default "gradual" }}
    {{- end }}
    {{- range $k, $v := .Values.mesh.extra_env }}
    - name: {{ $k }}
      value: {{ $v | quote }}
    {{- end }}
  {{- if .Values.mesh.public_port }}
  ports:
    - containerPort: {{ .Values.mesh.public_port }}
  {{- end }}
  readinessProbe:
    httpGet:
      path: /healthz
      port: {{ .Values.mesh.telemetry.port | default 1667 }}
  volumeMounts:
    - name: envoy-config-volume
      mountPath: /etc/envoy/
      readOnly: true
{{- if .Values.mesh.public_port }}
    - name: tls-certs-volume
      mountPath: /etc/envoy/ssl
      readOnly: true
{{- end }}
{{- if .Values.mesh.drain }}
  lifecycle:
    preStop:
      exec:
        command:
        - "/bin/sh"
        - "-c"
        - "/bin/drain-envoy.sh"
{{- else if .Values.mesh.prestop_sleep }}
{{ include "base.helper.prestop" .Values.mesh.prestop_sleep | nindent 2}}
{{- end }}

  resources:
{{- if .Values.mesh.resources }}
{{ toYaml .Values.mesh.resources | indent 4 }}
{{- else }}
    requests:
      cpu: 200m
      memory: 100Mi
    limits:
      cpu: 500m
      memory: 500Mi
{{- end }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- end }}{{/* end if .Values.mesh.enabled */}}
{{- end -}}

{{- define "mesh.deployment.volume" }}
{{- $release := include "base.name.release" . }}
{{- if .Values.mesh.enabled }}
- name: envoy-config-volume
  configMap:
    name: {{ $release }}-envoy-config-volume
{{- if .Values.mesh.public_port }}
- name: tls-certs-volume
  secret:
    secretName: {{ $release }}-tls-proxy-certs
{{- end }}{{- /* end if .Values.mesh.public_port */ -}}
{{- end }}{{- /* end if .Values.mesh.enabled */ -}}
{{- end -}}
