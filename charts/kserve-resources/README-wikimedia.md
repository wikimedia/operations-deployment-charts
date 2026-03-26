# Wikimedia KServe Resources Chart - Differences from Upstream

This document describes the differences between Wikimedia's kserve-resources chart (in this repository) and the upstream KServe chart (v0.17.0).

## Summary of Changes

**Added:**
- `templates/networkpolicy.yaml` — Calico network policies for ingress/egress control

**Deleted:**
- `files/common/certmanager.yaml`, `templates/common/certmanager.yaml` — cert-manager Issuer (Wikimedia uses CFSSL)

**Modified:**
- Images moved to `docker-regimedia.org` registry
- Deployment mode set to **Knative** (upstream defaults to Standard)
- Removed **kube-rbac-proxy** sidecar (metrics on port 8080 HTTP instead of 8443 HTTPS)
- Added CFSSL `issuerRef` to Certificate for webhook certs
- Added Wikimedia helper templates (`wmf.chartname`, `wmf.releasename`, `wmf.chartid`)
- Removed `_example` documentation block from configmap
- Various domain/gateway values adapted for Wikimedia infrastructure

---

## Detailed Changes

### Added Files

#### `templates/networkpolicy.yaml`

**Reason:** Wikimedia-specific Calico network policies for the KServe controller.

This file implements ingress and egress NetworkPolicies using Calico CRDs:

- **Ingress:** Allows traffic from Kubernetes API server (webhooks on port 9443) and Prometheus monitoring (port 8080)
- **Egress:** Allows traffic to Kubernetes API server

These policies are needed because Wikimedia uses Calico for networkPolicy enforcement and the upstream chart does not include network isolation by default.

---

### Deleted Files

#### `files/common/certmanager.yaml`

**Reason:** Wikimedia uses `cfssl-issuer` instead of `cert-manager` for certificate management.

The upstream cert-manager Issuer (`selfsigned-issuer`) was removed in favor of Wikimedia's internal CFSSL-based certificate infrastructure.

#### `templates/common/certmanager.yaml`

**Reason:** Template file for the cert-manager Issuer which was removed (see above).

---

### Modified Files

#### `Chart.yaml`

**Reason:** Wikimedia chart metadata for internal deployment.

Changes:

- `version`: `v0.17.0` → `0.1.0` (Wikimedia versioning)
- `description`: Updated to mention "Wikimedia LiftWing setup"
- `maintainers`: Changed from KServe Team to Wikimedia Machine Learning Team
- `icon`: Removed (not applicable for internal chart)
- Added `wmf/upstreamVersion: v1.17.0` annotation

---

#### `values.yaml`

**Reason:** Wikimedia-specific image registry and deployment configuration.

Changes:

- **Image registry:** All images use `docker-registry.wikimedia.org` instead of upstream registries (e.g., `kserve/agent` → `docker-registry.wikimedia.org/kserve-agent`)
- **deploymentMode:** Set to `Knative` (Wikimedia uses Knative for serverless-style deployments)
- **Ingress domain:** Changed from `example.com` to `wikimedia.org`
- **knativeGatewayService:** Set to `knative-local-gateway.istio-system.svc.cluster.local` for Knative mode
- **Removed rbacProxy configuration:** The upstream includes kube-rbac-proxy settings for secure metrics, but Wikimedia does not use this sidecar
- **controller.revisions:** Enabled (`true`) for Knative mode
- **Upstream issuer:** Uses `discovery` ClusterIssuer with `cfssl-issuer.wikimedia.org` group instead of cert-manager

---

#### `templates/_helpers.tpl`

**Reason:** Added Wikimedia-specific helper templates for consistent naming.

Added templates:

- `wmf.chartname`: Returns chart name truncated to 63 chars (DNS limit)
- `wmf.releasename`: Returns release name in `name-release` format, truncated to 63 chars
- `wmf.chartid`: Returns full chart identifier `name-version`

These are used by the networkpolicy.yaml for consistent Kubernetes resource naming.

---

#### `files/common/configmap.yaml`

**Reason:** Removed the `_example` block containing extensive documentation.

The upstream configmap includes an `_example` field with detailed documentation and comments explaining all available configuration options. Wikimedia removed this block to reduce clutter since the configuration is documented elsewhere.

---

#### `files/kserve/certificate-patch.yaml`

