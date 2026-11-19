{{- define "evalValue" -}}
{{- if and (kindIs "string" .value ) (and (contains "{{" .value) (contains "}}" .value)) }}
{{- /* We're dealing with a value itself containing a helm template expression that we evaluate at runtime */}}
{{- $evaluatedValue := tpl .value .Root -}}
{{- include "evalValue" (dict "value" $evaluatedValue "Root" .Root) -}}
{{- else }}
{{- .value -}}
{{- end -}}
{{- end -}}

{{- define "render_xml_file" -}}
{{- $Root := .Root }}
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
{{- range $k, $v := .config }}
  <property>
    <name>{{ $k }}</name>
    <value>{{ include "evalValue" (dict "value" $v "Root" $Root) }}</value>
  </property>
{{- end }}
</configuration>
{{- end }}

{{- define "app.volume.projected_jwt" }}
- name: rgw-token
  projected:
    sources:
    - serviceAccountToken:
        audience: "{{ $.Values.config.public.AWS_ENDPOINT_URL_STS }}"
        expirationSeconds: 3600
        path: token
{{- end }}