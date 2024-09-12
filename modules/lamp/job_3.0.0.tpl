{{/*
== configuration of jobs for a LAMP stack

- lamp.cron_properties(.job): Definitions of the scheduling properties of a cronjob
- lamp.container(.app, .job): the definition of a job container for a generic application.
  typical usage: {{ include "app.job.container" (dict "Root" . "Name" $cronjob  "Job" $cron_opts) }}
*/}}
{{- define "lamp.job.cron_properties" }}
schedule: "{{ .schedule | default "@daily" }}"
concurrencyPolicy: {{ .concurrency | default "Forbid" }}
{{- end }}

{{- define "lamp.job.container" }}
- name: {{ template "base.name.release" .Root }}-{{ .Name }}
  {{- if .Job.image_versioned }}
  image: "{{ .Root.Values.docker.registry }}/{{ .Job.image_versioned }}"
  {{- else }}
  image: {{ .Root.Values.docker.registry }}/{{ .Root.Values.lamp.phpfpm.image.name }}:{{ .Root.Values.lamp.phpfpm.image.version }}{{ if.Root.Values.lamp.phpfpm.image.flavour }}-{{ .Root.Values.lamp.phpfpm.image.flavour }}{{- end }}
  {{- end }}
  imagePullPolicy: {{.Root.Values.docker.pull_policy }}
  env:
  - name: SERVERGROUP
    value: {{ .Root.Values.lamp.servergroup }}
  - name: FCGI_MODE
    value: {{ .Root.Values.lamp.fcgi_mode }}
  - name: PHP__opcache__memory_consumption
    value: "{{ .Root.Values.lamp.phpfpm.opcache.size }}"
  - name: PHP__opcache__max_accelerated_files
    value: "{{ .Root.Values.lamp.phpfpm.opcache.nofiles }}"
  - name: FPM__request_slowlog_timeout
    value: "{{ .Root.Values.lamp.phpfpm.slowlog_timeout }}"
  - name: FPM__request_terminate_timeout
    value: "{{ .Root.Values.lamp.phpfpm.timeout }}"
  - name: PHP__apc__shm_size
    value: "{{ .Root.Values.lamp.phpfpm.apc.size }}"
  - name: FPM__pm__max_children
    value: "{{ .Root.Values.lamp.phpfpm.workers }}"
  - name: FCGI_URL
    value: "0.0.0.0:9000"
  - name: FCGI_ALLOW
    value: "127.0.0.1"
  command:
{{ toYaml .Job.command | indent 4 }}
  {{- if .Job.resources }}
  {{- include "base.helper.resources" .Job.resources | indent 2 }}
  {{- else }}
  {{- include "base.helper.resources" .Root.Values.lamp.phpfpm | indent 2 }}
  {{- end }}
  volumeMounts:
    - name: {{ template "base.name.release" .Root }}-app-config
      mountPath: "/srv/app/config"
      readOnly: true
  {{- if .Job.volumeMounts }}
  {{- toYaml .Job.volumeMounts | nindent 4 }}
  {{- end }}
{{ include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- end }}

{{- define "lamp.job.volume" }}
{{- if .Job.volumeMounts }}
volumes:
{{- toYaml  .Job.volumes  | nindent 2 }}
{{- end }}
{{- end }}
