{{/*
== Generic name helpers for our mesh network

 - mesh.name.service: the label for the service stood up by the service mesh
   for local TLS termination
 - mesh.name.fqdn: the fqdn for the mesh service
 - mesh.name.annotations: Annotations related to the mesh network to add to e.g.
   deployments to ensure they change when the configuration of the mesh changes.

*/}}
{{- define "mesh.name.service" -}}
{{ template "base.name.release" . }}-tls-service
{{- end -}}

{{- define "mesh.name.fqdn" -}}
{{ template "mesh.name.service" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}

{{- define "mesh.name.annotations" -}}
{{- if .Values.mesh.enabled }}
checksum/tls-config: {{ include "mesh.configuration.full" . | sha256sum }}
checksum/tls-certs: {{ printf "%v" (values .Values.mesh.certs | sortAlpha) | sha256sum }}
{{- if .Values.mesh.telemetry.enabled }}
envoyproxy.io/scrape: "true"
envoyproxy.io/port: "{{ .Values.mesh.telemetry.port }}"
{{- else }}
envoyproxy.io/scrape: "false"
{{- end }}
{{- end }}
{{- end -}}