{{- $flags := fromJson (include "mw.helpers.feature_flags" . ) -}}
{{ if $flags.job }}
apiVersion: batch/v1
kind: Job
metadata:
  # The release name includes a randomly generated token for each job, so names are unique.
  name: {{ template "mw.name.namespace.env.release" . }}
  {{- include "mw.helpers.labels" . | indent 2 }}
  {{- if or .Values.mwscript.comment .Values.mwscript.dblist }}
  annotations:
    {{- with .Values.mwscript.comment }}
    comment: {{ . | quote }}
    {{- end }}
    {{- with .Values.mwscript.dblist }}
    dblist: {{ . | quote }}
    {{- end }}
  {{- end }}
spec:
  template:
    metadata:
      labels:
        app: {{ template "base.name.chart" . }}
        release: {{ .Release.Name }}
        deployment: {{ .Release.Namespace }}
        routed_via: {{ .Values.routed_via | default .Release.Name }}
        {{- if .Values.mwscript.labels }}
        # The wrapper script adds "username" and "script" labels.
        {{- toYaml .Values.mwscript.labels | nindent 8 }}
        {{- end }}
      annotations:
        # Shut down the pod (via k8s-controller-sidecars) when the -app container is finished, even
        # if sidecars are still running.
        # TODO: This needs to be updated as sidecars are added/removed, else Jobs will stay active
        # with their sidecars running even after the main container completes.
        {{- $release := include "base.name.release" . -}}
        {{- $sidecars := list -}}
        {{- if .Values.cache.mcrouter.enabled -}}
          {{- $sidecars = print $release "-mcrouter" | append $sidecars -}}
        {{- end -}}
        {{- if .Values.mesh.enabled -}}
          {{- $sidecars = print $release "-tls-proxy" | append $sidecars -}}
        {{- end -}}
        {{- if .Values.mw.logging.rsyslog -}}
          {{- $sidecars = print $release "-rsyslog" | append $sidecars -}}
        {{- end -}}
        {{- if $sidecars }}
        pod.kubernetes.io/sidecars: {{ $sidecars | join "," }}
        {{- end }}
        {{- if .Values.mwscript.comment }}
        comment: {{ .Values.mwscript.comment | quote }}
        {{- end }}
    spec:
      {{- if .Values.terminationGracePeriodSeconds }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
      {{- end }}
      containers:
      # When adding or removing containers, also update the pod.kubernetes.io/sidecars annotation
      # above.
      {{- include "lamp.deployment" . | indent 8 }}
      {{- include "cache.mcrouter.deployment" . | indent 8 }}
      {{- include "mesh.deployment.container" . | indent 8}}
      {{- include "rsyslog.deployment" . | indent 8 }}
      {{- include "base.statsd.container" . | indent 8 }}
      volumes:
      {{- include "mw.volumes" . | indent 8}}
      {{- include "base.statsd.volume" . | indent 8 }}
      # Maintenance scripts aren't always idempotent, so to be on the safe side, we don't restart
      # them on failure. This means they might sometimes need to be manually restarted, if it's safe
      # to do so, after they're interrupted due to node failure etc. (This matches the pre-k8s
      # expectations that many scripts were designed for.)
      # TODO: Eventually, add a values entry to let specific scripts declare that they're idempotent
      # and opt into a more hands-off restart/backoff policy.
      restartPolicy: Never
  # As above, we're not assuming idempotence; don't restart the entire pod, either.
  backoffLimit: 0
  ttlSecondsAfterFinished: 604800  # 7 days
  {{- with .Values.mwscript.activeDeadlineSeconds }}
  activeDeadlineSeconds: {{ . }}
  {{- end -}}
{{ else if $flags.mercurius -}}
{{ $release := .Values.main_app.image }}
{{- if .Values.main_app.image | contains ":" }}
{{ $release = last (splitList ":" .Values.main_app.image ) }}
{{- end }}
{{- if hasKey .Values.mercurius "generation" }}
{{ $release = print $release "." .Values.mercurius.generation }}
{{- end }}
{{ $release = ( sha256sum $release | trunc 10 ) }}
{{- range $mercurius_job := .Values.mercurius.jobs }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ printf "mercurius-%s-%s" $release $mercurius_job | lower | trunc 63 | trimSuffix "-"}}
  {{- include "mw.helpers.labels" $ | indent 2 }}
  annotations:
    # Keep untracked objects rather than destroy them - preserve jobs after upgrades
    helm.sh/resource-policy: keep
