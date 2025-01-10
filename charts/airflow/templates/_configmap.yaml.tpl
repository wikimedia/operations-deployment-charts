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
      {{/*
        we need this because otherwise the airflow hostname is canonicalized to
        k8s-ingress-dse.discovery.wmnet, and we'd need to reflect this in the
        KDB, which does not make a whole lot of sense
      */}}
      dns_canonicalize_hostname = false
      rdns = false

    [realms]
      WIKIMEDIA = {
        kdc = krb1001.eqiad.wmnet
        kdc = krb2002.codfw.wmnet
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
    {{- range $config_section, $config := $.Values.config.airflow.config }}

    [{{ $config_section }}]
    {{- range $config_key, $config_value := $config }}
    {{- $value := include "evalValue" (dict "value" $config_value "Root" $)}}
    {{ $config_key }} = {{ template "toIniValue" (dict "value" $value)  }}
    {{- end }}

    {{- if eq $config_section "database" }}
    {{- include "airflow.config.database.sqlalchemy_connstr" $ | indent 4 }}
    {{- else if eq $config_section "core" }}
    {{- include "airflow.config.core.hostname_callable" $ | indent 4 }}
    {{- include "airflow.config.core.security" $ | indent 4 }}
    {{- else if eq $config_section "api" }}
    {{- include "airflow.config.api.auth_backends" $ | indent 4 }}
    {{- end }}
    {{- end }}

{{- end }}

{{/*
  This configmap is used to define the airflow webserver configuration
*/}}
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
    from airflow.www.fab_security.manager import AUTH_OAUTH

    AUTH_TYPE = AUTH_OAUTH
    {{- with $.Values.config.oidc }}
    OAUTH_PROVIDERS = [
        {
            "name": "CAS",
            "icon": "fa-openid",
            'token_key':'access_token',
            "remote_app": {
                "client_id": "{{ .client_id }}",
                "client_secret": "{{ .client_secret }}",
                "server_metadata_url": "https://{{ .idp_server }}/oidc/.well-known",
                'client_kwargs':{
                    'scope': 'openid email profile groups'
                },
            },
        }
    ]
    {{- end }}

    {{- with $.Values.config.airflow.auth }}
    AUTH_ROLE_ADMIN = {{ template "toPythonValue" (dict "value" .role_admin) }}
    AUTH_ROLES_SYNC_AT_LOGIN = {{ template "toPythonValue" (dict "value" .roles_sync_at_login) }}
    AUTH_USER_REGISTRATION = {{ template "toPythonValue" (dict "value" .user_registration) }}
    AUTH_USER_REGISTRATION_ROLE = {{ template "toPythonValue" (dict "value" .user_registration_role) }}

    # Flask-WTF
    WTF_CSRF_ENABLED = True
    WTF_CSRF_TIME_LIMIT = None
    AUTH_ROLES_MAPPING = {
      {{- range $ldapGroup, $airflowRole := .role_mappings }}
      "cn={{ $ldapGroup }},ou=groups,dc=wikimedia,dc=org": {{ template "toPythonValue" (dict "value" $airflowRole) }},
      {{- end }}
    }
    {{- end }}

    {{- range $path, $_ :=  $.Files.Glob "files/webserver_config/*.py"}}
    {{ $.Files.Get $path | nindent 4 }}
    {{- end }}

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
  {{/* This script outputs the URI used to connect to PGBouncer, using a service FQDN */}}
  pg_pooler_uri: |
    #!/bin/sh
    printf ${PG_URI} | sed "s/$PG_HOST.{{ $.Release.Namespace }}/$POSTGRESQL_AIRFLOW_{{ $.Values.config.airflow.instance_name | upper | replace "-" "_" }}_POOLER_RW_SERVICE_HOST/"

{{- end }}

{{- define "configmap.gitsync-sparse-checkout-file" }}
{{/*
  This allows us to configure what directories get git pulled by git-sync.
  By default, we sync wmf_airflow_common, and we also pull the directory containing
  the dags and config for the specific airflow instance we're deploying.

  See https://git-scm.com/docs/git-sparse-checkout and
*/}}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-gitsync-sparse-checkout-file
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ $.Release.Namespace }}
data:
  sparse-checkout.conf: |
    !/*
    !/*/
    /{{ $.Values.config.airflow.dags_folder }}/
    {{- range $extra_dag_folder := $.Values.gitsync.extra_dags_folders }}
    /{{ $extra_dag_folder }}/
    {{- end }}
    /wmf_airflow_common/

