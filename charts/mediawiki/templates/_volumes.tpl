{{- define "mw.volumes" }}
# Apache sites
- name: {{ template "wmf.releasename" . }}-httpd-sites
  configMap:
    name: {{ template "wmf.releasename" . }}-httpd-sites-config
# Datacenter
- name: {{ template "wmf.releasename" . }}-wikimedia-cluster
  configMap:
    name: {{ template "wmf.releasename" . }}-wikimedia-cluster-config
{{- if .Values.puppet_ca_crt }}
# CA bundle
- name: {{ template "wmf.releasename" . }}-ca-bundle
  configMap:
    name: {{ template "wmf.releasename" . }}-ca-bundle-config
    items:
    - key: puppet-ca
      path: certs/ca-certificates.crt
{{- end }}
# TLS configurations
{{- include "tls.volume" . }}
{{- if eq .Values.php.fcgi_mode "FCGI_UNIX" -}}
# Shared unix socket for php apps
- name: shared-socket
  emptydir: {}
{{- end -}}
{{- if .Values.mw.mcrouter.enabled -}}
# Mcrouter configuration
- name: {{ template "wmf.releasename" . }}-mcrouter-config
  configMap:
    name: {{ template "wmf.releasename" . }}-mcrouter-config
{{- end }}
{{- if .Values.mw.nutcracker.enabled }}
# Nutcracker configuration
- name: {{ template "wmf.releasename" . }}-nutcracker-config
  configMap:
    name: {{ template "wmf.releasename" . }}-nutcracker-config
{{- end }}
{{ end }}