

{{/* default scaffolding for containers */}}
{{- define "app.generic.container" }}
# The main application container
- name: {{ template "base.name.release" . }}
  image: {{ template "app.generic._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- include "app.generic._command" . | indent 2 }}
  ports:
    - containerPort: {{ .Values.app.port }}
  {{- with .Values.app.metricsPort }}
    - containerPort: {{ . }}
      name: app-metrics
  {{- end }}
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
  {{- if .Values.app.env_from }}
  envFrom:
  {{- toYaml .Values.app.env_from | nindent 4 }}
  {{- end}}
{{ include "base.helper.resources" .Values.app | indent 2 }}
{{ include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- with .Values.app.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
{{- end }}


{{- define "app.generic.volume" -}}
{{- with .Values.app.volumes }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*

TODO: modify how volumes/configmaps are defined here.

We need a generic data structure that gives us:
* the base name of the volume
* the configmap {filename: content} dictionary
* the mount point
* the container selector

And a corresponding set of templates for installing
the results.

Probably this should be a separated configuration module?
*/}}

{{- define "app.generic.networkpolicy_ingress" }}
{{- if or (not .Values.mesh.enabled) (ne .Values.app.port .Values.mesh.public_port)}}
- port: {{ .Values.app.port }}
  protocol: TCP
{{- end }}
{{- with .Values.app.metricsPort }}
- port: {{ . }}
  protocol: TCP
{{- end }}
{{- if .Values.debug.enabled }}
{{- range .Values.debug.ports }}
- port: {{ . }}
  protocol: TCP
{{- end }}{{- end }}
{{- end }}

{{- define "app.generic.service" }}
---
apiVersion: v1
kind: Service
metadata:
{{- include "base.meta.metadata" (dict "Root" . ) | indent 2 }}
spec:
  type: {{ template "base.helper.serviceType" . }}
  selector:
    {{/* we don't select over the release name, so we also select canaries. */}}
    app: {{ template "base.name.chart" . }}
    routed_via: {{ .Release.Name }}
  ports:
    - name: {{ .Values.service.port.name }}
      targetPort: {{ .Values.service.port.targetPort }}
      port: {{ .Values.service.port.port }}
      {{- if and (eq (include "base.helper.serviceType" .) "NodePort") .Values.service.port.nodePort }}
      nodePort: {{ .Values.service.port.nodePort }}
      {{- end }}
{{- end }}

{{- define "app.generic.debug_service" }}
---
apiVersion: v1
kind: Service
metadata:
{{- include "base.meta.metadata" (dict "Root" . "Name" "debug") | indent 2 }}
spec:
  type: NodePort
  selector:
    app: {{ template "base.name.chart" . }}
    release: {{ .Release.Name }}
  ports:
    {{- range $port := .Values.debug.ports }}
    - name: {{ template "base.name.release" $ }}-debug-{{ $port }}
      targetPort: {{ $port }}
      port: {{ $port }}
    {{- end }}
{{- end }}

{{/* private functions */}}
{{- define "app.generic._image" -}}
"{{ .Values.docker.registry }}/{{ .Values.app.image }}:{{ .Values.app.version }}"
{{- end -}}

{{- define "app.generic._command" -}}
{{- if .Values.app.command }}
command:
  {{- range .Values.app.command }}
  - {{ . }}
  {{- end }}
{{- end }}
{{- if .Values.app.args }}
args:
  {{- range .Values.app.args }}
  - {{ . | quote }}
  {{- end }}
{{- end }}
{{- end -}}