{{- end }}

{{- define "configmap.airflow-kubernetes-executor-pod-template" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-kubernetes-pod-templates
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  {{/*
    This template is used by the Kubernetes Executor to create task pods spec.
    This is the executor default template, the path to which is set in airflow.cfg
    cf https://airflow.apache.org/docs/apache-airflow-providers-cncf-kubernetes/stable/kubernetes_executor.html#example-pod-templates
  */}}
  kubernetes_executor_default_pod_template.yaml: |
    {{- include "kubernetes-executor.pod-template" (dict "profile" "default" "Root" . ) | nindent 4 }}

  {{/*
    This template is used by the Kubernetes Executor to create task pods themselves having permission to create children Pods.
    This is useful for task pods using the KubernetesPodOperator, or SparkKubernetesOperator, for example.
  */}}
  kubernetes_executor_pod_template_kubeapi_enabled.yaml: |
    {{- include "kubernetes-executor.pod-template" (dict "profile" "kubeapi" "Root" . ) | nindent 4 }}

  {{/*
    This template is used by the KubernetesPodOperator to construct a Pod specs from within a dag task.
    This is useful to get a DAG task to run non python code, for example the mediawiki dump CLI, etc.
    cf https://airflow.apache.org/docs/apache-airflow-providers-cncf-kubernetes/stable/operators.html#kubernetespodoperator
  */}}
  kubernetes_pod_operator_default_pod_template.yaml: |
    {{- include "kubernetes-pod-operator.pod-template" (dict "profiles" (list) "Root" . ) | nindent 4 }}

  {{/*
    This template is used by the KubernetesPodOperator to construct a Pod specs for pods that need
    access to hadoop.
  */}}
  kubernetes_pod_operator_hadoop_pod_template.yaml: |
    {{- include "kubernetes-pod-operator.pod-template" (dict "profiles" (list "kerberos" "hadoop") "Root" . ) | nindent 4 }}


{{- end }}

{{- define "configmap.airflow-hadoop-config" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-hadoop-configuration
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  core-site.xml: |
    {{- include "render_xml_file" ( dict "config" .Values.worker.config.hadoop.core ) | nindent 4 }}
  hdfs-site.xml: |
    {{- include "render_xml_file" ( dict "config" .Values.worker.config.hadoop.hdfs ) | nindent 4 }}
  yarn-site.xml: |
    {{- include "render_xml_file" ( dict "config" .Values.worker.config.hadoop.yarn ) | nindent 4 }}
  log4j.properties: |
    {{- .Files.Get "files/hadoop/log4j.properties" | nindent 4 }}
  hadoop-env.sh: |
    {{- .Files.Get "files/hadoop/hadoop-env.sh" | nindent 4 }}
  yarn-env.sh: |
    {{- .Files.Get "files/hadoop/yarn-env.sh" | nindent 4 }}
  hive-site.xml: |
    {{- include "render_xml_file" ( dict "config" .Values.worker.config.hadoop.hive ) | nindent 4 }}
{{- end }}

{{- define "configmap.airflow-spark-config" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-spark-configuration
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  hive-site.xml: |
    {{- include "render_xml_file" ( dict "config" .Values.worker.config.hadoop.hive ) | nindent 4 }}
  spark-defaults.conf: |
    {{- include "render_dotconf_file" ( dict "config" .Values.worker.config.spark.spark ) | nindent 4 }}
  log4j.properties: |
    {{- .Files.Get "files/spark/log4j.properties" | nindent 4 }}
  spark-env.sh: |
    {{- .Files.Get "files/spark/spark-env.sh" | nindent 4 }}
{{- end }}

{{- define "configmap.worker.extra-config" }}
{{- with $.Values.worker.config.extra_files }}
{{- range $directory, $config := . }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "airflow.worker.extra-config-resource-name" (dict "directory" $directory) }}
  {{- include "base.meta.labels" $ | indent 2 }}
  namespace: {{ $.Release.Namespace }}
data:
{{- range $filename, $content := $config }}
  {{ $filename }}: |
    {{- $content | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{- define "configmap.worker.extra-config" }}
{{- with $.Values.worker.config.extra_files }}
{{- range $directory, $config := . }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "airflow.worker.extra-config-resource-name" (dict "directory" $directory) }}
  {{- include "base.meta.labels" $ | indent 2 }}
  namespace: {{ $.Release.Namespace }}
data:
{{- range $filename, $content := $config }}
  {{ $filename }}: |
    {{- $content | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}