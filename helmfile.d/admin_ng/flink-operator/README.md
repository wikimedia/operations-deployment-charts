## Watched Namespaces

At WMF, we require that flink-kubernetes-operator is configured with
a value for [watchNamespaces](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/docs/operations/helm/#watching-only-specific-namespaces).

When installing the operator, RBAC resources will be created.  If `watchNamespaces`
is not set (or is an empty list), the default is to create k8s Cluster scoped (global)
RBAC resources, which we do not want.

To prevent this from accidentally happening, the default value of `rbac.create` is
overridden to false.  When deploying the operator, you must set
`rbac.create: true` in your cluster specific values, as well as configuring
`watchNamespaces`.


## Upgrading

Upgrading the flink-kubernetes-operator should be safe to do while
flink applications are running, as long as those applications are not
restarted while the flink-kubernetes-operator upgrade is in progress.

After upgrading production-images/flink/flink-kubernetes-operator and charts/{flink-kubernetes-operator,flink-kubernetes-operator-crds},
Bump the flink-kubernetes-operator image version in values.yaml.

After merging:

```
ssh deployment.eqiad.wmnet
sudo -i
cd /srv/deployment-charts/helmfile.d/admin_ng
helmfile -e <k8s-cluster-name> diff
# Make sure this looks as it should!

# If so, apply the changes.
# Note that this will apply all admin_ng changes, so make sure
# the only relevant changes are for flink-operator and flink-operator-crds releases.
helmfile -e <k8s-cluster-name> apply
```

