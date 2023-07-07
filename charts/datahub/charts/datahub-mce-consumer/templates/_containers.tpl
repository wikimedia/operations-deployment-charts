{{- define "limits.mce-consumer" }}
resources:
  requests:
{{ toYaml .Values.main_app.requests | indent 4 }}
  limits:
{{ toYaml .Values.main_app.limits | indent 4 }}
{{ end -}}

{{/* Generate a service name for the GMS service, depending on whether or not it uses TLS */}}
{{- define "wmf.gms-service.mce-consumer" -}}
  {{- if .Values.global.datahub.gms.useSSL }}
    {{- printf "datahub-gms-%s" .Release.Name | trunc 63 | trimSuffix "-" -}}-tls-service.{{ .Release.Namespace }}.svc.cluster.local
  {{- else -}}
    {{- printf "datahub-gms-%s" .Release.Name | trunc 63 | trimSuffix "-" -}}.{{ .Release.Namespace }}.svc.cluster.local
  {{- end }}
{{- end -}}

{{/* default scaffolding for containers */}}
{{- define "default.containers.mce-consumer" }}
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
    - name: SHOW_SEARCH_FILTERS_V2
      value: {{ .Values.global.datahub.search_and_browse.show_search_v2 | quote }}
    - name: SHOW_BROWSE_V2
      value: {{ .Values.global.datahub.search_and_browse.show_browse_v2 | quote }}
    - name: BACKFILL_BROWSE_PATHS_V2
      value: {{ .Values.global.datahub.search_and_browse.backfill_browse_v2 | quote }}
    {{- if .Values.global.datahub.systemUpdate.enabled }}
    - name: DATAHUB_UPGRADE_HISTORY_KAFKA_CONSUMER_GROUP_ID
      value: {{ printf "%s-%s" .Release.Name "duhe-consumer-job-client-mcp" }}
    - name: DATAHUB_REVISION
      value: {{ .Release.Revision | quote }}
    {{- end }}
    {{- if .Values.global.datahub.monitoring.enablePrometheus }}
    - name: ENABLE_PROMETHEUS
      value: "true"
    {{- end }}
    - name: MCE_CONSUMER_ENABLED
      value: "true"
    - name: KAFKA_BOOTSTRAP_SERVER
      value: "{{ required "Kafka bootstrap server must be specified" .Values.global.kafka.bootstrap.server }}"
    {{- if eq .Values.global.kafka.schemaregistry.type "INTERNAL" }}
    - name: KAFKA_SCHEMAREGISTRY_URL
      value: {{ printf "https://%s:%s/schema-registry/api/" ( include "wmf.gms-service.mce-consumer" $ ) ( .Values.global.datahub.gms.port | toString ) }}
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
    - name: ENTITY_REGISTRY_CONFIG_PATH
      value: /datahub/datahub-mce-consumer/resources/entity-registry.yml
    - name: EBEAN_DATASOURCE_USERNAME
      value: "{{ required "Database username must be specified" .Values.global.sql.datasource.username }}"
    - name: EBEAN_DATASOURCE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: mysql_password
    - name: EBEAN_DATASOURCE_HOST
      value: "{{ required "Database host must be specified" .Values.global.sql.datasource.host }}"
    - name: EBEAN_DATASOURCE_URL
      value: "{{ required "Database URL must be specified" .Values.global.sql.datasource.url }}"
    - name: EBEAN_DATASOURCE_DRIVER
      value: "{{ required "Database driver must be specified" .Values.global.sql.datasource.driver }}"
    - name: ELASTICSEARCH_HOST
      value: "{{ .Values.global.elasticsearch.host }}"
    - name: ELASTICSEARCH_PORT
      value: "{{ .Values.global.elasticsearch.port }}"
    - name: SKIP_ELASTICSEARCH_CHECK
      value: "{{ .Values.global.elasticsearch.skipcheck }}"
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
    - name: DATAHUB_GMS_HOST
      value: {{ template "wmf.gms-service.mce-consumer" $ }}
    - name: DATAHUB_GMS_PORT
      value: "{{ required "GMS port must be specified" .Values.global.datahub.gms.port }}"
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
    {{- if .Values.global.springKafkaConfigurationOverrides }}
    {{- range $configName, $configValue := .Values.global.springKafkaConfigurationOverrides }}
    - name: SPRING_KAFKA_PROPERTIES_{{ $configName | replace "." "_" | upper }}
      value: {{ $configValue | quote }}
    {{- end }}
    {{- end }}
    {{- if .Values.global.credentialsAndCertsSecrets }}
    {{- range $envVarName, $envVarValue := .Values.global.credentialsAndCertsSecrets.secureEnv }}
    - name: SPRING_KAFKA_PROPERTIES_{{ $envVarName | replace "." "_" | upper }}
      valueFrom:
        secretKeyRef:
          name: {{ $.Values.global.credentialsAndCertsSecrets.name }}
          key: {{ $envVarValue }}
    {{- end }}
    {{- end }}
    {{- with .Values.global.kafka.topics }}
    - name: METADATA_CHANGE_EVENT_NAME
      value: {{ .metadata_change_event_name }}
    - name: FAILED_METADATA_CHANGE_EVENT_NAME
      value: {{ .failed_metadata_change_event_name }}
    - name: METADATA_CHANGE_PROPOSAL_TOPIC_NAME
      value: {{ .metadata_change_proposal_topic_name }}
    - name: FAILED_METADATA_CHANGE_PROPOSAL_TOPIC_NAME
      value: {{ .failed_metadata_change_proposal_topic_name }}
    - name: METADATA_CHANGE_LOG_VERSIONED_TOPIC_NAME
      value: {{ .metadata_change_log_versioned_topic_name }}
    - name: METADATA_CHANGE_LOG_TIMESERIES_TOPIC_NAME
      value: {{ .metadata_change_log_timeseries_topic_name }}
    - name: DATAHUB_UPGRADE_HISTORY_TOPIC_NAME
      value: {{ .datahub_upgrade_history_topic_name }}
    {{- end }}
    - name: ALWAYS_EMIT_CHANGE_LOG
      value: {{ .Values.global.datahub.alwaysEmitChangeLog | quote }}
    - name: GRAPH_SERVICE_DIFF_MODE_ENABLED
      value: {{ .Values.global.datahub.enableGraphDiffMode | quote }}
{{ include "limits.mce-consumer" . | indent 2}}
{{- with .Values.main_app.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}

{{ end }}