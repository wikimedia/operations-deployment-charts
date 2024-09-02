{{/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
*/}}


{{/*
  This configmap is used to define the kerberos client configuration.
*/}}
{{- define "configmap.kerberos" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-kerberos-client-config
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  krb5.conf: |
    [libdefaults]
      default_realm = WIKIMEDIA
      kdc_timesync = 1
      ccache_type = 4
      forwardable = true
      proxiable = true
      ticket_lifetime = 2d
      renew_lifetime = 14d
      dns_canonicalize_hostname = true
      rdns = false

    [realms]
      WIKIMEDIA = {
        kdc = krb1001.eqiad.wmnet
        kdc = krb1002.codfw.wmnet
        admin_server = krb1001.eqiad.wmnet
      }
    [domain_realm]
      .wikimedia = WIKIMEDIA
      wikimedia = WIKIMEDIA
{{- end }}


# The below config is from a combination of rendered config as created by
# the upstream helm chart (using default values except the executor, which we've overridden
# with "LocalExecutor" as defined in our Airflow migration plan)

{{- define "configmap.airflow-config" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-config
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  # These are system-specified config overrides.
  airflow.cfg: |

    [core]
    colored_console_log = False
    {{- with $.Values.config.airflow }}
    dags_folder = {{ .dags_folder }}
    executor = {{ .executor }}
    load_examples = False
    remote_logging = False

    [database]
    load_default_connections = False
    {{- if not $.Values.postgresql.cloudnative }}
    sql_alchemy_conn = postgresql://{{ .dbUser }}:{{ .postgresqlPass }}@{{ .dbHost }}/{{ .dbName }}?sslmode=require&sslrootcert=/etc/ssl/certs/wmf-ca-certificates.crt
    {{- else }}
    {{/* This allows us to give airflow a command to execute to populate the sql_alchemy_conn value */}}
    sql_alchemy_conn_cmd = /opt/airflow/usr/bin/pg_pooler_uri
    {{- end }}
    {{- end }}

    [elasticsearch]
    json_format = True
    log_id_template = {dag_id}_{task_id}_{execution_date}_{try_number}

    [elasticsearch_configs]
    max_retries = 3
    retry_timeout = True
    timeout = 30

    [kerberos]
    ; ccache = /var/kerberos-ccache/cache
    ; keytab = /etc/airflow.keytab
    ; principal = airflow@FOO.COM
    ; reinit_frequency = 3600

    [kubernetes]
    ; airflow_configmap = airflow-config
    ; airflow_local_settings_configmap = airflow-config
    ; multi_namespace_mode = False
    ; namespace = airflow-analytics-test
    ; pod_template_file = /opt/airflow/pod_templates/pod_template_file.yaml
    ; worker_container_repository = docker-registry.wikimedia.org/repos/data-engineering/airflow
    ; worker_container_tag = latest

    [kubernetes_executor]
    multi_namespace_mode = False
    namespace = airflow-analytics-test
    pod_template_file = /opt/airflow/pod_templates/pod_template_file.yaml
    worker_container_repository = docker-registry.wikimedia.org/repos/data-engineering/airflow
    worker_container_tag = latest

    [logging]
    colored_console_log = False
    remote_logging = False

    ; config copied from our vm-hosted airflow instance
    [metrics]
    ;metrics_allow_list = operator_failures_,operator_successes_,sla_missed,executor.queued_tasks,dag.,dagrun.duration.,scheduler.scheduler_loop_duration,dag_processing.import_errors,dag_processing.total_parse_time,ti.failures,ti.successes,ti.finish,ti_failures,ti_successes
    ;statsd_custom_client_path = wmf_airflow_common.metrics.custom_statsd_client.CustomStatsClient
    ;statsd_host = localhost
    ;statsd_on = True
    ;statsd_port = 9125
    ;statsd_prefix = airflow

    [scheduler]
    run_duration = 41460
    standalone_dag_processor = False
    statsd_host = localhost
    statsd_on = False

    ; config copied from our vm-hosted airflow instance
    [smtp]
    smtp_host = mx1001.wikimedia.org
    smtp_mail_from = Airflow dse-k8s-eqiad: <noreply@wikimedia.org>
    smtp_port = 25
    smtp_ssl = False
    smtp_starttls = False

    [triggerer]
    default_capacity = 1000

    [webserver]
    enable_proxy_fix = True
    rbac = True

    {{- range $config_section, $config := $.Values.config.airflow.config }}

    [{{ $config_section }}]
    {{- range $config_key, $config_value := $config }}
    {{ $config_key }} = {{ template "toIni" (dict "value" $config_value)  }}
    {{- end }}
    {{- end }}
{{- end }}

{{- define "configmap.airflow-webserver-config" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-webserver-config
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  # These are system-specified config overrides.
  webserver_config.py: |
    """Default configuration for the Airflow webserver."""
    from __future__ import annotations
    import os
    from flask_appbuilder.const import AUTH_DB

    basedir = os.path.abspath(os.path.dirname(__file__))

    WTF_CSRF_ENABLED = True
    WTF_CSRF_TIME_LIMIT = None

    AUTH_TYPE = AUTH_DB
{{- end }}

{{- define "configmap.airflow-bash-executables" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-bash-executables
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  pg_pooler_uri: |
    #!/bin/sh
    printf ${PG_URI} | sed "s/$PG_HOST/$POOLER_NAME/"

{{- end }}

{{- define "configmap.airflow-connections" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-connections
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  connections.yaml: |
    {{- toYaml $.Values.config.connections | nindent 4 }}

{{- end }}
