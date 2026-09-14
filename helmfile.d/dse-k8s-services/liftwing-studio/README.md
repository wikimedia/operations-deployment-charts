# liftwing-studio

Kubernetes deployment of [liftwing-studio](https://gitlab.wikimedia.org/repos/data-engineering/liftwing-studio):
an [Open WebUI](https://github.com/open-webui/open-webui) chat frontend over the LLMs served on
Lift Wing, with a [LiteLLM](https://docs.litellm.ai/) proxy in between so Open WebUI sees a
standard OpenAI API. Runs on `dse-k8s-eqiad`, namespace `liftwing-studio`.

## Architecture

```
istio ingress :30443 ──> envoy tls-proxy :8443 ──> open-webui :8080 ──localhost:4000──> litellm ──HTTPS──> inference.discovery.wmnet:30443
                                                        │                                                  Host: llm-<model>.llm.wikimedia.org
                                                        ├──> postgresql-liftwing-studio-rw :5432  (cloudnative-pg, same namespace)
                                                        └──> /app/backend/data                    (Ceph RBD volume: uploads, vector store)
```

One pod, three containers: `open-webui`, `litellm` and the envoy tls-proxy sidecar. A single
replica with a `Recreate` strategy, because the Ceph RBD volume is single-writer.

## Key facts

| | |
|---|---|
| Releases | `liftwing-studio` (this one) and `postgresql-liftwing-studio` (cloudnative-pg), same namespace |
| Images | built with Blubber and published by CI from the GitLab repo above; tags are `<upstream version>-<pipeline timestamp>-<commit sha>`, pinned here with digests |
| Runtime user | both images run as uid/gid 900 with a numeric `USER`, which `runAsNonRoot` (no `runAsUser`) and `fsGroup: 900` require |
| Database | `openwebui` on the cnpg cluster; `DATABASE_URL` is read from the operator's `postgresql-liftwing-studio-app` secret (`uri` key), so no password lives in the private repo |
| Persistence | 10Gi `ceph-rbd-ssd` PVC at `/app/backend/data` for uploads and the Chroma vector store. Not backed up; the database is |
| Secrets | `LITELLM_MASTER_KEY` and `WEBUI_SECRET_KEY` under `dse-k8s_services/liftwing-studio/` in private puppet; the S3 backup credentials under `postgresql-liftwing-studio/` |
| Models | `litellm.config.model_list`, rendered into a ConfigMap. Each entry selects an isvc by `Host: llm-<model>.llm.wikimedia.org` |
| Egress | direct HTTPS to `inference.discovery.wmnet:30443`, allowed by `networkpolicy.egress.dst_nets` |
| URL | `https://liftwing-studio.discovery.wmnet:30443`, a CNAME to `k8s-ingress-dse.discovery.wmnet` in operations/dns, with a `service::catalog` entry in puppet for probing |
| Timeouts | 600s on both `mesh.upstream_timeout` and `litellm_settings.request_timeout`; completions stream for minutes |
| Config | `ENABLE_PERSISTENT_CONFIG` is on, so admin-panel settings persist in Postgres and the `config.public` values here only seed an empty database |
