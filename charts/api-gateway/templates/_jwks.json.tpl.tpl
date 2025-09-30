{{- define "jwks.config" }}
{
  "keys": [
  {{/* OCT should be used only for testing */}}
{{- if eq .Values.main_app.jwks.type "OCT" }}
    {
      "kty": "oct",
      "kid": "{{ .Values.main_app.jwks.kid }}",
      "k": "{{ .Values.main_app.jwks.key }}"
    }
{{- else }}
    {
          "alg" : "RS256",
          "e" : "AQAB",
          "kid" : "{{ .Values.main_app.jwks.kid }}",
          "kty" : "RSA",
          "n" : "{{ .Values.main_app.jwks.key }}",
          "use" : "sig"
      }
{{- end }}
  ]
}
{{ end }}
