{{- define "configmap.hadoop-config" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-hadoop-configuration
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  core-site.xml: |
    {{- include "render_xml_file" ( dict "config" .Values.config.hadoop.core ) | nindent 4 }}
  hdfs-site.xml: |
    {{- include "render_xml_file" ( dict "config" .Values.config.hadoop.hdfs ) | nindent 4 }}
  yarn-site.xml: |
    {{- include "render_xml_file" ( dict "config" .Values.config.hadoop.yarn ) | nindent 4 }}
  hive-site.xml: |
    {{- include "render_xml_file" ( dict "config" .Values.config.hadoop.hive ) | nindent 4 }}
{{- end }}

{{- define "configmap.spark-config" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-spark-configuration
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  hive-site.xml: |
    {{- include "render_xml_file" ( dict "config" .Values.config.hadoop.hive ) | nindent 4 }}
  spark-defaults.conf: |
    {{- include "render_dotconf_file" ( dict "config" .Values.config.spark.spark ) | nindent 4 }}
{{- end }}

{{- define "configmap.kerberos-client-config" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-kerberos-client-config
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
      dns_canonicalize_hostname = false
      rdns = false

    [realms]
      WIKIMEDIA = {
        {{- range $kerberos_server := $.Values.kerberos.servers }}
        kdc = {{ $kerberos_server }}
        {{- end }}
        admin_server = {{ $.Values.kerberos.admin }}
      }
    [domain_realm]
      .wikimedia = WIKIMEDIA
      wikimedia = WIKIMEDIA
{{- end }}
