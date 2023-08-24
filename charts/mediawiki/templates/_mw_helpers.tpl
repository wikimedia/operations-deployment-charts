{{/*

 Labels for releases.
 Typical values for a cluster of appservers will be
 app: MediaWiki
 chart: MediaWiki-0.1
 release: canary (or production)
 heritage: helm
 deployment: parsoid
*/}}
{{ define "mw.labels" }}
labels:
  app: {{ template "base.name.chart" . }}
  chart: {{ template "base.name.chartid" . }}
  release: {{ .Release.Name }}
  heritage: {{ .Release.Service }}
{{ end }}

{{/*

Network egress for MediaWiki

*/}}
{{- define "mediawiki.networkpolicy.egress" -}}
{{/* memcached */}}
{{- include "cache.mcrouter.egress" . -}}
{{- with .Values.mw.egress.database_networks }}
{{/* databases. For now we just ask for a CIDR and open ports 3306 and 3311 through 3320 */}}
- to:
  - ipBlock:
      cidr: {{ . }}
  ports:
  {{- $ports := list 3306 3310 3311 3312 3313 3314 3315 3316 3317 3318 3319 3320 -}}
  {{- range $ports }}
  - protocol: TCP
    port: {{.}}
  {{- end }}
{{- end }}
{{- range .Values.mw.egress.etcd_servers }}
- to:
  - ipBlock:
      cidr: {{ .ip }}/32
  ports:
  - protocol: TCP
    port: {{ .port }}
{{- end -}}
{{- range .Values.mw.egress.kubestage_servers }}
- to:
  - ipBlock:
      cidr: {{ .ip }}/32
  ports:
  - protocol: TCP
    port: {{ .port }}
{{- end -}}
{{- end -}}

{{/*

Special naming convention for mediawiki resources

*/}}
{{- define "mw.name.namespace.env.release" -}}
{{- $env := default "local" .Values.mw.datacenter -}}
{{- printf "%s.%s.%s" .Release.Namespace $env .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
