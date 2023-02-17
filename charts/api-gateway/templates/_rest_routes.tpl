{{- define "restgateway.routes" }}
            name: restgateway_route
            virtual_hosts:
            - name: restgateway_vhost
              domains:
{{- range $domain := .Values.main_app.domains }}
              - {{ $domain }}
{{- end }}
              routes:
{{- /* BEGIN restbase_routes definition */}}
{{- range $endpoint, $endpoint_config := .Values.main_app.restbase_routes }}
{{- range $route_name, $route_paths := $endpoint_config.urls }}
              - name: {{ $endpoint }}_{{ $route_name }}
                match:
                  safe_regex:
                    google_re2: {}
                    regex: '^/{{ $route_paths.in }}$'
                route:
                  regex_rewrite:
                    pattern:
                      google_re2: {}
                      regex: ^/{{ $route_paths.in }}$'
                    substitution: '/{{ $route_paths.out }}'
                  timeout: {{ $endpoint_config.timeout | default "15s" }}
                  cluster: {{ $endpoint }}_cluster
                  host_rewrite_literal: {{ $endpoint }}_cluster
{{- end }}
{{- end }}
{{- /* END restbase_routes definition */}}


{{- end }}
