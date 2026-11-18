{{/*
== Generic name helpers for our mesh network

 - mesh.name.service: the label for the service stood up by the service mesh
   for local TLS termination
 - mesh.name.fqdn: the fqdn for the mesh service
 - mesh.name.fqdn_all: a list of all the fqdn's for this service
 - mesh.name.annotations: Annotations related to the mesh network to add to e.g.
   deployments to ensure they change when the configuration of the mesh changes.

*/}}
{{- define "mesh.name.service" -}}
{{ template "base.name.release" . }}-tls-service
{{- end -}}

{{- define "mesh.name.fqdn" -}}
{{ template "mesh.name.service" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}

{{- /*
  Having the list of all domains here ensures backwards compatibility with what
  we used to generate via cergen. So services which are accessed via NodePort will
  still ship a certificate with the same domains in SAN as the cergen one.
*/ -}}
{{- define "mesh.name.fqdn_all" -}}
{{- $certmanager := (.Values.mesh.certmanager | default dict) }}
{{- $default_host := $certmanager.default_host | default .Release.Namespace -}}
{{- if not $certmanager.disableDefaultHosts -}}
{{- range $certmanager.domains -}}
- {{ $default_host }}.{{ . }}
{{ end -}} {{- /* end range $domains */ -}}
{{- end }} {{- /* if not $certmanager.disableDefaultHosts */ -}}
{{- /* Unconditionally add the cluster local name and extraFQDNs */ -}}
- {{ template "mesh.name.fqdn" . }}
{{ if $certmanager.extraFQDNs -}}
{{ $certmanager.extraFQDNs | toYaml }}
{{- end -}}
{{- end -}} {{- /* define */ -}}

{{- define "mesh.name.annotations" -}}
{{- if .Values.mesh.enabled }}
checksum/tls-config: {{ include "mesh.configuration.full" . | sha256sum }}
{{- if .Values.mesh.telemetry.enabled }}
envoyproxy.io/scrape: "true"
envoyproxy.io/port: "{{ .Values.mesh.telemetry.port }}"
{{- else }}
envoyproxy.io/scrape: "false"
{{- end }}
{{- end }}
{{- end -}}