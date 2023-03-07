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

