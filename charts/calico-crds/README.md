Grab the CRDs matching the calico version from the calico release tarball:
kubectl-slice -t "{{.metadata.name}}.yaml" --skip-non-k8s -f CALICO-TAR/k8s-manifests/crds.yaml -o .

This is a separate chart from the actual calico chart because helm does
currently not have a proper way for upgrading/deleting CRDs provided in the
"crds" directory of a helm chart, see:
https://helm.sh/docs/chart_best_practices/custom_resource_definitions/

kube-slice can be found at: https://github.com/patrickdappollonio/kubectl-slice
