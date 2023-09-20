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
