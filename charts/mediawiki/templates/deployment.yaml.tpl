apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "mw.name.namespace.env.release" . }}
  {{- include "mw.labels" . | indent 2 }}
spec:
  selector:
    matchLabels:
      app: {{ template "base.name.chart" . }}
      release: {{ .Release.Name }}
  replicas: {{ .Values.resources.replicas }}
  template:
    metadata:
      labels:
        app: {{ template "base.name.chart" . }}
        release: {{ .Release.Name }}
        deployment: {{ .Release.Namespace }}
        routed_via: {{ .Values.routed_via | default .Release.Name }}
      annotations:
        checksum/sites: {{ include "mw.web-sites" . | sha256sum }}
        {{- include "mw.rsyslog.annotations" . | indent 8 }}
{{/* please note: we don't use the base.meta module as mediawiki has no secrets whatsoever */}}
        {{- if .Values.monitoring.enabled }}
        prometheus.io/scrape_by_name: "true"
        {{- include "base.statsd.deployment_annotations" . | indent 8 }}
        {{- end }}
        {{- include "mesh.name.annotations" . | indent 8}}
        {{- if .Values.debug.enabled }}
        redeploy/me: {{ .Values.debug.annotation | default "change-me-to-redeploy" }}
        {{- end }}
    spec:
      # TODO: add affinity rules to ensure even distribution across rows
      {{- if .Values.affinity }}
      {{- toYaml .Values.affinity | nindent 6 }}
      {{- end }}
      {{- if .Values.terminationGracePeriodSeconds }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
      {{- end }}
      containers:
      {{- include "lamp.deployment" . | indent 8 }}
      {{- include "cache.mcrouter.deployment" . | indent 8 }}
      {{- if .Values.mw.localmemcached.enabled }}
        {{- include "localmemcached.deployment" . | indent 8 }}
      {{- end }}
      {{- include "mesh.deployment.container" . | indent 8}}
      {{- include "rsyslog.deployment" . | indent 8 }}
      {{- include "base.statsd.container" . | indent 8 }}
      volumes:
      {{- include "mw.volumes" . | indent 8}}
      {{- include "base.statsd.volume" . | indent 8 }}
