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
  name: {{ template "wmf.releasename" . }}-ca-config
data:
  ca.crt: |
{{ .Values.puppet_ca_crt | indent 4 }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-php-curl-config
data:
  "20-curl-mw.ini": |
    curl.cainfo="/etc/ssl/ca.crt"
    openssl.cafile="/etc/ssl/ca.crt"

{{- end }}
