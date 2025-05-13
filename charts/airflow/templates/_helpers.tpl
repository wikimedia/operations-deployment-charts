
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
  volumeMounts:
  {{- include "app.airflow.volumeMounts" . | indent 2 }}
  {{- include "kerberos.volumeMounts" (dict "Root" . "profiles" (list "keytab")) | indent 2 }}
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
  volumeMounts:
  {{- include "app.airflow.volumeMounts" . | indent 2 }}
  {{- include "kerberos.volumeMounts" (dict "Root" .) | indent 2 }}
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
  value: "/usr/local/lib/python3.9/site-packages:{{ $.Values.config.airflow.dags_root }}/{{ $.Values.gitsync.link_dir }}/:{{ $.Values.config.public.AIRFLOW_HOME }}"
- name: AIRFLOW_INSTANCE_NAME
  value: {{ $.Values.config.airflow.instance_name }}
- name: AIRFLOW_SCHEDULER_HOSTNAME
{{- if $.Values.scheduler.enabled }}
  value: {{ $.Values.scheduler.service_name }}
{{- else }}
  value: {{ $.Values.scheduler.remote_host }}
{{- end }}
{{- if $.Values.kerberos.enabled }}
{{- include "app.airflow.env.kerberos" (dict "Root" .) }}
- name: AIRFLOW_KERBEROS_HOSTNAME
  value: {{ index (splitList "/" $.Values.config.airflow.config.kerberos.principal) 1 }}
- name: AIRFLOW_APPOWNER
  value: {{ index (splitList "/" $.Values.config.airflow.config.kerberos.principal) 0 }}
- name: KRB5_PRINCIPAL
  value: {{ $.Values.config.airflow.config.kerberos.principal }}
{{- end }}
{{- include "airflow.env.requests-ca-bundle" . }}
{{- include "airflow.env.s3" . }}
- name: SCARF_ANALYTICS
  value: "False"
{{- end }}

{{- define "airflow.env.requests-ca-bundle" }}
- name: REQUESTS_CA_BUNDLE
  value: /etc/ssl/certs/ca-certificates.crt
{{- end }}

{{- define "airflow.env.s3" }}
{{/*
  We disable checksum calculation introduced in boto 1.36, as it only pertains to AWS S3, not our Ceph implementation
  cf https://docs.aws.amazon.com/sdkref/latest/guide/feature-dataintegrity.html
*/}}
- name: AWS_REQUEST_CHECKSUM_CALCULATION
  value: WHEN_REQUIRED
- name: AWS_RESPONSE_CHECKSUM_VALIDATION
  value: WHEN_REQUIRED
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

{{- define "airflow.config.core.security" }}
{{- if $.Values.kerberos.enabled }}
security = kerberos
{{- end }}
{{- end }}

{{- define "airflow.config.api.auth_backends" }}
{{- if $.Values.kerberos.enabled }}
auth_backends = airflow.providers.fab.auth_manager.api.auth.backend.kerberos_auth, airflow.api.auth.backend.session
{{- end }}
{{- end }}

{{- define "executor_pod._image" -}}
"{{ .Values.docker.registry }}/{{ .Values.app.executor_pod_image }}:{{ .Values.app.executor_pod_image_version }}"
{{- end -}}

{{- define "render_xml_file" -}}
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
{{- range $k, $v := .config }}
  <property>
    <name>{{ $k }}</name>
    <value>{{ $v }}</value>
  </property>
{{- end }}
</configuration>
{{- end }}

{{- define "render_dotconf_file" -}}
{{- range $k, $v := .config }}
{{ $k }}  {{ $v}}
{{- end }}
{{- end }}


{{- define "airflow.pod.host_aliases" }}
hostAliases:
{{- range $hostname, $ip := $.Values.host_aliases }}
- ip: {{ $ip }}
  hostnames:
  - {{ $hostname}}
{{- end }}
{{- end }}

{{- define "airflow.task-pod.resources" }}
resources:
  requests:
  {{- toYaml .Values.worker.resources.requests | nindent 4 }}
  limits:
  {{- toYaml .Values.worker.resources.limits | nindent 4 }}
{{- end }}

