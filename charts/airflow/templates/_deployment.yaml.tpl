{{- define "deployment.airflow.webserver" }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-webserver
  {{- include "base.meta.labels" . | indent 2 }}
    component: webserver
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: {{ .Values.resources.replicas }}
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: webserver
      annotations:
        {{- include "base.meta.pod_annotations" . | indent 8 }}
        {{- include "mesh.name.annotations" . | indent 8 }}
        checksum/airflow-bash-executables: {{ include "configmap.airflow-bash-executables" . | sha256sum }}
        checksum/airflow-config: {{ include "configmap.airflow-config" . | sha256sum }}
        checksum/airflow-connections: {{ include "configmap.airflow-connections" . | sha256sum }}
        checksum/airflow-webserver-config: {{ include "configmap.airflow-webserver-config" . | sha256sum }}
        checksum/gitsync-sparse-checkout: {{ include "configmap.gitsync-sparse-checkout-file" (dict "component" "webserver" "Root" $) | sha256sum }}
        checksum/kerberos-config: {{ include "configmap.kerberos" . | sha256sum }}
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      initContainers:
      {{- include "airflow.initcontainer.gitsync" . | nindent 6 }}
      - name: {{ template "base.name.release" . }}-initdb
        command: ["airflow"]
        args: ["db", "migrate"]
        image: {{ template "app.generic._image" . }}
        imagePullPolicy: {{ .Values.docker.pull_policy }}
        {{- include "app.airflow.env" . | indent 8 }}
        {{- include "base.helper.restrictedSecurityContext" . | nindent 8 }}
        {{ include "base.helper.resources" .Values.app | indent 8 }}
        {{- with .Values.app.volumeMounts }}
        volumeMounts:
        {{- toYaml . | nindent 8 }}
        {{- end }}
      containers:
        {{- include "app.airflow.container" . | indent 8 }}
        {{- include "mesh.deployment.container" . | indent 8 }}
      volumes:
        {{- include "app.generic.volume" . | indent 8 }}
        {{- include "mesh.deployment.volume" . | indent 8 }}
        - name: gitsync-sparse-checkout-config
          configMap:
            name: airflow-webserver-gitsync-sparse-checkout-file

{{- end }}


{{- define "deployment.airflow.scheduler" }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-scheduler
  {{- include "base.meta.labels" . | indent 2 }}
    component: scheduler
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: {{ .Values.resources.replicas }}
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: scheduler
      annotations:
        {{- include "base.meta.pod_annotations" . | indent 8 }}
        {{- if $.Values.monitoring.enabled }}
        prometheus.io/port: {{ $.Values.monitoring.prometheus_port | quote }}
        {{- end }}
        {{- include "mesh.name.annotations" . | indent 8 }}
        checksum/airflow-bash-executables: {{ include "configmap.airflow-bash-executables" . | sha256sum }}
        checksum/airflow-config: {{ include "configmap.airflow-config" . | sha256sum }}
        checksum/airflow-connections: {{ include "configmap.airflow-connections" . | sha256sum }}
        checksum/gitsync-sparse-checkout: {{ include "configmap.gitsync-sparse-checkout-file" (dict "component" "scheduler" "Root" $ ) | sha256sum }}
        checksum/kerberos-config: {{ include "configmap.kerberos" . | sha256sum }}
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      initContainers:
      {{- include "airflow.initcontainer.gitsync" . | nindent 6 }}
      containers:
        {{- include "app.airflow.scheduler" . | indent 8 }}
        {{- if $.Values.monitoring.enabled }}
        {{- include "base.statsd.container" . | indent 8 }}
        {{- end }}
        {{- if .Values.kerberos.enabled }}
          {{- include "kerberos.container" . | indent 8 }}
        {{- end }}
      volumes:
        {{- include "app.generic.volume" . | indent 8 }}
        {{- if $.Values.monitoring.enabled }}
        {{- include "base.statsd.volume" . | indent 8 }}
        {{- end }}
        - name: gitsync-sparse-checkout-config
          configMap:
            name: airflow-scheduler-gitsync-sparse-checkout-file

{{- end }}
