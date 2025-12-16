{{- define "deployment.spark.toolbox" }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-toolbox
  {{- include "base.meta.labels" . | indent 2 }}
    spark-role: driver
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: {{ .Values.toolbox.replicas }}
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        spark-role: driver
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      serviceAccountName: spark
      containers:
        - name: "spark-toolbox"
          command: ["sleep"]
          args: ["infinity"]
          image: {{ get $.Values.config.spark "spark.kubernetes.container.image" }}
          imagePullPolicy: {{ .Values.docker.pull_policy }}
          env:
            - name: HADOOP_CONF_DIR
              value: /etc/hadoop/conf
            - name: SPARK_CONF_DIR
              value: /etc/spark/conf
          volumeMounts:
          {{- include "spark.toolbox.volumemounts" . | indent 10 }}
          {{- include "base.helper.restrictedSecurityContext" . | indent 10 }}
          {{- include "base.helper.resources" $.Values.toolbox.resources | indent 10 }}
      volumes:
        {{- include "spark.toolbox.volumes" . | indent 8 }}

{{- end }}