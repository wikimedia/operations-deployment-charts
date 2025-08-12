{{/*
== Templates related to NetworkPolicy resources associated with external (aka not running in Kubernetes) services.

These templates provide the basic networkpolicy functionalities
in particular for egress.

 - base.networkpolicy.egress.exernal-services: defines calico NetworkPolicy resource allowing
   egress to Service resources associated with external services (databases, Kervberos, CAS, etc).

*/}}

{{- define "base.networkpolicy.egress.external-services.selector" }}
{{- if $.Values.external_services_selector }}
{{- $.Values.external_services_selector }}
{{- else }}
{{- $.Values.external_services_app_label_selector | default "app" }} == '{{ template "base.name.chart" $ }}' && release == '{{ $.Release.Name }}'
{{- end }}
{{- end }}

{{- define "base.networkpolicy.egress.external-services.annotations" }}
{{- if $.Values.external_services_annotations }}
annotations:
  {{- $.Values.external_services_annotations | toYaml | nindent 2 }}
{{- end }}
{{- end }}

{{- define "base.networkpolicy.egress.external-services" -}}
{{- if $.Values.external_services }}
{{- range $serviceType, $serviceNames := $.Values.external_services }}
{{- if $serviceNames }}
---
apiVersion: crd.projectcalico.org/v1
kind: NetworkPolicy
metadata:
  name: {{ template "base.meta.name" (dict "Root" $) }}-egress-external-services-{{ $serviceType }}
  {{- include "base.meta.labels" $ | indent 2 }}
  {{- include "base.networkpolicy.egress.external-services.annotations" $ | indent 2 }}
  namespace: {{ $.Release.Namespace }}
spec:
  selector: {{ include "base.networkpolicy.egress.external-services.selector" $ | quote }}
  types:
  - Egress
  egress:
    {{- range $serviceName := $serviceNames }}
    - action: Allow
      destination:
        services:
          name: {{ $serviceType }}-{{ $serviceName }}
          namespace: external-services
    {{- end }}

{{- end }}
{{- end }}
{{- end }}
{{- end }}
