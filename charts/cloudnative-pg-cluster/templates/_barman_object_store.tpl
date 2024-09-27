{{- define "cluster.barmanObjectStoreConfig" -}}

{{- if .scope.endpointURL }}
  endpointURL: {{ include "evalValue" (dict "value" .scope.endpointURL "Root" .Root) | quote }}
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
  {{- if ne .Root.Values.environmentName "override_me" }} {{/* don't fail when linting */}}
  {{- if or (eq .Root.Values.s3.secretKey "override_me") (eq .Root.Values.s3.accessKey "override_me") }}
  {{ fail "The s3.accessKey and s3.secreyKey values were not provided" }}
  {{- end }}
  {{- end }}
  {{- if empty .scope.endpointURL }}
  endpointURL: "https://s3.{{ required "You need to specify S3 region if endpointURL is not specified." .scope.s3.region }}.amazonaws.com"
  {{- end }}
  {{- if empty .scope.destinationPath }}
  destinationPath: "s3://{{ include "evalValue" (dict "value" .scope.s3.bucket "Root" .Root) }}{{ .scope.s3.path }}"
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
