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
  replicas: {{ .Values.spark.toolbox.replicas }}
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        spark-role: driver
    spec:
      {{- if .Values.spark.toolbox.affinity }}
      {{- toYaml .Values.spark.toolbox.affinity | nindent 6 }}
      {{- end }}
      serviceAccountName: spark
      containers:
        - name: "spark-toolbox"
          command: ["sleep"]
          args: ["infinity"]
          image: {{ get $.Values.config.spark "spark.kubernetes.container.image" }}
          imagePullPolicy: {{ .Values.docker.pull_policy }}
          volumeMounts:
          {{- include "hadoop.volumemounts" . | indent 10 }}
          {{- include "kerberos.volumemounts" . | indent 10 }}
          {{- include "spark.volumemounts" . | indent 10 }}
          {{- include "base.helper.restrictedSecurityContext" . | indent 10 }}
          {{- include "base.helper.resources" $.Values.spark.toolbox.resources | indent 10 }}
      volumes:
        {{- include "hadoop.volumes" . | indent 8 }}
        {{- include "kerberos.volumes" . | indent 8 }}
        {{- include "spark.volumes" . | indent 8 }}

{{- end }}

{{- define "deployment.kyuubi" }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kyuubi
  {{- include "base.meta.labels" . | indent 2 }}
    spark-role: driver
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: {{ .Values.kyuubi.toolbox.replicas }}
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        spark-role: driver
    spec:
      {{- if .Values.kyuubi.toolbox.affinity }}
      {{- toYaml .Values.kyuubi.toolbox.affinity | nindent 6 }}
      {{- end }}
      serviceAccountName: spark
      containers:
        - name: "kyuubi"
          command: ["sleep"]
          args: ["infinity"]
          image: {{ $.Values.kyuubi.image }}
          imagePullPolicy: {{ .Values.docker.pull_policy }}
          volumeMounts:
          {{- include "hadoop.volumemounts" . | indent 10 }}
          {{- include "kerberos.volumemounts" . | indent 10 }}
          {{- include "kyuubi.volumemounts" . | indent 10 }}
          {{- include "spark.volumemounts" . | indent 10 }}
          {{- include "base.helper.restrictedSecurityContext" . | indent 10 }}
          {{- include "base.helper.resources" $.Values.kyuubi.toolbox.resources | indent 10 }}
      volumes:
        {{- include "hadoop.volumes" . | indent 8 }}
        {{- include "kerberos.volumes" . | indent 8 }}
        {{- include "kyuubi.volumes" . | indent 8 }}
        {{- include "spark.volumes" . | indent 8 }}
{{- end }}