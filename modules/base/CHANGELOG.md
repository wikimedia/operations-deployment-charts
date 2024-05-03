## certificate 2.0.0

WARNING: Backwards incompatible change!
certificate 1.0.0 used to include the certificates objects name into the SAN's of the certificate which made it
require manual configuration to work with default scaffolding and modules. This version aligns SAN's so that
they are compatible with default scaffolding and modules by default.

- Make the certificate module compatible to module standard (in terms of service and object names, annotations etc.)
- Align the certificate module with the mesh.certificate modules API

## meta 2.0.0

WARNING: Backwards incompatible change added. Chart maintainers that use the
service mesh will have to take action

- mesh.name.annotations removed from base.meta.pod_annotations

## statsd 1.0.1
- Add prestop sleep helper

## statsd 1.0.0
- Add templates to add prometheus-statsd-exporter to a pod

## networkpolicy 1.2.0

- Add base.networkpolicy.egress.zookeeper. It allows charts to declare
 clusters they need to talk to by name.

## networkpolicy 1.1.0

- Add base.networkpolicy.egress.mariadb. It allows charts to abstract away
  MariaDB egress networkpolicy creation by just specifying required WMF MariaDB
  Sections

## helper 1.1.0
- Add base.helper.prestop

## meta 1.0.1

- Add base.meta.labels
