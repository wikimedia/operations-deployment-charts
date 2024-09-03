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
    {{- range $config_section, $config := $.Values.config.airflow.config }}

    [{{ $config_section }}]
    {{- range $config_key, $config_value := $config }}
    {{- $value := include "evalValue" (dict "value" $config_value "Root" $)}}
    {{ $config_key }} = {{ template "toIniValue" (dict "value" $value)  }}
    {{- end }}
    {{- if eq $config_section "database" }}
    {{- include "airflow.sqlalchemy.connstr" $ | indent 4}}
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

    {{- range $path, $_ :=  $.Files.Glob "files/**.py"}}
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
  name: airflow-{{ .component }}-gitsync-sparse-checkout-file
  {{- include "base.meta.labels" .Root | indent 2 }}
  namespace: {{ .Root.Release.Namespace }}
data:
  sparse-checkout.conf: |
    !/*
    !/*/
    {{- if ne .component "webserver"}} {{- /* The webserver does not need to have dags locally pulled */}}
    /{{ .Root.Values.config.airflow.dags_folder }}/
    {{- end }}
    /wmf_airflow_common/

{{- end }}
