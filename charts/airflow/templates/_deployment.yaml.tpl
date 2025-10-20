{{- define "deployment.airflow.webserver" }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "release.name" . }}-webserver
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
        {{- include "pod.annotations.secrets-configmap.checksums" . | indent 8 }}
        {{- include "mesh.name.annotations" . | indent 8 }}
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      serviceAccountName: {{ template "release.name" . }}
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
        {{- include "app.airflow.volumeMounts" . | indent 8 }}
      containers:
        {{- include "app.airflow.container" . | indent 8 }}
        {{- include "mesh.deployment.container" . | indent 8 }}
      volumes:
        {{- include "app.airflow.volumes" . | indent 8 }}
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
  name: {{ template "release.name" . }}-scheduler
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
        {{- include "pod.annotations.secrets-configmap.checksums" . | indent 8 }}
        {{- include "mesh.name.annotations" . | indent 8 }}
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      {{- if contains "LocalExecutor" $.Values.config.airflow.config.core.executor }}
      {{- include "airflow.pod.host_aliases" . | indent 6 }}
      {{- end }}
      serviceAccountName: {{ template "release.name" . }}
      containers:
        {{- if contains "LocalExecutor" $.Values.config.airflow.config.core.executor }}
        {{- include "app.airflow.scheduler" (dict "Root" . "profiles" (list "LocalExecutor")) | indent 8 }}
        {{- else }}
        {{- include "app.airflow.scheduler" (dict "Root" . "profiles" list) | indent 8 }}
        {{- end }}
      volumes:
        {{- include "app.airflow.volumes" . | indent 8 }}
        {{- include "kerberos.volumes" (dict "Root" .) | indent 8 }}
        {{/* If the scheduler is running with the LocalExecutor, it also needs the hadoop config files rendered locally */}}
        {{- if contains "LocalExecutor" $.Values.config.airflow.config.core.executor }}
        {{- include "airflow.task-pod.volumes" (dict "Root" . "profiles" (list "hadoop") "header" false) | indent 8 }}
        {{- end }}

{{- end }}
{{- end }}

{{- define "deployment.airflow.gitsync" }}
{{- if $.Values.gitsync.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "release.name" . }}-gitsync
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
        {{- include "pod.annotations.secrets-configmap.checksums" . | indent 8 }}
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
        {{- include "app.gitsync.volumeMounts" . | nindent 8 }}
      volumes:
      {{- include "app.gitsync.volumes" . | nindent 6 }}

{{- end }}
{{- end }}

{{- define "deployment.airflow.kerberos" }}
{{- if $.Values.kerberos.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "release.name" . }}-kerberos
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
        {{- include "pod.annotations.secrets-configmap.checksums" . | indent 8 }}
    spec:
      securityContext:
        fsGroup: {{ $.Values.kerberos.image_gid }}
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      {{- if $.Values.devenv.enabled }}
      {{/*
        In development environments, we need to wait for engineers to exec into that init container
        to run kinit, which will create the kerberos cache file, causing the init container to stop,
        and the kerberos renewer container to start.
      */}}
      initContainers:
      - name: "airflow-kinit"
        command: ["python3"]
        args:
        - -c
        - |
          import time
          import sys
          import os
          from pathlib import Path
          while True:
            if Path(os.environ['KRB5CCNAME']).exists():
              sys.exit(0)
            time.sleep(5)
        image: {{ template "app.generic._image" . }}
        imagePullPolicy: {{ .Values.docker.pull_policy }}
        {{- include "app.airflow.env" . | indent 8 }}
        {{- include "base.helper.restrictedSecurityContext" . | nindent 8 }}
        {{ include "base.helper.resources" $.Values.kerberos.resources | indent 8 }}
        volumeMounts:
        {{- include "app.airflow.volumeMounts" . | indent 8 }}
        {{- include "kerberos.volumeMounts" (dict "Root" . "profiles" (list "keytab")) | indent 8 }}
      {{- end }}
      containers:
      - name: "airflow-kerberos"
        {{- if $.Values.devenv.enabled }}
        {{/*
          In development environments, we cannot rely on a keytab, as the kerberos token is associated
          with the personal identity of the developer, instead of a service account. Due to the lack of
          keytab, we can't rely on the `airflow kerberos` command (which assumes a keytab is present),
          so we rely on the `krenew` command, to simpluy renew the ticket contained in the krb5 cache.
        */}}
        command: ["krenew"]
        args:
        - -K  {{/* Run as daemon, check ticket every <interval> minutes */}}
        - {{ $.Values.devenv.kerberos.ticket_renewal_interval_minutes | quote }}
        {{- else }}
        command: ["airflow"]
        args:
        - kerberos
        - --pid
        - /tmp/airflow-kerberos.pid
        {{- end }}
        image: {{ template "app.generic._image" . }}
        imagePullPolicy: {{ .Values.docker.pull_policy }}
        {{- include "app.airflow.env" . | indent 8 }}
        {{- include "base.helper.restrictedSecurityContext" . | nindent 8 }}
        {{ include "base.helper.resources" $.Values.kerberos.resources | indent 8 }}
        volumeMounts:
        {{- include "app.airflow.volumeMounts" . | indent 8 }}
        {{- include "kerberos.volumeMounts" (dict "Root" . "profiles" (list "keytab")) | indent 8 }}
      volumes:
      {{- include "app.airflow.volumes" . | indent 6 }}
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
  name: {{ template "release.name" . }}-envoy
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
        {{- include "pod.annotations.secrets-configmap.checksums" . | indent 8 }}
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
  name: {{ template "release.name" . }}-hadoop-shell
  {{- include "base.meta.labels" . | indent 2 }}
    component: hadoop-shell
    role: toolbox
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: 1
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: hadoop-shell
        role: toolbox
      annotations:
        {{- include "pod.annotations.secrets-configmap.checksums" . | indent 8 }}
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

