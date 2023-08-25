{{/*
== NetworkPolicy-related templates

These templates provide the basic networkpolicy functionalities
in particular for egress.

 - base.networkpolicy.egress-basic provides basic networkpolicy support
*/}}

{{- define "base.networkpolicy.egress-basic" -}}
{{- if .networkpolicy.egress.dst_ports }}
{{- range $ports := .networkpolicy.egress.dst_ports }}
    - ports:
      - protocol: {{ $ports.protocol | upper }}
        port: {{ $ports.port }}
{{- end }}
{{- end }}
{{- range $cidr := .networkpolicy.egress.dst_nets }}
    - to:
      - ipBlock:
          cidr: {{ $cidr.cidr }}
{{- if $cidr.ports }}
      ports:
{{- range $port := $cidr.ports }}
      - protocol: {{ $port.protocol | upper }}
        port: {{ $port.port }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/* Auto-generate egress networkpolicies for kafka brokers */}}
{{- define "base.networkpolicy.egress.kafka" -}}
{{- $clusters := .Values.kafka_brokers -}}
{{- if .Values.kafka }}{{ if .Values.kafka.allowed_clusters }}
{{- range $c := .Values.kafka.allowed_clusters }}
{{- $cidrs := index $clusters $c }}
# Brokers in the kafka cluster {{ $c }}
{{- range $cidrs }}
- to:
  - ipBlock:
      cidr: {{ . }}
  ports:
  - protocol: TCP
    port: 9092
  - protocol: TCP
    port: 9093
{{- end }} {{/* end range cidrs */}}
{{- end }} {{/* end range allowed_clusters */}}
{{- end }}{{ end }} {{/* end if's */}}
{{- end -}}