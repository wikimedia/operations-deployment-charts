{{/*
== configuration of jobs for a LAMP stack

- lamp.job.container(.lamp, .job): the definition of a job container for a LAMP application.
  typical usage: {{ include "lamp.job.container" (dict "Root" . .Job $cronjob) }}

*/}}
{{- define "lamp.job.container" }}
- name: {{ template "base.name.release" .Root }}-{{ .Job.name }}
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
{{- end }}