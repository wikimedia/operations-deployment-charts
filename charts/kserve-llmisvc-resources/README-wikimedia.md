# Wikimedia kserve-llmisvc-resources — differences from upstream

Vendored from upstream KServe **v0.20.0** (`oci://ghcr.io/kserve/charts/kserve-llmisvc-resources`).
This chart installs the **LLMInferenceService control plane only** — a controller Deployment, its
RBAC, webhooks and certificate. It installs no Gateway, HTTPRoute, VirtualService or Ingress.

It runs alongside `kserve-resources` without interfering with it. The controller is a separate
binary with its own scheme, leader-election ID and webhooks, it registers neither the Knative nor
the Istio APIs, and it never reads `deploy.defaultDeploymentMode`. Verified: the rendered object
names of this chart and of `kserve-resources` have an empty intersection.

## Divergence

### values.yaml

| Change | Why |
|---|---|
| `kserve.llmisvc.controller.image` -> `docker-registry.wikimedia.org/kserve-llmisvc-controller` | WMF registry |
| `imagePullPolicy: Always` -> `IfNotPresent` | WMF convention |
| `createGIECRDs: true` -> `false` | InferencePool / endpoint-picker needs Istio >= 1.27; ml-serve runs 1.24.2. Safe to omit: every GIE watch is gated on `IsCrdAvailable` (`controller.go:436-444`) and `Delete` tolerates `meta.IsNoMatchError` (`lifecycle_crud.go:65`). |
| `metricsBindAddress: 127.0.0.1` -> `0.0.0.0` | WMF Prometheus runs off-cluster on bare metal and cannot reach a loopback listener. |
| `extraArgs: [--metrics-secure=false]` | With secure metrics the controller installs controller-runtime's `WithAuthenticationAndAuthorization` filter, which requires a bearer token. WMF Prometheus presents a client certificate only, so it would get 401. |
| `controller.podAnnotations` gains `prometheus.io/{scrape,port}` | Upstream sets `prometheus.io/scrape` on the **Deployment**; Prometheus uses `role: pod` discovery and cannot see it. |
| Pruned every key except `kserve.version`, `kserve.llmisvc.*`, `commonLabels`, `commonAnnotations` | The pruned keys were read only by the templates deleted below. `values.schema.json` marks nothing as required. |

Note: `createSharedResources: false` is **not** needed here, because the templates that consumed it
are deleted. The controller still reads the `inferenceservice-config` ConfigMap that
`kserve-resources` owns, at runtime (`config_loader.go:193-205`) — that is intended.

### Deleted

- `templates/common/{certmanager,clusterstoragecontainer,configmap}.yaml` and all of `files/common/`.
  These re-render the cert-manager Issuer, the `ClusterStorageContainer/default` and the
  `inferenceservice-config` ConfigMap that the `kserve-resources` release already owns. Deleting
  them is what makes the two charts collision-free.

### Added

- `templates/networkpolicy.yaml` — two Calico policies. Upstream ships none, and ml-serve applies a
  `default-deny` GlobalNetworkPolicy to every namespace outside `kube-system` for both directions.
  Without these the apiserver cannot reach the webhooks on 9443 and the controller cannot reach the
  apiserver; since all six webhooks are `failurePolicy: Fail`, LLMInferenceService objects become
  uncreatable. Written with the chart's own `llm-isvc-resources.*` helpers so `_helpers.tpl` stays
  verbatim upstream.

### Modified

- `Chart.yaml` — WMF version `0.1.0` (chartmuseum publishes a version exactly once, and Helm 3 lint
  rejects a leading `v`), WMF maintainers, `wmf/upstreamVersion: v0.20.0`.
- `files/llmisvc/certificate-patch.yaml` — `+4` lines adding the cfssl `issuerRef`
  (`discovery` ClusterIssuer, group `cfssl-issuer.wikimedia.org`). Upstream has no values hook for
  this; an upstream PR adding `kserve.certManager.issuerRef` would remove the last patch.

## Operational notes

- The controller image puts the binary at `/manager`, because
  `files/llmisvc/deployment-patch.yaml` hardcodes `command: [/manager]`. This differs from
  `kserve-controller`, which WMF builds at `/usr/bin/manager` and patches in the chart.
- **Teardown order matters.** All six webhooks are `failurePolicy: Fail` with no
  `namespaceSelector`. While this release is down, CREATE/UPDATE of `llminferenceservices` and
  CREATE/UPDATE/DELETE of `llminferenceserviceconfigs` fail cluster-wide, which also blocks
  namespace deletion. Always destroy workload releases before this one.
- Installing a CRD while the controller is running is invisible to it: discovery is cached in a
  process-global map that is never invalidated (`pkg/utils/utils.go:240-262`). Restart the
  Deployment after adding any conditionally-watched CRD.
- `kserve.localmodel.enabled` must stay off cluster-wide. The mutating defaulter lists
  `LocalModelCache` and `LocalModelNamespaceCache` when it is on, and those CRDs are not in
  `charts/kserve-crd-minimal`.
