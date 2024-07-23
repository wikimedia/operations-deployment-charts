{{- if and .Values.mesh.enabled .Values.mesh.public_port }}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  {{- include "base.meta.metadata" (dict "Root" . "Name" "tls-proxy-certs") | indent 2 }}
spec:
  # CommonName is a common name to be used on the Certificate. The CommonName
  # should have a length of 64 characters or fewer to avoid generating invalid
  # CSRs. This value is ignored by TLS clients when any subject alt name is
  # set. This is x509 behavior: https://tools.ietf.org/html/rfc6125#section-6.4.4
  commonName: {{ include "base.meta.name" (dict "Root" . "Name" "tls-proxy-certs") | trunc 64 }}
  secretName: {{ include "base.meta.name" (dict "Root" . "Name" "tls-proxy-certs") }}
  dnsNames:
{{ include "mesh.name.fqdn_all" . | indent 4 }}
  # revisionHistoryLimit is the maximum number of CertificateRequest revisions that are maintained in the Certificat's history.
  # If not set, cert-manager will not clean up old CertificateRequests at all. Setting this to 2 makes to have the CR from the
  # previous Certificate still around after refresh.
  revisionHistoryLimit: 2
  issuerRef:
    # This references the cfssl ClusterIssuer "discovery" defined in admin_ng/cert-manager/cfssl-issuer-values.yaml
    name: discovery
    group: cfssl-issuer.wikimedia.org
    kind: ClusterIssuer
{{- end -}}