**Reason:** Added explicit issuerRef to use Wikimedia's CFSSL-based certificate infrastructure.

The upstream Certificate does not specify an `issuerRef`, relying on a default cluster issuer. Wikimedia explicitly configures the Certificate to use the `discovery` ClusterIssuer:

```yaml
issuerRef:
  name: discovery
  group: cfssl-issuer.wikimedia.org
  kind: ClusterIssuer
```

This ensures the webhook certificate is issued by Wikimedia's CFSSL-based certificate infrastructure.

---

#### `files/kserve/clusterrolebinding-patch.yaml`

**Reason:** Simplified RBAC - removed kube-rbac-proxy resources.

Changes:

- **Removed:** `kserve-proxy-role` ClusterRole (was needed for kube-rbac-proxy tokenreview/subjectaccessreview permissions)
- **Removed:** `kserve-proxy-rolebinding` ClusterRoleBinding (was binding the proxy role to the controller service account)
- The upstream adds these RBAC resources to support the kube-rbac-proxy sidecar, but Wikimedia does not use kube-rbac-proxy

---

#### `files/kserve/deployment-patch.yaml`

**Reason:** Simplified metrics exposure - removed kube-rbac-proxy sidecar.

Changes:

- **Removed kube-rbac-proxy sidecar container:** Upstream adds a kube-rbac-proxy sidecar on port 8443 for secure metrics exposure. Wikimedia does not use this sidecar.
- **Metrics port:** Changed from `8443` (HTTPS via rbac-proxy) to `8080` (HTTP direct)
- **Prometheus annotations:** Changed from port `8443`/`https` to `8080`/`http`
- **Manager command:** Changed from `/manager` to `/usr/bin/manager`
- The controller exposes metrics directly on port 8080 without the rbac-proxy wrapper

---

#### `files/kserve/resources.yaml`

**Reason:** Likely contains Wikimedia-specific resource definitions (CRDs, etc.).

Full diff not shown - consult the actual file for details.

---

## Image Registry Differences

| Component           | Upstream Image             | Wikimedia Image                                          |
| ------------------- | -------------------------- | -------------------------------------------------------- |
| agent               | kserve/agent               | docker-registry.wikimedia.org/kserve-agent               |
| router              | kserve/router              | docker-registry.wikimedia.org/kserve-router              |
| storage-initializer | kserve/storage-initializer | docker-registry.wikimedia.org/kserve-storage-initializer |
| controller          | kserve/kserve-controller   | docker-registry.wikimedia.org/kserve-controller          |

---

## kube-rbac-proxy Removal

The upstream chart includes a kube-rbac-proxy sidecar container for secure metrics exposure. Wikimedia has removed this sidecar for simplification:

**Upstream behavior:**

- Metrics exposed on port 8443 via kube-rbac-proxy
- Proxy requires ClusterRole/ClusterRoleBinding for tokenreview and subjectaccessreview
- Prometheus scrapes via HTTPS on port 8443

**Wikimedia behavior:**

- Metrics exposed directly on port 8080 (HTTP)
- No additional RBAC permissions required
- Prometheus scrapes via HTTP on port 8080

---

## ClusterRoleBinding Security Consideration

The upstream KServe chart uses a ClusterRoleBinding that grants the KServe controller permissions across all namespaces. This is a known security trade-off:

**Security concern:**

- The ClusterRoleBinding is namespace-agnostic, granting the KServe controller cluster-wide permissions
- Wikimedia has non-KServe namespaces and may add more in the future
- Ideally, this should be reworked to use RoleBindings per namespace for least-privilege

**Why we keep the ClusterRoleBinding:**

Namespace-scoped RoleBindings were evaluated but present a significant operational problem: when you call `helmfile destroy` on a specific InferenceService namespace (e.g., `edit-check`), it destroys the Role that has permissions to clean up resources in that namespace. This creates a catch-22 where you can no longer destroy InferenceServices cleanly.

**Rejected workarounds:**

1. **Not deleting roles/bindings on destroy** — leaves orphan resources requiring manual cleanup
2. **Pre-delete hooks on all ml-services** — would wire ml-services into chart assumptions and add complexity

**Future direction:**

We could explore an automatic mechanism to add RoleBindings when new InferenceService namespaces are created, or follow up with upstream to incorporate a namespace-scoped RBAC option.
