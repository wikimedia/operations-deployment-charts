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
  spark-defaults.conf: |
    {{- include "render_dotconf_file" ( dict "config" .Values.config.spark ) | nindent 4 }}
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

{{- define "configmap.spark-pod-templates" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-spark-pod-templates
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  driver.yaml: |
    apiVersion: v1
    Kind: Pod
    spec:
      containers:
      - name: spark-driver-template
        image: {{ get $.Values.config.spark "spark.kubernetes.container.image" }}
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
              drop:
              - ALL
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
  executor.yaml: |
    apiVersion: v1
    Kind: Pod
    spec:
      containers:
      - name: spark-executor-template
        image: {{ get $.Values.config.spark "spark.kubernetes.container.image" }}
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
              drop:
              - ALL
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
{{- end }}
