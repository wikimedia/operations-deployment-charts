This is a verbatim import of the helm chart from:
https://github.com/kubeflow/spark-operator/releases/download/v2.2.1/spark-operator-2.2.1.tgz

The only changes are:
* Removal of the 'crds' directory, since these CRDs have been added in 6b6bbce65bb10f89a8f68d5d59f942734225a064
* The addition of this README-WMF.md