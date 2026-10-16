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

{{- define "s3.web_identity.env" }}
{{- with .Values.s3.web_identity }}
{{- if .enabled }}
- name: AWS_ROLE_ARN
  value: {{ .role_arn }}
- name: AWS_ROLE_SESSION_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: AWS_WEB_IDENTITY_TOKEN_FILE
  value: /var/run/secrets/rgw/token
- name: AWS_ENDPOINT_URL_STS
  value: {{ .endpoint }}
- name: AWS_REGION
  value: {{ .region }}
{{- end }}
{{- end }}
{{- end }}

{{- define "s3.web_identity.volumemounts" }}
{{- if .Values.s3.web_identity.enabled }}
- mountPath: /var/run/secrets/rgw
  name: rgw-token
  readOnly: true
{{- end }}
{{- end }}

{{- define "s3.web_identity.volumes" }}
{{- with .Values.s3.web_identity }}
{{- if .enabled }}
# The kubelet renews the token before it expires.
- name: rgw-token
  projected:
    sources:
      - serviceAccountToken:
          audience: {{ .endpoint }}
          expirationSeconds: 3600
          path: token
{{- end }}
{{- end }}
{{- end }}
