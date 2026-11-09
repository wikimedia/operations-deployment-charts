# KEDA at WMF

Vendored from the upstream chart: https://github.com/kedacore/charts, tag
v2.21.0 (`keda/`). Upstream files are unchanged, apart from:

* `Chart.yaml`: WMF maintainers and the `wmf/upstreamVersion` annotation.
* A `calico` network policy flavor, alongside upstream's `cilium` and `kubernetes`
  ones: `templates/_calico.tpl`, `templates/*/calico-networkpolicy.yaml` and the
  `networkPolicy.calico` values. Proposed upstream: <upstream PR link>.

WMF-specific settings (images, resources, Prometheus egress) go in the admin_ng
release values, `helmfile.d/admin_ng/keda/values.yaml`, not in this chart.

Images are built in https://gitlab.wikimedia.org/repos/data-engineering/keda:
`keda`, `keda-metrics-apiserver` and `keda-admission-webhooks`. The binaries sit at the
paths upstream's templates run them from (`/keda`, `/keda-adapter`,
`/keda-admission-webhooks`).

## Upgrading

1. Bump `KEDA_VERSION` in the GitLab repo; merging publishes new images.
2. Replace everything here except the files above with the new upstream chart,
   and re-apply the `Chart.yaml` maintainers and annotation and, unless upstream has
   merged it by then, the `calico` flavor.
3. Bump the image tags in `helmfile.d/admin_ng/keda/values.yaml`.
