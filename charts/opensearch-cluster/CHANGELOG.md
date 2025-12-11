# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---
## [0.0.15]
### Added
  - Enable [certificate hot reloading]( https://docs.opensearch.org/2.19/security/configuration/tls/#hot-reloading-tls-certificates) to see if it works (ref https://phabricator.wikimedia.org/T412447).
### Deprecated
### Removed
### Fixed

## [0.0.14]
### Added
  - Set default number of replicas to "2" in order to match design doc.
### Deprecated
### Removed
### Fixed
- Give the "opensearch" user cluster-level permissions equal to the anonymous user.
- Give permissions to the `_cat/indices` API route to the anonymous and "opensearch" users.

## [0.0.13]
### Added
### Deprecated
### Removed
### Fixed
- Give the "opensearch" user permission to the bulk API route.

## [0.0.12]
### Added
### Deprecated
### Removed
### Fixed
- Set the minimum requests/limits to 4GB RAM/2 CPU cores. This aligns with our design doc.

## [0.0.11]
### Added
  - Ensure the OpenSearch operator has its own exclusive user. From now on, new clusters will get an "operator" user, and an "opensearch" user with full CRUD permissions on all indices, but no access to cluster operations.
### Deprecated
### Removed
### Fixed

## [0.0.10]
### Added
### Deprecated
### Removed
### Fixed
  - Fixed a bug where the admin username was hard-coded instead of sourced from `config.private.username`.

## [0.0.9]
### Added
### Deprecated
### Removed
  - Prometheus-related annotations. These are being clobbered rather than merged by other values files, likely due to a bug in the chart. Remove them with a comment to prevent any future confusion.
### Fixed


## [0.0.8]
### Added
  - Calico network policy to open port 9200 (REST API) globally, while reducing access to port 9300 (cluster state).
### Deprecated
### Removed
### Fixed
### Security


## [0.0.7]
### Added
  - Metadata to enable prometheus scrapes via https instead of http.
### Deprecated
### Removed
### Fixed
### Security

## [0.0.6]
### Added
- Admin x509 certificate issued by our discovery intermediate used by the security plugin to connect to Opensearch via mTLS as admin, to create the roles, role mappings, users, etc
- Service x509 certificate issued by our discovery intermediate for opensearch
- Gateway / VirtualService used to enable ingress to the OpenSearch service
### Changed
- Enable traffic to OpenSearch ports from the istio-system NS (ingress) and opensearch-operator
- Ensured the Certificate resources and associated secrets get fixed names to avoid having to override too many fields in our helmfile release value files
### Deprecated
### Removed
### Fixed
- rendering of the `opensearchCluster.tls.security.transport.generate` field
### Security
---

## [0.0.2]
### Added
### Changed
- Add `secret.yaml` template for rendering secrets. See [the upstream docs](https://github.com/opensearch-project/opensearch-k8s-operator/blob/v2.7.0/docs/userguide/main.md#securityconfig) for more details on how we must implement secrets, and `./fixtures/secret.yaml` for an idea of what the values look like.
- Add `networkpolicy_wmf.yaml`, which allows ingress to the pods.
### Deprecated
### Removed
### Fixed
### Security

## [0.0.1]
### Added
### Changed
- - **WMF-specific changes.** This is the first version of the chart modified for WMF; see
[the chart review on Wikitech](https://wikitech.wikimedia.org/wiki/Helm/Upstream_Charts/opensearch-operator) for more details.
### Deprecated
### Removed
### Fixed
### Security

## [2.6.1]
### Added
### Changed
- Updated `version` and `appVersion` to `2.6.1` for the initial release after the helm release decouple.
### Deprecated
### Removed
### Fixed
### Security

[Unreleased]: https://github.com/opensearch-project/opensearch-k8s-operator/compare/opensearch-operator-2.6.1...HEAD
[2.6.1]: https://github.com/opensearch-project/opensearch-k8s-operator/compare/opensearch-operator-2.6.0...opensearch-operator-2.6.1
