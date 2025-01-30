{{- $can_run := include "mw.can_run" . | include "mw.str2bool" }}
{{- $flags := fromJson ( include "mw.feature_flags" . ) }}
{{- if $can_run }}
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
    {{- include "mediawiki.networkpolicy.egress" . | indent 4 }}
    {{/* add egress rules for envoy upstream clusters. */}}
    {{- include "mesh.networkpolicy.egress" . | indent 4 }}
    {{- include "base.networkpolicy.egress.kafka" . | indent 4 }}
{{- end }}
{{- end }}
