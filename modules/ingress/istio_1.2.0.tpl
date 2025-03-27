{{/*
Allow to configure Ingress using istio-ingressgateway
https://istio.io/v1.15/docs/concepts/traffic-management/

Creates the following objects:
  - Gateway (https://istio.io/v1.15/docs/reference/config/networking/gateway/)
  - VirtualService (https://istio.io/v1.15/docs/reference/config/networking/virtual-service/)
  - DestinationRule (https://istio.io/v1.15/docs/reference/config/networking/destination-rule/)

In staging clusters, a generic Gateway is to be used instead of a dedicated one.

This requires TLS to be enabled as well (_tls_helpers.tpl).
*/}}

{{/*
Default HTTPRoute destination to be added if none given via .Values
*/}}
{{- define "ingress.istio._default_httproute_destination" -}}
- name: "default-destination"
  route:
  - destination:
      host: {{ template "mesh.name.fqdn" . }}
      port:
        number: {{ .Values.mesh.public_port }}
{{- end -}}

{{/*
List of hosts (FQDN) the Gateway should be configured for.
By default, this will be a list like:
- {{ gatewayHosts.default }}.discovery.wmnet
- {{ gatewayHosts.default }}.svc.codfw.wmnet
- {{ gatewayHosts.default }}.svc.eqiad.wmnet

If disableDefaultHosts is true, the above is skipped and only the list of
extraFQDNs is returned (if not empty).
*/}}
{{- define "ingress.istio.gatewayHosts" -}}
{{- if not .Values.ingress.gatewayHosts.disableDefaultHosts -}}
{{- $host := .Values.ingress.gatewayHosts.default | default .Release.Namespace -}}
{{- $fallback_domains := list "discovery.wmnet" "svc.codfw.wmnet" "svc.eqiad.wmnet" -}}
{{- $certmanager_domains := (.Values.mesh.certmanager | default dict).domains -}}
{{- $domains := .Values.ingress.gatewayHosts.domains | default $certmanager_domains | default $fallback_domains -}}
{{- range $domains -}}
- {{ $host }}.{{ . }}
{{ end -}} {{/* end range */}}
{{- end -}}
{{ if .Values.ingress.gatewayHosts.extraFQDNs -}}
{{ .Values.ingress.gatewayHosts.extraFQDNs | toYaml }}
{{- end -}}
{{- end -}}

{{/*
List of hosts (FQDN) the VirtualService should be configured for
*/}}
{{- define "ingress.istio.routeHosts" -}}
{{- if eq .Values.ingress.existingGatewayName "" }}
{{- include "ingress.istio.gatewayHosts" . -}}
{{- else -}}
{{- if  empty .Values.ingress.routeHosts }}
{{- fail "ingress.istio.routeHosts is required when ingress.existingGateway is set" }}
{{- else -}}
{{- .Values.ingress.routeHosts | toYaml }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Ingress default setup
*/}}
{{- define "ingress.istio.default" -}}
{{ include "ingress.istio.gateway" . }}
---
{{ include "ingress.istio.virtualservice" . }}
---
{{ include "ingress.istio.destinationrule" . }}
{{- end -}}

{{/*
Create a Istio Gateway object
https://istio.io/v1.15/docs/reference/config/networking/gateway/
*/}}
{{- define "ingress.istio.gateway" -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.existingGatewayName) -}}
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
{{- include "base.meta.metadata" (dict "Root" . ) | indent 2 }}
spec:
  selector:
    {{- if hasKey .Values.ingress "selectors" }}
    {{- .Values.ingress.selectors | toYaml | nindent 4 }}
    {{- else }}
    # This is the istio-ingressgateway this gateway will be attached to (provided by SRE)
    istio: ingressgateway
    {{- end }}
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      # credentialName is a secret that needs to be created in istio-system namespace.
      # This is done in a generic fashion by helmfile.d/admin_ng/helmfile_namespace_certs.yaml
      credentialName: {{ .Release.Namespace }}-tls-certificate
      mode: SIMPLE
    hosts:
    # TLS hosts can only be registered once. Another gateway using the same host will be ignored.
    {{- include "ingress.istio.gatewayHosts" . | nindent 4 -}}
{{- end -}}{{/* Values.ingress.enabled */}}
{{- end -}}{{/* define */}}


{{/*
Create a Istio VirtualService object
https://istio.io/v1.15/docs/reference/config/networking/virtual-service/
*/}}
{{- define "ingress.istio.virtualservice" -}}
{{- if .Values.ingress.enabled -}}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
{{- include "base.meta.metadata" (dict "Root" . ) | indent 2 }}
spec:
  hosts:
  {{- include "ingress.istio.routeHosts" . | nindent 2 }}
  gateways:
  {{- /*
  Attach this VirtualService to a namespace local gateway (created by ingress.gateway)
  or to an already existing Gateway specified via values.
  */}}
  - {{ .Values.ingress.existingGatewayName | default (include "base.name.release" .) }}
  http:
  {{- if gt (len .Values.ingress.httproutes) 0 -}}
  {{- range $route := .Values.ingress.httproutes }}
  - {{ $route | toYaml | indent 4 | trim }}
  {{- end }}
  {{- else -}} {{/* if gt (len .Values.ingress.httproutes) 0 */}}
  {{/* Default: Route everything to default destination */ -}}
  {{ include "ingress.istio._default_httproute_destination" . | indent 2 | trim }}
  {{- end }}
  {{- if .Values.ingress.custom_cors_policy }}
    corsPolicy: {{ .Values.ingress.custom_cors_policy | toYaml | nindent 6 }}
  {{- else if .Values.ingress.base_cors_policy }}
    corsPolicy:
      allowCredentials: false
      allowHeaders:
      - Api-User-Agent
      allowMethods:
      - POST
      - GET
      allowOrigins:
      - exact: '*'
  {{- end }}
{{- end -}}{{/* Values.ingress.enabled */}}
{{- end -}}{{/* define */}}


{{/*
Create a Istio DestinationRule object
https://istio.io/v1.15/docs/reference/config/networking/destination-rule/

The purpose if this default object is to enable TLS connections to upstream (backend) services
and configure verification of upstreams CA and SAN. Without the caCertificates and
subjectAltNames configuration, the ingressgateway will skip validation completely!
*/}}
{{- define "ingress.istio.destinationrule" -}}
{{- if .Values.ingress.enabled -}}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
{{- include "base.meta.metadata" (dict "Root" . ) | indent 2 }}
spec:
  host: {{ template "mesh.name.fqdn" . }}
  trafficPolicy:
    tls:
      mode: SIMPLE
      {{- /*
      Path to the file containing CA certificates used to verify upstream certs.
      This is expected to exist in the itsio/proxyv2 image.
      */}}
      caCertificates: /etc/ssl/certs/wmf-ca-certificates.crt
      {{- /*
      The ingressgateway will verify that the upstreams certificate SAN matches one of(!)
      the subjectAltNames provided here.
      */}}
      subjectAltNames:
      # Default tls-service certificates
      - {{ template "mesh.name.fqdn" . }}
{{- end -}}{{/* Values.ingress.enabled */}}
{{- end -}}{{/* define */}}
