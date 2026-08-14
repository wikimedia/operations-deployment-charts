{{- $flags := fromJson (include "mw.helpers.feature_flags" . ) -}}
{{ if $flags.web }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "mw.name.namespace.env.release" . }}
  {{- include "mw.helpers.labels" . | indent 2 }}
spec:
  selector:
    matchLabels:
      app: {{ template "base.name.chart" . }}
      release: {{ .Release.Name }}
  replicas: {{ .Values.resources.replicas }}
  {{- if .Values.strategy }}
  strategy:
  {{- toYaml .Values.strategy | nindent 6 }}
  {{- end }}
  template:
    metadata:
      labels:
        app: {{ template "base.name.chart" . }}
        release: {{ .Release.Name }}
        deployment: {{ .Release.Namespace }}
        routed_via: {{ .Values.routed_via | default .Release.Name }}
      annotations:
        checksum/sites: {{ include "mw.web-sites" . | sha256sum }}
        {{- if  .Values.php.envvars}}
        # we need to restart the deployment when we add/remove external
        # env variables, not just the ones we explicitly declare here.
        checksum/environment: {{ include "mw.lamp.envvars" . | sha256sum }}
        {{- end }}
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
      {{- if .Values.tolerations }}
      tolerations:
      {{- toYaml .Values.tolerations | nindent 8 }}
      {{- end }}
      {{- if .Values.terminationGracePeriodSeconds }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
      {{- end }}
      {{- if $flags.native_sidecars}}
      containers:
      {{- include "mediawiki.container" . | indent 8 }}
      initContainers:
      {{- if $flags.web }}
      {{- include "sidecars.httpd.container" . | indent 8 }}
      {{- include "sidecars.httpd-exporter.container" . | indent 8}}
      {{- end }}
      {{- if .Values.monitoring.enabled }}
      {{- include "sidecars.php-fpm-exporter.container" . | indent 8 }}
      {{- end }}
      {{- include "cache.mcrouter.container" . | indent 8 }}
      {{- if .Values.mw.localmemcached.enabled }}
        {{- include "localmemcached.deployment" . | indent 8 }}
      {{- end }}
      {{- include "mesh.deployment.container" . | indent 8 }}
      {{- include "rsyslog.deployment" . | indent 8 }}
      {{- include "base.statsd.container" . | indent 8 }}
      {{- end }}
      {{- if not $flags.native_sidecars}}
      containers:
      {{- if $flags.web }}
      {{- include "sidecars.httpd.container" . | indent 8 }}
      {{- end }}
      {{- include "mediawiki.container" . | indent 8 }}
      {{- if .Values.monitoring.enabled }}
      {{- if $flags.web }}
      {{- include "sidecars.httpd-exporter.container" . | indent 8 }}
      {{- end }}
      {{- include "sidecars.php-fpm-exporter.container" . | indent 8 }}
      {{- end }}
      {{- include "cache.mcrouter.container" . | indent 8 }}
      {{- if .Values.mw.localmemcached.enabled }}
        {{- include "localmemcached.deployment" . | indent 8 }}
      {{- end }}
      {{- include "mesh.deployment.container" . | indent 8}}
      {{- include "rsyslog.deployment" . | indent 8 }}
      {{- include "base.statsd.container" . | indent 8 }}
      {{- end }}
      volumes:
      {{- include "mw.volumes" . | indent 8}}
      {{- include "base.statsd.volume" . | indent 8 }}
{{- end }}
