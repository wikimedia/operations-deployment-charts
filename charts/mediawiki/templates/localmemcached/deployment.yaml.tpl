{{ define "localmemcached.deployment" }}
{{ $release := include "base.name.release" . }}
{{- $flags := fromJson (include "mw.helpers.feature_flags" . ) -}}

{{- range .Values.mw.localmemcached.ports -}}
- name: {{ $release }}-memcached-{{ . }}
  image: {{ $.Values.docker.registry }}/{{ $.Values.common_images.memcached }}
  imagePullPolicy: {{ $.Values.docker.pull_policy }}
  {{- if $flags.native_sidecars }}
  restartPolicy: Always
  {{- end }}
  env:
    - name: MEMC_PORT
      value: "{{ . }}"
  resources:
    requests:
{{ toYaml $.Values.mw.localmemcached.resources.requests | indent 6 }}
    limits:
{{ toYaml $.Values.mw.localmemcached.resources.limits | indent 6 }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{ end }}

{{ end }}