{{- define "deployment.task-shell" }}
{{- if $.Values.task_shell.enabled }}
{{/*
  This toolbox allows users to test network policies that would be applied to task pods themselves
*/}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "release.name" . }}-task-shell
  {{- include "base.meta.labels" . | indent 2 }}
    component: task-pod
    role: toolbox
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: 1
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: task-pod {{/* To assign task pod network policies */}}
        role: toolbox
      annotations:
        {{- include "pod.annotations.secrets-configmap.checksums" . | indent 8 }}
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      {{- include "airflow.pod.host_aliases" . | indent 6 }}
      volumes:
      - name: {{ template "release.name" . }}-bash-executables
        configMap:
          name: {{ template "release.name" . }}-bash-executables
          defaultMode: 0777
      containers:
      - name: "task-shell"
        command: ["sleep"]
        args: ["infinity"]
        image: {{ template "app.generic._image" . }}
        imagePullPolicy: {{ .Values.docker.pull_policy }}
        {{- include "base.helper.restrictedSecurityContext" . | indent 8 }}
        {{- include "base.helper.resources" $.Values.task_shell.resources | indent 8 }}
        volumeMounts:
        - name: {{ template "release.name" . }}-bash-executables
          mountPath: /opt/airflow/usr/bin

{{- end }}
{{- end }}

{{- define "deployment.statsd" }}
{{- if $.Values.monitoring.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "release.name" . }}-statsd
  {{- include "base.meta.labels" . | indent 2 }}
    component: statsd
    {{- include "statsd.labels.domain" . | indent 4 }}
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: 1
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: statsd
        {{- include "statsd.labels.domain" . | indent 8 }}
      annotations:
        checksum/statsd-config: {{ $.Files.Get "files/statsd/prometheus-statsd.yaml"  | sha256sum }}
        prometheus.io/scrape: "true"
        prometheus.io/port: {{ $.Values.monitoring.prometheus_port | quote }}
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      containers:
        {{- include "base.statsd.container" . | indent 8 }}
      volumes:
        {{- include "base.statsd.volume" . | indent 8 }}

{{- end }}
{{- end }}

{{- define "deployment.airflow.triggerer" }}
{{- if $.Values.triggerer.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "release.name" . }}-triggerer
  {{- include "base.meta.labels" . | indent 2 }}
    component: triggerer
spec:
  selector:
  {{- include "base.meta.selector" . | indent 4 }}
  replicas: 1
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
        component: triggerer
      annotations:
        {{- include "pod.annotations.secrets-configmap.checksums" . | indent 8 }}
        {{- include "mesh.name.annotations" . | indent 8 }}
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      serviceAccountName: {{ template "release.name" . }}
      containers:
        {{- include "app.airflow.triggerer" $ | indent 8 }}
      volumes:
        {{- include "app.airflow.volumes" . | indent 8 }}

{{- end }}
{{- end }}
