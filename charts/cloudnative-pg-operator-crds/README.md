The CRDs are copied from upstream:
https://github.com/cloudnative-pg/charts/tree/main/charts/cloudnative-pg/templates/crds

This is a separate chart from the actual cloudnative-pg-operator chart because helm does
currently not have a proper way for upgrading/deleting CRDs provided in the
"crds" directory of a helm chart.

If you are upgrading the cloudnative=pg-operator chart, please copy and update the upstream CRDs
to the templates/ directory here, and update Chart.yaml's appVersion to
match the upstream version.
(Chart.yaml version should be updated too, but it is an arbitrary
WMF only version.)

See: https://helm.sh/docs/chart_best_practices/custom_resource_definitions/
