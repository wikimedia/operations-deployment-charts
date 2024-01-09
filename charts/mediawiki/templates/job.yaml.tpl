{{ if .Values.mwscript.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  # The release name includes a randomly generated token for each job, so names are unique.
  name: {{ template "mw.name.namespace.env.release" . }}
  {{- include "mw.labels" . | indent 2 }}
spec:
  template:
    metadata:
      labels:
        app: {{ template "base.name.chart" . }}
        release: {{ .Release.Name }}
        deployment: {{ .Release.Namespace }}
        routed_via: {{ .Values.routed_via | default .Release.Name }}
        # The wrapper script adds "username" and "script" labels.
        {{- if .Values.mwscript.labels }}
        {{- toYaml .Values.mwscript.labels | nindent 8 }}
        {{- end }}
      annotations:
        # Shut down the pod (via k8s-controller-sidecars) when -app is the only container left.
        # TODO: This needs to be updated as sidecars are added/removed, else Jobs will stay active
        # with their sidecars running even after the main container completes.
        pod.kubernetes.io/sidecars: "\
          {{ include "base.name.release" . }}-mcrouter,\
          {{ include "base.name.release" . }}-tls-proxy,\
          {{ include "base.name.release" . }}-rsyslog"
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
  ttlSecondsAfterFinished: 3600
{{- end }}
