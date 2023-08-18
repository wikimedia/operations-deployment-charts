{{- define "cache.mcrouter.deployment" -}}
{{- if .Values.cache.mcrouter.enabled }}
# TODO: understand how to make mcrouter use the
# application CA when connecting to memcached via TLS
- name: {{ template "base.name.release" . }}-mcrouter
  image: {{ .Values.docker.registry }}/{{ .Values.common_images.mcrouter.mcrouter }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- with .Values.cache.mcrouter }}
  env:
    - name: PORT
      value: "11213"
    - name: CONFIG
      value: "file:/etc/mcrouter/config.json"
    - name: ROUTE_PREFIX
      value: "{{ .route_prefix }}"
    - name: CROSS_REGION_TO
      value: "{{ .cross_region_timeout }}"
    - name: CROSS_CLUSTER_TO
      value: "{{ .cross_cluster_timeout }}"
    - name: NUM_PROXIES
      value: "{{ .num_proxies }}"
    - name: PROBE_TIMEOUT
      value: "{{ .probe_timeout }}"
    - name: TIMEOUTS_UNTIL_TKO
      value: "{{ .timeouts_until_tko }}"
    # We don't want to listen to TLS here.
    # TODO: check if it can connect with TLS without the TLS settings.
    - name: USE_SSL
      value: "no"
  {{- end }}
  ports:
  # Please note: this port is not exposed outside of the pod.
    - name: mcrouter
      containerPort: 11213
  livenessProbe:
    tcpSocket:
      port: mcrouter
  readinessProbe:
    exec:
      command:
        - /bin/healthz
{{- if .Values.cache.mcrouter.prestop_sleep }}
{{ include "base.helper.prestop" .Values.cache.mcrouter.prestop_sleep | nindent 2}}
{{- end }}
  volumeMounts:
    - name: {{ template "base.name.release" . }}-mcrouter
      mountPath: /etc/mcrouter
  {{- with .Values.cache.mcrouter.resources }}
  resources:
    requests:
{{ toYaml .requests | indent 6 }}
    limits:
{{ toYaml .limits | indent 6 }}
  {{- end }}
{{- if .Values.monitoring.enabled }}
- name: {{ template "base.name.release" . }}-mcrouter-exporter
  image: {{ .Values.docker.registry }}/{{ .Values.common_images.mcrouter.exporter }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  args: ["--mcrouter.address", "127.0.0.1:11213", "-mcrouter.server_metrics", "-web.listen-address", ":9151" ]
  ports:
  # Port names are limited to 15 characters.
  - name: mcr-metrics
    containerPort: 9151
  livenessProbe:
    tcpSocket:
      port: mcr-metrics
  {{- with .Values.cache.mcrouter.exporter.resources }}
  resources:
    requests:
{{ toYaml .requests | indent 6 }}
    limits:
{{ toYaml .limits | indent 6 }}
  {{- end }}
{{- if .Values.cache.mcrouter.prestop_sleep }}
{{ include "base.helper.prestop" .Values.cache.mcrouter.prestop_sleep | nindent 2}}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}

{{ define "cache.mcrouter.volume" }}
{{- if .Values.cache.mcrouter.enabled }}
# Mcrouter configuration
- name: {{ template "base.name.release" . }}-mcrouter
  configMap:
    name: {{ template "base.name.release" . }}-mcrouter-config
{{- end }}
{{- end }}

{{/* Networkpolicy egress */}}
{{- define "cache.mcrouter.egress" -}}
{{- if .Values.cache.mcrouter.enabled }}
  {{- with .Values.cache.mcrouter -}}
    {{- $mcrouter_zone := .zone -}}
    {{- range .pools -}}
      {{- $is_local := eq $mcrouter_zone .zone }}
      {{- include "cache.mcrouter._egress_pool" (dict "is_local" $is_local "servers" .servers) }}
      {{- include "cache.mcrouter._egress_pool" (dict "is_local" $is_local "servers" .failover) }}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "cache.mcrouter._egress_pool" -}}
{{- range .servers }}
- to:
  - ipBlock:
      cidr: {{ . }}/32
  ports:
  - protocol: TCP
    port: {{if $.is_local }}11211{{- else -}}11214{{- end -}}
{{- end }}
{{- end }}

