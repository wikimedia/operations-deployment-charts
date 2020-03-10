{{/* TLS termination related helpers */}}


{{/*

 Deployment templates

*/}}

{{- define "tls.annotations" -}}
{{- if .Values.tls.enabled }}
checksum/tls: {{ printf "%s|%s|%s" .Values.tls.public_port .Values.main_app.port .Values.tls.certs.cert | sha256sum }}
{{- if .Values.tls.telemetry.enabled }}
envoyproxy.io/scrape: "true"
envoyproxy.io/port: "{{ .Values.tls.telemetry.port }}"
{{- else }}
envoyproxy.io/scrape: "false"
{{- end }}
{{- end }}
{{- end -}}

{{- define "tls.container" -}}
{{- if .Values.tls.enabled }}
- name: {{ .Values.main_app.name }}-tls-proxy
  image: {{ .Values.docker.registry }}/envoy-tls-local-proxy:{{ .Values.tls.image_version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
    - name: SERVICE_NAME
      value: {{ .Release.Name }}
    - name: SERVICE_PORT
      value: "{{ .Values.main_app.port }}" # env variables need to be strings
    - name: PUBLIC_PORT
      value: "{{ .Values.tls.public_port }}"
    - name: ADMIN_LISTEN
      value: {{ if .Values.tls.telemetry.enabled }}0.0.0.0{{ else }}127.0.0.1{{ end }}
    - name: ADMIN_PORT
      value: "{{ .Values.tls.telemetry.port }}"
    - name: UPSTREAM_TIMEOUT
      value: {{ .Values.tls.upstream_timeout }}
  ports:
    - containerPort: {{ .Values.tls.public_port }}
  volumeMounts:
    - name: tls-certs-volume
      mountPath: /etc/envoy/ssl
      readOnly: true
  resources:
{{- if .Values.tls.resources }}
{{ toYaml .Values.tls.resources | indent 4 }}
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

{{- define "tls.volume" }}
{{- if .Values.tls.enabled }}
- name: tls-certs-volume
  configMap:
    name: {{ template "wmf.releasename" . }}-tls-proxy-certs
{{- end }}
{{- end -}}

{{/*

 Service templates

*/}}
{{- define "tls.service" -}}
---
kind: Service
apiVersion: v1
metadata:
  name: {{ template "wmf.releasename" . }}-tls-service
  labels:
    chart: {{ template "wmf.chartname" . }}
    app: {{ .Values.main_app.name }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  type: NodePort
  selector:
    chart: {{ template "wmf.chartname" . }}
    app: {{ .Values.main_app.name }}
    routing_tag: {{ .Values.service.routing_tag | default .Release.Name }}
  ports:
    - name: {{ .Values.main_app.name }}-https
      protocol: TCP
      targetPort: {{ .Values.tls.public_port }}
      port: {{ .Values.tls.public_port }}
      nodePort: {{ .Values.tls.public_port }}
{{- end -}}

{{/*

 ConfigMap templates

*/}}

{{- define "tls.config" -}}
{{- if .Values.tls.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-tls-proxy-certs
  labels:
    chart: {{ template "wmf.chartname" . }}
    app: {{ .Values.main_app.name }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
data:
  service.crt: |-
{{ .Values.tls.certs.cert | indent 4 }}
  service.key: |-
{{ .Values.tls.certs.key | indent 4 }}
{{ end -}}
{{- end -}}

{{/*

 NetworkPolicy templates

*/}}
{{- define "tls.networkpolicy" -}}
{{- if .Values.tls.enabled }}
- port: {{ .Values.tls.public_port }}
  protocol: TCP
{{- if .Values.tls.telemetry.enabled }}
- port: {{ .Values.tls.telemetry.port }}
  protocol: TCP
{{- end }}
{{- end }}
{{- end -}}
