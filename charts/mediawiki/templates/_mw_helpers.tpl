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
  app: {{ template "wmf.chartname" . }}
  chart: {{ template "wmf.chartid" . }}
  release: {{ .Release.Name }}
  heritage: {{ .Release.Service }}
{{ end }}

{{/* 

Network egress for MediaWiki

*/}}
{{- define "mediawiki.networkpolicy.egress" -}}
{{/* memcached */}}
{{- if .mcrouter.enabled }}
  {{- $mcrouter_zone := .mcrouter.zone -}}
  {{- range .mcrouter.pools -}}
    {{- $is_local := eq $mcrouter_zone .zone }}
    {{- range .servers }}
- to:
  - ipBlock:
      cidr: {{ . }}/32
  ports:
  - protocol: TCP
    port: {{if $is_local }}11211{{- else -}}11214{{- end -}}
    {{- end }}
  {{- end }}
{{- end }}
{{- if .nutcracker.enabled }}
  {{- range .nutcracker.pools }}
    {{- range .servers }}
- to:
  - ipBlock:
      cidr: {{ .host }}/32
  ports:
  - protocol: TCP
    port: {{ .port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}