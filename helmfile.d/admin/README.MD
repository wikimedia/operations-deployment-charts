# Admin workflow

This repo intends to keep the namespace creation and namespaced policies
configuration in code. This assumes *for now* that every namespace is
configured the same way

# Managing a namespace that was not created using helmfile

That is sadly not possible, since API would refuse to patch the namespace
object. So the only workaround is to delete the namespace and recreate it
again.

# How to recreate a cluster

In the event etcd is wiped out and we want a quick recovery

  $ cd /srv/deployment-charts/helmfile.d/admin/${CLUSTER}/
  $ KUBECONFIG=/etc/kubernetes/admin-${CLUSTER}.config helmfile apply

# whats the raw chart, can we change it?

Is a simple helm chart that applies a raw yaml object. it could make sense to
create a chart that configures everything but this way looks clean enough
