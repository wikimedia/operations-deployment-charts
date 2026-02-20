{{/*
== configuration of a job (Job or CronJob) for a generic application
- app.job.cron_properties(.job): Definitions of the scheduling properties of a cronjob
- app.job.container(.app, .job): the definition of a job container for a generic application.
  typical usage: {{ include "app.job.container" (dict "Root" $root "Name" $cronjob  "Job" $cron_opts) }}
*/}}
{{- define "app.job.cron_properties" }}
schedule: "{{ .schedule | default "@daily" }}"
concurrencyPolicy: {{ .concurrency | default "Forbid" }}
{{- end }}

{{- define "app.job.job_properties" }}
{{- if .activeDeadlineSeconds }}
activeDeadlineSeconds: {{ .activeDeadlineSeconds }}
{{- end }}
{{- end }}

{{- define "app.job.container" }}
{{- $root := .Root }}
- name: {{ template "base.name.release" .Root}}-{{ .Name }}
  {{- if .Job.image_versioned }}
  image: "{{ .Root.Values.docker.registry }}/{{ .Job.image_versioned }}"
  {{- else }}
  image: "{{ .Root.Values.docker.registry }}/{{ .Root.Values.app.image }}:{{ .Root.Values.app.version }}"
  {{- end }}
  imagePullPolicy: {{ .Root.Values.docker.pull_policy }}
  env:
  {{- range $k, $v := .Root.Values.config.public }}
  - name: {{ $k | upper }}
    value: {{ $v | quote }}
  {{- end }}
  {{- range $k, $v := .Root.Values.config.private }}
  - name: {{ $k }}
    valueFrom:
      secretKeyRef:
        name: {{ template "base.name.release" $root }}-secret-config
        key: {{ $k }}
  {{- end }}
  command:
{{ toYaml .Job.command | indent 4 }}
  {{- if .Job.resources }}
  {{- include "base.helper.resources" .Job.resources | indent 2 }}
  {{- else }}
  {{- include "base.helper.resources" .Root.Values.app | indent 2 }}
  {{- end }}
  {{- if .Job.volumeMounts }}
  volumeMounts:
  {{- toYaml .Job.volumeMounts | nindent 4 }}
  {{- end }}
{{ include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- end }}

{{- define "app.job.volume" }}
{{- if .Job.volumeMounts }}
volumes:
{{- toYaml  .Job.volumes  | nindent 2 }}
{{- end }}
{{- end }}

