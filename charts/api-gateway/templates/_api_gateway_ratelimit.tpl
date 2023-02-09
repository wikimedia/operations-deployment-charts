{{ define "apigateway.ratelimit_rules" }}
                # For docs wiki, allow no JWT, but if JWT is supplied, verify it.
                - match:
                    prefix: /wiki/
                  requires:
                    requires_any:
                      requirements:
                        - provider_name: wikimedia
                        - allow_missing: {}
                - match:
                    prefix: /w/
                  requires:
                    requires_any:
                      requirements:
                        - provider_name: wikimedia
                        - allow_missing: {}
                - match:
                    path: /
                  requires:
                    requires_any:
                      requirements:
                        - provider_name: wikimedia
                        - allow_missing: {}
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
