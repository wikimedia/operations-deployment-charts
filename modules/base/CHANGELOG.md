## external-services-networkpolicy 1.2.0

- Allow the whole `selector` NetworkPolicy field to be overriden via the
  `external_services_selector` value (empty by default).

## helper 1.1.4

- Remove `tpl` from `base.helper.resourcesDataChecksum` template, to allow
  more flexibility when generating config-maps with special/reserved keywords
  for Helm templates.

## meta 2.0.2
- Add the `checksum/configuration` annotation to the base pod annotation template,
  that computes a stable checksum on all configmap resources defined in the `configmap.yaml`
  file.

## meta 2.0.1
- Secret checkums are now only computed on their data, meaning that they will remain
  stable if only the Secret metadata changes.

## helper 1.1.3

- Intreoduce a new `base.helper.resourcesDataChecksum` template, aiming at computing
  a checksum of a ConfigMap or Secret, based on their `data`, `stringData` or `binaryData`
  content only.

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
