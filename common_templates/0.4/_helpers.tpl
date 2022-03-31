{{/*
== Standard boilerplate safe names for kubernetes

The DNS spec in k8s limits names to 63 chars,
so we do the same for names here.

 - wmf.chartname
   The chart name safely truncated to 63 chars.
   We allow overriding this via .Values.chartName.

 - wmf.releasename
   The chart + release name truncated to 63 chars.

 - wmf.chartid
   chart name + chart version.

 - wmf.appbaseurl
   URL for the main_app port.  Uses wmf.releasename as the hostname.

The reason to limit ourselves to


NOTE: The main_app name is not used in any of these templates.
Because we isolate our applications within k8s namespaces,
these template variables should be unique within any given namespace.

*/}}

{{- define "wmf.chartname" -}}
{{- default .Chart.Name .Values.chartName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "wmf.releasename" -}}
{{- $name := default .Chart.Name .Values.chartName -}}
{{- printf "%s-%s" $name .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "wmf.chartid" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "wmf.appbaseurl" -}}
http://{{ template "wmf.releasename" . }}:{{ .Values.main_app.port }}
{{- end -}}

{{/*

 Egress NetworkPolicy template

*/}}
{{- define "wmf.networkpolicy.egress" -}}
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
{{- end }}

{{/* Auto-define egress networkpolicies for all authorized listeners from envoy */}}
{{- define "wmf.networkpolicy.egress.discovery" }}
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

{{/* Auto-generate egress networkpolicies for kafka brokers */}}
{{- define "wmf.networkpolicy.egress.kafka" -}}
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

{{/* Create kubernetes master/api environment variables to replace the standard ones to allow for successfull verification of TLS certs.
Values are provided via puppet profile::kubernetes::deployment_server::general */}}
{{- define "wmf.kubernetes.ApiEnv" -}}
- name: KUBERNETES_PORT_443_TCP_ADDR
  value: "{{ .Values.kubernetesApi.host }}"
- name: KUBERNETES_SERVICE_HOST
  value: "{{ .Values.kubernetesApi.host }}"
- name: KUBERNETES_SERVICE_PORT
  value: "{{ .Values.kubernetesApi.port }}"
- name: KUBERNETES_SERVICE_PORT_HTTPS
  value: "{{ .Values.kubernetesApi.port }}"
- name: KUBERNETES_PORT
  value: "tcp://{{ .Values.kubernetesApi.host }}:{{ .Values.kubernetesApi.port }}"
- name: KUBERNETES_PORT_443_TCP
  value: "tcp://{{ .Values.kubernetesApi.host }}:{{ .Values.kubernetesApi.port }}"
- name: KUBERNETES_PORT_443_TCP_PORT
  value: "{{ .Values.kubernetesApi.port }}"
{{- end -}}

{{/* Return Service.spec.type that should be used for services.
If Ingress is enabled, this returns ClusterIP unless ingress.keepNodePort is true. If keepNodePort is true or Ingress is disabled, this should return NodePort.
*/}}
{{- define "wmf.serviceType" -}}
{{/* Fail safe lookups to not break compatibility if ingress is not at all defined */}}
{{- with .Values.ingress | default (dict "enabled" false) -}}
{{- if and (.enabled | default false) (not (.keepNodePort | default false)) -}}
ClusterIP
{{- else -}}
NodePort
{{- end -}}
{{- end -}}
{{- end -}}
