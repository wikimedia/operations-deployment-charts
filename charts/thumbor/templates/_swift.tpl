{{- define "swift.config" }}
## The result storage thumbor should use to store generated images. This must be
## the full name of a python module (python must be able to import it)
## Defaults to: None
RESULT_STORAGE = 'wikimedia_thumbor.result_storage.swift'

SWIFT_HOST = '{{ .Values.main_app.swift.host }}'
SWIFT_API_PATH = '/v1/AUTH_{{ .Values.main_app.swift.account }}'
SWIFT_AUTH_PATH = '/auth/v1.0'
SWIFT_USER = '{{ .Values.main_app.swift.account }}:{{ .Values.main_app.swift.user }}'
SWIFT_PRIVATE_USER = '{{ .Values.main_app.swift.private_account }}:{{ .Values.main_app.swift.private_user }}'
#SWIFT_PATH_PREFIX = 'thumbor/'
SWIFT_SHARDED_CONTAINERS = [
  {{ range $container := .Values.main_app.swift.sharded_containers }}
    '{{ $container }}',
  {{- end }}
]
SWIFT_PRIVATE_CONTAINERS = [
  {{ range $container := .Values.main_app.swift.private_containers }}
    '{{ $container }}',
  {{- end }}
]
SWIFT_CONNECTION_TIMEOUT = 20
SWIFT_RETRIES = 1
{{- end }}
