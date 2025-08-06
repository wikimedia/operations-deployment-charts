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
- package.json and templates/vendor use [sextant](https://gitlab.wikimedia.org/repos/sre/sextant)
  for networkpolicy_1.2.0.tpl
- templates/networkpolicy.yaml is added to allow:
-- ingress access to metrics port
-- egress-basic using WMF's vendor/base/networkpolicy_1.2.0.tpl.
   Set `networkpolicy.egress.enabled: true` in your helmfile values to use this.
   If you enable egress, you must also set at least one of `networkpolicy.egress.dst_nets`
   or `networkpolicy.egress.dst_ports`.
-- egress to kubernetes API at .Values.kubernetesMasters.cidrs
-- ingress to webhook from kubernetes API at .Values.kubernetesMasters.cidrs if .Values.webhook.create is true.
- Added .fixtures for CI.
- Lowered operator logging level from ERROR to WARN
## Upgrading from upstream helm chart.

TODO: add better instructions.

The basic idea is to copy all files from upstream helm chart, and keep any of the
customizations noted in "Modifications from upstream..."  above.

Ideally we can keep all custom modifications in helm template files that are not
present in the upstream helm chart, e.g. networkpolicy.yaml.
In the cases where there are changes to a file used by upstream, we should
submit a JIRA and PR to get our changes upstreamed.

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