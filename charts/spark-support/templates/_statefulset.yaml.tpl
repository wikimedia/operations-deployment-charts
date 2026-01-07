{{- define "statefulset.kyuubi" }}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kyuubi
  {{- include "base.meta.labels" . | indent 2 }}
    spark-role: driver
spec:
  selector:
    matchLabels:
      {{- include "kyuubi.selectorLabels" . | nindent 6 }}
  serviceName: kyuubi-headless
  replicas: {{ .Values.kyuubi.replicas }}
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: kyuubi
        spark-role: driver
    spec:
      {{- if .Values.kyuubi.affinity }}
      {{- toYaml .Values.kyuubi.affinity | nindent 6 }}
      {{- end }}
      serviceAccountName: spark
      containers:
        - name: "kyuubi"
          args: ["kyuubi", "run"]
          image: {{ $.Values.kyuubi.image }}
          imagePullPolicy: {{ .Values.docker.pull_policy }}
          ports:
            {{- range $name, $frontend := .Values.kyuubi.server }}
            {{- if $frontend.enabled }}
            - name: {{ $name | kebabcase }}
              containerPort: {{ $frontend.port }}
            {{- end }}
            {{- end }}
            {{- if and .Values.kyuubi.metrics.enabled (.Values.kyuubi.metrics.reporters | nospace | splitList "," | has "PROMETHEUS") }}
            - name: prometheus
              containerPort: {{ .Values.kyuubi.metrics.prometheusPort }}
            {{- end }}
          volumeMounts:
          {{- include "hadoop.volumemounts" . | indent 10 }}
          {{- include "kerberos.volumemounts" . | indent 10 }}
          {{- include "kyuubi.volumemounts" . | indent 10 }}
          {{- include "spark.volumemounts" . | indent 10 }}
          {{- include "base.helper.restrictedSecurityContext" . | indent 10 }}
          {{- include "base.helper.resources" $.Values.kyuubi.resources | indent 10 }}
          {{- if .Values.kyuubi.livenessProbe.enabled }}
          livenessProbe:
            exec:
              command: ["/bin/bash", "-c", "$KYUUBI_HOME/bin/kyuubi status"]
            initialDelaySeconds: {{ .Values.kyuubi.livenessProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.kyuubi.livenessProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.kyuubi.livenessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.kyuubi.livenessProbe.failureThreshold }}
            successThreshold: {{ .Values.kyuubi.livenessProbe.successThreshold }}
          {{- end }}
          {{- if .Values.kyuubi.readinessProbe.enabled }}
          readinessProbe:
            exec:
              command: ["/bin/bash", "-c", "$KYUUBI_HOME/bin/kyuubi status"]
            initialDelaySeconds: {{ .Values.kyuubi.readinessProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.kyuubi.readinessProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.kyuubi.readinessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.kyuubi.readinessProbe.failureThreshold }}
            successThreshold: {{ .Values.kyuubi.readinessProbe.successThreshold }}
          {{- end }}
      volumes:
        {{- include "hadoop.volumes" . | indent 8 }}
        {{- include "kerberos.volumes" . | indent 8 }}
        {{- include "kyuubi.volumes" . | indent 8 }}
        {{- include "spark.volumes" . | indent 8 }}
{{- end }}