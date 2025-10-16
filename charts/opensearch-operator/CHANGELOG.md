# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.8-wmf]
### Added
### Changed
### Deprecated
### Removed
### Fixed
- Scoped the leader election role/rolebinding resources to the operator namespace, instead of the tenant namespaces.
### Security

## [0.0.7-wmf]
### Added
### Changed
- Allowed the operator to watch multiple namespaces
- Added network policies allowing the operator to egress to the opensearch pods in each watched namespace
### Deprecated
### Removed
### Fixed
### Security

## [0.0.6-wmf]
### Added
### Changed
- Add a network policy resource which allows egress to the Kubernetes API from the operator pods.
### Deprecated
### Removed
### Fixed
### Security

## [0.0.5-wmf]
### Added
### Changed
- Enhance pod security settings, as required by changes
tracked in [this Phab task](https://phabricator.wikimedia.org/T362978) .
- Move WMF-specific values out of the helm chart's
`values.yaml` and into `helmfile.d/dse-k8s-services/_opensearch_common_/values.yaml`.
### Deprecated
### Removed
### Fixed
### Security



## [0.0.4-wmf]
### Added
- **WMF-specific changes.** This is the first version of the chart modified for WMF; see
[the chart review on Wikitech](https://wikitech.wikimedia.org/wiki/Helm/Upstream_Charts/opensearch-operator) for more details.
### Changed
- Split out the single operator chart into an operator chart and a CRDs chart.
### Deprecated
### Removed
- **Unnecessary ClusterRoles**. Our current design installs an operator in each OpenSearch namespace, so cluster-wide permissions are not needed.
- **kube-rbac-proxy container** The upstream chart uses this proxy for the OpenSearch performance analyzer and OpenSearch Dashboards, and metrics. None of these are currently needed for our use case.

### Fixed
### Security

---
## [2.0.0]
### Added
### Changed
- Modified `version` to `2.0.0` and `appVersion` to `v2.0`.
- Allow chart image tag to pick from `appVersion`, unless explicitly passed `tag` values in `values.yaml` file.
### Deprecated
### Removed
### Fixed
### Security

---
## [1.0.3]
### Added
### Changed
- Added missing spec `dashboards.additionalConfig`
### Deprecated
### Removed
### Fixed
### Security

---
## [1.0.2]
### Added
### Changed
- Added README.md file to charts/ folder.
### Deprecated
### Removed
### Fixed
### Security

---
## [1.0.1]
### Added
### Changed
- Updated version to 1.0.1
### Deprecated
### Removed
### Fixed
### Security

[Unreleased]: https://github.com/opensearch-project/opensearch-k8s-operator/compare/opensearch-operator-2.0.0...HEAD
[2.0.0]: https://github.com/opensearch-project/opensearch-k8s-operator/compare/opensearch-operator-1.0.3...opensearch-operator-2.0.0
[1.0.3]: https://github.com/opensearch-project/opensearch-k8s-operator/compare/opensearch-operator-1.0.2...opensearch-operator-1.0.3
[1.0.2]: https://github.com/opensearch-project/opensearch-k8s-operator/compare/opensearch-operator-1.0.1...opensearch-operator-1.0.2
