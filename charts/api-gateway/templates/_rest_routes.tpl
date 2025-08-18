{{- define "restgateway.routes" }}
            name: restgateway_route
            virtual_hosts:
            - name: restgateway_vhost
              domains:
{{- range $domain := .Values.main_app.domains }}
              - "{{ $domain }}"
{{- end }}
              routes:
              - name: rest_gateway_root
                match:
                  path: "/"
                direct_response:
                  status: 200
                  body: {inline_string: "This is the REST Gateway."}
{{- /* BEGIN rest_gateway_routes definition */}}
{{- range $endpoint := .Values.main_app.rest_gateway_routes }}
{{- range $route := $endpoint.urls }}
{{- $cluster_name := ternary $endpoint.name $endpoint.cluster (not $endpoint.cluster) }}
              - name: {{ $endpoint.name }}_{{ $route.name }}
                match:
                  safe_regex:
                    google_re2: {}
                    regex: '^{{ $route.in }}$'
                  {{- if $endpoint.domain }}
                  headers:
                  - name: ':authority'
                    exact_match: '{{ $endpoint.domain }}'
                  {{- end }}
                {{- if not $route.disable_route_stats }}
                stat_prefix: {{ $endpoint.name }}_{{ $route.name }}
                {{- end }}
                {{- if $endpoint.request_headers_to_add }}
                request_headers_to_add:
                {{- range $rqh := $endpoint.request_headers_to_add }}
                  - header:
                      key: "{{ $rqh.key }}"
                      value: "{{ $rqh.value }}"
                    append_action: OVERWRITE_IF_EXISTS_OR_ADD
                {{- end }}
                {{- end }}
                {{- if or $endpoint.response_headers_to_add $endpoint.rb_response_headers }}
                response_headers_to_add:
                {{- range $rsh := $endpoint.response_headers_to_add }}
                  - header:
                      key: "{{ $rsh.key }}"
                      value: "{{ $rsh.value }}"
                    append_action: OVERWRITE_IF_EXISTS_OR_ADD
                {{- end }}
                {{- if $endpoint.rb_response_headers }}
                  - header:
                      key: "access-control-allow-origin"
                      value: "*"
                    append: false
                  - header:
                      key: "access-control-allow-methods"
                      value: "GET,HEAD"
                    append: false
                  - header:
                      key: "access-control-allow-headers"
                      value: "accept, content-type, content-length, cache-control, accept-language, api-user-agent, if-match, if-modified-since, if-none-match, dnt, accept-encoding"
                    append: false
                  - header:
                      key: "access-control-expose-headers"
                      value: "etag"
                    append: false
                  - header:
                      key: "x-content-type-options"
                      value: "nosniff"
                    append: false
                  - header:
                      key: "x-frame-options"
                      value: "SAMEORIGIN"
                    append: false
                  - header:
                      key: "referrer-policy"
                      value: "origin-when-cross-origin"
                    append: false
                  - header:
                      key: "x-xss-protection"
                      value: "1; mode=block"
                    append: false
                {{- end }}
                {{- end }}
                  {{- if $endpoint.params}}
                  query_parameters:
                  {{- range $param := $endpoint.params }}
                  - name: $param
                    present_match: true
                  {{- end }}
                  {{- end }}
                route:
                  regex_rewrite:
                    pattern:
                      google_re2: {}
                      regex: '^{{ $route.in }}$'
                    substitution: '{{ $route.out }}'
                  timeout: {{ $endpoint.timeout | default "15s" }}
                  cluster: {{ $cluster_name }}_cluster
                  {{- if $endpoint.ingress }}
                  auto_host_rewrite: true
                  {{- end }}
{{- end }}
{{- end }}
{{- /* END rest_gateway_routes definition */}}


{{- end }}
