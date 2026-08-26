# Wikimedia kserve-llmisvc-crd-minimal — differences from upstream

Vendored from upstream KServe **v0.20.0**. Installs the two LLMInferenceService CRDs with their
OpenAPI validation stripped, matching the approach in `charts/kserve-crd-minimal`.

## Divergence

- **Deleted** `templates/serving.kserve.io_clusterstoragecontainers.yaml` and
  `files/serving.kserve.io_clusterstoragecontainers.yaml`. The `ClusterStorageContainer` CRD is
  owned by the `kserve-crd-minimal` release. The llmisvc controller never reads that type — no
  reference anywhere under `pkg/controller/v1alpha2/llmisvc/`, and its ClusterRole grants nothing
  for it. Upstream guards the duplicate with a `lookup`, but `lookup` returns empty under
  `helm template`, so CI would validate a manifest set that is never applied.
- **Modified** `Chart.yaml` — WMF version `0.1.0`, WMF maintainers, `wmf/upstreamVersion: v0.20.0`.
- **Added** an empty `.fixtures/crds.yaml`. The Rakefile's `CDRS_GLOB` uses it to render the chart
  and generate kubeconform JSON schemas, which the workload chart's custom resources need.

## Ordering

This chart must be installed before `kserve-llmisvc-resources`. The `llminferenceservices` CRD
declares `conversion.strategy: Webhook` pointing at `llmisvc-webhook-server-service` in namespace
`kserve`, which the resources chart creates. Between the two installs, reads of that CRD fail.

Keep the two in separate releases so that destroying the control plane leaves the CRDs, and the
custom resources with them, intact.
