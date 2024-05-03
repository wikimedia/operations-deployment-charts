{{/*
== Create certificate resources ==

These templates create Certificate for all certificates defined in .Values.certificates
in the following structure:
  name: name of the certificate (Mandatory)
  secretName: name of the secret which will contain certificate data (Optional, Default: <base.name.release>-<certificate.name>)
  disableDefaultHosts: disable the default hosts in subject alt name: [<base.name.release>, <base.name.release>.<.Release.Namespace>.svc, <base.name.release>.<.Release.Namespace>.svc.cluster.local] (Optional. Default: false)
  extraFQDNs: additional subject alt names to use in the certificate (Optional)
  issuerRefName: name of the issuer (Optional. Default: discovery)
  issuerRefGroup: group of the issuer (Optional. Default: cfssl-issuer.wikimedia.org)
  issuerRefKind: kind of the issuer (Optional. Default: ClusterIssuer)
*/}}

{{- range $certificate := (.Values.certificates | default list) }}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  {{- include "base.meta.metadata" (dict "Root" $ "Name" $certificate.name) | indent 2 }}
spec:
  # CommonName is a common name to be used on the Certificate. The CommonName
  # should have a length of 64 characters or fewer to avoid generating invalid
  # CSRs. This value is ignored by TLS clients when any subject alt name is
  # set. This is x509 behavior: https://tools.ietf.org/html/rfc6125#section-6.4.4
  commonName: {{ include "base.meta.name" (dict "Root" $ "Name" $certificate.name) | trunc 64 }}
  secretName: {{ .secretName | default (include "base.meta.name" (dict "Root" $ "Name" $certificate.name)) }}
  dnsNames:
  {{- if not $certificate.disableDefaultHosts }}
  - {{ include "base.name.release" $ }}
  - {{ include "base.name.release" $ }}.{{ $.Release.Namespace }}.svc
  - {{ include "base.name.release" $ }}.{{ $.Release.Namespace }}.svc.cluster.local
  {{- end }}
  {{- if $certificate.extraFQDNs -}}
  {{ $certificate.extraFQDNs | toYaml | nindent 2 }}
  {{- end }}
  # revisionHistoryLimit is the maximum number of CertificateRequest revisions that are maintained in the Certificate's history.
  # If not set, cert-manager will not clean up old CertificateRequests at all. Setting this to 2 makes to have the CR from the
  # previous Certificate still around after refresh.
  revisionHistoryLimit: 2
  issuerRef:
    name: {{ $certificate.issuerRefName | default "discovery" }}
    group: {{ $certificate.issuerRefGroup | default "cfssl-issuer.wikimedia.org" }}
    kind: {{ $certificate.issuerRefKind | default "ClusterIssuer" }}
{{- end }} {{/* end range $certificate ... */}}
