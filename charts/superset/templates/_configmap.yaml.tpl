{{/*
  This configmap is used to define the kerberos client configuration.
*/}}
{{- define "configmap.kerberos" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: superset-kerberos-client-config
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
        kdc = krb1002.eqiad.wmnet
        kdc = krb1002.codfw.wmnet
        admin_server = krb1002.eqiad.wmnet
      }
    [domain_realm]
      .wikimedia = WIKIMEDIA
      wikimedia = WIKIMEDIA
{{- end }}


{{/*
  This configmap is used to define the gunicorn and superset configuration
*/}}
{{- define "configmap.superset" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: superset-config
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  gunicorn_config.py: |
    bind = '0.0.0.0:{{ $.Values.app.gunicorn_port }}'
    {{- range $k, $v := .Values.config.gunicorn }}
    {{ $k }} = {{ template "toPython" (dict "value" $v) }}
    {{- end }}
    {{- if $.Values.monitoring.enabled }}
    {{- if $.Values.monitoring.statsd }}
    statsd_host = "localhost:9125"
    statsd_prefix = "superset"
    {{- end }}
    {{- end }}

  superset_config.py: |
    {{- with $.Values.config.superset }}
    import datetime
    from flask_appbuilder.security.manager import AUTH_OAUTH

    #---------------------------------------------------------
    # Flask App Builder configuration
    #---------------------------------------------------------
    # Your App secret key
    SECRET_KEY = {{ template "toPython" (dict "value" .secret_key) }}

    # The SQLAlchemy connection string to your database backend
    # This connection defines the path to the database that stores your
    # superset metadata (slices, connections, tables, dashboards, ...).
    # Note that the connection information to connect to the datasources
    # you want to explore are managed directly in the web UI
    SQLALCHEMY_DATABASE_URI = '{{ .sqlalchemy_database_uri | replace "<PASSWORD>" .sqlalchemy_database_password }}?ssl_ca=/etc/ssl/certs/wmf-ca-certificates.crt'

    {{- if $.Values.localmemcached.enabled }}
    CACHE_URL = "{{ template "base.meta.name" (dict "Root" $ ) }}-memcached:{{ $.Values.localmemcached.port }}"
    {{- end }}
    wikimedia_superset_timeout = datetime.timedelta(minutes={{ .wikimedia_superset_timeout_minutes }}).seconds

    SQLLAB_TIMEOUT = wikimedia_superset_timeout
    SUPERSET_WEBSERVER_TIMEOUT = wikimedia_superset_timeout

    # Uploaded files will temporarily be stored in this directory.
    # This is used to support superset CSV uploads.
    UPLOAD_FOLDER = {{ template "toPython" (dict "value" .upload_folder) }}

    # We explicitly disable the old Druid interface to define datasources to favor
    # the Druid tables (via SQLAlchemy), since the latter are the only supported
    # ones by upstream.
    DRUID_IS_ACTIVE = {{ template "toPython" (dict "value" .druid_is_active) }}

    AUTH_TYPE = AUTH_OAUTH
    OAUTH_PROVIDERS = [
        {
            "name": "CAS",
            "icon": "fa-openid",
            'token_key':'access_token',
            "remote_app": {
                "client_id": "{{ $.Values.config.oidc.client_id }}",
                "client_secret": "{{ $.Values.config.oidc.client_secret }}",
                "server_metadata_url": "https://{{ $.Values.config.oidc.idp_server }}/oidc/.well-known",
                'client_kwargs':{
                    'scope': 'openid email profile groups'
                },
            },
        }
    ]
    AUTH_ROLES_MAPPING = {
      {{- range $ldapGroup, $supersetRole := .auth_role_mappings }}
      "cn={{ $ldapGroup }},ou=groups,dc=wikimedia,dc=org": {{ template "toPython" (dict "value" $supersetRole) }},
      {{- end }}
    }
    AUTH_ROLES_SYNC_AT_LOGIN = {{ template "toPython" (dict "value" .auth_roles_sync_at_login) }}
    AUTH_ROLE_ADMIN = {{ template "toPython" (dict "value" .auth_role_admin) }}
    AUTH_USER_REGISTRATION = {{ template "toPython" (dict "value" .auth_user_registration) }}
    AUTH_USER_REGISTRATION_ROLE = {{ template "toPython" (dict "value" .auth_user_registration_role) }}

    LOG_LEVEL = {{ template "toPython" (dict "value" .log_level) }}

    ENABLE_PROXY_FIX = {{ template "toPython" (dict "value" .enable_proxy_fix) }}
    password_mapping = {
        {{- range $dbUri, $password := .password_mapping }}
        {{ $dbUri | quote }}: {{ $password | quote }},
        {{- end}}
    }

    {{- if $.Values.localmemcached.enabled }}
    CACHE_CONFIG = {
        {{- range $config, $value := .cache_config }}
        {{ $config | upper | quote }}: {{ template "toPython" (dict "value" $value) }},
        {{- end }}
        "CACHE_MEMCACHED_SERVERS": [CACHE_URL],
    }

    FILTER_STATE_CACHE_CONFIG = {
        {{- range $config, $value := .filter_state_cache_config }}
        {{ $config | upper | quote }}: {{ template "toPython" (dict "value" $value) }},
        {{- end}}
        "CACHE_MEMCACHED_SERVERS": [CACHE_URL],
    }
    EXPLORE_FORM_DATA_CACHE_CONFIG = {
        {{- range $config, $value := .explore_form_data_cache_config }}
        {{ $config | upper | quote }}: {{ template "toPython" (dict "value" $value) }},
        {{- end}}
        "CACHE_MEMCACHED_SERVERS": [CACHE_URL],
    }
    {{- if .data_cache_config }}
    DATA_CACHE_CONFIG = {
      {{- range $config, $value := .data_cache_config }}
      {{ $config | upper | quote }}: {{ template "toPython" (dict "value" $value) }},
      {{- end}}
      "CACHE_MEMCACHED_SERVERS": [CACHE_URL],
    }
    {{- end }}
    RATELIMIT_STORAGE_URI = "memcached://" + CACHE_URL
    {{- end }}

    FEATURE_FLAGS = {
        {{- range $featureFlag := .feature_flags }}
        {{ $featureFlag | quote }}: True,
        {{- end }}
        {{- range $featureFlag := .extra_feature_flags }}
        {{ $featureFlag | quote }}: True,
        {{- end }}
    }

    {{- range $key, $value := .extra_configuration }}
    {{ $key }} = {{ template "toPython" (dict "value" $value) }}
    {{- end }}

    {{- range $path, $_ :=  $.Files.Glob "files/**.py"}}
    {{ $.Files.Get $path | nindent 4 }}
    {{- end }}

    ADDITIONAL_MIDDLEWARE = []
    CUSTOM_SECURITY_MANAGER = CustomSsoSecurityManager

    {{- end }}
{{- end }}

{{/*
  This configmap is used to configure nginx to serve the static assets
*/}}
{{- define "configmap.nginx" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  nginx.conf: |
    worker_processes  1;
    events {
      worker_connections  10240;
    }
    error_log /dev/stdout info;
    pid /tmp/nginx.pid;
    http {
      include mime.types;
      upstream superset {
        server 127.0.0.1:{{ .Values.app.gunicorn_port }};
        keepalive 64;
      }
      server {
        access_log /dev/stdout;
        listen       {{ .Values.app.port }};
        proxy_temp_path /tmp/proxy_temp;
        client_body_temp_path /tmp/client_temp;
        fastcgi_temp_path /tmp/fastcgi_temp;
        uwsgi_temp_path /tmp/uwsgi_temp;
        scgi_temp_path /tmp/scgi_temp;

        # Serve the requestctl-generator.html static page with the Content-Type: text/html
        # response header when hitting the /requestctl-generator endpoint
        location /requestctl-generator {
          default_type text/html;
          alias /app/superset/requestctl-generator/requestctl-generator.html;
          try_files $uri $uri/ =404;
        }

        location / {
          root       /app/superset;
          # Tune slightly for serving static content.
          sendfile   on;
          tcp_nopush on;
          try_files $uri @proxy_to_app;
        }

        location @proxy_to_app {
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header Host $http_host;
          proxy_ignore_client_abort on;
          proxy_redirect off;
          proxy_pass http://superset;
          proxy_set_header Connection "";
          proxy_http_version 1.1;
        }
      }
    }
{{- end }}

{{/*
  This configmap is used to serve the requestctl-generator.html page from nginx
*/}}
{{- define "configmap.requestctl-generator" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: requestctl-generator-page
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  requestctl-generator.html: |
    {{ $.Files.Get "files/requestctl-generator.html" | nindent 4 }}
{{- end }}
