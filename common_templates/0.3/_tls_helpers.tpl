{{/* TLS termination related helpers */}}


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
  name: {{ template "wmf.releasename" . }}-tls-service
  labels:
    app: {{ template "wmf.chartname" . }}
    chart: {{ template "wmf.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  type: NodePort
  selector:
    app: {{ template "wmf.chartname" . }}
    routed_via: {{ .Release.Name }}
  ports:
    - name: {{ template "wmf.releasename" . }}-https
      protocol: TCP
      port: {{ .Values.tls.public_port }}
      nodePort: {{ .Values.tls.public_port }}
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

  To instantiate remote clusters, you need to define two
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
*/}}
{{- if .Values.discovery | default false -}}
{{- range $name := .Values.discovery.listeners }}
{{- $listener := index $.Values.services_proxy $name }}
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
        "@type": type.googleapis.com/envoy.api.v2.auth.UpstreamTlsContext
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
  listeners:
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: {{ .Values.tls.telemetry.port | default 1667 }}
    filter_chains:
    - filters:
      - name: envoy.http_connection_manager
        typed_config:
          '@type': type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager
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
  - address:
      socket_address: {address: 0.0.0.0, port_value: {{ .Values.tls.public_port }} }
    filter_chains:
    - filters:
      - name: envoy.http_connection_manager
        typed_config:
          '@type': type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager
          http_filters:
          - name: envoy.filters.http.router
            typed_config: {}
          http_protocol_options: {accept_http_10: true}
          route_config:
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
          '@type': type.googleapis.com/envoy.api.v2.auth.DownstreamTlsContext
          common_tls_context:
            tls_certificates:
              - certificate_chain: {filename: /etc/envoy/ssl/service.crt}
                private_key: {filename: /etc/envoy/ssl/service.key}
    listener_filters:
    - name: envoy.filters.listener.tls_inspector
      typed_config: {}
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
      - name:  envoy.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager
          access_log:
          - name: envoy.file_access_log
            filter:
              status_code_filter:
                comparison:
                  op: "GE"
                  value:
                    default_value: 500
                    runtime_key: {{ $name }}_min_log_code
            typed_config:
              "@type": type.googleapis.com/envoy.config.accesslog.v2.FileAccessLog
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
{{- end -}}
