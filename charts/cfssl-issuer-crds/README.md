This is a separate chart from the actual chart because helm does
currently not have a proper way for upgrading/deleting CRDs provided in the
"crds" directory of a helm chart, see:
https://helm.sh/docs/chart_best_practices/custom_resource_definitions/

Updated CRD's can be generated via `make build/install.yaml` in the cfssl-issuer
source tree: https://gerrit.wikimedia.org/g/operations/software/cfssl-issuer