{{/*

Mcrouter configuration.

This is a relatively opinionated mcrouter configuration, supporting four types of routes:
* standalone: simple sharded pool as a backend
* standalone (with failover): adding a failover pool
* replica: cross-pool replicated, with failover
* warmup: two-layers caching with a frontend short-lived caching pool

It also assumes that:
* Each memcached server in the local zones can be reached with no TLS on port 11211
* Each memcached server in the remote zones can be reached with TLS on port 11214

Our "replicated routes" are in reality multiple routes, one pointing to a local pool for
read-write and one pointing to the same local pool for reads and to the remote one for writes.
This way, the application can funnel its writes to both routes when it needs cross-zone "consistency",
in typical memecached fashion.

*/}}
{{ define "cache.mcrouter.configmap" }}
{{- if .Values.cache.mcrouter.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
{{- include "base.meta.metadata" (dict "Root" . "Name" "mcrouter-config" ) | indent 2 }}
data:
  config.json: |-
{{ include "cache.mcrouter.config" . | indent 4 }}
{{- end }}
{{- end }}


{{ define "cache.mcrouter.config" }}
{{- with .Values.cache.mcrouter -}}
{{ include "cache.mcrouter._validate" . }}
{
  "pools": {
    {{- include "cache.mcrouter.pools" . | indent 2 }}
  },
  "routes": [
    {{- include "cache.mcrouter.routes" . | indent 2 }}
  ]
}
{{- end -}}
{{- end -}}

{{/*

Mcrouter pools
Each pool is expected to be presented as a struct with the following components:

{
    .name string  # the pool name, that you will refer to in the "routes" section
    .servers []string  # A list of servers. We usually prefer using IPs
    .failover []string  # An optional list of failover servers. If this is not defined only standalone routes will work
    .zone string  # The zone this pool is part of. mcrouter communicates with pools in different zones
                  # using tls.
}
*/}}

{{ define "cache.mcrouter.pools" }}
{{- $last_pool := last .pools -}}
{{- $mcrouter_zone := .zone -}}
{{- range .pools -}}
  {{- $pool := dict "pool" . "mcrouter_zone" $mcrouter_zone -}}
  {{- include "cache.mcrouter._pool" $pool | indent 2 }}{{ if ne .name $last_pool.name }},{{end}}
{{- end }}
{{- end }}

{{/* Define a mcrouter pool. */}}
{{ define "cache.mcrouter._pool" }}
{{- $is_local := eq .mcrouter_zone .pool.zone }}
"{{ .pool.name }}": {
  "servers": {{ include "cache.mcrouter._pool.servers" (dict "is_local" $is_local "servers" .pool.servers) }}
}{{- if .pool.failover -}},
"{{ .pool.name }}-failover": {
  "servers": {{ include "cache.mcrouter._pool.servers" (dict "is_local" $is_local "servers" .pool.failover) }}
}{{- end -}}
{{- end -}}


{{/* Define the list of servers in a pool.

    Expects two inputs:
    .is_local to know if the pool is dc-local or not
    .servers to get a servers list.
 */}}
{{- define "cache.mcrouter._pool.servers" -}}
{{- $connfmt := "%s:11211:ascii:plain" -}}
{{- if not .is_local -}}
  {{- $connfmt = "%s:11214:ascii:ssl" -}}
{{- end -}}
{{- $shards := list }}
{{- range .servers }}
  {{- $shards = append $shards (printf $connfmt .) -}}
{{- end -}}
{{ toPrettyJson $shards }}
{{- end -}}

{{/*

Mcrouter routes

Expects as input a list of route structs that should look like:

{
 .route string  # the path of the route.
 .pool string  # the name of the pool.
 .failover_time int  # The time for which a failover is kept. Defaults to 600 seconds.
                     # A setting of 0 means there is no failover.
 # the following are alternative to each other, and define a different type of route:
 .:  # this is a route that has 2 layers of caching, with a small ttl locally
    .pool string  # then name of the pool
    .ttl int  # the ttl for objects in the warm cache. Defaults to 10 seconds
 .split: # This is for a route that splits reads and writes. It can be used for application-driven replication.
   .pool string  # the name of the pool we're writing to
 .replica: # this actually sets up one split pool and a standalone pool you can use for application-driven replication
    .route string  # the route for the split pool
    .pool string  # the name of the pool we're writing to
}

*/}}
{{ define "cache.mcrouter.routes" }}
{{- $last_route := last .routes }}
{{- range .routes }}
  {{- include "cache.mcrouter._route" . | indent 2 }}{{if ne .route $last_route.route }},{{end}}
{{- end }}
{{- end }}


{{/* private functions for the routes */}}
{{/* route switcher */}}
{{- define "cache.mcrouter._route" }}
{{- if .warmup }}
    {{- include "cache.mcrouter._route.warmup" . }}
{{- else if .replica -}}
    {{- include "cache.mcrouter._route.replica" . }}
{{- else if .split -}}
    {{- include "cache.mcrouter._route.split" (dict "route" .route "read_pool" .pool "write_pool" .split.pool) }}
{{- else -}}
    {{- include "cache.mcrouter._route.standalone" . }}
{{- end -}}
{{- end }}

{{/* standalone route */}}
{{ define "cache.mcrouter._route.standalone" }}
{{- $route := .route | trimSuffix "/" }}
{
  "aliases": [
    "{{ $route }}/"
  ],
  "route": {
{{ include "cache.mcrouter._failover" . | indent 4 }}
  }
}
{{- end }}


{{/*
    "Replica" routes

    setup two routes, one that writes and reads locally, the other one reading locally but writing remotely.
    Applications that want to replicate their data will need to write to both using a wildcard prefix.
*/}}
{{ define "cache.mcrouter._route.replica" }}
  {{- template "cache.mcrouter._route.split" (dict "route" .route "read_pool" .pool "write_pool" .pool "failover_time" .failover_time) }},
  {{- template "cache.mcrouter._route.split" (dict "route" .replica.route "read_pool" .pool "write_pool" .replica.pool "failover_time" .failover_time) }}
{{- end }}


{{/* split route with failover

    The inputs we expect here are:
    * .read_pool, which pool to read from
    * .write_pool, which pool to write to

 */}}
{{ define "cache.mcrouter._route.split" }}
{{- $route := .route | trimSuffix "/" }}
{
  "aliases": [
    "{{ $route }}/"
  ],
  "route": {
    "default_policy": {
{{ include "cache.mcrouter._failover" (dict "pool" .read_pool "failover_time" .failover_time) | indent 6 }}
    },
    "operation_policies": {
      "delete": {
        "children": [
          {
{{ include "cache.mcrouter._failover" (dict "pool" .write_pool "failover_time" .failover_time) | indent 12 }}
          }
        ],
        "type": "AllSyncRoute"
      },
      "set": {
        "children": [
          {
{{ include "cache.mcrouter._failover" (dict "pool" .write_pool "failover_time" .failover_time) | indent 12 }}
          }
        ],
        "type": "AllSyncRoute"
      }
    },
    "type": "OperationSelectorRoute"
  }
}
{{- end }}

{{/* standalone route with 2 layers of caching.

This is a two-layered cache configuration.

For reads, use WarmUpRoute to try the "warmup" pool first. If it's not
there, WarmUpRoute tries the ordinary pool next, and writes the
result back to the warmup cache, with a short expiration time of  by default 10 seconds.
Based on https://github.com/facebook/mcrouter/wiki/Two-level-caching#local-instance-with-small-ttl


*/}}
{{ define "cache.mcrouter._route.warmup" }}
{{- $route := .route | trimSuffix "/" }}
{
  "aliases": [
    "{{ $route }}/"
  ],
  "route": {
    "type": "OperationSelectorRoute",
    "operation_policies": {
      "get": {
        "type": "WarmUpRoute",
        "exptime":{{ .warmup.ttl | default "10"  }}
        "cold": "PoolRoute|{{ .warmup.pool }}",
        "warm": {
{{ include "cache.mcrouter._failover" . | indent 10 }}
        }
      }
    },
    "default_policy": {
{{ include "cache.mcrouter._failover" . | indent 6 }}
    }
  }
}
{{- end }}

{{- define "cache.mcrouter._failover" }}
{{- if ne .failover_time 0.0 -}}
"failover": "PoolRoute|{{ .pool }}-failover",
"failover_errors": [
  "tko"
],
"failover_exptime": {{ .failover_time | default "600" }},
"normal": "PoolRoute|{{ .pool }}",
"type": "FailoverWithExptimeRoute"
{{- else -}}
"pool": "{{ .pool }}",
"type": "PoolRoute"
{{- end -}}
{{- end }}

{{- define "cache.mcrouter._validate" -}}
{{- $pools := .pools -}}
  {{- range .routes -}}
    {{- include "cache.mcrouter._validate._pool" (dict "pools" $pools "route" . "pool" .pool) }}
    {{- if .warmup -}}
      {{- include "cache.mcrouter._validate._pool" (dict "pools" $pools "route" . "pool" .warmup.pool) }}
    {{- else if .replica -}}
      {{- include "cache.mcrouter._validate._pool" (dict "pools" $pools "route" . "pool" .replica.pool) }}
    {{- else if .split -}}
      {{- include "cache.mcrouter._validate._pool" (dict "pools" $pools "route" . "pool" .split.pool) }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "cache.mcrouter._validate._pool" -}}
  {{- $pool := dict "name" "" }}
  {{- $pool_name := .pool }}
  {{- range .pools -}}
    {{- if eq .name $pool_name -}}
      {{- $pool = . -}}
    {{- end -}}
  {{- end -}}
  {{- if eq $pool.name "" -}}
    {{- fail (printf "Could not find pool %s, route %s" .pool .route.route) -}}
  {{- end -}}
  {{- if and (ne .route.failover_time 0.0) (not (hasKey $pool "failover")) -}}
    {{- fail (printf "Pool %s has no failover servers list, route %s" .pool .route.route) -}}
  {{- end -}}
{{- end -}}

