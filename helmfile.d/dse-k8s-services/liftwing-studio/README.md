# liftwing-studio

Kubernetes deployment of [liftwing-studio](https://gitlab.wikimedia.org/repos/data-engineering/liftwing-studio):
a [LibreChat](https://github.com/LibreChat-AI/LibreChat) chat frontend over the LLMs served on
Lift Wing, with a [LiteLLM](https://docs.litellm.ai/) proxy in between so LibreChat sees a
standard OpenAI API. Runs on `dse-k8s-eqiad`, namespace `liftwing-studio`.

## Architecture

```
istio ingress :30443 ──> envoy tls-proxy :8443 ──> librechat :3080 ──localhost:4000──> litellm ──HTTPS──> inference.discovery.wmnet:30443
                                                        │                                               Host: llm-<model>.llm.wikimedia.org
                                                        ├──HTTPS──> idp.wikimedia.org  (OIDC)
                                                        ├──> ferretdb :27017 ──> postgresql-liftwing-studio-rw :5432  (MongoDB wire protocol over DocumentDB)
                                                        └──> /app/uploads, /app/client/public/images  (Ceph RBD volume)
```

One pod, three containers: `librechat`, `litellm` and the envoy tls-proxy sidecar. A single
replica with a `Recreate` strategy, because the Ceph RBD volume is single-writer.

## Key facts

| | |
|---|---|
| Releases | `liftwing-studio` (this one), `ferretdb-liftwing-studio` and `postgresql-liftwing-studio` (cloudnative-pg), all in the same namespace |
| Images | built with Blubber and published by CI from the GitLab repo above; tags are `<upstream version>-<pipeline timestamp>-<commit sha>`, pinned here with digests |
| Runtime user | both images run as uid/gid 900 with a numeric `USER`, which `runAsNonRoot` (no `runAsUser`) and `fsGroup: 900` require |
| Database | LibreChat needs MongoDB. FerretDB 2.x serves the MongoDB wire protocol on top of a cnpg cluster running the `postgresql-documentdb` image, the same stack as growthbook. `MONGO_URI` is assembled in the pod from the `username` and `password` keys of the operator's `postgresql-liftwing-studio-app` secret, since FerretDB authenticates clients as PostgreSQL users |
| Persistence | 10Gi `ceph-rbd-ssd` PVC for uploads and generated images, mounted by `subPath`. Not backed up; the database is |
| Config | `librechat.yaml` is rendered from `app.config` into a ConfigMap at `/etc/librechat`; everything else is environment |
| Secrets | `LITELLM_MASTER_KEY`, `CREDS_KEY`, `CREDS_IV`, `JWT_SECRET`, `JWT_REFRESH_SECRET`, `OPENID_CLIENT_SECRET` and `OPENID_SESSION_SECRET` under `dse-k8s_services/liftwing-studio/` in private puppet; the S3 backup credentials under `postgresql-liftwing-studio/`. The OIDC client secret is also needed on the idp side, under `profile::idp::services` |
| Models | `litellm.config.model_list`, rendered into a ConfigMap. Each entry selects an isvc by `Host: llm-<model>.llm.wikimedia.org`. LibreChat lists them through a single custom endpoint in `app.config` |
| Egress | direct HTTPS to `inference.discovery.wmnet:30443` via `networkpolicy.egress.dst_nets`, and to the idp hosts via `external_services: {cas: [idp]}`. FerretDB is reached through the cluster-wide `allow-pod-to-pod` policy |
| URL | `https://liftwing-studio.discovery.wmnet:30443`, a CNAME to `k8s-ingress-dse.discovery.wmnet` in operations/dns, with a `service::catalog` entry in puppet for probing. Internal only, so a browser needs a tunnel to that name and the internal CA |
| Auth | OIDC against idp.wikimedia.org, client `liftwing_studio`. Access is restricted to the `wmf` and `nda` LDAP groups by `required_groups` in puppet's `profile::idp::services`. Local login is off; accounts are created on first SSO login with the `USER` role, and nobody is promoted to `ADMIN` automatically |
| Timeouts | 600s on both `mesh.upstream_timeout` and `litellm_settings.request_timeout`; completions stream over SSE for minutes |
