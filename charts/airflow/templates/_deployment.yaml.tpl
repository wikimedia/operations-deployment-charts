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
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      serviceAccountName: airflow
      initContainers:
      - name: {{ template "base.name.release" . }}-initdb
        command: ["airflow"]
        args: ["db", "migrate"]
        image: {{ template "app.generic._image" . }}
        imagePullPolicy: {{ .Values.docker.pull_policy }}
        {{- include "app.airflow.env" . | indent 8 }}
        {{- include "base.helper.restrictedSecurityContext" . | nindent 8 }}
        {{ include "base.helper.resources" .Values.app | indent 8 }}
        volumeMounts:
        {{- toYaml .Values.app.volumeMounts  | nindent 8 }}
      containers:
        {{- include "app.airflow.container" . | indent 8 }}
        {{- include "mesh.deployment.container" . | indent 8 }}
      volumes:
        {{- include "app.generic.volume" . | indent 8 }}
        {{/* We need the keytab to be mounted in the webserver for the API Kerberos authentication to work */}}
        {{- include "kerberos.volumes" (dict "Root" . "profiles" (list "keytab")) | indent 8 }}
        {{- include "mesh.deployment.volume" . | indent 8 }}


{{- end }}


{{- define "deployment.airflow.scheduler" }}
{{- if $.Values.scheduler.enabled }}
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
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      {{- if eq $.Values.config.airflow.config.core.executor "LocalExecutor" }}
      {{- include "airflow.pod.host_aliases" . | indent 6 }}
      {{- end }}
      serviceAccountName: airflow
      containers:
        {{- include "app.airflow.scheduler" . | indent 8 }}
        {{- if $.Values.monitoring.enabled }}
        {{- include "base.statsd.container" . | indent 8 }}
        {{- end }}
      volumes:
        {{- include "app.generic.volume" . | indent 8 }}
        {{- include "kerberos.volumes" (dict "Root" .) | indent 8 }}
        {{- if $.Values.monitoring.enabled }}
        {{- include "base.statsd.volume" . | indent 8 }}
        {{- end }}

{{- end }}
{{- end }}

{{- define "deployment.airflow.gitsync" }}
{{- if $.Values.gitsync.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-gitsync
  {{- include "base.meta.labels" . | indent 2 }}
    component: gitsync
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: {{ .Values.resources.replicas }}
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: gitsync
      annotations:
        {{- include "base.meta.pod_annotations" . | indent 8 }}
    spec:
      securityContext:
        fsGroup: {{ $.Values.gitsync.image_gid }} {{/* This allows the volumes to be writable by the git-sync gid */}}
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      containers:
      - name: {{ template "base.name.release" . }}-git-sync
        image: "{{ .Values.docker.registry }}/{{ .Values.gitsync.image_name }}:{{ .Values.gitsync.image_tag }}"
        imagePullPolicy: {{ .Values.docker.pull_policy }}
        command: ["git-sync"]
        args:
        - "--repo={{ $.Values.gitsync.dags_repo }}"
        - "--root={{ $.Values.gitsync.root_dir }}"
        - "--link={{ $.Values.gitsync.link_dir }}"
        - "--ref={{ $.Values.gitsync.ref }}"
        - "--period={{ $.Values.gitsync.period }}s"
        - "--depth=1" {{/* Performs a shallow clone */}}
        - "--sparse-checkout-file=/etc/gitsync/sparse-checkout.conf"
        {{- include "base.helper.restrictedSecurityContext" . | indent 8 }}
        volumeMounts:
        {{- toYaml $.Values.gitsync.volumeMounts | nindent 8 }}
      volumes:
      {{- toYaml $.Values.gitsync.volumes | nindent 6 }}

{{- end }}
{{- end }}

{{- define "deployment.airflow.kerberos" }}
{{- if $.Values.kerberos.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-kerberos
  {{- include "base.meta.labels" . | indent 2 }}
    component: kerberos
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: {{ .Values.resources.replicas }}
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: kerberos
      annotations:
        {{- include "base.meta.pod_annotations" . | indent 8 }}
    spec:
      securityContext:
        fsGroup: {{ $.Values.kerberos.image_gid }}
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      containers:
      - name: "airflow-kerberos"
        command: ["airflow"]
        args:
        - kerberos
        - --pid
        - /tmp/airflow-kerberos.pid
        image: {{ template "app.generic._image" . }}
        imagePullPolicy: {{ .Values.docker.pull_policy }}
        {{- include "app.airflow.env" . | indent 8 }}
        {{- include "base.helper.restrictedSecurityContext" . | nindent 8 }}
        {{ include "base.helper.resources" $.Values.kerberos.resources | indent 8 }}
        volumeMounts:
        {{- toYaml $.Values.app.volumeMounts | nindent 8 }}
        {{- include "kerberos.volumeMounts" (dict "Root" . "profiles" (list "keytab")) | indent 8 }}
      volumes:
      {{- toYaml $.Values.app.volumes | nindent 6 }}
      {{- include "kerberos.volumes" (dict "Root" . "profiles" (list "keytab")) | indent 6 }}


{{- end }}
{{- end }}

{{- define "deployment.envoy" }}
{{- if $.Values.mesh.enabled }}
{{/*
  We deploy a standalone envoy instance to proxy requests to the service mesh.

  We decided to do this instead of starting an envoy sidecar along with airflow task pods
  because it is less complex, requires less external moving parts (we needed the a specific
  controller to exec into the envoy sidecar and SIGTERM it when the airflow task container was
  done, to allow the pod to terminate), and this setup was inherently racy.
  Indeed, the task pod was racing envoy, and could send a request to the mesh before envoy
  was ready to receive them.

  All in all, this is cleaner, and can be observable via
  https://grafana.wikimedia.org/d/b1jttnFMz/envoy-telemetry-k8s

  */}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envoy
  {{- include "base.meta.labels" . | indent 2 }}
    component: envoy
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: {{ .Values.resources.replicas }}
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: envoy
      annotations:
        {{- include "base.meta.pod_annotations" . | indent 8 }}
        {{- include "mesh.name.annotations" . | indent 8 }}
    spec:
      containers:
      {{- include "mesh.deployment.container" . | indent 6 }}
      volumes:
      {{- include "mesh.deployment.volume" . | indent 6 }}
{{- end }}
{{- end }}


{{- define "deployment.hadoop-shell" }}
{{- if $.Values.hadoop_shell.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hadoop-shell
  {{- include "base.meta.labels" . | indent 2 }}
    component: hadoop-shell
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: 1
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: hadoop-shell
      annotations:
        {{- include "base.meta.pod_annotations" . | indent 8 }}
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      {{- include "airflow.task-pod.volumes" (dict "Root" $ "profiles" (list "hadoop" "kerberos")) | indent 6 }}
      {{- include "airflow.pod.host_aliases" . | indent 6 }}
      containers:
      - name: "hadoop-shell"
        command: ["sleep"]
        args: ["infinity"]
        image: {{ template "app.generic._image" . }}
        imagePullPolicy: {{ .Values.docker.pull_policy }}
        env:
        {{- include "app.airflow.env.hadoop" . | indent 8 }}
        {{- include "app.airflow.env.kerberos" (dict "Root" .) | indent 8 }}
        {{- include "base.helper.restrictedSecurityContext" . | indent 8 }}
        {{- include "base.helper.resources" $.Values.hadoop_shell.resources | indent 8 }}
        {{- include "airflow.task-pod.volumeMounts" (dict "Root" $ "profiles" (list "hadoop" "kerberos")) | indent 8 }}

{{- end }}
{{- end }}