{{- define "airflow.kubernetes-pod-operator.resources" }}
resources:
  requests:
  {{- toYaml .Values.kubernetes_pod_operator.resources.requests | nindent 4 }}
  limits:
  {{- toYaml .Values.kubernetes_pod_operator.resources.limits | nindent 4 }}
{{- end }}

{{- define "app.airflow.env.hadoop" }}
{{- with .Values.worker.env.hadoop }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "app.airflow.env.spark" }}
{{- with .Values.worker.env.spark }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "app.airflow.env.kerberos" }}
{{- $profiles := .profiles | default list }}
{{- with .Root.Values.kerberos.env.base }}
{{ toYaml . }}
{{- end }}
{{- if has "keytab" $profiles }}
{{- with .Root.Values.kerberos.env.keytab }}
{{ toYaml . }}
{{- end }}
{{- end }}
{{- end }}

{{- define "kerberos.volumes" }}
{{- $profiles := .profiles | default list }}
{{- if .Root.Values.kerberos.enabled }}
{{ include "app.kerberos.volumes.base" .Root }}
{{- if has "keytab" $profiles }}
{{ include "app.kerberos.volumes.keytab" .Root }}
{{- end }}
{{- end }}
{{- end }}

{{- define "kerberos.volumeMounts" }}
{{- $profiles := .profiles | default list }}
{{- if .Root.Values.kerberos.enabled }}
{{ include "app.kerberos.volumeMounts.base" .Root }}
{{- if has "keytab" $profiles }}
{{ include "app.kerberos.volumeMounts.keytab" .Root }}
{{- end }}
{{- end }}
{{- end }}

{{- define "airflow.task-pod.volumes" }}
{{- if .profiles }}
volumes:
{{- if has "airflow" .profiles }}
{{ include "app.airflow.volumes" .Root }}
{{- end }}
{{- if has "hadoop" .profiles }}
{{- include "app.worker.volumes.hadoop" .Root }}
{{- end }}
{{- if has "spark" .profiles }}
{{- include "app.worker.volumes.spark" .Root }}
{{- end }}
{{- if has "kerberos" .profiles }}
{{- include "kerberos.volumes" (dict "Root" .Root "profiles" .profiles) }}
{{- end }}
{{- end }}
{{- include "airflow.worker.extra-config-volumes" (dict "Root" .Root) }}
{{- end }}

{{- define "airflow.task-pod.volumeMounts" }}
{{- if .profiles }}
volumeMounts:
{{- if has "airflow" .profiles }}
{{- include "app.airflow.volumeMounts" .Root }}
{{- end }}
{{- if has "hadoop" .profiles }}
{{- include "app.worker.volumeMounts.hadoop" .Root }}
{{- end }}
{{- if has "spark" .profiles }}
{{- include "app.worker.volumeMounts.spark" .Root }}
{{- end }}
{{- if has "kerberos" .profiles }}
{{- include "kerberos.volumeMounts" (dict "Root" .Root "profiles" .profiles) }}
{{- end }}
{{- end }}
{{- include "airflow.worker.extra-config-volume-mounts" (dict "Root" .Root) }}
{{- end }}

{{- define "airflow.task-pod.env" }}
{{- if .header }}
env:
{{- end }}
{{- include "airflow.env.requests-ca-bundle" .Root }}
{{- include "airflow.env.s3" .Root }}
{{- if .profiles }}
{{- if has "hadoop" .profiles }}
{{- include "app.airflow.env.hadoop" .Root }}
{{- end }}
{{- if has "spark" .profiles }}
{{- include "app.airflow.env.spark" .Root }}
{{- end }}
{{- if has "kerberos" .profiles }}
{{- include "app.airflow.env.kerberos"  (dict "Root" .Root "profiles" .profiles) }}
{{- end }}
{{- end }}
{{- end }}

{{- define "airflow.worker.extra-config-resource-name" -}}
{{ template "release.name" .Root }}-worker-extra-configuration{{ .directory | replace "/" "-" }}
{{- end -}}

{{- define "airflow.worker.extra-config-volumes" }}
{{- range $directory, $config := .Root.Values.worker.config.extra_files }}
- name: {{ include "airflow.worker.extra-config-resource-name" (dict "Root" .Root "directory" $directory) }}
  configMap:
    name: {{ include "airflow.worker.extra-config-resource-name" (dict "Root" .Root "directory" $directory) }}
{{- end }}
{{- end }}

