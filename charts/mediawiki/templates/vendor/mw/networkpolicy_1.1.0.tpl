{{/* MediaWiki networkpolicy template

Installs a MediaWiki networkpolicy.
{{ template "mw.networkpolicy" . }}

*/}}
{{- define "mw.networkpolicy" }}
{{- $flags := fromJson ( include "mw.helpers.feature_flags" . ) }}
{{- if $flags.networkpolicy }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ template "base.name.release" . }}
  {{- include "mw.helpers.labels" . | indent 2 }}
spec:
  podSelector:
    matchLabels:
      {{- if .Values.mw.networkpolicy.selectors }}
      {{- .Values.mw.networkpolicy.selectors | toYaml | nindent 6}}
      {{- else }}
      app: {{ template "base.name.chart" . }}
      release: {{ .Release.Name }}
      {{- end }}
  policyTypes:
  {{- if .Values.networkpolicy.egress.enabled }}
    - Egress
  {{- end }}
    - Ingress
  ingress:
    - ports:
      {{- if $flags.web }}
      - port: {{ .Values.php.httpd.port }}
        protocol: TCP
      {{- end }}
      {{- if $flags.mercurius }}
      - port: {{ .Values.mercurius.monitor_port }}
        protocol: TCP
      {{- end }}
      {{- if .Values.monitoring.enabled }}
      {{- if $flags.web }}
      {{/* httpd exporter */}}
      - port: 9117
        protocol: TCP
      {{/* php-fpm exporter */}}
      - port: 9118
        protocol: TCP
      {{/* php other stats */}}
      - port: 9181
        protocol: TCP
      {{- end -}}
      {{- if .Values.cache.mcrouter.enabled }}
      - port: 9151
        protocol: TCP
      {{- end }}
      {{- end }}
      {{- include "mesh.networkpolicy.ingress" . | indent 6}}
{{- if .Values.networkpolicy.egress.enabled }}
  egress:
    {{- include "base.networkpolicy.egress-basic" .Values }}
    {{- include "mw.networkpolicy.egress" . | indent 4 }}
    {{/* add egress rules for envoy upstream clusters. */}}
    {{- include "mesh.networkpolicy.egress" . | indent 4 }}
    {{- include "base.networkpolicy.egress.kafka" . | indent 4 }}
{{- end }}
{{- end }}
{{- end }}

{{/*

Network egress for MediaWiki

*/}}
{{- define "mw.networkpolicy.egress" -}}
{{/* memcached */}}
{{- include "cache.mcrouter.egress" . -}}
{{- with .Values.mw.egress.database_networks }}
{{/* databases. For now we just ask for a CIDR and open ports 3306 and 3311 through 3320 */}}
- to:
  - ipBlock:
      cidr: {{ . }}
  ports:
  {{- $ports := list 3306 3310 3311 3312 3313 3314 3315 3316 3317 3318 3319 3320 -}}
  {{- range $ports }}
  - protocol: TCP
    port: {{.}}
  {{- end }}
{{- end }}
{{- range .Values.mw.egress.etcd_servers }}
- to:
  - ipBlock:
      cidr: {{ .ip }}/32
  ports:
  - protocol: TCP
    port: {{ .port }}
{{- end -}}
{{- range .Values.mw.egress.kubestage_servers }}
- to:
  - ipBlock:
      cidr: {{ .ip }}/32
  ports:
  - protocol: TCP
    port: {{ .port }}
{{- end -}}
{{- end -}}