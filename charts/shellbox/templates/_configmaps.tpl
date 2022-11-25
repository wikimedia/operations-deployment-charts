{{ define "shellbox.secret" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-shellbox-httpd-config
  labels:
    app: {{ template "base.name.chart" . }}
    chart: {{ template "base.name.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
data:
  90-shellbox.conf: |-
    SetEnvIf Request_URI . SHELLBOX_SECRET_KEY={{ .Values.shellbox.secret_key }}
{{end}}
