{{/*
== Configuration for the service mesh sidecar.

 - mesh.configuration.configmap: returns the configmaps for the TLS/mesh service
 - mesh.configuration.full: returns the full service mesh configuration

*/}}

{{- define "mesh.configuration.configmap" }}
{{- if .Values.mesh.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  {{- include "base.meta.metadata" (dict "Root" . "Name" "envoy-config-volume") | indent 2 }}
data:
  {{- include "mesh.configuration.full" . | nindent 2 }}
{{ end -}}{{/* end mesh enabled */}}
{{- end -}}

{{/*

mesh.configuration.full should output all config parts required by envoy as it's
output is also used to compute the checksum/tls-config (e.g. restat the pod on
config changes).

*/}}
{{- define "mesh.configuration.full" -}}
envoy.yaml: |-
  {{- include "mesh.configuration.envoy" . | nindent 2 }}
{{- if .Values.mesh.public_port }}
tls_certificate_sds_secret.yaml: |-
  {{- include "mesh.configuration.tls_certificate_sds_secret" . | nindent 2 }}
{{- end }}
{{- if .Values.mesh.error_page }}
error_page.html: |-
  {{- .Values.mesh.error_page | nindent 2 }}
{{ end -}}
{{- end -}}

{{- define "mesh.configuration.envoy_admin_address" -}}
{{ $admin := (.Values.mesh.admin | default dict) }}
{{- if $admin.bind_tcp | default false }}
socket_address:
  address: 127.0.0.1
  port_value: {{ $admin.port | default 1666 }}
{{- else }}
pipe:
  path: /var/run/envoy/admin.sock
{{- end }}
{{- end -}}

{{- define "mesh.configuration.envoy" -}}
admin:
  access_log:
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
      # Don't write this to stdout/stderr to not send all the requests for metrics from prometheus to logstash.
      path: /var/log/envoy/admin-access.log
  address:
    {{- include "mesh.configuration.envoy_admin_address" . | indent 4 }}
  # Don't apply global connection limits to the admin listener so we can still get metrics when overloaded
  ignore_global_conn_limit: true
layered_runtime:
  layers:
    # If inserting a static layer, add it *before* the empty admin_layer, so
    # we can continue to make changes via the admin console and they'll
    # overwrite values from the previous layer.
    - name: admin_layer_0
      admin_layer: {}
{{- if hasKey .Values.mesh "envoy_stats_config" | default dict -}}
{{- if .Values.mesh.envoy_stats_config }}
stats_config:
  {{- toYaml .Values.mesh.envoy_stats_config | nindent 2}}
{{- end }}
{{- else }}
stats_config:
  # Tweak histogram buckets
  # https://phabricator.wikimedia.org/T391333
  histogram_bucket_settings:
    - match:
        safe_regex:
          regex: ".+rq_time$"
      buckets: [
        1,
        5,
        10,
        25,
        50,
        100,
        250,
        500,
        1000,
        2500
      ]
    - match:
        safe_regex:
          regex: ".+upstream_cx_connect_ms$"
      buckets: [
        1,
        5,
        10,
        25,
        50,
        100,
        250,
        500,
        1000
      ]
    - match:
        safe_regex:
          regex: ".+(upstream|downstream)_cx_length_ms$"
      buckets: [
        2500,
        5000,
        10000,
        30000,
        60000,
        300000
      ]
    # remove 0.5, 1 and > 60000 default buckets
    - match:
        safe_regex:
          regex: ".+"
      buckets: [
        5,
        10,
        25,
        50,
        100,
        250,
        500,
        1000,
        2500,
        5000,
        10000,
        30000,
        60000
      ]
{{- end }}
overload_manager:
  resource_monitors:
    # Limit the total number of allowed active connections per envoy instance.
    # Envoy's configuration best practice "Configuring Envoy as an edge proxy" uses 50k connections
    # which is still essentially unlimited in our use case.
    - name: envoy.resource_monitors.global_downstream_max_connections
      typed_config:
        '@type': type.googleapis.com/envoy.extensions.resource_monitors.downstream_connections.v3.DownstreamConnectionsConfig
        max_active_downstream_connections: 50000
static_resources:
  clusters:
  {{- if .Values.mesh.public_port -}}
  {{- include "mesh.configuration._local_cluster" . | indent 2 }}
  {{- end -}}
  {{- if (.Values.mesh.tracing | default dict).enabled }}
  {{- include "mesh.configuration._tracing_cluster" . | indent 2}}
  {{- end -}}
  {{- include "mesh.configuration._admin_cluster" . | indent 2 }}
  {{- /* $ratelimit.enabled will be set to true below if any listener has rate limits configured */ -}}
  {{- $ratelimit := dict "enabled" false -}}
  {{- if .Values.discovery | default false -}}
    {{- range $name := .Values.discovery.listeners }}
      {{- $listener := (index $.Values.services_proxy $name) }}
      {{- if not $listener }}
        {{- fail (printf "Listener %s not found in the proxies" $name) }}
      {{- end }}
      {{- $values := dict "Name" $name "Upstream" $listener.upstream -}}
      {{- include "mesh.configuration._cluster" $values | indent 2 }}
      {{- if $listener.split -}}
        {{ $split_name := printf "%s-split" $name }}
        {{- $values := dict "Name" $split_name "Upstream" $listener.split -}}
        {{- include "mesh.configuration._cluster" $values | indent 2 }}
      {{- end }}
      {{- /* Figure out if a rate limit is configured for this listener */ -}}
      {{- if or (hasKey $listener "ratelimit") (hasKey ($.Values.discovery.ratelimit_listeners | default dict) $name) -}}
        {{- $ratelimit := set $ratelimit "enabled" true -}}
      {{- end }}
    {{- end }}
    {{- if $ratelimit.enabled }}
      {{- include "mesh.configuration._ratelimit_cluster" . | indent 2 }}
    {{- end }}
  {{- end }}
  {{- if .Values.tcp_proxy| default false -}}
    {{- range $name := .Values.tcp_proxy.listeners }}
      {{- $values := dict "Name" $name "Listener" (index $.Values.tcp_services_proxy $name) }}
      {{- include "mesh.configuration._tcp_cluster" $values | indent 2 }}
    {{- end }}
  {{- end }}
  listeners:
  {{- $af_aware_dot := . -}}
  {{- $af_aware_dot = set $af_aware_dot "listen_address" "::" }}
  {{- include "mesh.configuration._admin_listener" $af_aware_dot | indent 2}}
  {{- $af_aware_dot = set $af_aware_dot "listen_address" "0.0.0.0" }}
  {{- include "mesh.configuration._admin_listener" $af_aware_dot | indent 2}}
  {{- if .Values.mesh.public_port -}}
  {{- $af_aware_dot = set $af_aware_dot "listen_address" "::" }}
  {{- include "mesh.configuration._local_listener" $af_aware_dot | indent 2}}
  {{- $af_aware_dot = set $af_aware_dot "listen_address" "0.0.0.0" }}
  {{- include "mesh.configuration._local_listener" $af_aware_dot | indent 2}}
  {{- end -}}
  {{- if .Values.discovery | default false -}}
    {{- range $name := .Values.discovery.listeners }}
      {{- /* Fetch the listener configuration from global services_proxy structure */ -}}
      {{- $listener := index $.Values.services_proxy $name -}}
      {{- /* If a rate limit is configured "client side", override the global rate limit settings with those */ -}}
      {{- if hasKey ($.Values.discovery.ratelimit_listeners | default dict) $name -}}
        {{- $merged := deepCopy ($listener.ratelimit | default dict) | merge (get $.Values.discovery.ratelimit_listeners $name) -}}
        {{- $listener := set $listener "ratelimit" $merged -}}
      {{- end -}}
      {{- $values := dict "Name" $name "Listener" $listener "Root" $ -}}
      {{- $values = set $values "listen_address" "::" }}
      {{- include "mesh.configuration._listener" $values | indent 2 }}
      {{- $values = set $values "listen_address" "0.0.0.0" }}
      {{- include "mesh.configuration._listener" $values | indent 2 }}
    {{- end -}}
  {{- end -}}
  {{- if .Values.tcp_proxy| default false -}}
    {{- range $name := .Values.tcp_proxy.listeners }}
      {{- $values := dict "Name" $name "Listener" (index $.Values.tcp_services_proxy $name) "Root" $ }}
      {{- $values = set $values "listen_address" "::" }}
      {{- include "mesh.configuration._tcp_listener" $values | indent 2 }}
      {{- $values = set $values "listen_address" "0.0.0.0" }}
      {{- include "mesh.configuration._tcp_listener" $values | indent 2 }}
    {{- end -}}
  {{- end -}}
{{- end -}}




{{/* Private functions */}}
{{/* TLS termination for the local service */}}
{{- define "mesh.configuration._local_cluster_name" -}}
LOCAL_{{ (.Values.mesh.tracing | default dict).service_name | default .Release.Namespace }}
{{- end -}}
{{- define "mesh.configuration._local_cluster" }}
- name: {{ template "mesh.configuration._local_cluster_name" . }}
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
    cluster_name: {{ template "mesh.configuration._local_cluster_name" . }}
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            socket_address: {address: 127.0.0.1, port_value: {{ .Values.mesh.upstream_local_port | default .Values.app.port }} }
  type: strict_dns
{{- end }}
{{/* Tracing cluster */}}
{{- define "mesh.configuration._tracing_cluster" }}
- name: otel_collector
  type: strict_dns
  lb_policy: round_robin
  typed_extension_protocol_options:
    envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
      "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
      explicit_http_config:
        http2_protocol_options: {}
  load_assignment:
    cluster_name: otel_collector
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            socket_address:
              address: {{ .Values.mesh.tracing.host | default "main-opentelemetry-collector.opentelemetry-collector.svc.cluster.local" }}
              port_value: {{ .Values.mesh.tracing.port | default "4317" }}
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
    socket_address:
      address: "{{ .listen_address | default "0.0.0.0" }}"
      port_value: {{ .Values.mesh.public_port }}
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
        {{- if (.Values.mesh.faultinjection | default dict).enabled }}
        {{- /* Fault needs to be before any other filter */}}
        - name: envoy.filters.http.fault
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.fault.v3.HTTPFault
            max_active_faults: 100
            abort:
              http_status: {{ .Values.mesh.faultinjection.http_status | default 503 }}
              percentage:
                numerator: {{ .Values.mesh.faultinjection.pct | default 0 }}
                denominator: HUNDRED
        {{- end }}
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
              {{- if $hdr.append | default false }}
              append_action: APPEND_IF_EXISTS_OR_ADD
              {{- else }}
              append_action: OVERWRITE_IF_EXISTS_OR_ADD
              {{- end }}
          {{- end }}
          {{- end }}
          virtual_hosts:
          - domains: ['*']
            name: tls_termination
            routes:
            - match: {prefix: /}
              route:
                cluster: {{ template "mesh.configuration._local_cluster_name" . }}
                timeout: {{ .Values.mesh.upstream_timeout | default "60s" }}
                {{- if .Values.mesh.idle_upstream_timeout | default false }}
                idle_timeout: {{ .Values.mesh.idle_upstream_timeout }}
                {{- end }}
                {{- if .Values.mesh.upstream_retry_policy }}
                retry_policy:
                {{- range $k, $v :=  .Values.mesh.upstream_retry_policy }}
                  {{ $k }}: {{ $v }}
                {{- end }}
                {{- end }}
        {{- include "mesh.configuration._error_page" . | indent 8 }}
        {{- if (.Values.mesh.tracing | default dict).enabled }}
        request_id_extension:
          typed_config:
              "@type": type.googleapis.com/envoy.extensions.request_id.uuid.v3.UuidRequestIdConfig
              pack_trace_reason: false
        tracing:
          {{- if (.Values.mesh.tracing | default dict).sampling }}
          random_sampling:
            value: {{ .Values.mesh.tracing.sampling }}
          {{- end }}
          provider:
            name: envoy.tracers.opentelemetry
            typed_config:
              "@type": type.googleapis.com/envoy.config.trace.v3.OpenTelemetryConfig
              grpc_service:
                envoy_grpc:
                  cluster_name: otel_collector
                timeout: 0.250s
              service_name: {{ .Values.mesh.tracing.service_name | default .Release.Namespace }}
        {{- end }}
        stat_prefix: ingress_https_{{ .Release.Name }}
        server_name: {{ .Release.Name }}-tls
        server_header_transformation: APPEND_IF_ABSENT
        internal_address_config:
          unix_sockets: true
          cidr_ranges:
          - address_prefix: 10.0.0.0
            prefix_len: 8
          - address_prefix: 127.0.0.1
            prefix_len: 32
          - address_prefix: "::1"
            prefix_len: 128
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
        common_tls_context:
          {{- /*
          Configure envoy to read certificates from static SDS config.
          This will enable an inotify watcher and hot-reloading on certificate changes.
          */}}
          tls_certificate_sds_secret_configs:
            name: tls_sds
            sds_config:
              path_config_source:
                path: /etc/envoy/tls_certificate_sds_secret.yaml
              resource_api_version: V3
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
      tracing_enabled: false # default is true
      retry_policy:
        num_retries: 1
        retry_on: 5xx
      upstream:
        address: svcA.discovery.wmnet
        port: 10100  # this is the port on the remote system
        encryption: false
        ips:
        - 1.2.3.4
      # If you have a split section, traffic will be split between the main address and this one
      # based on the percentage indicated.
      split:
        address: svcB.discovery.wmnet
        port: 10200
        encryption: true
        percentage: 10
        keepalive: "6s"
        sets_sni: true
        sni_rewrites_host_header: true
        ips:
          - 1.2.3.3


For TCP load balancer, we define the TCP service, and then we add upstreams as a list under 'tcp_services_proxy'.
There is also the option to set custom health checks, otherwise all upstreams
will be considered always up.
More info: https://www.envoyproxy.io/docs/envoy/v1.23.12/api-v3/config/core/v3/health_check.proto#envoy-v3-api-msg-config-core-v3-healthcheck
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
       health_checks:                # optional, if not set all upstreams will be always considered up
       - timeout: 5s
         interval: 5s
         unhealthy_threshold: 3
         initial_jitter: 1s
         healthy_threshold: 5
         tcp_health_check: {}
         always_log_health_check_failures: true
         event_log_path: "/dev/stdout"
*/}}
{{- define "mesh.configuration._listener" }}
- address:
    socket_address:
      protocol: TCP
      address: "{{ .listen_address | default "0.0.0.0" }}"
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
        {{- if and (.Root.Values.mesh.tracing | default dict).enabled (.Listener.tracing_enabled | default true) }}
        tracing:
          {{- if (.Root.Values.mesh.tracing | default dict).sampling }}
          random_sampling:
            value: {{ .Root.Values.mesh.tracing.sampling }}
          {{- end }}
          provider:
            name: envoy.tracers.opentelemetry
            typed_config:
              "@type": type.googleapis.com/envoy.config.trace.v3.OpenTelemetryConfig
              grpc_service:
                envoy_grpc:
                  cluster_name: otel_collector
                timeout: 0.250s
        {{- end }}
        stat_prefix: {{ .Name }}_egress
        http_filters:
        {{- if hasKey .Listener "ratelimit" }}
        # The ratelimit filter checks with the ratelimit service to perform global rate limiting.
        # https://www.envoyproxy.io/docs/envoy/v1.23.3/api-v3/extensions/filters/http/ratelimit/v3/rate_limit.proto#envoy-v3-api-msg-extensions-filters-http-ratelimit-v3-ratelimit
        - name: envoy.filters.http.ratelimit
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimit
            # The domain must match a configured domain in the ratelimit service.
            domain: {{ .Listener.ratelimit.domain | default .Name }}
            # By default, the Rate Limit filter in Envoy translates a 429 HTTP response code to UNAVAILABLE as
            # specified in the gRPC mapping document. Translate to RESOURCE_EXHAUSTED instead to provide more
            # context to the client.
            rate_limited_as_resource_exhausted: true
            # The timeout for the rate limit service RPC, defaults to 20ms
            timeout: {{ (.Root.Values.mesh.ratelimit).timeout | default "0.02s" }}
            # Indicate whether a failure in the ratelimit service should result in requests being denied.
            failure_mode_deny: false
            # Enable X-RateLimit headers in the response.
            # https://www.envoyproxy.io/docs/envoy/v1.23.3/api-v3/extensions/filters/http/ratelimit/v3/rate_limit.proto#envoy-v3-api-enum-extensions-filters-http-ratelimit-v3-ratelimit-xratelimitheadersrfcversion
            # Format ratelimit headers using the IETF draft format:
            # https://datatracker.ietf.org/doc/id/draft-polli-ratelimit-headers-03.html
            enable_x_ratelimit_headers: DRAFT_VERSION_03
            # Specify where to find the ratelimit service (a cluster defined in this config).
            rate_limit_service:
              transport_api_version: V3
              grpc_service:
                envoy_grpc:
                  cluster_name: ratelimit
        {{- end }}
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
            {{- if hasKey .Listener "ratelimit" }}
            {{- /* Rate limit by user agent by default */ -}}
            {{- if eq (.Listener.ratelimit.by | default "user-agent") "user-agent" }}
            # Perform rate-limit related actions on the request.
            rate_limits:
            - actions:
              # Read a request header and use its value to set the value of a descriptor entry.
              # https://www.envoyproxy.io/docs/envoy/v1.23.3/api-v3/config/route/v3/route_components.proto#envoy-v3-api-msg-config-route-v3-ratelimit-action-requestheaders
              - request_headers:
                  header_name: user-agent
                  descriptor_key: user-agent
            {{- else }}
            {{- fail "Only user-agent ratelimiting is supported" }}
            {{- end }}
            {{- end }}
            routes:
            {{- if .Listener.split }}
            - match:
                prefix: "/"
                runtime_fraction:
                  default_value:
                    numerator: {{ .Listener.split.percentage }}
                    denominator: HUNDRED
                  runtime_key: routing.traffic_shift.{{ .Name }}
              route:
                {{- if .Listener.http_host }}
                host_rewrite_literal: {{ .Listener.http_host }}
                {{- end }}
                {{- /* can't use a simple | default true here cause false, a Boolean, is considered empty */ -}}
                {{- if and .Listener.split.sets_sni (not .Listener.http_host) (or (kindIs "invalid" .Listener.split.sni_rewrites_host_header) .Listener.split.sni_rewrites_host_header) }}
                auto_host_rewrite: true
                {{- end }}
                cluster: {{ .Name }}-split
                timeout: {{ .Listener.timeout }}
                {{- if .Listener.retry_policy }}
                retry_policy:
                {{- range $k, $v :=  .Listener.retry_policy }}
                  {{ $k }}: {{ $v }}
                {{- end -}}
                {{- end }}
            {{- end }}
            - match:
                prefix: "/"
              route:
                {{- if .Listener.http_host }}
                host_rewrite_literal: {{ .Listener.http_host }}
                {{- end }}
                {{- /* can't use a simple | default true here cause false, a Boolean, is considered empty */ -}}
                {{- if and .Listener.upstream.sets_sni (not .Listener.http_host) (or (kindIs "invalid" .Listener.upstream.sni_rewrites_host_header) .Listener.upstream.sni_rewrites_host_header) }}
                auto_host_rewrite: true
                {{- end }}
                cluster: {{ .Name }}
                timeout: {{ .Listener.timeout }}
                {{- /* puppet-defined idle timeout
                 note that route-level idle timeouts are stream idle timeouts in envoy terminology and
                 behave differently to other idle timeout settings - see 039059f18b2 in puppet and
                 the envoy docs
                */}}
                {{- if .Listener.upstream.idle_timeout }}
                idle_timeout: {{ .Listener.upstream.idle_timeout }}
                {{- end }}
                {{- if .Listener.retry_policy }}
                retry_policy:
                {{- range $k, $v :=  .Listener.retry_policy }}
                  {{ $k }}: {{ $v }}
                {{- end -}}
                {{- end }}
        internal_address_config:
          unix_sockets: true
          cidr_ranges:
          - address_prefix: 10.0.0.0
            prefix_len: 8
          - address_prefix: 127.0.0.1
            prefix_len: 32
          - address_prefix: "::1"
            prefix_len: 128
{{- end }}

