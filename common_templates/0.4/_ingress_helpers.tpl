{{/*
Allow to configure Ingress using istio-ingressgateway
https://istio.io/v1.9/docs/concepts/traffic-management/

Creates the following objects:
  - Gateway (https://istio.io/v1.9/docs/reference/config/networking/gateway/)
  - VirtualService (https://istio.io/v1.9/docs/reference/config/networking/virtual-service/)
  - DestinationRule (https://istio.io/v1.9/docs/reference/config/networking/destination-rule/)

In staging clusters, a generic Gateway is to be used instead of a dedicated one.

This requires TLS to be enabled as well (_tls_helpers.tpl).
*/}}

{{/*
Default HTTPRoute destination to be added if none given via .Values
*/}}
{{- define "default_httproute_destination" -}}
- name: "default-destination"
  route:
  - destination:
      host: {{ template "tls.servicefqdn" . }}
      port:
        number: {{ .Values.tls.public_port }}
{{- end -}}

{{/*
List of hosts (FQDN) the Gateway should be configured for
*/}}
{{- define "ingress.gatewayHosts" -}}
{{- if .Values.ingress.gatewayHosts -}}
{{- .Values.ingress.gatewayHosts | toYaml }}
{{- else -}}
- {{ .Release.Namespace }}.discovery.wmnet
{{- end -}}
{{- end -}}

{{/*
List of hosts (FQDN) the VirtualService should be configured for
*/}}
{{- define "ingress.routeHosts" -}}
{{- if eq .Values.ingress.existingGatewayName "" }}
{{- include "ingress.gatewayHosts" . -}}
{{- else -}}
{{- if  empty .Values.ingress.routeHosts }}
{{- fail "ingress.routeHosts is required when ingress.existingGateway is set" }}
{{- else -}}
{{- .Values.ingress.routeHosts | toYaml }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Ingress default setup
*/}}
{{- define "ingress.default" -}}
{{ include "ingress.gateway" . }}
---
{{ include "ingress.virtualservice" . }}
---
{{ include "ingress.destinationrule" . }}
{{- end -}}

{{/*
Create a Istio Gateway object
https://istio.io/v1.9/docs/reference/config/networking/gateway/
*/}}
{{- define "ingress.gateway" -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.existingGatewayName) -}}
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: {{ template "wmf.releasename" . }}
  labels:
    app: {{ template "wmf.chartname" . }}
    chart: {{ template "wmf.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  selector:
    # This is the istio-ingressgateway this gateway will be attached to (provided by SRE)
    istio: ingressgateway
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
    {{- include "ingress.gatewayHosts" . | nindent 4 -}}
{{- end -}}{{/* Values.ingress.enabled */}}
{{- end -}}{{/* define */}}


{{/*
Create a Istio VirtualService object
https://istio.io/v1.9/docs/reference/config/networking/virtual-service/
*/}}
{{- define "ingress.virtualservice" -}}
{{- if .Values.ingress.enabled -}}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: {{ template "wmf.releasename" . }}
  labels:
    app: {{ template "wmf.chartname" . }}
    chart: {{ template "wmf.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  hosts:
  {{- include "ingress.routeHosts" . | nindent 2 }}
  gateways:
  {{- /*
  Attach this VirtualService to a namespace local gateway (created by ingress.gateway)
  or to an already existing Gateway specified via values.
  */}}
  - {{ .Values.ingress.existingGatewayName | default (include "wmf.releasename" .) }}
  http:
  {{- if gt (len .Values.ingress.httproutes) 0 -}}
  {{- range $route := .Values.ingress.httproutes }}
  - {{ $route | toYaml | indent 4 | trim }}
  {{- end }}
  {{- else -}} {{/* if gt (len .Values.ingress.httproutes) 0 */}}
  {{/* Default: Route everything to default destination */ -}}
  {{ include "default_httproute_destination" . | indent 2 | trim }}
  {{- end }}
{{- end -}}{{/* Values.ingress.enabled */}}
{{- end -}}{{/* define */}}


{{/*
Create a Istio DestinationRule object
https://istio.io/v1.9/docs/reference/config/networking/destination-rule/

The purpose if this default object is to enable TLS connections to upstream (backend) services
and configure verification of upstreams CA and SAN. Without the caCertificates and
subjectAltNames configuration, the ingressgateway will skip validation completely!
*/}}
{{- define "ingress.destinationrule" -}}
{{- if .Values.ingress.enabled -}}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: {{ template "wmf.releasename" . }}
  labels:
    app: {{ template "wmf.chartname" . }}
    chart: {{ template "wmf.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  host: {{ template "tls.servicefqdn" . }}
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

      Unfortunately out cergen certificates do not include {{ template "tls.servicefqdn" . }}
      right now. So add gatewayHosts (which will default to {{ .Release.Namespace }}.discovery.wmnet)
      and routeHosts as well in case externalGatewayName is set. One of them should match, so
      this is fine until all tls-proxies have cert-manager certs.

      Including both templates might lead to duplicate entries, need to check if that is fine.
      */}}
      subjectAltNames:
      - {{ template "tls.servicefqdn" . }}
      {{- include "ingress.gatewayHosts" . | nindent 6 }}
      {{- include "ingress.routeHosts" . | nindent 6 }}
{{- end -}}{{/* Values.ingress.enabled */}}
{{- end -}}{{/* define */}}