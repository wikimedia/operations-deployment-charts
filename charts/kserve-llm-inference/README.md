# kserve-llm-inference

Renders **LLMInferenceService** resources for LiftWing, plus the WMF runtime preset they
depend on. This is the llmisvc counterpart to `charts/kserve-inference`.

It is a **separate chart on purpose**. `helmfile.d/ml-services/*/helmfile.yaml` pins no
version for `wmf-stable/kserve-inference`, so adding templates there would reach every
LiftWing namespace on its next apply.

Requires the `kserve-llmisvc-crd-minimal` and `kserve-llmisvc-resources` releases in the
`kserve` namespace.

## What it renders

| Object | Notes |
|---|---|
| `LLMInferenceServiceConfig/kserve-config-llm-template` | The runtime preset, in the **release namespace** |
| `LLMInferenceService` | One per `llm_inference_services` entry |
| `NetworkPolicy` (k8s) | Ingress on the vLLM port |
| `NetworkPolicy` (Calico) | Egress to `networkpolicy.egress.dst_nets`, when set |

It renders no ServiceAccount, Deployment, Service, Gateway, HTTPRoute, VirtualService or
Ingress. The controller creates the Deployment and Service; the ServiceAccount is the one
`kserve-inference` already owns in the namespace.

## Three things that are load-bearing

**The preset name.** For a single-node service with no workers the controller appends a base
ref named exactly `kserve-config-llm-template`. If no config with that name resolves, the
service sits at `PresetsCombined=False / ConfigNotFound` forever. Lookup order is the
service's own namespace first, then `kserve`.

**The preset namespace.** It is rendered into the release namespace, never `kserve`.
`PREVENT_WELL_KNOWN_CONFIG_DELETION` defaults to true and the validating webhook refuses to
delete a well-known name only when the namespace is `kserve`. A preset there is undeletable,
which breaks `helm uninstall` and atomic rollback. Only one release per namespace may own it.

**The `storage-initializer` init container stanza.** It exists solely to attach a
securityContext and resources to the init container the controller injects. Upstream's
`CreateInitContainerWithConfig` sets no securityContext and `StorageInitializerConfig` has no
field for one, so the chart value `kserve.storage.containerSecurityContext` in
`kserve-llmisvc-resources` is dead code. Without this stanza PodSecurity `restricted` rejects
every pod.

## The runtime

`ml/amd-vllm022` — ROCm 7.2.0, vLLM 0.22.1, gfx90a and gfx942. The image has no
ENTRYPOINT, so the preset supplies the command: `vllm serve /mnt/models`, the OpenAI API
server, on port 8000.

This is a **different contract** from the existing `kserve-inference` images, which are
`kserve.Model` subclasses served by `kserve.ModelServer()` on port 8080 at
`/v1/models/<name>:predict`. Existing InferenceServices are unaffected by this chart, and
their images are not reusable here.

`{{ .Spec.Model.Name }}` in the command is evaluated by the **controller**, not Helm. It is
emitted literally on purpose. A Go-template error there is a hard CREATE rejection, because
the controller validates the preset against a synthetic sample on admission.

## Adding a service

```yaml
llm_inference_services:
  llm-qwen3-14b:
    model:
      uri: s3://wmf-ml-models/llm/qwen3-14b-fp8/
    replicas: 1
    template:
      containers:
        - name: main
          resources:
            requests: {cpu: "16", memory: 16Gi, ephemeral-storage: 30Gi, amd.com/gpu: "1"}
            limits:   {cpu: "16", memory: 16Gi, ephemeral-storage: 35Gi, amd.com/gpu: "1"}
          env:
            - name: VLLM_ADDITIONAL_ARGS
              value: "--max-model-len 16384"
```

Name services `llm-*` if they should later be publicly routable: rest-gateway's
`liftwing_llm` route group already matches `(llm-[\w.-]+)` by regex.

Resource requests and limits must be explicit. The namespace LimitRange defaults to
100Mi/100m, which no LLM starts under, and both must sit inside the namespace
ResourceQuota. `template` is a free-form PodSpec overlay merged over the preset by
container name — GPUs, tolerations and node pinning go there.

## Not supported

No `spec.router`, so no Gateway API objects and no external exposure — services are
reachable in-cluster at `<name>-kserve-workload-svc.<namespace>.svc`.

Never set `spec.router.scheduler`: it requires a GIE v1 `InferencePool` CRD with no
availability guard, and InferencePool needs Istio >= 1.27 while ml-serve runs 1.24.2.

No `spec.worker` (multi-node): the upstream worker presets add `IPC_LOCK`, `SYS_RAWIO` and
`NET_RAW`, which PodSecurity `restricted` forbids.

No `spec.scaling`: it needs WVA and KEDA, neither of which is deployed.
