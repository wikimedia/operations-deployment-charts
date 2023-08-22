{{- define "limits.frontend" }}
resources:
  requests:
{{ toYaml .Values.main_app.requests | indent 4 }}
  limits:
{{ toYaml .Values.main_app.limits | indent 4 }}
{{ end -}}

{{/* Generate a service name for the GMS service, depending on whether or not it uses TLS */}}
{{- define "wmf.gms-service.frontend" -}}
  {{- if .Values.mesh.enabled }}
    {{- printf "datahub-gms-%s" .Release.Name | trunc 63 | trimSuffix "-" -}}-tls-service.{{ .Release.Namespace }}.svc.cluster.local
  {{- else -}}
    {{- printf "datahub-gms-%s" .Release.Name | trunc 63 | trimSuffix "-" -}}.{{ .Release.Namespace }}.svc.cluster.local
  {{- end }}
{{- end -}}

{{/* default scaffolding for containers */}}
{{- define "default.containers.frontend" }}
# The main application container
- name: {{ template "base.name.release" . }}
  image: "{{ .Values.docker.registry }}/{{ .Values.main_app.image }}:{{ .Values.main_app.version }}"
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- if .Values.main_app.command }}
  command:
    {{- range .Values.main_app.command }}
    - {{ . }}
    {{- end }}
  {{- end }}
  {{- if .Values.main_app.args }}
  args:
    {{- range .Values.main_app.args }}
    - {{ . }}
    {{- end }}
  {{- end }}
  ports:
    - containerPort: {{ .Values.app.port }}
  {{- if .Values.debug.enabled }}
  {{- range .Values.debug.ports }}
    - containerPort: {{ . }}
  {{- end }}{{ end }}
  {{- if .Values.main_app.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.main_app.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.main_app.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.main_app.readiness_probe | nindent 4 }}
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
    {{- if .Values.global.datahub.monitoring.enablePrometheus }}
    - name: ENABLE_PROMETHEUS
      value: "true"
    {{- end }}
    - name: DATAHUB_GMS_HOST
      value: {{ template "wmf.gms-service.frontend" $ }}
    - name: DATAHUB_GMS_PORT
      value: "{{ required "GMS port must be specified" .Values.global.datahub.gms.port }}"
    - name: DATAHUB_SECRET
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: datahub_encryption_key
    - name: DATAHUB_APP_VERSION
      value: "{{ .Chart.AppVersion }}"
    - name: DATAHUB_PLAY_MEM_BUFFER_SIZE
      value: "{{ required "Play memory buffer size must be specified" .Values.global.datahub.play.mem.buffer.size }}"
    - name: DATAHUB_ANALYTICS_ENABLED
      value: "{{ .Values.global.datahub_analytics_enabled }}"
    - name: KAFKA_BOOTSTRAP_SERVER
      value: "{{ required "Kafka bootstrap server must be specified" .Values.global.kafka.bootstrap.server }}"
    - name: ELASTIC_CLIENT_HOST
      value: "{{ required "Elasticsearch host must be specified"  .Values.global.elasticsearch.host }}"
    - name: ELASTIC_CLIENT_PORT
      value: "{{ required "Elasticsearch port must be specified" .Values.global.elasticsearch.port }}"
    {{- with .Values.global.elasticsearch.useSSL }}
    - name: ELASTIC_CLIENT_USE_SSL
      value: {{ . | quote }}
    {{- end }}
    {{- with .Values.global.elasticsearch.auth }}
    - name: ELASTIC_CLIENT_USERNAME
      value: {{ .username }}
    - name: ELASTIC_CLIENT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: elasticsearch_password
    {{- end }}
    {{- with .Values.global.elasticsearch.indexPrefix }}
    - name: INDEX_PREFIX
      value: {{ . }}
    {{- end }}
    {{- if .Values.global.kafka.topics }}
    - name: DATAHUB_TRACKING_TOPIC
      value: {{ .Values.global.kafka.topics.datahub_usage_event_name}}
    {{- else }}
    - name: DATAHUB_TRACKING_TOPIC
      value: "DataHubUsageEvent_v1"
    {{- end }}
    {{- if .Values.global.datahub.gms.useSSL }}
    - name: DATAHUB_GMS_USE_SSL
      value: "true"
    {{- end }}
    {{- if .Values.global.datahub.metadata_service_authentication.enabled }}
    - name: METADATA_SERVICE_AUTH_ENABLED
      value: "true"
    - name: DATAHUB_SYSTEM_CLIENT_ID
      value: {{ .Values.global.datahub.metadata_service_authentication.systemClientId }}
    - name: DATAHUB_SYSTEM_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: token_service_signing_key
    {{- end }}
    - name: AUTH_OIDC_ENABLED
      value: "true"
    - name: AUTH_OIDC_CLIENT_ID
      value: "datahub_staging"
    - name: AUTH_OIDC_PRE_PROVISIONING_REQUIRED
      value: "false"
    - name: AUTH_OIDC_DISCOVERY_URI
      value: "https://idp-test.wikimedia.org/oidc/.well-known"
    - name: AUTH_OIDC_BASE_URL
      value: "https://datahub-frontend.k8s-staging.discovery.wmnet"
    - name: AUTH_OIDC_USER_NAME_CLAIM
      value: "preferred_username"
    - name: AUTH_OIDC_JIT_PROVISIONING_ENABLED
      value: "true"
    - name: AUTH_OIDC_EXTRACT_GROUPS_ENABLED
      value: "true"
{{ include "limits.frontend" . | indent 2}}
{{- if or (.Values.main_app.volumeMounts) (.Values.auth.ldap.enabled) }}
  volumeMounts:
  {{- with .Values.main_app.volumeMounts }}
    {{ toYaml . | indent 4 }}
  {{- end }}
  {{- with .Values.auth.ldap.enabled }}
    - name: {{ template "base.name.release" $ }}-jaas
      mountPath: /datahub-frontend/conf/jaas.conf
      subPath: jaas.conf
      readOnly: true
  {{- end }}
{{- end }}

{{- end }}

