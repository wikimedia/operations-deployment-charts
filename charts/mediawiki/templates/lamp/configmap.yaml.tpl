{{ include "mesh.configuration.configmap" . }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-httpd-sites-config
  {{- include "mw.labels" . | indent 2}}
data:
{{ include "mw.web-sites" . }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-wikimedia-cluster-config
data:
  wikimedia-cluster: {{ .Values.mw.datacenter }}
{{- if .Values.mw.wmerrors }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-wmerrors
data:
{{ .Values.mw.wmerrors | toYaml | indent 2 }}
{{- end -}}
{{- if .Values.debug.php.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-php-debug-config
data:
{{- range $k, $v := .Values.debug.php.contents }}
  "{{ $k }}.php": {{ $v | toYaml | indent 4 }}
{{- end }}
{{- end -}}
{{- if .Values.mw.httpd.additional_config }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-httpd-early-config
data:
  00-aaa.conf: {{- .Values.mw.httpd.additional_config | toYaml | indent 4 }}
{{- end }}
