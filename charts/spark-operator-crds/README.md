The CRDs are copied from upstream:
https://github.com/kubeflow/spark-operator/tree/v2.2.1/charts/spark-operator-chart/crds

This is a separate chart from the actual spark-operator chart because we wish to install
the CRDs independently of the main spark-operator, as a separate helmfile release.

If you are upgrading the spark-operator chart, please copy and update the upstream CRDs
to the templates/ directory here, and update Chart.yaml's appVersion to
match the upstream version.
(Chart.yaml version should be updated too, but it is an arbitrary
WMF only version.)

See: https://helm.sh/docs/chart_best_practices/custom_resource_definitions/
