{{ define "localmemcached.deployment" }}
{{ $release := include "wmf.releasename" . }}

{{- range .Values.mw.localmemcached.ports -}}
- name: {{ $release }}-memcached-{{ . }}
  image: {{ $.Values.docker.registry }}/{{ $.Values.common_images.memcached }}
  imagePullPolicy: {{ $.Values.docker.pull_policy }}
  env:
    - name: MEMC_PORT
      value: "{{ . }}"
  resources:
    requests:
{{ toYaml $.Values.mw.localmemcached.resources.requests | indent 6 }}
    limits:
{{ toYaml $.Values.mw.localmemcached.resources.limits | indent 6 }}

{{ end }}

{{ end }}
