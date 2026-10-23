# gateway-api-crds

The Kubernetes Gateway API CRDs, standard channel.

This is a separate chart from anything that uses them because helm does currently
not have a proper way for upgrading/deleting CRDs provided in the "crds" directory
of a helm chart, see:
https://helm.sh/docs/chart_best_practices/custom_resource_definitions/

## Updating to a new version

Pick the version first: see the comment on `appVersion` in `Chart.yaml`.

Grab the CRDs from the release source tarball, which has one file per CRD, and
replace the contents of `templates/` with them:

```bash
VERSION=v1.4.1
curl -sSL "https://github.com/kubernetes-sigs/gateway-api/archive/refs/tags/${VERSION}.tar.gz" | tar -xz -C /tmp
rm templates/*.yaml
cp /tmp/gateway-api-${VERSION#v}/config/crd/standard/gateway.networking.k8s.io_*.yaml templates/
# Drop the trailing status block: the API server sets it, and its null fields
# fail kubeconform validation in CI. (On macOS use `sed -i ''`.)
sed -i '/^status:$/,$d' templates/*.yaml
git add templates/*.yaml
```

Then bump `version` and `appVersion` in `Chart.yaml`, and update the URL in `sources`.