{{- define "airflow.worker.extra-config-volume-mounts" }}
{{- range $directory, $config := .Root.Values.worker.config.extra_files }}
- name: {{ include "airflow.worker.extra-config-resource-name" (dict "Root" .Root "directory" $directory) }}
  mountPath: {{ $directory }}
{{- end }}
{{- end }}

{{- define "kubernetes-executor.pod-template" -}}
apiVersion: v1
kind: Pod
metadata:
  name: overriden-at-runtime
  labels: {{/* It's important we set the app and release label to have the external_services network policies apply */}}
    {{- include "base.meta.pod_labels" .Root | indent 4 }}
    component: task-pod
    {{- if eq .profile "kubeapi" }}
    kubeapi_enabled: 'True' {{/* Non default operators, such as KubernetesPodOperator or SparkKubernetesOperator need to talk to the kube API */}}
    {{- end }}
spec:
  restartPolicy: Never
  {{- include "airflow.pod.host_aliases" .Root | indent 2 }}
  {{- if eq .profile "kubeapi" }}
  serviceAccountName: {{ template "release.name" .Root }} {{/* Non default operators, such as KubernetesPodOperator or SparkKubernetesOperator need to create pods */}}
  {{- end }}
  {{ include "airflow.task-pod.volumes" (dict "Root" .Root "profiles" (list "airflow" "hadoop" "spark" "kerberos" "keytab")) | indent 2 }}
  containers:
  - name: base
    image: {{ template "executor_pod._image" .Root }}
    imagePullPolicy: IfNotPresent
    {{- include "app.airflow.env" .Root | indent 4 }}
    {{- include "airflow.task-pod.env" (dict "Root" .Root "header" false "profiles" (list "hadoop" "spark" "kerberos" "keytab")) | nindent 4 }}
    {{- include "airflow.task-pod.volumeMounts" (dict "Root" .Root "profiles" (list "airflow" "hadoop" "spark" "kerberos" "keytab")) | indent 4 }}
    {{- if eq .profile "kubeapi" }}
    {{- include "airflow.kubernetes-pod-operator.resources" .Root | nindent 4 }}
    {{- else }}
    {{- include "airflow.task-pod.resources" .Root | nindent 4 }}
    {{- end }}
    {{- include "base.helper.restrictedSecurityContext" .Root | nindent 4 }}
{{- end }}

{{- define "kubernetes-pod-operator.pod-template" }}
apiVersion: v1
kind: Pod
metadata:
  labels: {{/* It's important we set the app and release label to have the external_services network policies apply */}}
    {{- include "base.meta.pod_labels" .Root | indent 4 }}
    component: task-pod
spec:
  restartPolicy: Never
  {{- include "airflow.task-pod.volumes" (dict "Root" .Root "profiles" .profiles) | nindent 2 }}
  containers:
  - name: base
    image: {{ template "executor_pod._image" .Root }}
    imagePullPolicy: IfNotPresent
    {{- include "airflow.task-pod.env" (dict "Root" .Root "header" true "profiles" .profiles) | nindent 4 }}
    {{- include "airflow.task-pod.volumeMounts" (dict "Root" .Root "profiles" .profiles) | nindent 4 }}
    {{- include "airflow.task-pod.resources" .Root | nindent 4 }}
    {{- include "base.helper.restrictedSecurityContext" .Root | nindent 4 }}
{{- end }}


{{ define "release.name" }}
{{- if .Values.devenv.enabled }}
{{- template "base.name.release" . }}
{{- else }}
{{- printf "airflow" }}
{{- end }}
{{- end }}


{{- define "app.airflow.volumes" }}
- name: {{ template "release.name" . }}-config
  configMap:
    name: {{ template "release.name" . }}-config
- name: {{ template "release.name" . }}-webserver-config
  configMap:
    name: {{ template "release.name" . }}-webserver-config
- name: {{ template "release.name" . }}-bash-executables
  configMap:
    name: {{ template "release.name" . }}-bash-executables
    defaultMode: 0777
