This is a verbatim import of the upstream helm chart version 15.7.1 from:
https://github.com/topolvm/topolvm/tree/topolvm-chart-v15.7.1/charts/topolvm

It was obtained with:
  helm repo add topolvm https://topolvm.github.io/topolvm/
  helm pull topolvm/topolvm --version 15.7.1

The only changes from upstream in this import are:
* Removal of the 'templates/crds' directory. We install the TopoLVM CRDs
  separately, as the admin user, via the topolvm-crds chart, following the
  pattern we use for other operators and plugins.
  See https://wikitech.wikimedia.org/wiki/Kubernetes/Upstream_Helm_charts_policy
* Removal of the bundled 'cert-manager' subchart. cert-manager is installed
  cluster-wide at WMF (see helmfile.d/admin_ng/cert-manager) and the subchart is
  disabled by default upstream (cert-manager.enabled: false). This removes the
  'charts/cert-manager' directory, the 'Chart.lock' file and the 'dependencies'
  stanza from Chart.yaml.
* The chart 'version' field uses WMF's own scheme, starting at 0.0.1. The
  upstream chart version we imported is recorded in the wmf/upstreamVersion
  annotation in Chart.yaml.
* The addition of this README-WMF.md

Further WMF customisations (image registry, lvmd.managed, RBAC, etc.) are
applied in subsequent commits on top of this import.
