{{- define "evalValue" -}}
{{- if and (kindIs "string" .value ) (and (contains "{{" .value) (contains "}}" .value)) }}
{{- /* We're dealing with a value itself containing a helm template expression that we evaluate at runtime */}}
{{- $evaluatedValue := tpl .value .Root -}}
{{- include "evalValue" (dict "value" $evaluatedValue "Root" .Root) -}}
{{- else }}
{{- .value -}}
{{- end -}}
{{- end -}}

{{- define "render_xml_file" -}}
{{- $Root := .Root }}
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
{{- range $k, $v := .config }}
  <property>
    <name>{{ $k }}</name>
    <value>{{ include "evalValue" (dict "value" $v "Root" $Root) }}</value>
  </property>
{{- end }}
</configuration>
{{- end }}

{{- define "app.volume.projected_jwt" }}
- name: rgw-token
  projected:
    sources:
    - serviceAccountToken:
        audience: "{{ $.Values.config.public.AWS_ENDPOINT_URL_STS }}"
        expirationSeconds: 3600
        path: token
{{- end }}


{{- define "app.generic.container.extended" }}
# The main application container
- name: {{ template "base.name.release" . }}
  image: {{ template "app.generic._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- include "app.generic._command" . | indent 2 }}
  ports:
    - containerPort: {{ .Values.app.port }}
  {{/* start customization */}}
  {{- range $port := .Values.app.extra_ports }}
    - containerPort: {{ $port.port }}
      name: {{ $port.name }}
  {{- end }}
  {{/* end customization */}}
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


{{- define "app.generic.service.extended" }}
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
    {{/* start customization */}}
    {{- range $port := .Values.app.extra_ports }}
    - name: {{ $port.name }}
      targetPort: {{ $port.port }}
      port: {{ $port.port }}
    {{- end }}
    {{/* end customization */}}

{{- end }}
