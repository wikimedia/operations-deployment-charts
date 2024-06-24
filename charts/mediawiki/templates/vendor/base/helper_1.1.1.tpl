{{/*
== General-purpose helpers

This is a generic collection of helpers.

 - base.helper.serviceType: returns what type of service to use if you're using ingress or not.
 - base.helper.resources: returns a resources definition based on .requests and .limits passed to it.
 - base.helper.prestop: returns a preStop hook definition for a simple sleep
*/}}

{{/* Return Service.spec.type that should be used for services.
If Ingress is enabled, this returns ClusterIP unless ingress.keepNodePort is true. If keepNodePort is true or Ingress is disabled, this should return NodePort.
*/}}
{{- define "base.helper.serviceType" -}}
{{/* Fail safe lookups to not break compatibility if ingress is not at all defined */}}
{{- $ingress := .Values.ingress | default (dict "enabled" false) -}}
{{- if and ($ingress.enabled | default false) (not ($ingress.keepNodePort | default false)) -}}
ClusterIP
{{- else if not (dig "nodePort" true .Values.service) -}}
{{- /* Duplicate but easier to read:
Use ClusterIP if service.nodePort is false
Also use "dig" instead of "default" above as `(false | default true) == true` */ -}}
ClusterIP
{{- else -}}
NodePort
{{- end -}}
{{- end -}}

{{- define "base.helper.resources" }}
resources:
  requests:
{{ toYaml .requests | indent 4 }}
  limits:
{{ toYaml .limits | indent 4 }}
{{- end -}}

{{- define "base.helper.prestop" }}
{{- if . -}}
lifecycle:
  preStop:
    exec:
      command:
      - "/bin/sh"
      - "-c"
      - "sleep {{ . | default 0 }}"
{{- end -}}
{{- end -}}
