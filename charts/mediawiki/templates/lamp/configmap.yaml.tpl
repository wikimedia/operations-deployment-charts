{{ include "tls.config" . }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-httpd-sites-config
  {{- include "mw.labels" . | indent 2}}
data:
{{ include "mw.web-sites" . }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-wikimedia-cluster-config
data:
  wikimedia-cluster: {{ .Values.mw.datacenter }}
{{- if .Values.mw.wmerrors }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-wmerrors
data:
{{ .Values.mw.wmerrors | toYaml | indent 2 }}
{{- end -}}