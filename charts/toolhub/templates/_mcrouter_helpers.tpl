{{/*
Mcrouter configuration.

Simplified version of mcrouter config used by the MediaWiki chart. Toolhub
does not need or use all of the fancy routing features of mcrouter, but we are
trying to keep it's data in the same pools which are used by MediaWiki wikis.
This is intended to reduce maintenance burden on SREs, but may increase
maintenance burden on these k8s resource configurations when things are
refactored for the MediaWiki charts.

Note: the reused data from MediaWiki is publiished as
/etc/helmfile-defaults/mediawiki/mcrouter_pools.yaml via Puppet. That file
looks something like:

    ---
    mw:
      mcrouter:
        pools:
          - name: eqiad-servers
            zone: eqiad
            servers: [...]
            failover: [...]
          - name: codfw-servers
            zone: codfw
            servers: [...]
            failover: [...]
          - name: eqiad-proxies
            zone: eqiad
            servers: [...]
            failover: [...]
          - name: codfw-proxies
            zone: codfw
            servers: [...]
            failover: [...]
*/}}
{{ define "mcrouter.config_template" }}
{{- $pools := .Values.mw.mcrouter.pools -}}
{{- $last_pool := last .Values.mw.mcrouter.pools }}
{{- with .Values.mcrouter -}}
  {{- $mcrouter_zone := .zone -}}
{
  "pools": {
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
{{- end -}}{{/* "mcrouter.config_template" */}}

{{ define "mcrouter.pool" }}
{{- $is_local := eq .mcrouter_zone .pool.zone }}
"{{ .pool.name }}": {
  "servers": {{ include "mcrouter.pool_servers" (dict "is_local" $is_local "servers" .pool.servers) }}
}{{- if .pool.failover -}},
"{{ .pool.name }}-failover": {
  "servers": {{ include "mcrouter.pool_servers" (dict "is_local" $is_local "servers" .pool.failover) }}
}{{- end -}}
{{- end -}}
{{/* define "mcrouter.pool" */}}

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
{{- end -}}{{/* "mcrouter.pool_servers" */}}

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
{{- end -}}{{/* "mcrouter.route" */}}

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
{{- end -}}{{/* "mcrouter.failover-route" */}}

{{- define "mcrouter.container" -}}
{{- if .Values.mcrouter.enabled }}
- name: {{ template "base.name.release" . }}-mcrouter
  image: {{ .Values.docker.registry }}/{{ .Values.common_images.mcrouter.mcrouter }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- with .Values.mcrouter }}
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
  volumeMounts:
    - name: {{ template "base.name.release" . }}-mcrouter-config-volume
      mountPath: /etc/mcrouter
  resources:
    requests:
{{ toYaml .Values.mcrouter.resources.requests | indent 6 }}
    limits:
{{ toYaml .Values.mcrouter.resources.limits | indent 6 }}
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
  resources: {}
{{- end -}}
{{- end }}
{{- end -}}{{/* "mcrouter.container" */}}

{{- define "mcrouter.config" -}}
{{- if .Values.mcrouter.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-mcrouter-config
  labels:
    app: {{ template "base.name.chart" . }}
    chart: {{ template "base.name.chartid" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
data:
  config.json: |-
{{ include "mcrouter.config_template" . | indent 4 }}
{{- end }}
{{- end -}}{{/* "mcrouter.config" */}}

{{- define "mcrouter.volume" -}}
{{- if .Values.mcrouter.enabled }}
- name: {{ template "base.name.release" . }}-mcrouter-config-volume
  configMap:
      name: {{ template "base.name.release" . }}-mcrouter-config
{{- end }}
{{- end -}}{{/* "mcrouter.volume" */}}
