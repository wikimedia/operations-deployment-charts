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
{{- if and .Values.mwscript.enabled .Values.mwscript.labels }}
  # The mwscript-k8s wrapper script adds "username" and "script" labels.
{{- toYaml .Values.mwscript.labels | nindent 2 }}
{{- end }}
{{- if and .Values.mwcron.enabled .Values.mwcron.labels }}
{{- toYaml .Values.mwcron.labels | nindent 2 }}
{{- end }}
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

{{/*

str2bool helper, turns "true" string into pseudo-boolean.
If input is "true", return the "true" string that will evaluate as true in conditions,
else, return the empty string that will evaluate as false.

*/}}
{{- define "mw.str2bool" -}}
  {{- $output := "" -}}
  {{- if eq . "true" -}}
    {{- $output = "true" -}}
  {{- end -}}
  {{ $output }}
{{- end -}}

{{/*

Maintenance check for mediawiki cron jobs and mwscript
Returns true if mwcron/mwscript is enabled, the datacentre is primary and not read-only

*/}}
{{- define "mw.maintenance.can_run" -}}
  {{- $is_primary_dc := eq $.Values.mw.primary_dc $.Values.mw.datacenter -}}
  {{- $is_read_only := index $.Values.mw.read_only $.Values.mw.datacenter -}}
  {{- print (and (or $.Values.mwcron.enabled $.Values.mwscript.enabled) (and $is_primary_dc (not $is_read_only))) -}}
{{- end -}}