spec:
  template:
    metadata:
      labels:
        app: {{ template "base.name.chart" $ }}
        release: {{ $.Release.Name }}
        deployment: {{ $.Release.Namespace }}
        routed_via: {{ $.Values.routed_via | default $.Release.Name }}
      annotations:
        # Scrape our metrics port
        prometheus.io/scrape_by_name: "true"
        {{ if and $.Values.mesh.enabled $.Values.mesh.telemetry.enabled -}}
        # TODO: T382630 - Replace with mesh.name.annotations when we have an
        # automatic solution for helmfile-only changes.
        envoyproxy.io/scrape: "true"
        envoyproxy.io/port: "{{ $.Values.mesh.telemetry.port }}"
        {{- end }}
        # Shut down the pod (via k8s-controller-sidecars) when the -app container is finished, even
        # if sidecars are still running.
        # TODO: This needs to be updated as sidecars are added/removed, else Jobs will stay active
        # with their sidecars running even after the main container completes.
        {{- $release := include "base.name.release" $ -}}
        {{- $sidecars := list -}}
        {{- if $.Values.mesh.enabled -}}
          {{- $sidecars = print $release "-tls-proxy" | append $sidecars -}}
        {{- end -}}
        {{- if $.Values.mw.logging.rsyslog -}}
          {{- $sidecars = print $release "-rsyslog" | append $sidecars -}}
        {{- end -}}
        {{- if $sidecars }}
        pod.kubernetes.io/sidecars: {{ $sidecars | join "," }}
        {{- end }}
    spec:
      containers:
      # When adding or removing containers, also update the pod.kubernetes.io/sidecars annotation
      # above.
      {{- include "mesh.deployment.container" $ | indent 8}}
      {{- $configpath := printf "/etc/mercurius/%s.yaml" $mercurius_job }}
      {{- include "lamp.deployment" $ | replace "MERCURIUS_JOB_PLACEHOLDER" $configpath | indent 8 }}
      {{- include "rsyslog.deployment" $ | indent 8 }}
      volumes:
      {{- include "mw.volumes" $ | indent 8}}
      # Exiting 0 indicates that mercurius has picked up a new version and will
      # later be started with a new deployment. Exiting 1 is an actual error
      # and is grounds for a restart.
      restartPolicy: OnFailure
  backoffLimit: {{ $.Values.mercurius.backoff_limit }}
  ttlSecondsAfterFinished: 86400  # 1 day
{{- end }}
{{- end }}
{{ if $flags.dumps }}
{{- if .Values.dumps.enabled }}{{/* TODO: remove dumps.enabled once we're ok enabling it in dse */}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ template "base.name.release" . }}-dumps-job-template
  {{- include "mw.labels" . | indent 2 }}
  {{- if .Values.dumps.comment }}
  annotations:
    comment: {{ .Values.dumps.comment | quote }}
  {{- end }}
spec:
  # We do not wish to execute anything at the moment, so create a suspended job
  suspend: true
  template:
    metadata:
      labels:
        app: {{ template "base.name.chart" . }}
        release: {{ .Release.Name }}
        deployment: {{ .Release.Namespace }}
      annotations:
        # Shut down the pod (via k8s-controller-sidecars) when the -app container is finished, even
        # if sidecars are still running.
        # TODO: This needs to be updated as sidecars are added/removed, else Jobs will stay active
        # with their sidecars running even after the main container completes.
        {{- $release := include "base.name.release" . -}}
        {{- $sidecars := list -}}
        {{- if .Values.cache.mcrouter.enabled -}}
          {{- $sidecars = print $release "-mcrouter" | append $sidecars -}}
        {{- end -}}
        {{- if .Values.mesh.enabled -}}
          {{- $sidecars = print $release "-tls-proxy" | append $sidecars -}}
        {{- end -}}
        {{- if .Values.mw.logging.rsyslog -}}
          {{- $sidecars = print $release "-rsyslog" | append $sidecars -}}
        {{- end -}}
        {{- if $sidecars }}
        pod.kubernetes.io/sidecars: {{ $sidecars | join "," }}
        {{- end }}
    spec:
      {{- if .Values.terminationGracePeriodSeconds }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
      {{- end }}
      # We need to be able to write to the mounted volume as the www-data user
      securityContext:
        fsGroup: 33
      containers:
      # When adding or removing containers, also update the pod.kubernetes.io/sidecars annotation
      # above.
      {{- include "lamp.deployment" . | indent 8 }}
      {{- include "cache.mcrouter.deployment" . | indent 8 }}
      {{- include "mesh.deployment.container" . | indent 8}}
      {{- include "rsyslog.deployment" . | indent 8 }}
      {{- include "base.statsd.container" . | indent 8 }}
      volumes:
      {{- include "mw.volumes" . | indent 8}}
      {{- include "base.statsd.volume" . | indent 8 }}
      {{- include "dumps.volume" . | indent 8 }}
      restartPolicy: Never
  backoffLimit: 0
  ttlSecondsAfterFinished: 604800  # 7 days
  {{- with .Values.dumps.activeDeadlineSeconds }}
  activeDeadlineSeconds: {{ . }}
  {{- end -}}
{{- end }}
{{- end }}