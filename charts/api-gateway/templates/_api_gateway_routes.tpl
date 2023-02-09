{{- define "apigateway.routes" }}
{{- $strip_cookies := .Values.main_app.strip_api_cookies }}
            name: api_wikimedia_org_route
            virtual_hosts:
            - name: api_wikimedia_org_vhost
              domains:
{{- range $domain := .Values.main_app.domains }}
              - {{ $domain }}
{{- end }}
              virtual_clusters:
                - name: rw
                  headers:
                    - name: ":method"
                      safe_regex_match:
                        google_re2: {}
                        regex: "(POST|PUT|PATCH|DELETE)"
                    - name: ":path"
                      exact_match: "/healthz"
                      invert_match: true
                - name: r
                  headers:
                    - name: ":method"
                      safe_regex_match:
                        google_re2: {}
                        regex: "(GET|HEAD|OPTIONS)"
                    - name: ":path"
                      exact_match: "/healthz"
                      invert_match: true
              rate_limits:
                # For all rate limits, the top-level key is route_name. This is provided by custom
                # routes like discovery services in order to allow them to define their own limits,
                # but *also* to allow them to have their own rate limit counters. If a service does
                # not have a custom rate limit defined, it will be considered part of the global rate
                # limit (in this case the default route_name of "default_rate").

                # We define custom rate limits in our values file, which translates into providing
                # route-level metadata. Metadata cannot be provided at cluster level for it to be
                # obeyed in this section, so we don't

                # For authenticated requests, the following descriptor is produced:
                # - {value: ("route_name", "<route_name>")("client_id","<aud>")("user_id","<uid>"), override:(value:1000,unit:MINUTE)}
                # Applying limit/unit for client_id/user_id pair.
                #
                # If JWT is absent, no descriptor generated.
                # If override is missing, descriptor is ignored since it's not configured in the service
                - stage: 0
                  actions:
                    - metadata:
                        source: ROUTE_ENTRY
                        metadata_key:
                          key: envoy.filters.http.ratelimit
                          path:
                            - key: route_name
                        descriptor_key: route_name
                        default_value: default_rate
                    - metadata:
                        source: DYNAMIC
                        descriptor_key: client_id
                        metadata_key:
                          key: envoy.filters.http.jwt_authn
                          path:
                            - key: jwt_payload
                            - key: aud
                    - metadata:
                        source: DYNAMIC
                        descriptor_key: user_id
                        metadata_key:
                          key: envoy.filters.http.jwt_authn
                          path:
                            - key: jwt_payload
                            - key: sub
                  limit:
                    dynamic_metadata:
                      metadata_key:
                        key: envoy.filters.http.jwt_authn
                        path:
                          - key: jwt_payload
                          - key: ratelimit
                # For authenticated requests emit the following descriptor:
                # - {value: ("route_name", "<route_name>")("user_class_anon_fallback","<class>")("client_ip","123.123.123.123)}
                # which will be ignored by the service, since we only match on "anon" class.
                # For unauthenticated requests <class> would fallback to "anon", and the statically
                # configured limit will kick in.
                - stage: 0
                  actions:
                    - metadata:
                        source: ROUTE_ENTRY
                        metadata_key:
                          key: envoy.filters.http.ratelimit
                          path:
                            - key: route_name
                        descriptor_key: route_name
                        default_value: default_rate
                    - metadata:
                        source: DYNAMIC
                        descriptor_key: user_class_anon_fallback
                        metadata_key:
                          key: envoy.filters.http.jwt_authn
                          path:
                            - key: jwt_payload
                            - key: aud
                        default_value: anon
                    - request_headers:
                        # Use x-client-ip because Envoy's X-forwarded-for won't trust
                        # the upstream IP in cases of more than one IP in the list.
                        header_name: x-client-ip
                        descriptor_key: client_ip
              routes:
              - name: api-portal-redirect
                match:
                  path: '/'
                redirect:
                  path_redirect: '/wiki/'
                typed_per_filter_config:
                  envoy.filters.http.ratelimit:
                    "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimitPerRoute
                    vh_rate_limits: IGNORE
              - name: api-portal
                match:
                  prefix: "/wiki/"
                route:
                  cluster: appserver_cluster
                typed_per_filter_config:
                  envoy.filters.http.ratelimit:
                    "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimitPerRoute
                    vh_rate_limits: IGNORE
              - name: api-portal-static
                match:
                  prefix: "/static/"
                route:
                  cluster: appserver_cluster
                typed_per_filter_config:
                  envoy.filters.http.ratelimit:
                    "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimitPerRoute
                    vh_rate_limits: IGNORE
              - name: api-portal-restbase
                match:
                  prefix: "/api/rest_v1/"
                route:
                  cluster: restbase_cluster
                  prefix_rewrite: "/api.wikimedia.org/v1/"
                typed_per_filter_config:
                  envoy.filters.http.ratelimit:
                    "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimitPerRoute
                    vh_rate_limits: IGNORE
              - name: favicon
                match:
                  path: "/favicon.ico"
                route:
                  cluster: appserver_cluster
                typed_per_filter_config:
                  envoy.filters.http.ratelimit:
                    "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimitPerRoute
                    vh_rate_limits: IGNORE
              - name: robotstxt
                match:
                  path: "/robots.txt"
                route:
                  cluster: appserver_cluster
                typed_per_filter_config:
                  envoy.filters.http.ratelimit:
                    "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimitPerRoute
                    vh_rate_limits: IGNORE
              - name: appletouch-icon
                match:
                  path: "/apple-touch-icon.png"
                route:
                  cluster: appserver_cluster
                typed_per_filter_config:
                  envoy.filters.http.ratelimit:
                    "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimitPerRoute
                    vh_rate_limits: IGNORE
              - name: api-portal
                match:
                  prefix: "/w/"
                route:
                  cluster: appserver_cluster
                typed_per_filter_config:
                  envoy.filters.http.ratelimit:
                    "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimitPerRoute
                    vh_rate_limits: IGNORE
{{- /*
BEGIN restbase route definition
*/}}
              - name: feed
{{- if $strip_cookies }}
                request_headers_to_remove: ["cookie"]
                response_headers_to_remove: ["set-cookie"]
{{- end }}
                match:
                  prefix: "/feed/"
                route:
                  cors: &api_cors
                    allow_origin_string_match:
                      - prefix: "*"
                    allow_headers: 'Api-User-Agent,Authorization'
                  regex_rewrite:
                    pattern:
                      google_re2: {}
                      regex: '^/feed/v1/(\w+)/(\w+)/'
                    substitution: '/\2.\1.org/v1/feed/'
                  cluster: restbase_cluster
{{- if .Values.main_app.restbase_dev }}
              - name: restbase
                match:
                  prefix: "/restbase/"
                route:
                  cluster: restbase_cluster
                  regex_rewrite:
                    pattern:
                      google_re2: {}
                      regex: '^/restbase/(.*)'
                    substitution: '/\1'
{{- end }}
{{- /*
END restbase route definition
*/}}
{{- /*
BEGIN descriptions/mobileapps_cluster route definition
*/}}
              - name: descriptions
{{- if $strip_cookies }}
                request_headers_to_remove: ["cookie"]
                response_headers_to_remove: ["set-cookie"]
{{- end }}
                match:
                  safe_regex:
                    google_re2: {}
                    regex: '^/core/v1/(\w+)/(\w+)/page/(.*)/description$'
                route:
                  cors: *api_cors
                  regex_rewrite:
                    pattern:
                      google_re2: {}
                      regex: '^/core/v1/(\w+)/(\w+)/page/(.*)/description$'
                    substitution: '/\2.\1.org/v1/page/description/\3'
                  cluster: mobileapps_cluster
{{- /* END descriptions/mobileapps_cluster route definition */}}
{{- /* BEGIN pathing_map cluster definition */}}
{{- range $cluster, $api_routes := .Values.main_app.pathing_map }}
{{- /* BEGIN pathing_map route definition */}}
{{- range $api_route, $route_opts := $api_routes }}
              - name: pathing_map_{{ $cluster }}
{{- if $strip_cookies }}
                request_headers_to_remove: ["cookie"]
                response_headers_to_remove: ["set-cookie"]
{{- end }}
                match:
                  safe_regex:
                    google_re2: {}
                    regex: '^{{ $api_route }}$'
                route:
                  cors: *api_cors
{{- if $route_opts.path }}
                  regex_rewrite:
                    pattern:
                      google_re2: {}
                      regex: '^{{ $api_route }}$'
                    substitution: '{{ $route_opts.path }}'
{{- end }}
                  cluster: {{ $cluster }}
{{- if $route_opts.host }}
                  host_rewrite_path_regex:
                    pattern:
                      google_re2: {}
                      regex: '^{{ $api_route }}.*'
                    substitution: '{{ $route_opts.host }}'
{{- end }}
{{- end }}
{{- /* END pathing_map route definition - read methods*/}}
{{- end }}
{{- /* END pathing_map cluster definition */}}
{{- /* BEGIN discovery_endpoints route definition */}}
{{- range $discovery_route, $discovery_opts := .Values.main_app.discovery_endpoints }}
              - name: {{ $discovery_route }}_route
{{- if $strip_cookies }}
                request_headers_to_remove: ["cookie"]
                response_headers_to_remove: ["set-cookie"]
{{- end }}
                match:
                  safe_regex:
                    google_re2: {}
                    regex: '^/service/{{ $discovery_opts.path }}(.*)$'
                route:
                  timeout: {{ $discovery_opts.timeout | default "15s" }}
                  cors: *api_cors
                  regex_rewrite:
                    pattern:
                      google_re2: {}
{{- if $discovery_opts.full_path_trim }}
                      regex: '^{{ $discovery_opts.full_path_trim }}(.*)$'
{{- else }}
                      regex: '^/service/{{ $discovery_opts.path }}(.*)$'
{{- end }}
{{- if or (not $discovery_opts.host_rewrite_path) $discovery_opts.full_path_trim }}
                    substitution: '/\1'
{{- else if $discovery_opts.host_rewrite_path }}
{{- /* if we have a regex in our match already, the rest-of-path regex moves */}}
                    substitution: '/\2'
{{- end }}
                  cluster: {{ $discovery_route}}_cluster
{{- if $discovery_opts.host }}
                  host_rewrite_literal: '{{ $discovery_opts.host }}'
{{- else if $discovery_opts.host_rewrite_path }}
                  host_rewrite_path_regex:
                    pattern:
                      google_re2: {}
                      regex: '^/service/{{ $discovery_opts.path }}(.*)$'
                    substitution: '{{ $discovery_opts.host_rewrite_path }}'
{{- end }}
{{- if $discovery_opts.ratelimit_config }}
                metadata:
                  filter_metadata:
                    envoy.filters.http.ratelimit:
                      route_name: {{ $discovery_route }}
{{- end }}
{{- end }}
{{- /* END discovery_endpoints route definition */}}
{{- /* BEGIN staging_endpoints route definition */}}
{{- if eq .Release.Name "staging" }}
{{- if .Values.main_app.staging_endpoints }}
{{- range $staging_route, $staging_opts := .Values.main_app.staging_endpoints }}
              - name: {{ $staging_route }}_route
{{- if $strip_cookies }}
                request_headers_to_remove: ["cookie"]
                response_headers_to_remove: ["set-cookie"]
{{- end }}
                match:
                  safe_regex:
                    google_re2: {}
                    regex: '^/staging/{{ $staging_opts.path }}/(.*)$'
                route:
                  timeout: {{ $staging_opts.timeout | default "15s" }}
                  cors: *api_cors
                  regex_rewrite:
                    pattern:
                      google_re2: {}
                      regex: '^/staging/{{ $staging_opts.path }}/(.*)$'
                    substitution: '/\1'
                  cluster: {{ $staging_route}}_cluster
{{- end }}
{{- end }}
{{- end }}
{{- /* END staging_endpoints route definition */}}
{{- end }}
