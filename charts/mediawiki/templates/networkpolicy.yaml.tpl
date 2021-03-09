apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ template "wmf.releasename" . }}
  {{- include "mw.labels" . | indent 2 }}
spec:
  podSelector:
    matchLabels:
      app: {{ template "wmf.chartname" . }}
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
      {{- if .Values.mw.mcrouter.enabled }}
      - port: 9151
        protocol: TCP
      {{- end }}
      {{- if .Values.mw.nutcracker.enabled }}
      - port: 9191
        protocol: TCP
      {{- end }}
      {{- end }}
      {{- include "tls.networkpolicy" . | indent 6}}
{{- if .Values.networkpolicy.egress.enabled }}
  egress:
    {{- include "wmf.networkpolicy.egress" .Values }}
    {{- include "wmf.networkpolicy.egress" (.Files.Get "default-network-policy-conf.yaml" | fromYaml) }}
    {{- include "mediawiki.networkpolicy.egress" .Values.mw | indent 4 }}
    {{/* add egress rules for envoy upstream clusters. */}}
    {{- include "wmf.networkpolicy.egress.discovery" . | indent 4 }}
{{- end }}
