{{- define "limits.gms" }}
resources:
  requests:
{{ toYaml .Values.main_app.requests | indent 4 }}
  limits:
{{ toYaml .Values.main_app.limits | indent 4 }}
{{ end -}}

{{/* default scaffolding for containers */}}
{{- define "default.containers.gms" }}
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
    - name: DATAHUB_GMS_PORT
      value: "{{ required "GMS port must be specified" .Values.global.datahub.gms.port }}"
    {{- if .Values.global.datahub.gms.useSSL }}
    - name: DATAHUB_GMS_USE_SSL
      value: "true"
    {{- end }}
    - name: ENTITY_REGISTRY_CONFIG_PATH
      value: /datahub/datahub-gms/resources/entity-registry.yml
    - name: DATAHUB_ANALYTICS_ENABLED
      value: "{{ .Values.global.datahub_analytics_enabled }}"
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
    - name: KAFKA_BOOTSTRAP_SERVER
      value: "{{ required "Kafka bootstrap server must be specified" .Values.global.kafka.bootstrap.server }}"
    - name: KAFKA_SCHEMAREGISTRY_URL
      value: "{{ required "Schema registry URL must be specified" .Values.global.kafka.schemaregistry.url }}"
    {{- with .Values.global.kafka.schemaregistry.type }}
    - name: SCHEMA_REGISTRY_TYPE
      value: "{{ . }}"
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
    {{- if .Values.global.datahub.metadata_service_authentication.enabled }}
    - name: METADATA_SERVICE_AUTH_ENABLED
      value: "true"
    - name: DATAHUB_TOKEN_SERVICE_SIGNING_KEY
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: token_service_signing_key
    - name: DATAHUB_SYSTEM_CLIENT_ID
      value: {{ .Values.global.datahub.metadata_service_authentication.systemClientId }}
    - name: DATAHUB_SYSTEM_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: token_service_signing_key
    {{- end }}
    {{- if .Values.global.datahub.managed_ingestion.enabled }}
    - name: UI_INGESTION_ENABLED
      value: "true"
    - name: SECRET_SERVICE_ENCRYPTION_KEY
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: token_service_signing_key
    {{- else }}
    - name: UI_INGESTION_ENABLED
      value: "false"
    {{- end }}
    {{- if .Values.global.datahub.managed_ingestion.defaultCliVersion }}
    - name: UI_INGESTION_DEFAULT_CLI_VERSION
      value: "{{ .Values.global.datahub.managed_ingestion.defaultCliVersion }}"
    {{- end }}
    {{- if not .Values.global.datahub_standalone_consumers_enabled }}
    - name: MCE_CONSUMER_ENABLED
      value: "true"
    - name: MAE_CONSUMER_ENABLED
      value: "true"
    {{- end }}
    {{- if .Values.global.datahub.enable_retention }}
    - name: ENTITY_SERVICE_ENABLE_RETENTION
      value: "true"
    {{- end }}
    - name: ELASTICSEARCH_QUERY_MAX_TERM_BUCKET_SIZE
      value: {{ .Values.global.elasticsearch.search.maxTermBucketSize | quote }}
    - name: ELASTICSEARCH_QUERY_EXACT_MATCH_EXCLUSIVE
      value: {{ .Values.global.elasticsearch.search.exactMatch.exclusive | quote }}
    - name: ELASTICSEARCH_QUERY_EXACT_MATCH_WITH_PREFIX
      value: {{ .Values.global.elasticsearch.search.exactMatch.withPrefix | quote }}
    - name: ELASTICSEARCH_QUERY_EXACT_MATCH_FACTOR
      value: {{ .Values.global.elasticsearch.search.exactMatch.exactFactor | quote }}
    - name: ELASTICSEARCH_QUERY_EXACT_MATCH_PREFIX_FACTOR
      value: {{ .Values.global.elasticsearch.search.exactMatch.prefixFactor | quote }}
    - name: ELASTICSEARCH_QUERY_EXACT_MATCH_CASE_FACTOR
      value: {{ .Values.global.elasticsearch.search.exactMatch.caseSensitivityFactor | quote }}
    - name: ELASTICSEARCH_QUERY_EXACT_MATCH_ENABLE_STRUCTURED
      value: {{ .Values.global.elasticsearch.search.exactMatch.enableStructured | quote }}
    - name: ELASTICSEARCH_SEARCH_GRAPH_TIMEOUT_SECONDS
      value: {{ .Values.global.elasticsearch.search.graph.timeoutSeconds | quote }}
    - name: ELASTICSEARCH_SEARCH_GRAPH_BATCH_SIZE
      value: {{ .Values.global.elasticsearch.search.graph.batchSize | quote }}
    - name: ELASTICSEARCH_SEARCH_GRAPH_MAX_RESULT
      value: {{ .Values.global.elasticsearch.search.graph.maxResult | quote }}
    - name: SEARCH_SERVICE_ENABLE_CACHE
      value: {{ .Values.global.datahub.cache.search.enabled | quote }}
    {{- if .Values.global.datahub.cache.search.enabled }}
    - name: CACHE_TTL_SECONDS
      value: {{ .Values.global.datahub.cache.search.primary.ttlSeconds | quote }}
    - name: CACHE_MAX_SIZE
      value: {{ .Values.global.datahub.cache.search.primary.maxSize | quote }}
    - name: CACHE_ENTITY_COUNTS_TTL_SECONDS
      value: {{ .Values.global.datahub.cache.search.homepage.entityCounts.ttlSeconds | quote }}
    {{- end }}
    - name: LINEAGE_SEARCH_CACHE_ENABLED
      value: {{ .Values.global.datahub.cache.search.lineage.enabled | quote }}
    {{- if .Values.global.datahub.cache.search.lineage.enabled }}
    - name: CACHE_SEARCH_LINEAGE_TTL_SECONDS
      value: {{ .Values.global.datahub.cache.search.lineage.ttlSeconds | quote }}
    - name: CACHE_SEARCH_LINEAGE_LIGHTNING_THRESHOLD
      value: {{ .Values.global.datahub.cache.search.lineage.lightningThreshold | quote }}
    {{- end }}
    {{- with .Values.global.elasticsearch.index.enableMappingsReindex }}
    - name: ELASTICSEARCH_INDEX_BUILDER_MAPPINGS_REINDEX
      value: {{ . | quote }}
    {{- end }}
    {{- with .Values.global.elasticsearch.index.enableSettingsReindex }}
    - name: ELASTICSEARCH_INDEX_BUILDER_SETTINGS_REINDEX
      value: {{ . | quote }}
    {{- end }}
    - name: ALWAYS_EMIT_CHANGE_LOG
      value: {{ .Values.global.datahub.alwaysEmitChangeLog | quote }}
    - name: GRAPH_SERVICE_DIFF_MODE_ENABLED
      value: {{ .Values.global.datahub.enableGraphDiffMode | quote }}
{{ include "limits.gms" . | indent 2}}
{{- with .Values.main_app.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
{{- end }}

{{ end }}