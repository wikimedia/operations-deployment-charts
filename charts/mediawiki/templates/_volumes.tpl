{{- define "mw.volumes" }}
{{ $release := include "base.name.release" . }}
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
{{- if .Values.mw.mail_host }}
# sendmail configuration
- name: {{ $release }}-mail
  configMap:
    name: {{ $release }}-mail-config
{{- end }}
# TLS configurations
{{- include "mesh.deployment.volume" . }}
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
{{- if .Values.mw.geoip }}
# GeoIP data
- name: {{ $release }}-geoip
  hostPath:
    path: /usr/share/GeoIP
- name: {{ $release }}-geoipinfo
  hostPath:
    path: /usr/share/GeoIPInfo
{{- end }}
{{ end }}
