{{- define "mw.volumes" }}
{{ $release := include "base.name.release" . }}
{{- if .Values.mw.httpd.enabled }}
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
{{- if .Values.cache.mcrouter.enabled }}
{{ template "cache.mcrouter.volume" . }}
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
{{- if .Values.php.envvars }}
- name: {{ $release }}-php-envvars
  configMap:
    name: {{ $release }}-php-envvars
{{- end }}
{{- if and (.Values.mwscript.enabled) (.Values.mwscript.textdata) }}
- name: {{ $release }}-mwscript-textdata
  configMap:
    name: {{ $release }}-mwscript-textdata
{{- end }}
{{- if .Values.mercurius.enabled }}
- name: {{ $release }}-mercurius-config
  configMap:
    name: {{ $release }}-mercurius-config
- name: {{ $release }}-mercurius-script
  configMap:
    name: {{ $release }}-mercurius-script
{{- end }}

{{ end }}