- name: {{ template "release.name" . }}-connections-variables
  secret:
    secretName: {{ template "release.name" . }}-connections-variables
- name: {{ template "release.name" . }}-kubernetes-pod-templates
  configMap:
    name: {{ template "release.name" . }}-kubernetes-pod-templates
- name: {{ template "release.name" . }}-logs
  emptyDir: {}
- name: {{ template "release.name" . }}-dags
  persistentVolumeClaim:
    claimName: {{ template "release.name" . }}-dags-pvc
{{- end }}

{{- define "app.airflow.volumeMounts" }}
- name: {{ template "release.name" . }}-config
  mountPath: /opt/airflow/airflow.cfg
  subPath: airflow.cfg
- name: {{ template "release.name" . }}-webserver-config
  mountPath: /opt/airflow/webserver_config.py
  subPath: webserver_config.py
- name: {{ template "release.name" . }}-webserver-config
  mountPath: /opt/airflow/airflow_local_settings.py
  subPath: airflow_local_settings.py
- name: {{ template "release.name" . }}-logs
  mountPath: /opt/airflow/logs
- name: {{ template "release.name" . }}-bash-executables
  mountPath: /opt/airflow/usr/bin
- name: {{ template "release.name" . }}-connections-variables
  mountPath: /opt/airflow/secrets
- name: {{ template "release.name" . }}-dags
  readOnly: true
  mountPath: /opt/airflow/dags
- name: {{ template "release.name" . }}-kubernetes-pod-templates
  mountPath: /opt/airflow/pod_templates
{{- end }}

{{- define "app.gitsync.volumes" }}
- name: {{ template "release.name" . }}-dags
  persistentVolumeClaim:
    claimName: {{ template "release.name" . }}-dags-pvc
- name: {{ template "release.name" . }}-sparse-checkout-config
  configMap:
    name: {{ template "release.name" . }}-gitsync-sparse-checkout-file
{{- end }}

{{- define "app.gitsync.volumeMounts" }}
- name: {{ template "release.name" . }}-dags
  mountPath: /dags
- name: {{ template "release.name" . }}-sparse-checkout-config
  mountPath: /etc/gitsync/sparse-checkout.conf
  subPath: sparse-checkout.conf
{{- end }}

{{ define "app.worker.volumes.hadoop" }}
- name: {{ template "release.name" . }}-hadoop-configuration
  configMap:
    name: {{ template "release.name" . }}-hadoop-configuration
{{- end }}

{{ define "app.worker.volumes.spark" }}
- name: {{ template "release.name" . }}-spark-configuration
  configMap:
    name: {{ template "release.name" . }}-spark-configuration
{{- end }}

{{ define "app.worker.volumeMounts.hadoop" }}
- name: {{ template "release.name" . }}-hadoop-configuration
  mountPath: /etc/hadoop/conf
{{- end }}


{{ define "app.worker.volumeMounts.spark" }}
- name: {{ template "release.name" . }}-spark-configuration
  mountPath: /etc/spark3/conf
{{- end }}

{{- define "app.kerberos.volumes.base" }}
- name: {{ template "release.name" . }}-kerberos-client-config
  configMap:
    name: {{ template "release.name" . }}-kerberos-client-config
- name: {{ template "release.name" . }}-kerberos-token
  persistentVolumeClaim:
    claimName: {{ template "release.name" . }}-kerberos-token-pvc
{{- end }}

{{- define "app.kerberos.volumes.keytab" }}
- name: {{ template "release.name" . }}-kerberos-keytab
  secret:
    secretName: {{ template "release.name" . }}-kerberos-keytab
{{- end }}

{{- define "app.kerberos.volumeMounts.base" }}
- name: {{ template "release.name" . }}-kerberos-client-config
  mountPath: /etc/krb5.conf
  subPath: krb5.conf
- name: {{ template "release.name" . }}-kerberos-token
  mountPath: /tmp/airflow_krb5_ccache
{{- end }}

{{- define "app.kerberos.volumeMounts.keytab" }}
- name: {{ template "release.name" . }}-kerberos-keytab
  mountPath: /etc/kerberos/keytabs
  readOnly: true
{{- end }}
