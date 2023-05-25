{{/*
== Configuration for the service mesh sidecar.

 - mesh.configuration.configmap: returns the configmaps for the TLS/mesh service
 - mesh.configuration.full: returns the full service mesh configuration

*/}}

{{- define "mesh.configuration.configmap" }}
{{- if .Values.mesh.enabled }}
{{/* Only render the certs configmap if public_port is configured. */}}
{{- if .Values.mesh.public_port }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  {{- include "base.meta.metadata" (dict "Root" . "Name" "tls-proxy-certs") | indent 2 }}
data:
  service.crt: |-
{{ .Values.mesh.certs.cert | indent 4 }}
  service.key: |-
{{ .Values.mesh.certs.key | indent 4 }}
{{ end -}}
---
apiVersion: v1
kind: ConfigMap
metadata:
  {{- include "base.meta.metadata" (dict "Root" . "Name" "envoy-config-volume") | indent 2 }}
data:
  envoy.yaml: |-
    {{- include "mesh.configuration.full" . | nindent 4 }}
{{- if .Values.mesh.error_page }}
  error_page.html: |-
    {{- .Values.mesh.error_page | nindent 4 }}
{{ end -}}
{{ end -}}{{/* end mesh enabled */}}
{{- end -}}

{{- define "mesh.configuration.full" -}}
admin:
  access_log:
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
      # Don't write this to stdout/stderr to not send all the requests for metrics from prometheus to logstash.
      path: /var/log/envoy/admin-access.log
  address:
    socket_address: {address: 127.0.0.1, port_value: {{ .Values.mesh.admin.port | default 1666 }}}
static_resources:
  clusters:
  {{- if .Values.mesh.public_port -}}
  {{- include "mesh.configuration._local_cluster" . | indent 2 }}
  {{- end -}}
  {{- include "mesh.configuration._admin_cluster" . | indent 2 }}
  {{- if .Values.discovery | default false -}}
    {{- range $name := .Values.discovery.listeners }}
      {{- $values := dict "Name" $name "Listener" (index $.Values.services_proxy $name) -}}
      {{- include "mesh.configuration._cluster" $values | indent 2 }}
    {{- end }}
  {{- end }}
  {{- if .Values.tcp_proxy| default false -}}
    {{- range $name := .Values.tcp_proxy.listeners }}
    {{- $values := dict "Name" $name "Listener" (index $.Values.tcp_services_proxy $name) }}
      {{- include "mesh.configuration._tcp_cluster" $values | indent 2 }}
    {{- end }}
  {{- end }}
  listeners:
  {{- include "mesh.configuration._admin_listener" . | indent 2}}
  {{- if .Values.mesh.public_port -}}
  {{- include "mesh.configuration._local_listener" . | indent 2}}
  {{- end -}}
  {{- if .Values.discovery | default false -}}
    {{- range $name := .Values.discovery.listeners }}
      {{- $values := dict "Name" $name "Listener" (index $.Values.services_proxy $name) -}}
      {{- include "mesh.configuration._listener" $values | indent 2 }}
    {{- end -}}
  {{- end -}}
  {{- if .Values.tcp_proxy| default false -}}
    {{- range $name := .Values.tcp_proxy.listeners }}
      {{- $values := dict "Name" $name "Listener" (index $.Values.tcp_services_proxy $name) }}
      {{- include "mesh.configuration._tcp_listener" $values | indent 2 }}
    {{- end -}}
  {{- end -}}
{{- end -}}




{{/* Private functions */}}
{{/* TLS termination for the local service */}}
{{- define "mesh.configuration._local_cluster" }}
- name: local_service
  typed_extension_protocol_options:
    envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
      "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
      common_http_protocol_options:
        idle_timeout: {{ .Values.mesh.idle_timeout | default "4.5s" }}
      # This allows switching on protocol based on what protocol the downstream connection used.
      use_downstream_protocol_config: {}
  connect_timeout: 1.0s
  lb_policy: round_robin
  load_assignment:
    cluster_name: local_service
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            socket_address: {address: 127.0.0.1, port_value: {{ .Values.app.port }} }
  type: strict_dns
{{- end }}
{{- /*
  TLS termination for the downstream service.

  It listens on mesh.public_port, and forwards traffic to app.port on localhost.
  If an application needs to add headers (maybe to inject the connecting IP address)
  it can declare tls.request_headers_to_add, an array of maps with "header" / "value" / "append"

  If mesh.public_port is not defined, no _local_listener will be deployed.
*/}}
{{- define "mesh.configuration._local_listener" }}
- address:
    socket_address: {address: 0.0.0.0, port_value: {{ .Values.mesh.public_port }} }
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
                  default_value: {{ .Values.mesh.local_access_log_min_code | default 500 }}
                  runtime_key: tls_terminator_min_log_code
          # TODO: use a stream logger once we upgrade from 1.15
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
            path: "/dev/stdout"
        http_filters:
        - name: envoy.filters.http.router
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
        http_protocol_options: {accept_http_10: true}
        route_config:
          {{- if .Values.mesh.request_headers_to_add | default false }}
          request_headers_to_add:
          {{- range $hdr := .Values.mesh.request_headers_to_add }}
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
                timeout: {{ .Values.mesh.upstream_timeout | default "60s" }}
        {{- include "mesh.configuration._error_page" . | indent 8 }}
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
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.listener.tls_inspector.v3.TlsInspector
{{- end }}

{{/* Mesh network configuration. */}}
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
{{- define "mesh.configuration._listener" }}
{{- if not .Listener }}
{{-  fail (printf "Listener %s not found in the proxies" .Name) }}
{{-  end }}
- address:
    socket_address:
      protocol: TCP
      address: 0.0.0.0
      port_value: {{ .Listener.port }}
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
                  runtime_key: {{ .Name }}_min_log_code
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
            path: "/dev/stdout"
        stat_prefix: {{ .Name }}_egress
        http_filters:
        - name: envoy.filters.http.router
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
        route_config:
        {{- if .Listener.xfp }}
          request_headers_to_remove:
          - x-forwarded-proto
          request_headers_to_add:
          - header:
              key: "x-forwarded-proto"
              value: "{{ .Listener.xfp }}"
        {{- end }}
          name: {{ .Name }}_route
          virtual_hosts:
          - name: {{ .Name }}
            domains: ["*"]
            routes:
            - match:
                prefix: "/"
              route:
                {{- if .Listener.http_host }}
                host_rewrite_literal: {{ .Listener.http_host }}
                {{- end }}
                {{- if and .Listener.uses_ingress (not .Listener.http_host) }}
                auto_host_rewrite: true
                {{- end }}
                cluster: {{ .Name }}
                timeout: {{ .Listener.timeout }}
                {{- if .Listener.retry_policy }}
                retry_policy:
                {{- range $k, $v :=  .Listener.retry_policy }}
                  {{ $k }}: {{ $v }}
                {{- end -}}
                {{- end }}
{{- end }}


{{- define "mesh.configuration._cluster" }}
{{- if not .Listener }}
{{-  fail (printf "Listener %s not found in the proxies" .Name) }}
{{-  end }}
- name: {{ .Name }}
  connect_timeout: 0.25s
  {{- if .Listener.keepalive }}
  typed_extension_protocol_options:
    envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
      "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
      common_http_protocol_options:
        idle_timeout: {{ .Listener.keepalive }}
      # This allows switching on protocol based on what protocol the downstream connection used.
      use_downstream_protocol_config: {}
  {{- end }}
  type: STRICT_DNS
  dns_lookup_family: V4_ONLY
  lb_policy: ROUND_ROBIN
  load_assignment:
    cluster_name: cluster_{{ .Name }}
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            socket_address:
              address: {{ .Listener.upstream.address }}
              port_value: {{ .Listener.upstream.port }}
{{- /*
Given we go through a load-balancer, we want to keep the number of requests that go through a single connection pool small
*/}}
  max_requests_per_connection: 1000
  {{- if .Listener.upstream.encryption }}
  transport_socket:
    name: envoy.transport_sockets.tls
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
      {{- if .Listener.uses_ingress }}
      sni: {{ .Listener.upstream.address }}
      {{- end }}
      common_tls_context:
        tls_params:
          tls_minimum_protocol_version: TLSv1_2
          cipher_suites: ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
        validation_context:
          trusted_ca:
            filename: /etc/ssl/certs/wmf-ca-certificates.crt
  {{- end -}}
{{- end }}

{{/* TCP proxy cluster and listener */}}
{{- define "mesh.configuration._tcp_listener" }}
- address:
    socket_address:
      address: 0.0.0.0
      port_value: {{ .Listener.port }}
  filter_chains:
  - filters:
    - name: envoy.filters.network.tcp_proxy
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
        stat_prefix: destination
        cluster: {{.Name}}
{{- end }}

{{- define "mesh.configuration._tcp_cluster" }}
- name: {{ .Name }}
  connect_timeout: {{ .Listener.connect_timeout | default "30s" }}
  type: STRICT_DNS
  dns_lookup_family: V4_ONLY
  load_assignment:
    cluster_name: {{ .Name }}
    endpoints:
    - lb_endpoints:
    {{- range $upstream := .Listener.upstreams }}
      - endpoint:
          address:
            socket_address:
              address: {{ $upstream.address }}
              port_value:  {{ $upstream.port }}
    {{- end }}
{{- end }}

{{/* Admin interface */}}

  {{- /*
    Admin listener. Only allows access to /stats and a static /healthz url
  */}}
{{- define "mesh.configuration._admin_listener" }}
- address:
    socket_address:
      address: 0.0.0.0
      port_value: {{ .Values.mesh.telemetry.port | default 1667 }}
  filter_chains:
  - filters:
    - name: envoy.filters.network.http_connection_manager
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
        http_filters:
        - name: envoy.filters.http.router
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
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
{{- end }}

{{- define "mesh.configuration._admin_cluster" }}
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
{{- end }}


{{/*

Error page handling

*/}}
{{- define "mesh.configuration._error_page" }}
{{- if .Values.mesh.error_page }}
local_reply_config:
  mappers:
  - filter:
      # We only intercept pages with
      # status code 502 or higher.
      status_code_filter:
        comparison:
          op: "GE"
          value:
            default_value: 502
            runtime_key: errorpage_min_code

    body_format_override:
      text_format_source:
        filename: "/etc/envoy/error_page.html"
      content_type: "text/html; charset=UTF-8"
{{- end }}
{{- end }}
