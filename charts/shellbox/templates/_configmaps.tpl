{{ define "shellbox.secret" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-shellbox-httpd-config
  labels:
    app: {{ template "wmf.chartname" . }}
    chart: {{ template "wmf.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
data:
  90-shellbox.conf: |-
    SetEnvIf Request_URI . SHELLBOX_SECRET_KEY={{ .Values.shellbox.secret_key }}
{{end}}
