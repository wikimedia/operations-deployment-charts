This is a separate chart from the actual chart because helm does
currently not have a proper way for upgrading/deleting CRDs provided in the
"crds" directory of a helm chart, see:
https://helm.sh/docs/chart_best_practices/custom_resource_definitions/

Updated CRD's can be generated via `make build/install.yaml` in the cfssl-issuer
source tree: https://gerrit.wikimedia.org/g/operations/software/cfssl-issuer

Then split the file per resource using kubectl-slice:
kubectl-slice -t "{{.metadata.name}}.yaml" --skip-non-k8s -f cfssl-issuer/build/install.yaml -o .

kube-slice can be found at: https://github.com/patrickdappollonio/kubectl-slice

"creationTimestamp: null" fields need to be removed from updated CRDs as those will trigger
validation errors in kubeconform.
