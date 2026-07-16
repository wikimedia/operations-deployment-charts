{{- /* Defines constants upon which the mw-api.lua plugin script depends. */}}
{{- define "restgateway.cluster_specifier_plugins.constants.mw-api.lua" }}
-- Constants derived from helm values.
local DEFAULT_CLUSTER = "{{ include "restgateway.cluster_specifier_plugins.endpoint_to_cluster" ( dict "value" .params.default "Root" .Root ) }}"
{{- end }}
