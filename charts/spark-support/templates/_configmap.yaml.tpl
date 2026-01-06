{{- define "configmap.hadoop-config" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: hadoop-configuration
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
{{/*
See the following links regarding these optimization parameters for S3
https://spark.apache.org/docs/3.5.7/cloud-integration.html#recommended-settings-for-writing-to-object-stores
https://spark.apache.org/docs/3.5.7/cloud-integration.html#parquet-io-settings
https://spark.apache.org/docs/3.5.7/cloud-integration.html#hadoop-s3a-committers
*/}}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: spark-configuration
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  spark-defaults.conf: |-
    {{- include "render_dotconf_file" ( dict "config" .Values.config.spark ) | indent 4 }}
    {{- if and $.Values.config.private.aws_access_key_id $.Values.config.private.aws_secret_access_key }}
    spark.hadoop.fs.s3a.access.key: {{ $.Values.config.private.aws_access_key_id }}
    spark.hadoop.fs.s3a.secret.key: {{ $.Values.config.private.aws_secret_access_key }}
    spark.fs.s3a.endpoint: https://rgw.eqiad.dpe.anycast.wmnet/
    spark.fs.s3a.path.style.access: true
    spark.hadoop.mapreduce.fileoutputcommitter.algorithm.version: 2
    spark.hadoop.mapreduce.fileoutputcommitter.cleanup-failures.ignored: true
    spark.hadoop.parquet.enable.summary-metadata: false
    spark.sql.parquet.mergeSchema: false
    spark.sql.parquet.filterPushdown: true
    spark.sql.hive.metastorePartitionPruning: true
    spark.hadoop.fs.s3a.committer.name: directory
    spark.sql.sources.commitProtocolClass: org.apache.spark.internal.io.cloud.PathOutputCommitProtocol
    spark.sql.parquet.output.committer.class: org.apache.spark.internal.io.cloud.BindingParquetOutputCommitter
    {{- end }}
{{- end }}

{{- define "configmap.kerberos-client-config" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kerberos-client-config
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
  name: spark-pod-templates
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
        env:
          - name: HADOOP_CONF_DIR
            value: /etc/hadoop/conf
          - name: SPARK_CONF_DIR
            value: /etc/spark/conf
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
              drop:
              - ALL
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        volumeMounts:
          - mountPath: /etc/krb5.conf
            name: kerberos-client-config
            subPath: krb5.conf
          - mountPath: /etc/security/keytabs
            name: kerberos-keytabs
      volumes:
        - name: kerberos-client-config
          configMap:
            name: kerberos-client-config
        - name: kerberos-keytabs
          secret:
            secretName: kerberos-keytabs
  executor.yaml: |
    apiVersion: v1
    Kind: Pod
    spec:
      containers:
      - name: spark-executor-template
        image: {{ get $.Values.config.spark "spark.kubernetes.container.image" }}
        env:
          - name: HADOOP_CONF_DIR
            value: /etc/hadoop/conf
          - name: SPARK_CONF_DIR
            value: /etc/spark/conf
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
              drop:
              - ALL
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        volumeMounts:
          - mountPath: /etc/krb5.conf
            name: kerberos-client-config
            subPath: krb5.conf
      volumes:
        - name: kerberos-client-config
          configMap:
            name: kerberos-client-config

{{- end }}

{{- define "configmap.dbt-profiles" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dbt-profiles
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  profiles.yml: |
    datalake:
      target: dev
      outputs:
        dev:
          type: spark
          method: thrift
          schema: "btullis"
          host: localhost
          port: 10009
          server_side_parameters:
            "spark.dynamicAllocation.maxExecutors": "64"
{{- end }}

{{- define "configmap.kyuubi-config" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kyuubi-configuration
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  kyuubi-defaults.conf: |-
    {{- include "render_dotconf_file" ( dict "config" .Values.config.kyuubi ) | indent 4 }}
  kyuubi-env.sh: |-
    export KYUUBI_LOG_DIR=/tmp
    export KYUUBI_PID_DIR=/tmp
    export KYUUBI_WORK_DIR_ROOT=/tmp
{{- end }}
