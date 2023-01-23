# New rules
* Environments are clusters now (as in helmfile.d/services)
* There is a value "cluster_group" to group a number of environments (clusters) together
** The cluster_group (if any) is defined in the clusters values.yaml at `values/< .Environment.Name >/values.yaml`
* There is one helmfile to rule them all (helmfile.yaml)
* You can deploy a cluster using only `helmfile -e staging-codfw -i apply`
* If you want to limit the releases you are deploying, you may use a label selector on the release:
  `helmfile -e staging-codfw -l name=flink-operator diff`

# Basic releases
Global defaults for basic releases are defined in `values/common.yaml`.
They can be overridden per cluster_group `values/< .Values.cluster_group >/values.yaml` and
environment (cluster) in `values/< .Environment.Name >/values.yaml`.

Basic releases should use the `wmf-stable/raw` chart only to deploy objects not
directly related to any chart/deployment.

## namespaces (helmfile_namespaces.yaml)
Deploys **all** namespaces, plus:
* RoleBinding for deploy users
* RoleBinding for default system account
* LimitRange
* ResourceQuota

## pod-security-policies (helmfile_psp.yaml)
* Default PodSecurityPolicies for restricted and privileged
* Corresponding ClusterRoles to access those PSP's
* Rolebinding for the kube-system namespace to the privileged role
**FIXME:** This needs investigation as it does not seem to work as intended

## rbac-rules (helmfile_rbac.yaml)
RBAC stuff that does not directly relate to a helm deployment
* ClusterRole for deploy users and prometheus
* ClusterRoleBinging for rsyslog (**TODO:** investigate why that's needed and what it does)
* ClusterRoleBindings for prometheus to access api-metrics and heapster

# Additional releases
Everything else should come in it's own folder containing it's own helmfile **with releases only**.
Default values applied to all clusters should live in `< folder >/values.yaml`.
They can be overridden per environment in `values/< .Environment.Name >/values.yaml`,
per cluster_group in `values/< .Values.cluster_group >/values.yaml`
and or per release and environment in `values/< .Environment.Name >/< .Release.Name >-values.yaml`.