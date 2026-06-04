{{/*
    Re-uses the same logic as the app.generic.container template
    but injects the necessary environment variables from the kafka
    external services.
*/}}
{{- define "app.kafka-ui.container" }}
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
  {{/* Start of custom behavior */}}
  {{- range $i, $cluster_name := (sortAlpha $.Values.external_services.kafka) }}
    - name: KAFKA_CLUSTERS_{{ $i }}_NAME
      value: {{ $cluster_name }}
    - name: KAFKA_CLUSTERS_{{ $i }}_BOOTSTRAPSERVERS
      value: kafka-{{ $cluster_name }}.external-services.svc.cluster.local:9092
    #- name: KAFKA_CLUSTERS_{{ $i }}_METRICS_PORT
    #  value: {{ $.Values.kafka.jmx_port | quote }}
    - name: KAFKA_CLUSTERS_{{ $i }}_READONLY
      value: "true"
  {{- end }}
  {{/* End of custom behavior */}}
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