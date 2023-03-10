{{ define "apigateway.ratelimit_rules" }}
                {{- if hasKey .Values.main_app.ratelimiter "prefixes_without_required_jwt" }}
                # For docs wiki, allow no JWT, but if JWT is supplied, verify it.
                {{- range .Values.main_app.ratelimiter.prefixes_without_required_jwt }}
                {{- range $k, $v := . }}
                - match:
                    {{ $k }}: {{ $v }}
                  requires:
                    requires_any:
                      requirements:
                        - provider_name: wikimedia
                        - allow_missing: {}
                {{- end }}
                {{- end }}
                {{- end }}
                # For everything else, block non-idempotent requests without JWT
                - match:
                    headers:
                      - name: ":method"
                        safe_regex_match:
                          google_re2: {}
                          regex: "(POST|PUT|PATCH|DELETE)"
                    prefix: /
                  requires:
                    provider_name: wikimedia
                # For idempotent requests, allow missing JWT, but verify it if provided
                - match:
                    headers:
                      - name: ":method"
                        safe_regex_match:
                          google_re2: {}
                          regex: "(GET|HEAD|OPTIONS)"
                    prefix: /
                  requires:
                    requires_any:
                      requirements:
                        - provider_name: wikimedia
                        - allow_missing: {}
{{- end }}
