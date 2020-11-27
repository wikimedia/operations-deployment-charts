Grab the CRDs matching the calico version from the calico release tarball:
./k8s-manifests/crds.yaml

This is a separate chart from the actual calico chart because helm does
currently not have a proper way for upgrading/deleting CRDs provided in the
"crds" directory of a helm chart, see:
https://helm.sh/docs/chart_best_practices/custom_resource_definitions/