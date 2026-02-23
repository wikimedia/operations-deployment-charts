## configuration 1.15.2

- Ensure that local TLS listeners are correctly marked as `traffic_direction: INBOUND`.

## configuration 1.15.0

- Allow the envoyproxy local cluster to forward to an alternative
  `local_upstream_port`. This may be useful if an additional reverse proxy
  is required in the chain.

## configuration 1.14.4

- When tracing is enabled, set `pack_trace_reason: false` to avoid `X-Request-Id`
  mangling. T407826

## networkpolicy 1.2.1

- When tracing is enabled, also allow egress to otelcol port 4318 (http).

## configuration 1.13.0

- Set a custom new default for the Envoy histogram metrics settings, and
  add a parameter to override the configuration (if needed).

## configuration 1.12.0

- Add parameter sni_rewrites_host_header to allow toggling off the behavior of
  envoy setting whatever is receives in the SNI to the HTTP host header

## configuration 1.11.0

- Allow setting `tcp_keepalive` and route-level `idle_timeout` in for
  mesh http clusters, with values coming from puppet's mesh
  configuration values.

## configuration 1.10.1

- Allow to set a health check config for the tcp_proxy.

## service 1.2.0

- Add support for additional label selectors for the tls termination Service

## configuration 1.10.0

- Set route-level idle_timeout to the supplied timeout value.

## configuration 1.9.1

- Fix a mistake in the fault injection filter that caused problematic
  configuration stanzas. It should have been caught in CI and code review

## configuration 1.9.0

- Add support for Envoy's fault injection filter.

## configuration 1.6.4 / configuration 1.7.2 / configuration 1.8.1
- Use the namespace by default for tracing service names.
  Also support overriding it in values.

## configuration 1.8.0
- Add opt-in support for ratelimiting of incoming traffic

## configuration 1.6.3 / configuration 1.7.1
- Make hardcoded `local_service` cluster name instead incorporate a service name.
  The prefix `LOCAL_` is also added to preserve ease of use in grafana.

## configuration 1.7.0

- Listen unconditionally on IPv6/IPv4

## configuration 1.2.2 / configuration 1.3.4 / configuration 1.4.4 / configuration 1.5.1 / configuration 1.6.1
- Switch from wmf-ca-certificates to ca-certificates to allow the service mesh
  to talk to endpoints with Let's encrypt issued certificates

## configuration 1.6.0 / certificate 1.1.0 / deployment 1.3.0 / name 1.1.0
- Remove cergen support from the modules
- Enable cert-manager certificates by default
  On upgrade you may drop the following keys from values.yaml files:
  - .Values.mesh.certs
  - .Values.mesh.certmanager.enabled

## configuration 1.5.0 / networkpolicy 1.2.0
- Allow traffic splitting to a mesh listener.
  This should mostly be a noop unless split are defined in the listeners

## configuration 1.4.3
- Rename parameter uses_sni to the correct sets_sni
## configuration 1.4.2
- Rename parameter uses_ingress to uses_sni.

## configuration 1.4.1
- Add tracing support (sending to otel-collector over grpc)

## configuration 1.4.0
- Stop listening for admin connections on .Values.mesh.admin.port by default.
  If this it still required (which it is for draining support)
  .Values.admin.bind_tcp needs to be set to true.
- Configuration wise this is backwards compatible with previous versions
  although it is a behavior change.

## deployment 1.2.3
- Add concurrency option

## deployment 1.2.0
- Add draining and prestop_sleep options

## configuration 1.2.0
- Use wmf-certificates instead of .Values.puppet_ca_crt; Bug: T333551

## configuration 1.1.1
- Support a custom error page T287983
- Fix the bug with the certificates configmap introduced with 1.1.0

## 1.1.0
- Support mesh service proxy without exposing a Service for public_port.
  This allows us to use the the service mesh for egress,
  without exposing a listener if it isn't needed.
