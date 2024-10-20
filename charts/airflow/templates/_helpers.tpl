
{{/*
    copy of the app.generic.container template, with support for fetching
    PG connection details from the PG secrets
*/}}
{{- define "app.airflow.container" }}
# The main application container
- name: {{ template "base.name.release" . }}
  image: {{ template "app.generic._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- include "app.generic._command" . | indent 2 }}
  ports:
    - containerPort: {{ .Values.app.port }}
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
  {{- include "app.airflow.env" . | indent 2 }}
  {{- include "base.helper.resources" .Values.app | indent 2 }}
  {{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
  {{- with .Values.app.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 4 }}
  {{- end }}
{{- end }}

{{- define "app.airflow.scheduler" }}
- name: {{ template "base.name.release" . }}
  image: {{ template "app.generic._image" . }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  command: ["airflow"]
  args: ["scheduler", "--pid" , "/tmp/airflow-scheduler.pid"]
  ports:
  {{- if eq $.Values.config.airflow.config.core.executor "LocalExecutor" }}
  - containerPort: {{ $.Values.scheduler.local_executor_api_port }}
  {{- end }}
  - containerPort: {{ $.Values.config.airflow.config.scheduler.scheduler_health_check_server_port }}
  {{- if .Values.scheduler.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.scheduler.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.scheduler.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.scheduler.readiness_probe | nindent 4 }}
  {{- end }}
  {{- include "app.airflow.env" . | indent 2 }}
  {{- include "base.helper.resources" .Values.scheduler | indent 2 }}
  {{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
  {{- with .Values.scheduler.volumeMounts }}
  volumeMounts:
{{ toYaml . | indent 2 }}
  {{- end }}
{{- end }}

{{ define "app.airflow.env" }}
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
  {{- if .Values.postgresql.cloudnative }}
  {{- range $secret_data_name, $env_var := .Values.postgresql.secrets }}
  - name: {{ $env_var }}
    valueFrom:
      secretKeyRef:
        name: {{ $.Values.pgServiceName }}-app
        key: {{ $secret_data_name }}
  {{- end }}
  - name: POOLER_NAME
    value: {{ $.Values.pgServiceName }}-pooler-rw
  {{- end }}
  {{- if $.Values.postgresql.cloudnative }}
  {{/*
    According to https://github.com/sqlalchemy/sqlalchemy/discussions/8386, when using pgbouncer and sqlalchemy,
    we should delegate all pooling to pgbouncer, and disable it at the sqlalchemy level.
    This is done by setting `poolclass=NullPool` at the sqlalchemy level, which airflow does when you pass
    AIRFLOW__DATABASE__SQL_ALCHEMY_POOL_ENABLED = False.
    cf https://github.com/apache/airflow/blob/9af26368df3651b21c66ccefa6147158ecf2a8d7/airflow/settings.py#L523-L525
  */}}
  - name: AIRFLOW__DATABASE__SQL_ALCHEMY_POOL_ENABLED
    value: "False"
  {{- end }}
  - name: PYTHONPATH
    value: "/usr/local/lib/python3.11/site-packages:{{ $.Values.config.airflow.dags_root }}/{{ $.Values.gitsync.link_dir }}/:{{ $.Values.config.public.AIRFLOW_HOME }}"
  - name: AIRFLOW_INSTANCE_NAME
    value: {{ $.Values.config.airflow.instance_name }}
  - name: AIRFLOW_SCHEDULER_HOSTNAME
  {{- if $.Values.scheduler.enabled }}
    value: {{ $.Values.scheduler.service_name }}
  {{- else }}
    value: {{ $.Values.scheduler.remote_host }}
  {{- end }}
{{- end }}


{{/* Represents a Go variable as an INI value */}}
{{- define "toIniValue" -}}
{{- if kindIs "bool" .value -}}
{{- .value | toString | camelcase }}
{{- else -}}
{{ .value }}
{{- end -}}
{{- end -}}

{{/* Represents a Go variable as a literal Python value */}}
{{- define "toPythonValue" -}}
{{- if kindIs "string" .value -}}
{{- .value | quote }}
{{- else if kindIs "float64" .value -}}
{{- .value }}
{{- else if kindIs "int64" .value -}}
{{- .value }}
{{- else if kindIs "bool" .value -}}
{{- .value | toString | camelcase }}
{{- else if kindIs "slice" .value -}}
[{{- range $i, $item := .value -}}{{- template "toPythonValue" (dict "value" $item) -}}{{- if lt  $i (sub (len $.value) 1) }}, {{- else -}}]{{- end -}}{{- end -}}
{{- else if kindIs "map" .value -}}
{ {{- range $key, $val := .value }}{{ $key | quote }}: {{ template "toPythonValue" (dict "value" $val) }},{{- end -}} }
{{- end -}}
{{- end -}}
{{/*
  Recursively evaluate a value until it is no longer if the form of a helm template.
  We need this template to be recursive because we could have a setup of the following form

  x: "hi"
  y: "{{ $.Values.x }}"
  z: "{{ $.Valuez.y }}"

  z would first be evaluated to "{{ $.Values.x }}", and when recursively evaluated once more,
  it would finally be evaluated to "hi".

*/}}
{{- define "evalValue" -}}
{{- if and (kindIs "string" .value ) (and (contains "{{" .value) (contains "}}" .value)) }}
{{- /* We're dealing with a value itself containing a helm template expression that we evaluate at runtime */}}
{{- $evaluatedValue := tpl .value .Root -}}
{{- include "evalValue" (dict "value" $evaluatedValue "Root" .Root) -}}
{{- else if kindIs "bool" .value }}
{{- toString .value | title -}}
{{- else }}
{{- .value -}}
{{- end -}}
{{- end -}}


{{- define "airflow.config.database.sqlalchemy_connstr" -}}
{{- if not $.Values.postgresql.cloudnative }}
{{- with $.Values.config.airflow }}
sql_alchemy_conn = postgresql://{{ .dbUser }}:{{ .postgresqlPass }}@{{ .dbHost }}/{{ .dbName }}?sslmode=require&sslrootcert=/etc/ssl/certs/wmf-ca-certificates.crt
{{- end }}
{{- else }}
{{- /* This allows us to give airflow a command to execute to populate the sql_alchemy_conn value */}}
sql_alchemy_conn_cmd = /opt/airflow/usr/bin/pg_pooler_uri
{{- end }}
{{- end -}}

{{- define "airflow.config.core.hostname_callable" -}}
{{- if eq $.Values.config.airflow.config.core.executor "LocalExecutor" }}
{{/*
  When we are running with the LocalExecutor, the tasks are executed in the scheduler pod
  as subprocesses, meaning that we need to tell airflow to use the scheduler service name
  when using the API to fetch logs for currently running tasks. Indeed, the logs are local
  to the scheduler pod until the task completes, after which they are uploaded to s3.
*/}}
hostname_callable = webserver_config.get_scheduler_service_name
{{- end }}
{{- end }}

{{- define "airflow.initcontainer.gitsync" -}}

{{- end -}}


{{- define "secret.airflow-connections-variables" }}
---
apiVersion: v1
kind: Secret
metadata:
  name: airflow-connections-variables
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
type: Opaque
stringData:
  connections.yaml: |
    {{- tpl ( toYaml $.Values.config.connections) $ | nindent 4 }}
  variables.yaml: |
    {{- tpl ( toYaml $.Values.config.variables) $  | nindent 4 }}

{{- end }}

{{- define "executor_pod._image" -}}
"{{ .Values.docker.registry }}/{{ .Values.app.executor_pod_image }}:{{ .Values.app.executor_pod_image_version }}"
{{- end -}}
