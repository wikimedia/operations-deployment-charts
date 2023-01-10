# flink-kubernetes-operator Helm chart

This chart was copied from upstream [flink-kubernetes-operator's helm chart](https://github.com/apache/flink-kubernetes-operator/tree/main/helm/flink-kubernetes-operator
), and modified to work in WMF's kubernetes environments.

This chart will enable use of the [FlinkDeployment](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/docs/custom-resource/overview/#overview) 
CRD to deploy Flink clusters in single application mode.

WMF separates the installation of CRDs from the installation of this operator.
Please install the flink-kubernetes-operator-crds chart before this one.

See the [Flink Kubernetes Operator documentation](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/)
for more information.


## Modifications from upstream flink-kubernetes-operator helm chart

https://github.com/apache/flink-kubernetes-operator/tree/main/helm/flink-kubernetes-operator

- crds are moved to a separate chart: flink-kubernetes-operator-crds
- templates/networkpolicy.yaml is added to allow:
-- access to metrics port
-- egress to kubernetes API at .Values.kubernetesMasters.cidrs
-- ingress to webhook from kubernetes API at .Values.kubernetesMasters.cidrs if .Values.webhook.create is true.
 

## Summary of ServiceAccounts and RBAC

- `flink-operator` ServiceAccount is created in `.Release.Namespace`.

For each namespace in `watchNamespaces`:
- `flink` ServiceAccount is created in the watched namespace.

- A `flink-operator` Role is created with a RoleBinding giving
  the `flink-operator` ServiceAccount in `.Release.Namespace` permissions to manage
  `pods`, `services`, `events`, `configmaps`, `secrets`, `deployments`,
  `deployments/finalizers`, `replicasets`, `ingresses`, and all flink
  operator CRDs (e.g. FlinkDeployments ).  This will allow the operator
  to create Flink JobManager pods in the watched namespace.

- A `flink` Role is created with a RoleBinding giving the `flink`
  ServiceAccount in the watched namespace permissions to manage
  `pods`, `configmaps`, `deployments` and `deployments/finalizers`.
  These resources are managed by the Flink JobManager pod, as well
  as manage some minimal state needed for HA in `configmaps`.  


## Dynamic operator configuration and namespaces

If `kubernetes.operator.dynamic.namespaces.enabled` and `kubernetes.operator.dynamic.config.enabled`
are enabled for the operator, `watchNamespaces` will dynamically be
propagated through to the operator as `kubernetes.operator.watched.namespaces`
in flink-conf.yaml.  This allows you to add new namespaces to which
the operator will be able to create resources in.  You should
be able to change the value of `watchNamespaces`, upgrade your helm release,
and then deploy FlinkDeployments into new namespaces.

See:
- https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/docs/operations/configuration/#dynamic-operator-configuration
- https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/docs/operations/helm/#watching-only-specific-namespaces