{{- define "render_xml_file" -}}
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
{{- range $k, $v := .config }}
  <property>
    <name>{{ $k }}</name>
    <value>{{ $v }}</value>
  </property>
{{- end }}
</configuration>
{{- end }}

{{- define "render_dotconf_file" -}}
{{- range $k, $v := .config }}
{{ $k }} {{ $v}}
{{- end }}
{{- end }}

{{- define "spark.volumes" }}
{{- with .Values.spark.volumes }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "spark.volumemounts" }}
{{- with .Values.spark.volumemounts }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "kyuubi.volumes" }}
{{- with .Values.kyuubi.volumes }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "kyuubi.volumemounts" }}
{{- with .Values.kyuubi.volumemounts }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "kerberos.volumes" }}
{{- with .Values.kerberos.volumes }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "kerberos.volumemounts" }}
{{- with .Values.kerberos.volumemounts }}
{{ toYaml . }}
{{- end }}
{{- end }}


{{- define "hadoop.volumes" }}
{{- with .Values.hadoop.volumes }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "hadoop.volumemounts" }}
{{- with .Values.hadoop.volumemounts }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "kyuubi.frontend.protocols" -}}
  {{- $protocols := list }}
  {{- range $name, $frontend := .Values.kyuubi.server }}
    {{- if $frontend.enabled }}
      {{- $protocols = $name | snakecase | upper | append $protocols }}
    {{- end }}
  {{- end }}
  {{- if not $protocols }}
    {{ fail "At least one frontend protocol must be enabled!" }}
  {{- end }}
  {{- $protocols |  join "," }}
{{- end }}

{{- define "kyuubi.selectorLabels" -}}
component: kyuubi
{{- end -}}