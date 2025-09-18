{{- define "jwks.config" }}
{
  "keys": [
      {
          "alg" : "RS256",
          "e" : "AQAB",
          "kid" : "{{ .Values.main_app.jwks.kid }}",
          "kty" : "RSA",
          "n" : "{{ .Values.main_app.jwks.key }}",
          "use" : "sig"
      }
  ]
}
{{ end }}
