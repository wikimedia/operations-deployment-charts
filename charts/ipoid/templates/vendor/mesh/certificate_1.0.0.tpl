{{- if and (.Values.mesh.certmanager | default dict).enabled .Values.mesh.public_port }}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  {{- include "base.meta.metadata" (dict "Root" . "Name" "tls-proxy-certs") | indent 2 }}
spec:
  commonName: {{ include "mesh.name.fqdn" . }}
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