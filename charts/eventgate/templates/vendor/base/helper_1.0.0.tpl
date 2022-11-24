{{/*
== General-purpose helpers

This is a generic collection of helpers.

 - base.helper.serviceType: returns what type of service to use if you're using ingress or not.
 - base.helper.resources: returns a resources definition based on .requests and .limits passed to it.
*/}}

{{/* Return Service.spec.type that should be used for services.
If Ingress is enabled, this returns ClusterIP unless ingress.keepNodePort is true. If keepNodePort is true or Ingress is disabled, this should return NodePort.
*/}}
{{- define "base.helper.serviceType" -}}
{{/* Fail safe lookups to not break compatibility if ingress is not at all defined */}}
{{- with .Values.ingress | default (dict "enabled" false) -}}
{{- if and (.enabled | default false) (not (.keepNodePort | default false)) -}}
ClusterIP
{{- else -}}
NodePort
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "base.helper.resources" }}
resources:
  requests:
{{ toYaml .requests | indent 4 }}
  limits:
{{ toYaml .limits | indent 4 }}
{{- end -}}