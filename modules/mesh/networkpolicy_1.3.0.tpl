{{/* Auto-define egress networkpolicies for all authorized listeners from envoy */}}
{{- define "mesh.networkpolicy.egress" }}
{{- if .Values.discovery | default false -}}
  {{- range $name := .Values.discovery.listeners }}
    {{- $listener := index $.Values.services_proxy $name }}
    {{- with $listener.upstream }}
    {{- if .ips }}
# Network egress to {{ $name }}
- to:
  {{- range .ips }}
  - ipBlock:
      cidr: {{ . }}
  {{- end }}
  ports:
  - protocol: TCP
    port: {{ .port }}
    {{- end }}
    {{- end }} {{/* end with upstream */}}
    {{- range $split := $listener.splits }}
    {{- if $split.ips }}
# Network egress to {{ $name }}_{{ $split.name }}-split
- to:
  {{- range $split.ips }}
  - ipBlock:
      cidr: {{ . }}
  {{- end }}
  ports:
  - protocol: TCP
    port: {{ $split.port }}
    {{- end }}
    {{- end }} {{/* end range splits */}}
  {{- end }} {{/* end range listeners */}}
{{- end }}
{{- if (.Values.mesh.tracing | default dict).enabled }}
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: {{ .Values.mesh.tracing.otel_collector_namespace | default "opentelemetry-collector" }}
    podSelector:
      matchLabels:
      {{- if .Values.mesh.tracing.otel_pod_selector }}
        {{ .Values.mesh.tracing.otel_pod_selector | toYaml | nindent 8 }}
      {{- else }}
        component: agent-collector
      {{- end }}
  ports:
    - protocol: TCP
      port: {{ .Values.mesh.tracing.port | default 4317 }}
    - protocol: TCP
      port: {{ .Values.mesh.tracing.app_port | default 4318 }}
{{- end -}}
{{- end -}}


{{- define "mesh.networkpolicy.ingress" -}}
{{- if .Values.mesh.enabled }}
{{- if .Values.mesh.public_port }}
- port: {{ .Values.mesh.public_port }}
  protocol: TCP
{{- range .Values.mesh.restricted_listeners }}
- port: {{ .port }}
  protocol: TCP
{{- end }}
{{- end }}
{{- if .Values.mesh.telemetry.enabled }}
- port: {{ .Values.mesh.telemetry.port }}
  protocol: TCP
{{- end }}
{{- end }}
{{- end -}}
