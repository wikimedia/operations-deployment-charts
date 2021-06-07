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
{{- if .Values.puppet_ca_crt }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-ca-bundle-config
data:
  puppet-ca: {{ .Values.puppet_ca_crt }}
{{- end }}