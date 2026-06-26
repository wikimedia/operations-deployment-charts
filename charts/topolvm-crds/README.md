The CRD is copied from upstream:
https://github.com/topolvm/topolvm/tree/topolvm-chart-v15.7.1/charts/topolvm/templates/crds/topolvm.io_logicalvolumes.yaml

This is a separate chart from the actual topolvm chart because we wish to install
the CRD independently of the main topolvm chart, as a separate helmfile release
managed by the admin user, following the pattern we use for other operators and
plugins.

Notes on the WMF copy:
* Only the `topolvm.io` LogicalVolume CRD is shipped. Upstream also ships a
  legacy `topolvm.cybozu.com` CRD (used when `useLegacy: true`); we do not use
  the legacy naming, so it is omitted.
* The upstream `{{ if not .Values.useLegacy }}` guard is removed so that this is
  a plain, non-templated CRD.
* A `helm.sh/resource-policy: keep` annotation is added so that uninstalling
  this chart never deletes the CRD. Deleting the LogicalVolume CRD would
  cascade-delete every LogicalVolume custom resource, which track real LVM
  logical volumes on the hosts.

If you are upgrading the topolvm chart, please copy and update the upstream CRD
to the templates/ directory here, and update Chart.yaml's appVersion to match the
upstream version.
(Chart.yaml version should be updated too, but it is an arbitrary WMF only
version.)

See: https://helm.sh/docs/chart_best_practices/custom_resource_definitions/
