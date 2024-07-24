{{- define "mongodb.deployment" }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "base.meta.name" (dict "Root" . ) }}-mongodb
  labels:
    app: mongodb
    chart: {{ template "base.name.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  selector:
    matchLabels:
      app: mongodb
      release: {{ .Release.Name }}
  replicas: {{ .Values.mongodb.resources.replicas }}
  template:
    metadata:
      labels:
        app: mongodb
        release: {{ .Release.Name }}
        routed_via: {{ .Values.routed_via | default .Release.Name }}
      annotations:
        checksum/mongodb-config: {{ include "mongodb.configmap" . | sha256sum }}
    spec:
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      containers:
        - name: {{ include "base.name.release" . }}-mongodb
          image: {{ $.Values.docker.registry }}/{{ $.Values.mongodb.image }}:{{ $.Values.mongodb.version }}
          imagePullPolicy: {{ $.Values.docker.pull_policy }}
          command: ['/opt/mongodb/bin/mongod']
          args:
          - --config
          - /etc/mongodb/mongod.conf
          ports:
          - containerPort: {{ .Values.mongodb.port }}
            protocol: TCP
          livenessProbe: {{ $.Values.mongodb.liveness_probe | toYaml | nindent 12 }}
          readinessProbe: {{ $.Values.mongodb.readiness_probe | toYaml | nindent 12 }}
          resources:
            requests:
              {{- toYaml $.Values.mongodb.resources.requests | nindent 14 }}
            limits:
              {{- toYaml $.Values.mongodb.resources.limits | nindent 14 }}
          {{- include "base.helper.restrictedSecurityContext" . | nindent 10 }}
          volumeMounts:
            {{-  toYaml $.Values.mongodb.volumeMounts | nindent 12 }}
      volumes:
      {{-  toYaml $.Values.mongodb.volumes | nindent 8 }}
{{- end }}

{{- define "mongodb.service" }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ template "base.meta.name" (dict "Root" . ) }}-mongodb
  labels:
    app: mongodb
    chart: {{ template "base.name.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  type: ClusterIP
  selector:
    app: mongodb
    release: {{ .Release.Name }}
    routed_via: {{ .Values.routed_via | default .Release.Name }}
  ports:
    - name: {{ template "base.meta.name" (dict "Root" . ) }}-mongodb
      protocol: TCP
      port: {{ $.Values.mongodb.port }}
      targetPort: {{ $.Values.mongodb.port }}
{{- end }}

{{- define "mongodb.configmap" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-config
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  mongod.conf: |
    {{- toYaml $.Values.mongodb.config | nindent 4 }}
{{- end }}

{{- define "mongodb.networkpolicy" }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ template "base.meta.name" (dict "Root" . ) }}-mongodb
  labels:
    app: mongodb
    chart: {{ template "base.name.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  podSelector:
    matchLabels:
      app: mongodb
      release: {{ .Release.Name }}
  policyTypes:
    - Ingress
  ingress:
    - ports:
      - port: {{ $.Values.mongodb.port }}
        protocol: TCP
{{- end }}