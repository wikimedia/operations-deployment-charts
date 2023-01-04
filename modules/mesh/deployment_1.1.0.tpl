{{- define "mesh.deployment.container" -}}
{{- if .Values.mesh.enabled }}
- name: {{ template "base.name.release" . }}-tls-proxy
  image: {{ .Values.docker.registry }}/envoy:{{ .Values.mesh.image_version | default "latest" }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
    - name: SERVICE_NAME
      value: {{ .Release.Name }}
    - name: SERVICE_ZONE
      value: "default"
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
{{- end }}
{{- end -}}

{{- define "mesh.deployment.volume" }}
{{- $release := include "base.name.release" . }}
{{- if .Values.mesh.enabled }}
- name: envoy-config-volume
  configMap:
    name: {{ $release }}-envoy-config-volume
{{- if .Values.mesh.public_port }}
- name: tls-certs-volume
  configMap:
    name: {{ $release }}-tls-proxy-certs
{{- end }}
{{- end }}
{{- end -}}