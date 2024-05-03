{{/*
== Certificate related template

These templates create Certificate for all certificates define in .Values.certificates

Inputs:
 - name: name of the certificate (Mandatory)
 - secretName: name of the secret containing (Optional)
 - dnsNames: dns names to add to the certificate (Optional)
 - issuerRefName: name of the issuer (Optional. Defulat: discovery)
 - issuerRefGroup: group of the issuer (Optional. Defulat: cfssl-issuer.wikimedia.org)
 - issuerRefKind: kind of the issuer (Optional. Defulat: ClusterIssuer)
*/}}

{{- define "base.certificate" -}}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ $.certificate.name }}-certs
spec:
  secretName: {{ with $.certificate.secretName }}{{ . }}{{ else }}{{ $.release }}-{{ $.certificate.name }}-certs{{ end }}
  commonName: {{ $.release }}-{{ $.certificate.name }}.{{ $.namespace }}.svc
  dnsNames:
{{- with $.certificate.dnsNames }}
{{- toYaml . | nindent 2 }}
{{- else }}
  - {{ $.release }}-{{ $.certificate.name }}.{{ $.namespace }}.svc
  - {{ $.release }}-{{ $.certificate.name }}.{{ $.namespace }}.svc.cluster.local
{{- end }}
  issuerRef:
    name: {{ with $.certificate.issuerRefName }}{{ . }}{{ else }}discovery{{ end }}
    group: {{ with $.certificate.issuerRefGroup }}{{ . }}{{ else }}cfssl-issuer.wikimedia.org{{ end }}
    kind: {{ with $.certificate.issuerRefKind }}{{ . }}{{ else }}ClusterIssuer{{ end }}
{{- end }}

{{- $namespace := .Release.Namespace -}}
{{- $release := (include "base.name.release" .) -}}
{{- range $certificate := .Values.certificates }}
{{- include "base.certificate" (dict "certificate" $certificate "namespace" $namespace "release" $release) }}
{{- end }}