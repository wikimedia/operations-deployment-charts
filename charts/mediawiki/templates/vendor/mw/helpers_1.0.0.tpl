{{/*

 Labels for releases.
 Typical values for a cluster of appservers will be
 app: MediaWiki
 chart: MediaWiki-0.1
 release: canary (or production)
 heritage: helm
 deployment: parsoid
*/}}
{{ define "mw.helpers.labels" }}
{{- $flags := fromJson ( include "mw.helpers.feature_flags" . ) }}
labels:
  app: {{ template "base.name.chart" . }}
  chart: {{ template "base.name.chartid" . }}
  release: {{ .Release.Name }}
  heritage: {{ .Release.Service }}
{{- if and $flags.job .Values.mwscript.labels }}
  # The mwscript-k8s wrapper script adds "username" and "script" labels.
{{- toYaml .Values.mwscript.labels | nindent 2 }}
{{- end }}
{{- if and $flags.periodic .Values.mwcron.labels }}
{{- toYaml .Values.mwcron.labels | nindent 2 }}
{{- end }}
{{ end }}

{{/*

Helper that allows to define feature flags based on the servergroup

It returns a json string of a dictionary of feature flags, where the key is the flag name
and the value is the boolean value.

Usage:
{{- $flags := include "mw.helpers.feature_flags" . | fromJson -}}
{{- if $flags.web }}
....
*/}}
{{ define "mw.helpers.feature_flags" }}
{{ $traits := fromJson (include "mw.helpers._traits" .Values.php.servergroup ) }}
{{ $features := .Values.mw.helpers.feature_flags }}
{{ $flags := deepCopy $features.default }}
{{ if $traits.async }}
  {{ $flags = mergeOverwrite $flags $features.async }}
{{ end }}
{{ if $traits.cli }}
  {{ $flags = mergeOverwrite $flags $features.cli }}
{{ end }}
{{ if $traits.periodic }}
  {{ $flags = mergeOverwrite $flags $features.periodic }}
{{ end }}
{{ if $traits.videoscaler }}
  {{ $flags = mergeOverwrite $flags $features.videoscaler }}
{{ end }}
{{ if $traits.dumps }}
  {{ $flags = mergeOverwrite $flags $features.dumps }}
{{ end }}
{{ toJson $flags }}
{{ end }}


{{- define "mw.helpers._traits" -}}
  {{ $servergroup := . }}
  {{/* The async trait might regulate timeouts and other settings */}}
  {{- $async := false }}
  {{- range list "-async" "jobrunner" }}
    {{- if contains . $servergroup  }}
      {{- $async = true }}
    {{- end }}
  {{- end }}
  {{/* The cli trait will indicate if a webservice is needed or not */}}
  {{- $cli := false }}
  {{- range list "script" "cron" }}
    {{- if contains . $servergroup  }}
      {{- $cli = true }}
    {{- end }}
  {{- end }}
  {{- $periodic := false }}
  {{- range list "dumps" "cron" }}
    {{- if contains . $servergroup  }}
      {{- $periodic = true }}
    {{- end }}
  {{- end }}
  {{/* The videoscaling trait indicates if we're running videoscaling jobs here */}}
  {{- $videoscaler := false }}
  {{- range list "videoscaler" }}
    {{- if contains . $servergroup  }}
      {{- $videoscaler = true }}
    {{- end }}
  {{- end }}
  {{/* The dumps trait indicates if we're running dumps here */}}
  {{- $dumps := false }}
  {{- range list "dumps" -}}
    {{- if contains . $servergroup -}}
      {{- $dumps = true -}}
    {{- end }}
  {{- end }}
  {{- $traits := dict "async" $async "cli" $cli "videoscaler" $videoscaler "periodic" $periodic "dumps" $dumps -}}
  {{- toJson $traits -}}
{{- end -}}
