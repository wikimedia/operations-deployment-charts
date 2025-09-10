The CRDs are copied from upstream:
https://github.com/opensearch-project/opensearch-k8s-operator/tree/main/charts/opensearch-operator/files

Upstream does not use a separate chart for the CRDs, as they grant the operator the rights to install
its own CRDs. We do not grant those rights, therefore we have this separate chart for installing them.

If you are upgrading the opensearch-operator chart, please copy and update the upstream CRDs
to the templates/ directory here, and update Chart.yaml's appVersion to
match the upstream version. (Chart.yaml version should be updated too, but it is an arbitrary
WMF only version.)

See: https://helm.sh/docs/chart_best_practices/custom_resource_definitions/

