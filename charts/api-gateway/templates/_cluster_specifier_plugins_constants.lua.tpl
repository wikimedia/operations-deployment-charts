{{- /* Defines constants upon which the mw-api.lua plugin script depends. */}}
{{- define "restgateway.cluster_specifier_plugins.constants.mw-api.lua" }}
-- Constants derived from helm values.
local DEFAULT_CLUSTER = "{{ include "restgateway.cluster_specifier_plugins.endpoint_to_cluster" ( dict "value" .params.default "Root" .Root ) }}"
{{- if .params.xwd_backends }}
local XWD_BACKEND_CLUSTERS = {
{{- range $backend, $backend_endpoint := .params.xwd_backends }}
  ["{{ $backend }}"] = "{{ include "restgateway.cluster_specifier_plugins.endpoint_to_cluster" ( dict "value" $backend_endpoint "Root" $.Root ) }}",
{{- end }}
}
{{- end }}
{{- if .params.host_diversion }}
local HOST_DIVERSION_CLUSTERS = {
{{- range $host, $host_endpoint := .params.host_diversion }}
  ["{{ $host }}"] = "{{ include "restgateway.cluster_specifier_plugins.endpoint_to_cluster" ( dict "value" $host_endpoint "Root" $.Root ) }}",
{{- end }}
}
{{- end }}
{{- end }}
