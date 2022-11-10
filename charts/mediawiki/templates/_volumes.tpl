{{- define "mw.volumes" }}
{{ $release := include "wmf.releasename" . }}
# Apache sites
- name: {{ $release }}-httpd-sites
  configMap:
    name: {{ $release }}-httpd-sites-config
{{- if .Values.mw.httpd.additional_config }}
# Additional httpd debug configuration
- name: {{ $release }}-httpd-early
  configMap:
    name: {{ $release }}-httpd-early-config
{{- end }}
# Datacenter
- name: {{ $release }}-wikimedia-cluster
  configMap:
    name: {{ $release }}-wikimedia-cluster-config
# TLS configurations
{{- include "tls.volume" . }}
{{- if eq .Values.php.fcgi_mode "FCGI_UNIX" }}
# Shared unix socket for php apps
- name: shared-socket
  emptyDir: {}
{{- end }}
{{- if .Values.mw.wmerrors }}
- name: {{ $release }}-wmerrors
  configMap:
    name: {{ $release }}-wmerrors
{{- end }}
{{- if .Values.debug.php.enabled }}
# php debug volume
- name: {{ $release }}-php-debug
  configMap:
    name: {{ $release }}-php-debug-config
{{- end }}
{{- if .Values.mw.mcrouter.enabled }}
# Mcrouter configuration
- name: {{ $release }}-mcrouter-config
  configMap:
    name: {{ $release }}-mcrouter-config
{{- end }}
{{- if .Values.mw.logging.rsyslog }}
- name: {{ $release }}-rsyslog-config
  configMap:
    name: {{ $release }}-rsyslog-config
- name: php-logging
  emptyDir: {}
{{- end }}
{{ end }}
