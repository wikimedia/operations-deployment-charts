{{/*
== General-purpose helpers

This is a generic collection of helpers.

 - base.helper.serviceType: returns what type of service to use if you're using ingress or not.
 - base.helper.resources: returns a resources definition based on .requests and .limits passed to it.
 - base.helper.prestop: returns a preStop hook definition for a simple sleep
 - base.helper.restrictedSecurityContext: returns a securityContext definition compatible with the restricted PSS profile.
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

{{- define "base.helper.restrictedSecurityContext" }}
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
     drop:
     - ALL
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
{{- end -}}


{{/*
  This helper will render the template located at the provided path
  (assumed to contain ConfigMap or Secret resources) and perform a
  sha256sum of the content of their `data`, `stringData` or `binaryData` field.

  This can be used to compute the checksum of secrets and/or configmaps
  that only changes when their actual content changes, but not when
  their metadata (eg labels) changes.
*/}}
{{- define "base.helper.resourcesDataChecksum" }}
{{- $renderedResources :=  include (print .Root.Template.BasePath .resourceFilePath) .Root }}
{{- $dataArray := list }}
{{- range $resourceStr := split "---\n" $renderedResources }}
{{- $resource := fromYaml $resourceStr }}
{{- if get $resource "data"}}
{{- $dataArray = append $dataArray (get $resource "data") }}
{{- else if get $resource "stringData"}}
{{- $dataArray = append $dataArray (get $resource "stringData") }}
{{- else if get $resource "binaryData"}}
{{- $dataArray = append $dataArray (b64enc (get $resource)) }}
{{- end }}
{{- end }}
{{- toString $dataArray | sha256sum }}
{{- end }}
