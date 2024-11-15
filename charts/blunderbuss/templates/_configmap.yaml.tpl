{{/*
 This configmap is used to define the kerberos client configuration.
 */}}
{{- define "configmap.kerberos" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: blunderbuss-kerberos-client-config
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


{{/*
 This configmap is used to define the gunicorn and blunderbuss configuration
 */}}
{{- define "configmap.blunderbuss" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: blunderbuss-config
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
    statsd_prefix = "blunderbuss"
    {{- end }}
    {{- end }}

{{- end }}
