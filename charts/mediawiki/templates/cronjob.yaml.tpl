{{- $flags := fromJson (include "mw.helpers.feature_flags" . ) }}
{{- if $flags.cron }}
{{- $can_run := include "mw.can_run" . | include "mw.str2bool" }}
{{- if $can_run }}
{{ $release := include "base.name.release" . }}
{{- range $jobConfig := .Values.mwcron.jobs }}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ $jobConfig.name }}
  {{- include "mw.helpers.labels" $ | indent 2 }}
    team: "{{ $jobConfig.labels.team }}"
    script: "{{ $jobConfig.labels.script }}"
  annotations:
    comment: {{ $jobConfig.description | quote }}
spec:
  suspend: {{ has $jobConfig.name $.Values.mwcron.suspended_jobs }}
  schedule: {{ $jobConfig.schedule | default "@daily" | quote }}
  concurrencyPolicy: {{ $jobConfig.concurrency | default "Replace" }}
  # startingDeadlineSeconds must be more than 10 seconds if set
  # see https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/#job-creation
  {{- if $jobConfig.startingDeadlineSeconds }}
  startingDeadlineSeconds: {{ max $jobConfig.startingDeadlineSeconds 10 }}
  {{- end }}
  failedJobsHistoryLimit: {{ $jobConfig.failedJobsHistoryLimit | default 1 }}
  successfulJobsHistoryLimit: {{ $jobConfig.successfulJobsHistoryLimit | default 3 }}
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: {{ template "base.name.chart" $ }}
            release: {{ $.Release.Name }}
            deployment: {{ $.Release.Namespace }}
            routed_via: {{ $.Values.routed_via | default $.Release.Name }}
            team: "{{ $jobConfig.labels.team }}"
            script: "{{ $jobConfig.labels.script }}"
            cronjob: "{{ $jobConfig.name }}"
          annotations:
            # Shut down the pod (via k10s-controller-sidecars) when the -app container is finished, even
            # if sidecars are still running.
            # TODO: This needs to be updated as sidecars are added/removed, else Jobs will stay active
            # with their sidecars running even after the main container completes.
            {{- $release := include "base.name.release" $ -}}
            {{- $sidecars := list -}}
            {{- if $.Values.cache.mcrouter.enabled -}}
              {{- $sidecars = print $release "-mcrouter" | append $sidecars -}}
            {{- end -}}
            {{- if $.Values.mesh.enabled -}}
              {{- $sidecars = print $release "-tls-proxy" | append $sidecars -}}
            {{- end -}}
            {{- if $.Values.mw.logging.rsyslog -}}
              {{- $sidecars = print $release "-rsyslog" | append $sidecars -}}
            {{- end -}}
            {{- if $sidecars }}
            pod.kubernetes.io/sidecars: {{ $sidecars | join "," }}
            {{- end }}
            comment: {{ $jobConfig.description | quote }}
        spec:
          terminationGracePeriodSeconds: {{ $jobConfig.terminationGracePeriodSeconds | default $.Values.terminationGracePeriodSeconds }}
          containers:
          # When adding or removing containers, also update the pod.kubernetes.io/sidecars annotation
          # above.
          {{- include "lamp.deployment" (merge (dict "JobConfig" $jobConfig) $ ) | indent 10 }}
          {{- include "cache.mcrouter.deployment" $ | indent 10 }}
          {{- include "mesh.deployment.container" $ | indent 10}}
          {{- include "rsyslog.deployment" $ | indent 10 }}
          {{- include "base.statsd.container" $ | indent 10 }}
          volumes:
          {{- include "mw.volumes" $ | indent 12}}
          {{- include "base.statsd.volume" $ | indent 12 }}
          # Maintenance cronjobs should be idempotent, or at worst duplicate work should be harmless.
          # However, as a first pass, we don't want to restart them on failure so we get good signal for
          # the migration.
          # TODO: Eventually, let the cronjobs declare if they should restart on failure.
          restartPolicy: Never
      # As above, we're not assuming idempotence; don't restart the entire pod, either.
      backoffLimit: {{ $jobConfig.backoffLimit | default 0 }}
      ttlSecondsAfterFinished: {{ $jobConfig.ttlSecondsAfterFinished | int | default 106400 }}  # {{ $jobConfig.ttlSecondsAfterFinished | int | default 106400 | toString | duration }}

---
{{- end }} {{/* end range $jobConfig */}}
{{- end }} {{/* end if $can_run */}}
{{- end }} {{/* end if $flags.cron */}}
