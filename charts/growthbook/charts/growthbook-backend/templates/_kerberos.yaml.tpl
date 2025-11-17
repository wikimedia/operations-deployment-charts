{{/*
  This configmap is used to define the kerberos client configuration.
*/}}
{{- define "kerberos.configmap" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: growthbook-kerberos-config
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  krb5.conf: |
    [libdefaults]
      default_realm = WIKIMEDIA
      kdc_timesync = 1
      ccache_type = 4
      forwardable = true
      proxiable = true
      ticket_lifetime = 2d
      renew_lifetime = 14d
      dns_canonicalize_hostname = false
      rdns = false

    [realms]
      WIKIMEDIA = {
        {{- range $kerberos_server := $.Values.kerberos.servers }}
        kdc = {{ $kerberos_server }}
        {{- end }}
        admin_server = {{ $.Values.kerberos.admin }}
      }
    [domain_realm]
      .wikimedia.org = WIKIMEDIA
      wikimedia.org = WIKIMEDIA
      discovery.wmnet = WIKIMEDIA
{{- end }}

{{- define "kerberos.container" }}
{{- $release := include "base.name.release" . }}
- name: {{ $release }}-renew-kerberos-token
  image: {{ $.Values.docker.registry }}/{{ $.Values.common_images.kerberos.image }}:{{ $.Values.common_images.kerberos.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
  {{- range $k, $v := .Values.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  command:
    - /usr/bin/k5start {{/* This container continually renews the kerberos ticket using a given keytab */}}
    - -a   {{/* Renew on each wakeup when running as a daemon */}}
    - -K   {{/* Run as daemon, check ticket every <interval> minutes */}}
    - {{ default "60" $.Values.kerberos.ticket_renewal_interval_minutes | quote }}
    - -f   {{/* Use <keytab> for authentication rather than password */}}
    - /etc/kerberos/keytabs/{{ $.Chart.Name }}.keytab
    - -U   {{/* Use the first principal in the keytab as the client principal and don't look for a principal on the command line */}}
    - -v   {{/* Verbose */}}
  {{- include "base.helper.resources" $.Values.kerberos.resources | indent 2 }}
  {{- include "base.helper.restrictedSecurityContext" . | nindent 2 }}
  volumeMounts:
{{- toYaml $.Values.app.volumeMounts | nindent 4 }}
{{- end }}

{{- define "kerberos.secret" }}
{{/*
  This secret is used to render the service Kerberos keytab on disk.
*/}}
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: growthbook-kerberos-keytab
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  {{ $.Chart.Name }}.keytab: |
    {{- $.Values.kerberos.keytab | nindent 4 }}

{{- end }}