{{- define "mesh.configuration._cluster" }}
- name: {{ .Name }}
  connect_timeout: 0.25s
  {{- if .Upstream.keepalive }}
  typed_extension_protocol_options:
    envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
      "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
      common_http_protocol_options:
        idle_timeout: {{ .Upstream.keepalive }}
        # Given we go through a load-balancer, we want to keep the number of requests that go through a single connection pool small
        max_requests_per_connection: 1000
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
              address: {{ .Upstream.address }}
              port_value: {{ .Upstream.port }}
  {{- /* Use puppet-defined tcp keepalives for connections to upstreams */}}
  {{- if .Upstream.tcp_keepalive }}
  upstream_connection_options:
    tcp_keepalive:
    {{- range $k, $v := .Upstream.tcp_keepalive }}
      {{ $k }}: {{ $v }}
    {{- end }}
  {{- end }}
  {{- if .Upstream.encryption }}
  {{- include "mesh.configuration._transport_socket_tls" (dict "Upstream" .Upstream) | indent 2 }}
  {{- end }}
{{- end }}

{{/* TCP proxy cluster and listener */}}
{{- define "mesh.configuration._tcp_listener" }}
- address:
    socket_address:
      address: "{{ .listen_address | default "0.0.0.0" }}"
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
{{- with .Listener.health_checks }}
  health_checks:
  {{- range . }}
    - timeout: {{ .timeout }}
      interval: {{ .interval }}
      unhealthy_threshold: {{ .unhealthy_threshold }}
      {{- with .initial_jitter }}
      initial_jitter: {{ . }}
      {{- end }}
      healthy_threshold: {{ .healthy_threshold }}
      tcp_health_check: {}
      {{- with .always_log_health_check_failures }}
      always_log_health_check_failures: {{ . }}
      {{- end }}
      {{- with .event_log_path }}
      event_logger:
      - name: envoy.health_check.event_sinks.file
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.health_check.event_sinks.file.v3.HealthCheckEventFileSink
          event_log_path: {{ . }}
      {{- end }}
  {{- end }}
{{- end }}
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

