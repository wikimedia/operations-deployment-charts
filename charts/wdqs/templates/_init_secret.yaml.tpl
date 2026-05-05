{{- define "app.init.secret" }}
apiVersion: v1
kind: Secret
metadata:
{{- include "base.meta.metadata" (dict "Root" . "Name" "init-secret-config" ) | indent 2 }}
type: Opaque
{{- if .Values.init.config.private }}
data: {{- range $k := (keys .Values.init.config.private | sortAlpha) }}
  {{ $k }}: {{ get $.Values.init.config.private $k | b64enc | quote }}
{{- end -}}
{{- end }}
{{- end }}
