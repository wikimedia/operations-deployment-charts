{{- define "limits.mae-consumer" }}
resources:
  requests:
{{ toYaml .Values.main_app.requests | indent 4 }}
  limits:
{{ toYaml .Values.main_app.limits | indent 4 }}
{{ end -}}

{{/* Generate a service name for the GMS service, depending on whether or not it uses TLS */}}
{{- define "wmf.gms-service.mae-consumer" -}}
  {{- if .Values.global.datahub.gms.useSSL }}
    {{- printf "https://datahub-gms-%s" .Release.Name | trunc 63 | trimSuffix "-" -}}-tls-service.{{ .Release.Namespace }}.svc.cluster.local
  {{- else -}}
    {{- printf "http://datahub-gms-%s" .Release.Name | trunc 63 | trimSuffix "-" -}}.{{ .Release.Namespace }}.svc.cluster.local
  {{- end }}
{{- end -}}
{{- define "wmf.gms-service.scheme" -}}
  {{- if .Values.global.datahub.gms.useSSL }}
  https://
  {{- else -}}
  http://
  {{- end }}
{{- end -}}
{{/* default scaffolding for containers */}}
{{- define "default.containers.mae-consumer" }}
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
    - name: MAE_CONSUMER_ENABLED
      value: "true"
    - name: ENTITY_REGISTRY_CONFIG_PATH
      value: /datahub/datahub-mae-consumer/resources/entity-registry.yml
    - name: DATAHUB_GMS_HOST
      value: {{ template "wmf.gms-service.mae-consumer" $ }}
    - name: DATAHUB_GMS_PORT
      value: "{{ required "GMS port must be specified" .Values.global.datahub.gms.port }}"
    - name: KAFKA_BOOTSTRAP_SERVER
      value: "{{ required "Kafka bootstrap server must be specified" .Values.global.kafka.bootstrap.server }}"
    {{- if eq .Values.global.kafka.schemaregistry.type "INTERNAL" }}
    - name: KAFKA_SCHEMAREGISTRY_URL
      value: {{ printf "%s%s:%s/schema-registry/api/" ( include "wmf.gms-service.scheme" $ ) ( include "wmf.gms-service.mae-consumer" $ ) ( .Values.global.datahub.gms.port | toString ) }}
    {{- else if eq .Values.global.kafka.schemaregistry.type "KAFKA" }}
    - name: KAFKA_SCHEMAREGISTRY_URL
      value: "{{ .Values.global.kafka.schemaregistry.url }}"
    {{- end }}
    {{- with .Values.global.kafka.schemaregistry.type }}
    - name: SCHEMA_REGISTRY_TYPE
      value: "{{ . }}"
    {{- end }}
    {{- with .Values.global.kafka.schemaregistry.glue }}
    - name: AWS_GLUE_SCHEMA_REGISTRY_REGION
      value: "{{ .region }}"
    {{- with .registry }}
    - name: AWS_GLUE_SCHEMA_REGISTRY_NAME
      value: "{{ . }}"
    {{- end }}
    {{- end }}
    - name: ELASTICSEARCH_HOST
      value: "{{ required "Elasticsearch host must be specified" .Values.global.elasticsearch.host }}"
    - name: ELASTICSEARCH_PORT
      value: "{{ required "Elasticsearch port must be specified" .Values.global.elasticsearch.port }}"
    {{- with .Values.global.elasticsearch.useSSL }}
    - name: ELASTICSEARCH_USE_SSL
      value: {{ . | quote }}
    {{- end }}
    {{- with .Values.global.elasticsearch.auth }}
    - name: ELASTICSEARCH_USERNAME
      value: {{ .username }}
    - name: ELASTICSEARCH_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: elasticsearch_password
    {{- end }}
    {{- with .Values.global.elasticsearch.indexPrefix }}
    - name: INDEX_PREFIX
      value: {{ . }}
    {{- end }}
    - name: GRAPH_SERVICE_IMPL
      value: {{ .Values.global.graph_service_impl }}
    - name: DATAHUB_ANALYTICS_ENABLED
      value: "{{ .Values.global.datahub_analytics_enabled }}"
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
    {{- with .Values.global.kafka.topics }}
    - name: METADATA_AUDIT_EVENT_NAME
      value: {{ .metadata_audit_event_name }}
    - name: DATAHUB_USAGE_EVENT_NAME
      value: {{ .datahub_usage_event_name }}
    - name: METADATA_CHANGE_LOG_VERSIONED_TOPIC_NAME
      value: {{ .metadata_change_log_versioned_topic_name }}
    - name: METADATA_CHANGE_LOG_TIMESERIES_TOPIC_NAME
      value: {{ .metadata_change_log_timeseries_topic_name }}
    - name: PLATFORM_EVENT_TOPIC_NAME
      value: {{ .platform_event_topic_name }}
    - name: DATAHUB_UPGRADE_HISTORY_TOPIC_NAME
      value: {{ .datahub_upgrade_history_topic_name }}
    {{- end }}
    {{- if .Values.global.datahub.managed_ingestion.enabled }}
    - name: UI_INGESTION_ENABLED
      value: "true"
    {{- else }}
    - name: UI_INGESTION_ENABLED
      value: "false"
    {{- end }}
    {{- if .Values.global.datahub.managed_ingestion.defaultCliVersion }}
    - name: UI_INGESTION_DEFAULT_CLI_VERSION
      value: "{{ .Values.global.datahub.managed_ingestion.defaultCliVersion }}"
    {{- end }}
{{ include "limits.mae-consumer" . | indent 2}}
{{- with .Values.main_app.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}
  {{- include "base.helper.restrictedSecurityContext" . | nindent 2 }}
{{ end }}