{{/* Admin listener. Only allows access to /stats and a static /healthz url */}}
{{- define "mesh.configuration._admin_listener" }}
- address:
    socket_address:
      address: "{{ .listen_address | default "0.0.0.0" }}"
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
        internal_address_config:
          unix_sockets: true
          cidr_ranges:
          - address_prefix: 10.0.0.0
            prefix_len: 8
          - address_prefix: 127.0.0.1
            prefix_len: 32
          - address_prefix: "::1"
            prefix_len: 128
  # Don't apply global connection limits to the admin listener so we can still get metrics when overloaded
  ignore_global_conn_limit: true
{{- end }}

{{- define "mesh.configuration._admin_cluster" }}
- name: admin_interface
  type: static
  connect_timeout: 1.0s
  lb_policy: round_robin
  load_assignment:
    cluster_name: admin_interface
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            {{- include "mesh.configuration.envoy_admin_address" . | indent 12 }}
{{- end }}

{{/*
  Rate limit cluster.

  This cluster is used to contact the ratelimit service. It is used by the
  rate_limit http filter to check if a request should be allowed or not.
  Uses gRPC with TLS.
*/}}
{{- define "mesh.configuration._ratelimit_cluster" }}
- name: ratelimit
  type: STRICT_DNS
  connect_timeout: 0.25s
  lb_policy: ROUND_ROBIN
  protocol_selection: USE_CONFIGURED_PROTOCOL
  http2_protocol_options: {}
  load_assignment:
    cluster_name: ratelimit
    endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: {{ (.Values.mesh.ratelimit).host | default "ratelimit-main.ratelimit.svc.cluster.local." }}
                port_value: {{ (.Values.mesh.ratelimit).port | default "8081" }}
  {{- include "mesh.configuration._transport_socket_tls" dict | indent 2 }}
{{- end }}

{{/* Error page handling */}}
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

{{/*

Create a SDS config for TLS secrets to have the certificate and key files
watched with inotify and reloaded automatically without restart.

*/}}
{{- define "mesh.configuration.tls_certificate_sds_secret" -}}
resources:
- "@type": "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret"
  name: tls_sds
  tls_certificate:
    certificate_chain:
      filename: /etc/envoy/ssl/tls.crt
    private_key:
      filename: /etc/envoy/ssl/tls.key
{{- end -}}

{{/* transport socket configuration for upstream TLS connections */}}
{{- define "mesh.configuration._transport_socket_tls" }}
transport_socket:
  name: envoy.transport_sockets.tls
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
    {{- if (get (.Upstream) "sets_sni") }}
    sni: {{ .Upstream.address }}
    {{- end }}
    common_tls_context:
      tls_params:
        cipher_suites: ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
      validation_context:
        trusted_ca:
          filename: /etc/ssl/certs/ca-certificates.crt
{{- end -}}
