{{- define "cluster.bootstrap.post_init_app_sql" }}
{{- if eq .Values.type "postgis" }}
- CREATE EXTENSION IF NOT EXISTS postgis;
- CREATE EXTENSION IF NOT EXISTS postgis_topology;
- CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
- CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
{{- else if eq .Values.type "timescaledb" }}
- CREATE EXTENSION IF NOT EXISTS timescaledb;
{{- end }}
{{- with .Values.cluster.initdb }}
    {{- range .postInitApplicationSQL }}
      {{- printf "- %s" . | nindent 6 }}
    {{- end -}}
{{- end -}}
{{- end }}

{{- define "cluster.bootstrap" -}}
{{- if eq .Values.mode "standalone" }}
bootstrap:
  initdb:
    {{- with .Values.cluster.initdb }}
        {{- with (omit . "postInitApplicationSQL" "import") }}
            {{- . | toYaml | nindent 4 }}
        {{- end }}
    {{- end }}
    postInitApplicationSQL: {{ include "cluster.bootstrap.post_init_app_sql" . | default "[]" }}

    {{- if .Values.cluster.initdb.import }}
    import:
      type: {{ default "microservice" .Values.cluster.initdb.import.type }}
      databases:
        - {{ required ".Values.cluster.initdb.import.dbname is required in import mode" .Values.cluster.initdb.import.dbname }}
      source:
        externalCluster: external-database
externalClusters:
- name: external-database
  connectionParameters:
    host: {{ required ".Values.cluster.initdb.import.host is required in import mode" .Values.cluster.initdb.import.host }}
    port: {{ default "5432" .Values.cluster.initdb.import.port | quote }}
    user: {{ required ".Values.cluster.initdb.import.user is required in import mode" .Values.cluster.initdb.import.user }}
    dbname: {{ required ".Values.cluster.initdb.import.dbname is required in import mode" .Values.cluster.initdb.import.dbname }}
  password:
    name: {{ include "cluster.fullname" . }}-bootstrap-import
    key: password
    {{- end }}

{{- else if eq .Values.mode "recovery" -}}
bootstrap:
  recovery:
    {{- with .Values.recovery.pitrTarget.time }}
    recoveryTarget:
      targetTime: {{ . }}
    {{- end }}
    {{- if eq .Values.recovery.method "backup" }}
    backup:
      name: {{ .Values.recovery.backupName }}
    {{- else if eq .Values.recovery.method "object_store" }}
    source: objectStoreRecoveryCluster
    {{- end }}

externalClusters:
  - name: objectStoreRecoveryCluster
    barmanObjectStore:
      serverName: {{ default (include "cluster.fullname" .) .Values.recovery.clusterName }}
      {{- $d := dict "chartFullname" (include "cluster.fullname" .) "scope" .Values.recovery "secretPrefix" "recovery" "Root" $ -}}
      {{- include "cluster.barmanObjectStoreConfig" $d | nindent 4 }}
{{-  else }}
  {{ fail "Invalid cluster mode!" }}
{{- end }}
{{- end }}
