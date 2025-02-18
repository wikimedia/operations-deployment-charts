This chart is used to create the [ValidatingAdmissionPolicy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/) objects used by all clusters. It consists of policies replicating the kubernetes [pod security standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) as well as custom policies for particular workloads.


# pod-security-standards
The policies in the `pod-security-standards` folder replicate the profiles defined in the pod security standards, but allow for mor fine grained control by excluding particular policies on a per namespace level.

They are generated from kyverno's upstream policies written in CEL using [kyverno-policy-parser.py](https://gitlab.wikimedia.org/repos/sre/kyverno-policy-parser):

```bash
pipx install git+https://gitlab.wikimedia.org/repos/sre/kyverno-policy-parser.git
kyverno-policy-parser --output-dir charts/validating-admission-policies/templates/pod-security-standards/
```

The script also creates basic chainsaw tests from upstream data but the whole process is far from perfect. So after running the script to update the policies, the resulting diff should be investigated closely (also because it might override necessary local changes).

Each resulting ValidatingAdmissionPolicy has its matching ValidatingAdmissionPolicyBinding which binds the policy to namespaces via namespace labels:

- `pod-security.wmf.org/profile`: Can be set to `baseline` or `restricted` which binds all policies of the respective profile to the namespace.
- `pod-security.wmf.org/<policy name>`: Can be set to `exclude` to exclude a particular policy from being bound to the namespace.

## Example
The following namespace would:
- apply all `baseline` policies (as `restricted` includes `baseline`)
- apply all `restricted` policies except `restrict-volume-types-restricted-volumes`

Pods scheduled in this namespace would need to adhere to the `restricted` profile while still being abe to mount arbitrary volume types.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: foo
  labels:
    pod-security.wmf.org/profile: restricted
    pod-security.wmf.org/restrict-volume-types-restricted-volumes: exclude
```


# custom-policies
Contains custom policies and bindings.

These are WMF specific hand crafted policies. For consistency sake, they should come with a binding of the same name which allows to `include` the policy at a namespace level, like:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: fancy-new-policy
spec:
  policyName: fancy-new-policy
  matchResources:
    namespaceSelector:
      matchExpressions:
      - key: pod-security.wmf.org/fancy-new-policy
        operator: In
        values:
        - include
```


# Testing
[Chainsaw](https://kyverno.github.io/chainsaw) is used for end to end testing of all policies. These tests can be run on a local [kind](https://kyverno.github.io/chainsaw) cluster or any other compatible kubernetes cluster (keep in mind that chainsaw will create multiple namespaces and resources during tests, it might also fail to clean them up).

You may run `make test` create a compatible cluster with kind and run all tests. Kind and chainsaw need to be installed though.
