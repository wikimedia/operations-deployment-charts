{{/* TLS termination related helpers */}}


{{/*

 Deployment templates

*/}}

{{- define "tls.annotations" -}}
{{- if .Values.tls.enabled }}
checksum/tls: {{ printf "%s|%s|%s" .Values.tls.public_port .Values.main_app.port .Values.tls.certs.cert | sha256sum }}
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
  image: {{ .Values.docker.registry }}/envoy:{{ .Values.tls.image_version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
    - name: SERVICE_NAME
      value: {{ .Release.Name }}
    - name: SERVICE_ZONE
      value: "default"
  ports:
    - containerPort: {{ .Values.tls.public_port }}
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
    name: {{ template "wmf.releasename" . }}}-envoy-config-volume
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
kind: Service
apiVersion: v1
metadata:
  name: {{ template "wmf.releasename" . }}-tls-service
  labels:
    app: {{ template "wmf.chartname" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  type: NodePort
  selector:
    app: {{ template "wmf.chartname" . }}
    release: {{ .Release.Name }}
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
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "wmf-releasename" . }}-envoy-config-volume
  labels:
    app: {{ template "wmf.chartname" . }}
    chart: {{ template "wmf.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
  data:
    envoy.yaml: |-
{{ template "tls.envoy_template" . }}
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
      # Idle timeout is the time a keepalive connection will stay idle before being
      # closed. It's important to keep it similar to the backend idle timeout.
      idle_timeout: {{ .Values.tls.idle_timeout | default 5s }}
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
  listeners:
  - address:
      socket_address:
        address: {{ if .Values.tls.telemetry.enabled }}0.0.0.0{{ else }}127.0.0.1{{ end }}
        port_value: {{ .Values.tls.telemetry.port | default 1667 }}
    filter_chains:
    - filters:
      - name: envoy.http_connection_manager
        typed_config:
          '@type': type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager
          http_filters:
          - name: envoy.router
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
          - name: envoy.router
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
                  timeout: {{ .Values.tls.upstream_timeout }}
          stat_prefix: ingress_https_{{ .Release.Name }}
          server_name: {{ .Release.Name }}-tls
          server_header_transformation: APPEND_IF_ABSENT
      tls_context:
        common_tls_context:
          tls_certificates:
          - certificate_chain: {filename: /etc/envoy/ssl/service.crt}
            private_key: {filename: /etc/envoy/ssl/service.key}
    listener_filters:
    - name: envoy.listener.tls_inspector
      typed_config: {}
{{- end -}}