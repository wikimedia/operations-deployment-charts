{{/*

Mcrouter configuration.

This is a relatively opinionated mcrouter configuration, supporting three types of routes:
* simple
* simple with failover
* replicated with failover

It also assumes that:
* Each memcached server in the local zones can be reached with no TLS on port 11211
* Each memcached server in the remote zones can be reached with TLS on port 11214

Our "replicated routes" are in reality multiple routes, one pointing to a local pool for
read-write and one pointing to the same local pool for reads and to the remote one for writes.
This way, the application can funnel its writes to both routes when it needs cross-zone "consistency",
in typical memecached fashion.

*/}}

{{ define "mcrouter.config" }}
{{- with .Values.mw.mcrouter -}}
  {{- $mcrouter_zone := .zone -}}
  {{- $pools := .pools -}}
{
  "pools": {
  {{- $last_pool := last .pools }}
  {{- range $pools -}}
    {{- $pool := dict "pool" . "mcrouter_zone" $mcrouter_zone -}}
    {{- include "mcrouter.pool" $pool | indent 4 }}{{ if ne .name $last_pool.name }},{{end}}
  {{- end }}
  },
  "routes": [
{{- $last_route := last .routes }}
  {{- range .routes }}
  {{- include "mcrouter.route" . | indent 4 }}{{if ne .route $last_route.route }},{{end}}
  {{- end }}
  ]
}
{{- end -}}
{{- end -}}

{{/* Define a mcrouter pool. See the assumptions above. */}}
{{ define "mcrouter.pool" }}
{{- $is_local := eq .mcrouter_zone .pool.zone }}
"{{ .pool.name }}": {
  "servers": {{ include "mcrouter.pool_servers" (dict "is_local" $is_local "servers" .pool.servers) }}
}{{- if .pool.failover -}},
"{{ .pool.name }}-failover": {
  "servers": {{ include "mcrouter.pool_servers" (dict "is_local" $is_local "servers" .pool.failover) }}
}{{- end -}}
{{- end -}}

{{/* Define the list of servers in a pool. */}}
{{- define "mcrouter.pool_servers" -}}
{{- $connfmt := "%s:11211:ascii:plain" -}}
{{- if not .is_local -}}
  {{- $connfmt := "%s:11214:ascii:ssl" -}}
{{- end -}}
{{- $shards := list }}
{{- range .servers }}
  {{- $shards = append $shards (printf $connfmt .) -}}
{{- end -}}
{{ toPrettyJson $shards }}
{{- end -}}

{{/*
Define a mcrouter route.

We have three types of main routes:
* standalone: simple route to a single pool
* standalone: (with failover) route that uses a failover pool
* replica: deletes are replicated across different pools, including failovers

All these routes can either include a failover pool or not.
 */}}
{{ define "mcrouter.route" }}
{{- $route := .route | trimSuffix "/" -}}
{{- if eq .type "standalone" -}}
    {{- if .failover }}
{
  "aliases": [
    "{{ $route }}/"
  ],
  "route": {
    "failover": "PoolRoute|{{ .pool }}-failover",
    "failover_errors": [
      "tko"
    ],
    "failover_exptime": 600,
    "normal": "PoolRoute|{{ .pool }}",
    "type": "FailoverWithExptimeRoute"
  }
}
    {{- else -}}
{
  "aliases": [
    "{{ $route }}/"
  ],
  "route": "PoolRoute|{{ .pool }}"
}
    {{- end -}}
{{- else if (eq .type "replica") -}}
{{/*
  Set up two failover routes - both read locally, only one writes remotely
*/}}
  {{- template "mcrouter.failover-route" dict "route" .route "read_pool" .pool "write_pool" .pool }},
  {{- template "mcrouter.failover-route" dict "route" .remote.route "read_pool" .pool "write_pool" .remote.pool }}
{{- end -}}
{{- end -}}

{{/*
  A single failover route with separation between reads and writes to different pools.
*/}}
{{ define "mcrouter.failover-route" }}
{{- $route := .route | trimSuffix "/" -}}
{
  "aliases": [
    "{{ $route }}/"
  ],
  "route": {
    "default_policy": {
      "failover": "PoolRoute|{{ .read_pool }}-failover",
      "failover_errors": [
        "tko"
      ],
      "failover_exptime": 600,
      "normal": "PoolRoute|{{ .read_pool }}",
      "type": "FailoverWithExptimeRoute"
    },
    "operation_policies": {
      "delete": {
        "children": [
          {
            "failover": "PoolRoute|{{ .write_pool }}-failover",
            "failover_errors": [
              "tko"
            ],
            "failover_exptime": 600,
            "normal": "PoolRoute|{{ .write_pool }}",
            "type": "FailoverWithExptimeRoute"
          }
        ],
        "type": "AllSyncRoute"
      },
      "set": {
        "children": [
          {
            "failover": "PoolRoute|{{ .write_pool }}-failover",
            "failover_errors": [
              "tko"
            ],
            "failover_exptime": 600,
            "normal": "PoolRoute|{{ .write_pool }}",
            "type": "FailoverWithExptimeRoute"
          }
        ],
        "type": "AllSyncRoute"
      }
    },
    "type": "OperationSelectorRoute"
  }
}
{{- end -}}