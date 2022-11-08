The API objects in this chart are a combination of what can be found in the
calico release tarball ./k8s-manifests/calico-typha.yaml or
https://github.com/projectcalico/calico/tree/v3.23.3/calico/_includes/charts/calico
as well as in the "calico the hard way" documentation at
https://docs.projectcalico.org/getting-started/kubernetes/hardway/

A to mention difference is that we don't install CNI plugins and configuration
via this helm chart but via puppet and that we split up the kubernetes service
accounts and RBAC rules for calico-node, calico-cni and typha which the release
manifests do not (but "calico the hard way" does).