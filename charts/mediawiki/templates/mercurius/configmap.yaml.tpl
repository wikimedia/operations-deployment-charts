{{ define "mw.mercurius.configmap" }}
{{- if .Values.mercurius.enabled -}}
{{ $release := .Values.main_app.image }}
{{- if .Values.main_app.image | contains ":" }}
{{ $release = last (splitList ":" .Values.main_app.image ) }}
{{- end }}
{{ $ts := now | date "2006-01-02T15:04:05Z" }}
{{- if .Values.mercurius.dummy_ts }}
{{ $ts = .Values.mercurius.dummy_ts }}
{{- end }}
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
  {{- range $mercurius_job := $.Values.mercurius.jobs }}
  {{ $mercurius_job }}.yaml: |-
    release-id: "{{ $release }}"
    release-time: {{ $ts }}
    release-path: /etc/mercurius/release.json
    tls:
      ca-path: /etc/ssl/certs/wmf-ca-certificates.crt
      ciphers: "ECDHE-ECDSA-AES256-GCM-SHA384"
      curves: "P-256"
      sig-algs: "ECDSA+SHA256"
    {{- with $.Values.mercurius }}
    topics:
      - {{ $.Values.mw.datacenter }}.mediawiki.job.{{ $mercurius_job }}
    brokers:
    {{- range $broker := .brokers }}
      - {{ $broker }}
    {{- end }}
    group: mercurius-{{ $.Values.mw.datacenter }}-{{ $mercurius_job }}
    workers: {{ .workers }}
    command: /bin/bash
    command-args:
      - /usr/bin/mercurius-wrapper
    max-retries: {{ .max_retries }}
    retry-interval: {{ .retry_interval }}
    {{- if .consumer_properties }}
    consumer-properties:
    {{- range $property, $value := .consumer_properties }}
      {{ $property }}: {{ $value }}
    {{- end }}
    {{- end }}
    {{- end }}
{{- end }}
{{- end }}
{{- end -}}
