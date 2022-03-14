{{/*
TLS termination related helpers.

== Label conventions

We try to stick with label names recommended by Helm best practices:

  - app
    The chart name being used.

  - chart
    The specific chart version

  - release
    The release within the current namespace, usually 'production' or 'canary'

  - heritage
    Always 'helm', used to indicated with k8s that the resource is managed by Helm.

== Resource naming conventions

k8s resources are prefixed with the wmf.releasename template,
defined in _helpers.tpl. wmf.releasename is the chartname + the
current release name, so usually somethign like 'chartname-production'.
E.g. the Envoy TLS k8s Service resource is called
'chartname-production-tls-service'.

== Canary releases and Service routing

The Services defined here support 'canary' releases.  This is used
to be able to deploy changes to a limited number of pods that are routed
real traffic, without having to deploy changes to the entire pod cluster.

When a release has the -canary suffix, this template will not create a Service for the canary release. The Service resources that are created for the production
release uses a `routed_via` selector set to .Release.Name (which will always
be 'production', because we don't create any Service for 'canary' release).

The _scaffold/templates/deployment.yaml template sets the `routed_via` label
on pods to .Values.routed_via, defaulting to .Release.Name.

To enable canary releases, you just need to override .Values.routed_via
in your helmfile service's values-canary.yaml file and set it to 'production'.
This will cause the canary release's pods, as well as the production release's pods,
to all have the label `routed_via: production`.  Since the 'production' release's
Service targets all pods that have this label, it will route to both production release and canary release pods.

*/}}

{{/*

  Generic helpers

*/}}
{{- define "tls.servicename" -}}
{{ template "wmf.releasename" . }}-tls-service
{{- end -}}

