{{- define "localmemcached.deployment" }}
{{- $release := include "base.name.release" . }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "base.meta.name" (dict "Root" . ) }}-memcached
  labels:
    app: memcached
    chart: {{ template "base.name.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  selector:
    matchLabels:
      app: memcached
      release: {{ .Release.Name }}
  replicas: {{ .Values.localmemcached.resources.replicas }}
  template:
    metadata:
      labels:
        app: memcached
        release: {{ .Release.Name }}
        routed_via: {{ .Values.routed_via | default .Release.Name }}
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      containers:
        - name: {{ $release }}-memcached
          image: {{ $.Values.docker.registry }}/{{ $.Values.common_images.memcached.image }}:{{ $.Values.common_images.memcached.version }}
          imagePullPolicy: {{ $.Values.docker.pull_policy }}
          ports:
          - containerPort: {{ .Values.localmemcached.port }}
            protocol: TCP
          env:
            - name: MEMC_PORT
              value: "{{ .Values.localmemcached.port }}"
            - name: MEMC_MODE
              value: "insecure"
          resources:
            requests:
              {{- toYaml $.Values.localmemcached.resources.requests | nindent 14 }}
            limits:
              {{- toYaml $.Values.localmemcached.resources.limits | nindent 14 }}
{{- end }}

{{- define "localmemcached.service" }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ template "base.meta.name" (dict "Root" . ) }}-memcached
  labels:
    app: memcached
    chart: {{ template "base.name.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  type: ClusterIP
  selector:
    app: memcached
    release: {{ .Release.Name }}
    routed_via: {{ .Values.routed_via | default .Release.Name }}
  ports:
    - name: {{ template "base.meta.name" (dict "Root" . ) }}-memcached
      protocol: TCP
      port: {{ $.Values.localmemcached.port }}
      targetPort: {{ $.Values.localmemcached.port }}
{{- end }}

{{- define "localmemcached.networkpolicy" }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ template "base.meta.name" (dict "Root" . ) }}-memcached
  labels:
    app: superset
    chart: {{ template "base.name.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  podSelector:
    matchLabels:
      app: memcached
      release: {{ .Release.Name }}
  policyTypes:
    - Ingress
  ingress:
    - ports:
      - port: {{ $.Values.localmemcached.port }}
        protocol: TCP
{{- end }}
