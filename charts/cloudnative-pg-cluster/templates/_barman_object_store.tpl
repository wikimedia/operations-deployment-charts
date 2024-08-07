{{- define "cluster.barmanObjectStoreConfig" -}}

{{- if .scope.endpointURL }}
  endpointURL: {{ .scope.endpointURL | quote }}
{{- end }}

{{- if or (.scope.endpointCA.create) (.scope.endpointCA.name) }}
  endpointCA:
    name: {{ .chartFullname }}-ca-bundle
    key: ca-bundle.crt
{{- end }}

{{- if .scope.destinationPath }}
  destinationPath: {{ .scope.destinationPath }}
{{- end }}

{{- if eq .scope.provider "s3" }}
  {{- if empty .scope.endpointURL }}
  endpointURL: "https://s3.{{ required "You need to specify S3 region if endpointURL is not specified." .scope.s3.region }}.amazonaws.com"
  {{- end }}
  {{- if empty .scope.destinationPath }}
  destinationPath: "s3://{{ required "You need to specify S3 bucket if destinationPath is not specified." .scope.s3.bucket }}{{ .scope.s3.path }}"
  {{- end }}
  {{- $secretName := coalesce .scope.secret.name (printf "%s-%s-s3-creds" .chartFullname .secretPrefix) }}
  s3Credentials:
    accessKeyId:
      name: {{ $secretName }}
      key: ACCESS_KEY_ID
    secretAccessKey:
      name: {{ $secretName }}
      key: ACCESS_SECRET_KEY
{{- end -}}
{{- end -}}
