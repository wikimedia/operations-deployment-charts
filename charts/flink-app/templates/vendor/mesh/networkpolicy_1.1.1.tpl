{{/* Auto-define egress networkpolicies for all authorized listeners from envoy */}}
{{- define "mesh.networkpolicy.egress" }}
{{- if .Values.discovery | default false -}}
  {{- range $name := .Values.discovery.listeners }}
    {{- $listener := index $.Values.services_proxy $name }}
    {{- with $listener.upstream }}
# Network egress to {{ $name }}
- to:
  {{- range .ips }}
  - ipBlock:
      cidr: {{ . }}
  {{- end }}
  ports:
  - protocol: TCP
    port: {{ .port }}
    {{- end }} {{/* end with upstream */}}
  {{- end }} {{/* end range listeners */}}
{{- end }}
{{- end -}}


{{- define "mesh.networkpolicy.ingress" -}}
{{- if .Values.mesh.enabled }}
{{- if .Values.mesh.public_port }}
- port: {{ .Values.mesh.public_port }}
  protocol: TCP
{{- end }}
{{- if .Values.mesh.telemetry.enabled }}
- port: {{ .Values.mesh.telemetry.port }}
  protocol: TCP
{{- end }}
{{- end }}
{{- end -}}