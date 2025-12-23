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
{{ $k }}  {{ $v}}
{{- end }}
{{- end }}

{{- define "spark.volumes" }}
{{- with .Values.volumes }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "spark.volumemounts" }}
{{- with .Values.volumemounts }}
{{ toYaml . }}
{{- end }}
{{- end }}