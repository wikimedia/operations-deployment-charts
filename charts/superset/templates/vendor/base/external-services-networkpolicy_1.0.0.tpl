{{/*
== Templates related to NetworkPolicy resources associated with external (aka not running in Kubernetes) services.

These templates provide the basic networkpolicy functionalities
in particular for egress.

 - base.networkpolicy.egress.exernal-services: defines calico NetworkPolicy resource allowing
   egress to Service resources associated with external services (databases, Kervberos, CAS, etc).

*/}}
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
  namespace: {{ $.Release.Namespace }}
spec:
  selector: name == '{{ template "base.meta.name" (dict "Root" $) }}'
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
