{{- $can_run_maintenance := include "mw.maintenance.can_run" . | include "mw.str2bool" }}
{{- if and (not $can_run_maintenance) (not .Values.mw.httpd.enabled) (not .Values.mercurius.enabled) }}
{{/*
  Maintenance scripts are disabled, we're not serving traffic, and we're not running mercurius.
*/}}
{{- else }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ template "base.name.release" . }}
  {{- include "mw.labels" . | indent 2 }}
spec:
  podSelector:
    matchLabels:
      app: {{ template "base.name.chart" . }}
      release: {{ .Release.Name }}
  policyTypes:
  {{- if .Values.networkpolicy.egress.enabled }}
    - Egress
  {{- end }}
    - Ingress
  ingress:
    - ports:
      - port: {{ .Values.php.httpd.port }}
        protocol: TCP
      {{- if .Values.mercurius.enabled }}
      - port: {{ .Values.mercurius.monitor_port }}
        protocol: TCP
      {{- end }}
      {{- if .Values.monitoring.enabled }}
      {{/* httpd exporter */}}
      - port: 9117
        protocol: TCP
      {{/* php-fpm exporter */}}
      - port: 9118
        protocol: TCP
      {{/* php other stats */}}
      - port: 9181
        protocol: TCP
      {{- if .Values.cache.mcrouter.enabled }}
      - port: 9151
        protocol: TCP
      {{- end }}
      {{- end }}
      {{- include "mesh.networkpolicy.ingress" . | indent 6}}
{{- if .Values.networkpolicy.egress.enabled }}
  egress:
    {{- include "base.networkpolicy.egress-basic" .Values }}
    {{- include "mediawiki.networkpolicy.egress" . | indent 4 }}
    {{/* add egress rules for envoy upstream clusters. */}}
    {{- include "mesh.networkpolicy.egress" . | indent 4 }}
    {{- include "base.networkpolicy.egress.kafka" . | indent 4 }}
{{- end }}
{{- end }}
