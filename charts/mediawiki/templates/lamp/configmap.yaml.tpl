{{ define "mw.lamp.envvars"}}
{{- if .Values.php.envvars }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-php-envvars
data:
  envvars.inc: |-
  {{- range $k := (keys .Values.php.envvars | sortAlpha)  }}
    env['{{ $k }}'] = ${{ "{" }}{{ $k }}{{ "}" }}
  {{- end -}}
{{- end }}
{{- end }}
{{ define "mw.lamp.configmap" }}
{{- $flags := fromJson (include "mw.feature_flags" . ) -}}
{{- if $flags.web }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-httpd-sites-config
  {{- include "mw.labels" . | indent 2}}
data:
{{ include "mw.web-sites" . }}
{{- if .Values.mw.httpd.additional_config }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-httpd-early-config
data:
  00-aaa.conf: {{- .Values.mw.httpd.additional_config | toYaml | indent 4 }}
{{- end }}
{{- end }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-wikimedia-cluster-config
data:
  wikimedia-cluster: {{ .Values.mw.datacenter }}
{{- if .Values.mw.wmerrors }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-wmerrors
data:
{{ .Values.mw.wmerrors | toYaml | indent 2 }}
{{- end -}}
{{- if .Values.debug.php.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-php-debug-config
data:
{{- range $k, $v := .Values.debug.php.contents }}
  "{{ $k }}.php": {{ $v | toYaml | indent 4 }}
{{- end }}
{{- end -}}

{{- if .Values.mw.mail_host }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-mail-config
data:
  .msmtprc: |-
    account default
    host {{ .Values.mw.mail_host }}
    from wiki@wikimedia.org
    timeout 1
{{- end }}
{{ include "mw.lamp.envvars" . }}
{{- end }}
{{- if .Values.mwscript.textdata }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-mwscript-textdata
data:
{{- range $k, $v := .Values.mwscript.textdata }}
  "{{ $k }}": {{ $v | toYaml | indent 4 }}
{{- end }}
{{- end }}