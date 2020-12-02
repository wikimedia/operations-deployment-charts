# New rules
* Environments are clusters now (as in helmfile.d/services)
* There is one helmfile to rule them all (helmfile.yaml)
* You can deploy a cluster using only `helmfile -e staging-codfw sync`

# Basic releases
Global defaults for basic releases are defined in `values/values.yaml`.
They can be overridden per environment (cluster) in `values/< .Environment.Name >/values.yaml`

Basic releases should use the `wmf-stable/raw` chart only to deploy objects not
directly related to any chart/deployment.

## namespaces (helmfile_namespaces.yaml)
Deploys **all** namespaces, plus:
* RoleBinding for deploy users
* RoleBinding for deafult system account
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
* ClusterRoleBinging for rsyslog (**TODO:** incestigate why that's needed and what it does)
* ClusterRoleBindings for prometheus to access api-metrics and heapster

# Additional releases
Everything else should come in it's own folder containing it's own helmfile **with releases only**.
Default values applied to all clusters should live in `< folder >/values.yaml`.
They can be overridden per environment in `values/< .Environment.Name >/values.yaml`
and or per release and environment in `values/< .Environment.Name >/< .Release.Name >-values.yaml`.