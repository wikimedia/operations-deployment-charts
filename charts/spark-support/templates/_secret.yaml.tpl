{{- define "secret.kerberos-keytab" }}
{{- if $.Values.kerberos.keytabs }}
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: kerberos-keytabs
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  {{- range $keytab, $keytab_data := $.Values.kerberos.keytabs }}
  {{ $keytab }}.keytab: |
    {{- tpl $keytab_data $ | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

apiVersion: v1
kind: Secret
metadata:
  name: "secrets"
type: Opaque
{{- if .Values.config.private }}
data: {{- range $k := (keys .Values.config.private | sortAlpha) }}
  {{ $k }}: {{ get $.Values.config.private $k | b64enc | quote }}
{{- end -}}
{{- end }}

