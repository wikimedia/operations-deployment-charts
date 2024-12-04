{{ define "mw.mercurius.configmap" }}
{{- if .Values.mercurius.enabled -}}
{{ $release := .Values.main_app.version }}
{{ $ts := now | date "2006-01-02T15:04:05Z" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" $ }}-mercurius-script
  {{- include "mw.labels" $ | indent 2}}
data:
  mercurius-wrapper: |
    {{- .Files.Get "files/mercurius_wrapper.sh" | nindent 4 }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" $ }}-mercurius-config
  {{- include "mw.labels" $ | indent 2}}
data:
  release.json: |-
    {{ dict "id" $release "ts" $ts | toJson }}
  # in future we will create a config for each job - for now share the config
  mercurius.yaml: |-
    release-id: "{{ $release }}"
    release-time: {{ $ts }}
    release-path: /etc/mercurius/release.json
    tls:
      ca-path: /etc/ssl/certs/wmf-ca-certificates.crt
      ciphers: "ECDHE-ECDSA-AES256-GCM-SHA384"
      curves: "P-256"
      sig-algs: "ECDSA+SHA256"
    {{- $job_count := len $.Values.mercurius.jobs }}
    {{- if gt $job_count 1 }}
    {{- fail "Mercurius chart currently only supports one job" }}
    {{- end -}}
    {{- with $.Values.mercurius }}
    topics:
    {{- range $mercurius_job := .jobs }}
      - {{ $.Values.mw.datacenter }}.mediawiki.job.{{ $mercurius_job }}
    {{- end }}
    brokers:
    {{- range $broker := .brokers }}
      - {{ $broker }}
    {{- end }}
    group: mercurius-{{ $.Values.mw.datacenter }}
    workers: {{ .workers }}
    command: /bin/bash
    command-args:
      - /usr/bin/mercurius-wrapper
    max-retries: {{ .max_retries }}
    retry-interval: {{ .retry_interval }}
    consumer-properties:
      # avoid processing old jobs on startup
      auto.offset.reset: largest
    {{- end }}
{{- end }}
{{- end -}}
