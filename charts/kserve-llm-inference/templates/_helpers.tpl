{{/* Common labels. `app-wmf` rather than `app`, because KServe sets `app` itself. */}}
{{- define "kserve-llm-inference.labels" -}}
app-wmf: {{ .Chart.Name }}
chart: {{ .Chart.Name }}-{{ .Chart.Version }}
release: {{ .Release.Name }}
{{- end -}}

{{- define "kserve-llm-inference.vllmImage" -}}
{{ .Values.registry }}/{{ .Values.vllm.image }}:{{ .Values.vllm.version }}
{{- end -}}