{{- define "tls.servicefqdn" -}}
{{ template "tls.servicename" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}

{{/*

 Deployment templates

*/}}
{{- define "tls.annotations" -}}
{{- if .Values.tls.enabled }}
checksum/tls-config: {{ include "tls.envoy_template" . | sha256sum }}
checksum/tls-certs: {{ printf "%v" (values .Values.tls.certs | sortAlpha) | sha256sum }}
{{- if .Values.tls.telemetry.enabled }}
envoyproxy.io/scrape: "true"
envoyproxy.io/port: "{{ .Values.tls.telemetry.port }}"
{{- else }}
envoyproxy.io/scrape: "false"
{{- end }}
{{- end }}
{{- end -}}

{{- define "tls.container" -}}
{{- if .Values.tls.enabled }}
- name: {{ template "wmf.releasename" . }}-tls-proxy
  image: {{ .Values.docker.registry }}/envoy:{{ .Values.tls.image_version | default "latest" }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
    - name: SERVICE_NAME
      value: {{ .Release.Name }}
    - name: SERVICE_ZONE
      value: "default"
  ports:
    - containerPort: {{ .Values.tls.public_port }}
  readinessProbe:
    httpGet:
      path: /healthz
      port: {{ .Values.tls.telemetry.port | default 1667 }}
  volumeMounts:
    - name: envoy-config-volume
      mountPath: /etc/envoy/
      readOnly: true
    - name: tls-certs-volume
      mountPath: /etc/envoy/ssl
      readOnly: true
  resources:
{{- if .Values.tls.resources }}
{{ toYaml .Values.tls.resources | indent 4 }}
{{- else }}
    requests:
      cpu: 200m
      memory: 100Mi
    limits:
      cpu: 500m
      memory: 500Mi
{{- end }}
{{- end }}
{{- end -}}

{{- define "tls.volume" }}
{{- if .Values.tls.enabled }}
- name: envoy-config-volume
  configMap:
    name: {{ template "wmf.releasename" . }}-envoy-config-volume
- name: tls-certs-volume
  configMap:
    name: {{ template "wmf.releasename" . }}-tls-proxy-certs
{{- end }}
{{- end -}}

{{/*

 Service templates

*/}}
{{- define "tls.service" -}}
{{ if .Values.tls.enabled }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ template "tls.servicename" . }}
  labels:
    app: {{ template "wmf.chartname" . }}
    chart: {{ template "wmf.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  type: {{ template "wmf.serviceType" . }}
  selector:
    app: {{ template "wmf.chartname" . }}
    routed_via: {{ .Release.Name }}
  ports:
    - name: {{ template "wmf.releasename" . }}-https
      protocol: TCP
      port: {{ .Values.tls.public_port }}
      {{- if eq (include "wmf.serviceType" .) "NodePort" }}
      nodePort: {{ .Values.tls.public_port }}
      {{- end }}
{{- end }}
{{- end -}}


{{/*

 ConfigMap templates

*/}}

{{- define "tls.config" -}}
{{- if .Values.tls.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-tls-proxy-certs
  labels:
    app: {{ template "wmf.chartname" . }}
    chart: {{ template "wmf.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
data:
  service.crt: |-
{{ .Values.tls.certs.cert | indent 4 }}
  service.key: |-
{{ .Values.tls.certs.key | indent 4 }}
{{- if .Values.puppet_ca_crt }}
  ca.crt: |-
{{ .Values.puppet_ca_crt | indent 4 }}
{{- end }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf.releasename" . }}-envoy-config-volume
  labels:
    app: {{ template "wmf.chartname" . }}
    chart: {{ template "wmf.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
data:
  envoy.yaml: |-
    {{- include "tls.envoy_template" . | nindent 4 }}
{{ end -}}
{{- end -}}

{{/*

 NetworkPolicy templates

*/}}
{{- define "tls.networkpolicy" -}}
{{- if .Values.tls.enabled }}
- port: {{ .Values.tls.public_port }}
  protocol: TCP
{{- if .Values.tls.telemetry.enabled }}
- port: {{ .Values.tls.telemetry.port }}
  protocol: TCP
{{- end }}
{{- end }}
{{- end -}}




{{/*

  Envoy configuration

*/}}

{{- define "tls.envoy_template" -}}
admin:
  access_log_path: /var/log/envoy/admin-access.log
  address:
    socket_address: {address: 127.0.0.1, port_value: 1666}
static_resources:
  clusters:
  - name: local_service
    common_http_protocol_options:
      idle_timeout: {{ .Values.tls.idle_timeout | default "4.5s" }}
    connect_timeout: 1.0s
    lb_policy: round_robin
    load_assignment:
      cluster_name: local_service
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address: {address: 127.0.0.1, port_value: {{ .Values.main_app.port }} }
    type: strict_dns
  - name: admin_interface
    connect_timeout: 1.0s
    lb_policy: round_robin
    load_assignment:
      cluster_name: admin_interface
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address: {address: 127.0.0.1, port_value: 1666 }
    type: strict_dns
{{- /*
  Remote clusters.

  To instantiate remote http clusters, you need to define two
  data structures:
  - A list of remote service configurations (that can be shared between charts)
  - A list of which services you intend to reach from your service (which will be specific)

  discovery:
    listeners:
      - svcA
  services_proxy:
    svcA:
      keepalive: "5s"
      port: 6060  # this is the local port
      http_host: foobar.example.org  # this is the Host: header that will be added to your request
      timeout: "60s"
      retry_policy:
        num_retries: 1
        retry_on: 5xx
      upstream:
        address: svcA.discovery.wmnet
        port: 10100  # this is the prot on the remote system
        encryption: false

Note: The tcp_services_proxy is using API v3
For TCP load balancer, we define the TCP service, and then we add upstreams as a list
under 'tcp_services_proxy'.
  tcp_proxy:
    listeners:
      - tcpServiceA
  tcp_services_proxy:
     tcpServiceA:
       connect_timeout: "30s"
       max_connect_attempts: 5
       port: 6060                    # this is the local port
       upstreams:
         - address: 1.2.3.4
           port: 10100               # this is the port on the remote system
         - address: 4.5.6.7
           port: 10100
*/}}
{{- if .Values.discovery | default false -}}
{{- range $name := .Values.discovery.listeners }}
{{- $listener := index $.Values.services_proxy $name }}
{{- if not $listener }}
{{-  fail (printf "Listener %s not found in the proxies" $name) }}
{{-  end }}
  - name: {{ $name }}
    connect_timeout: 0.25s
    {{- if $listener.keepalive }}
    common_http_protocol_options:
      idle_timeout: {{ $listener.keepalive }}
    {{- end }}
    type: STRICT_DNS
    dns_lookup_family: V4_ONLY
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: cluster_{{ $name }}
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: {{ $listener.upstream.address }}
                port_value: {{ $listener.upstream.port }}
{{- /*
  Given we go through a load-balancer, we want to keep the number of requests that go through a single connection pool small
*/}}
    max_requests_per_connection: 1000
    {{- if $listener.upstream.encryption }}
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
        common_tls_context:
          tls_params:
            tls_minimum_protocol_version: TLSv1_2
            cipher_suites: ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
          validation_context:
            trusted_ca:
              filename: /etc/envoy/ssl/ca.crt
    {{- end -}}
{{- end }}
{{- end }}
{{- /*

TCP proxies

*/}}
{{- if .Values.tcp_proxy| default false -}}
{{- range $name := .Values.tcp_proxy.listeners }}
{{- $listener := index $.Values.tcp_services_proxy $name }}
  - name: {{ $name }}
    connect_timeout: {{ $listener.connect_timeout | default "30s" }}
    type: STRICT_DNS
    dns_lookup_family: V4_ONLY
    load_assignment:
      cluster_name: {{ $name }}
      endpoints:
      - lb_endpoints:
      {{- range $upstream := $listener.upstreams }}
        - endpoint:
            address:
              socket_address:
                address: {{ $upstream.address }}
                port_value:  {{ $upstream.port }}
      {{- end }}
{{- end }}
{{- end }}
  listeners:
  {{- /*
    Admin listener. Only allows access to /stats and a static /healthz url
  */}}
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: {{ .Values.tls.telemetry.port | default 1667 }}
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          http_filters:
          - name: envoy.filters.http.router
            typed_config: {}
          http_protocol_options: {accept_http_10: true}
          route_config:
            virtual_hosts:
            - domains: ['*']
              name: admin_interface
              routes:
              - match: {prefix: /stats }
                route:
                  cluster: admin_interface
                  timeout: 5.0s
              - match: {prefix: /healthz}
                direct_response:
                  status: 200
                  body: {inline_string: "OK"}
              - match: {prefix: /}
                direct_response:
                  status: 403
                  body: {inline_string: "You can't access this url."}
          stat_prefix: admin_interface
  {{- /*
    TLS termination for the downstream service.

    It listens on tls.public_port, and forwards traffic to main_app.port on localhost.
    If an application needs to add headers (maybe to inject the connecting IP address)
    it can declare tls.request_headers_to_add, an array of maps with "header" / "value" / "append"
  */}}
  - address:
      socket_address: {address: 0.0.0.0, port_value: {{ .Values.tls.public_port }} }
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          access_log:
          - filter:
              status_code_filter:
                comparison:
                  op: "GE"
                  value:
                    default_value: 500
                    runtime_key: tls_terminator_min_log_code
            # TODO: use a stream logger once we upgrade from 1.15
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
              path: "/dev/stdout"
          http_filters:
          - name: envoy.filters.http.router
            typed_config: {}
          http_protocol_options: {accept_http_10: true}
          route_config:
            {{- if .Values.tls.request_headers_to_add | default false }}
            request_headers_to_add:
            {{- range $hdr := .Values.tls.request_headers_to_add }}
              - header:
                  key: {{ $hdr.header }}
                  value: "{{ $hdr.value }}"
                append: {{ $hdr.append | default false }}
            {{- end }}
            {{- end }}
            virtual_hosts:
            - domains: ['*']
              name: tls_termination
              routes:
              - match: {prefix: /}
                route:
                  cluster: local_service
                  timeout: {{ .Values.tls.upstream_timeout | default "60s" }}
          stat_prefix: ingress_https_{{ .Release.Name }}
          server_name: {{ .Release.Name }}-tls
          server_header_transformation: APPEND_IF_ABSENT
      transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
          common_tls_context:
            tls_certificates:
              - certificate_chain: {filename: /etc/envoy/ssl/service.crt}
                private_key: {filename: /etc/envoy/ssl/service.key}
    listener_filters:
    - name: envoy.filters.listener.tls_inspector
      typed_config: {}
  {{- /*
    Discovery listeners
  */}}
  {{- if .Values.discovery | default false -}}
  {{- range $name := .Values.discovery.listeners }}
  {{- $listener := index $.Values.services_proxy $name }}
  - address:
      socket_address:
        protocol: TCP
        address: 0.0.0.0
        port_value: {{ $listener.port }}
    filter_chains:
    - filters:
      - name:  envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          access_log:
          - filter:
              status_code_filter:
                comparison:
                  op: "GE"
                  value:
                    default_value: 500
                    runtime_key: {{ $name }}_min_log_code
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
              path: "/dev/stdout"
          stat_prefix: {{ $name }}_egress
          http_filters:
          - name: envoy.filters.http.router
            typed_config: {}
          route_config:
          {{- if $listener.xfp }}
            request_headers_to_remove:
            - x-forwarded-proto
            request_headers_to_add:
            - header:
               key: "x-forwarded-proto"
               value: "{{ $listener.xfp }}"
          {{- end }}
            name: {{ $name }}_route
            virtual_hosts:
            - name: {{ $name }}
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  {{- if $listener.http_host }}
                  host_rewrite: {{ $listener.http_host }}
                  {{- end }}
                  cluster: {{ $name }}
                  timeout: {{ $listener.timeout }}
                  {{- if $listener.retry_policy }}
                  retry_policy:
                  {{- range $k, $v :=  $listener.retry_policy }}
                    {{ $k }}: {{ $v }}
                  {{- end -}}
                  {{- end }}
  {{- end -}}
  {{- end -}}
  {{- if .Values.tcp_proxy| default false -}}
  {{- range $name := .Values.tcp_proxy.listeners }}
  {{- $listener := index $.Values.tcp_services_proxy $name }}
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: {{ $listener.port }}
    filter_chains:
    - filters:
      - name: envoy.filters.network.tcp_proxy
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
          stat_prefix: destination
          cluster: {{$name}}
  {{- end -}}
  {{- end -}}
{{- end -}}
