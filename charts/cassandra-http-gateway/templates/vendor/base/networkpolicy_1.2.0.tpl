{{/*
== NetworkPolicy-related templates

These templates provide the basic networkpolicy functionalities
in particular for egress.

 - base.networkpolicy.egress-basic - provides basic networkpolicy support
 - base.networkpolicy.egress.mariadb - provides access to specifically defined WMF MariaDB sections
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
{{- end }}{{/* end range $port := $cidr.ports */}}
{{- end }}{{/* end if $cidr.ports */}}
{{- end }}{{/* end range $cidr := .networkpolicy.egress.dst_nets */}}
{{- if .networkpolicy.egress.extraRules }}
{{- toYaml .networkpolicy.egress.extraRules | nindent 4}}
{{- end }}{{/* end if .networkpolicy.egress.extraRules */}}
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

{{/* Auto-generate egress networkpolicies for zookeeper */}}
{{- define "base.networkpolicy.egress.zookeeper" -}}
{{- $clusters := .Values.zookeeper_clusters -}}
{{- if .Values.zookeeper }}{{ if .Values.zookeeper.allowed_clusters }}
{{- range $c := .Values.zookeeper.allowed_clusters }}
{{- $cidrs := index $clusters $c }}
# Nodes in the zookeeper cluster {{ $c }}
{{- range $cidrs }}
- to:
  - ipBlock:
      cidr: {{ . }}
  ports:
  - protocol: TCP
    port: 2181
{{- end }} {{/* end range cidrs */}}
{{- end }} {{/* end range allowed_clusters */}}
{{- end }}{{ end }} {{/* end if's */}}
{{- end -}}

{{/* Auto-generate egress networkpolicies for MariaDB sections */}}
{{- define "base.networkpolicy.egress.mariadb" -}}
{{/* MariaDB egress. Ask for MariaDB section names. We hardcode eqiad/codfw CIDRs they are kinda ossified */}}
{{- if and .Values.mariadb .Values.mariadb.egress }}
{{- $section_ports := .Values.mariadb.section_ports }}
{{- $ports := list 3306 }}
{{- range .Values.mariadb.egress.sections }}
  {{- if not (hasKey $section_ports .) }}
    {{- fail (print "Inexistent section specified: " .) }}
  {{- end }}
  {{- $port := get $section_ports . }}
  {{- $ports = append $ports $port }}
{{- end }}
{{- $ports = compact $ports }}
- to:
  - ipBlock:
      cidr: 10.64.0.0/12
  - ipBlock:
      cidr: 10.192.0.0/12
  ports:
  {{- range $ports }}
  - protocol: TCP
    port: {{.}}
  {{- end }}
{{- end }}
{{- end }}
