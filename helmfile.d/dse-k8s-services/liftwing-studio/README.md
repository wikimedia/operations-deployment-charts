# liftwing-studio

Kubernetes deployment of [liftwing-studio](https://gitlab.wikimedia.org/repos/data-engineering/liftwing-studio):
a [LibreChat](https://github.com/LibreChat-AI/LibreChat) chat frontend over the LLMs served on
Lift Wing. Runs on `dse-k8s-eqiad`, namespace `liftwing-studio`.

## Architecture

```
browser
   │ HTTPS liftwing-studio.wikimedia.org
   ▼
cache_text (haproxy + ATS) ──HTTPS to liftwing-studio.discovery.wmnet, SNI liftwing-studio.wikimedia.org──> k8s-ingress-dse (LVS :30443) ──> istio ingressgateway
   │
   ▼
┌─ pod liftwing-studio-production ──────────────────────────────────────────────┐
│ envoy tls-proxy :8443 ──> librechat :3080 ──localhost:4000──> litellm         │
│                               │                                  │            │
└───────────────────────────────┼──────────────────────────────────┼────────────┘
                                │                                  │ HTTPS, Host: llm-<model>.llm.wikimedia.org
          ┌─────────────────────┼─────────────────┐                ▼
          ▼                     ▼                 ▼           inference.discovery.wmnet:30443
   idp.wikimedia.org   ferretdb :27017     Ceph RBD volume    (ml-serve istio → isvc)
       (OIDC)                │             uploads, images
                             ▼
              postgresql-liftwing-studio (cnpg, documentdb)
```

Three releases share the namespace:

| release | chart | what it runs |
|---|---|---|
| `liftwing-studio` | `liftwing-studio` | one pod: `librechat`, `litellm` and the envoy tls-proxy sidecar |
| `ferretdb-liftwing-studio` | `ferretdb` | one stateless FerretDB pod behind the `ferretdb` Service |
| `postgresql-liftwing-studio` | `cloudnative-pg-cluster` | a two-instance PostgreSQL cluster with the DocumentDB extension |

### Request path

The public name is `liftwing-studio.wikimedia.org`, a CNAME to `dyna.wikimedia.org` in
operations/dns, so browsers reach the cache_text edge. haproxy terminates TLS there with the
`*.wikimedia.org` certificate, and ATS maps the host to `https://liftwing-studio.discovery.wmnet:30443`
(`profile::trafficserver::backend::mapping_rules` in puppet). ATS keeps the original Host header and
uses it as the SNI, so it connects to the discovery name but asks for, and verifies, a certificate
for `liftwing-studio.wikimedia.org`. The host is in `cache::alternate_domains`
with `caching: 'pass'`, because every response is per-user, and its mapping rule raises ATS's
`transaction_active_timeout_out` from cache_text's 205s to 600s so long streamed responses aren't cut.

`liftwing-studio.discovery.wmnet` is a CNAME to `k8s-ingress-dse.discovery.wmnet`, the shared DSE
ingress. The istio ingressgateway terminates TLS with the namespace certificate, which carries
`liftwing-studio.wikimedia.org` as an extra SAN (`tlsExtraSANs` in admin_ng), selects this service by
SNI and Host, and re-encrypts to the envoy tls-proxy on 8443. That presents the release's own mesh
certificate and hands plain HTTP to LibreChat on 3080. The internal name still routes, but LibreChat
builds its login callback from `DOMAIN_SERVER`, so logins return to the public name.

LibreChat serves both the web client and its API. Chat completions stream back to the browser
over Server-Sent Events, which is plain long-lived HTTP; nothing on this path upgrades to
websockets. The 600s `mesh.upstream_timeout` is what lets a slow completion keep streaming.

### Models

LibreChat does not talk to Lift Wing directly. Its one custom endpoint, `Lift Wing`, points at
LiteLLM on `localhost:4000`, which presents a single OpenAI-compatible API with every model behind
it. LiteLLM exists because each Lift Wing model is a separate inference service selected by Host
header on a shared gateway: `litellm.config.model_list` maps a model name to
`https://inference.discovery.wmnet:30443/openai/v1` plus a per-model
`Host: llm-<model>.llm.wikimedia.org`. LibreChat's endpoint headers are per endpoint rather than
per model, so without LiteLLM each model would have to appear as a provider of its own.

The two sides must agree: a model is usable only if it is in LiteLLM's `model_list` and in the
`default` list of the endpoint in `app.config`. Both sides authenticate with the same
`LITELLM_MASTER_KEY`.

The models currently exist only on ml-serve-eqiad, while `inference.discovery.wmnet` is
active-active. A request resolved to codfw reaches a gateway with no matching isvc and gets a 404
rather than failing over.

### Data

LibreChat stores everything through Mongoose and supports only MongoDB. WMF does not run MongoDB,
so FerretDB translates the MongoDB wire protocol into calls on the DocumentDB extension inside a
cnpg-managed PostgreSQL cluster, the same arrangement growthbook uses. FerretDB holds no state; all
data and the S3 backups live in PostgreSQL.

FerretDB authenticates MongoDB clients as PostgreSQL roles, so there is one set of credentials:
the `username` and `password` keys of the operator-generated `postgresql-liftwing-studio-app`
secret. LibreChat assembles `MONGO_URI` from them in the pod, and FerretDB's initContainer writes
its own PostgreSQL URI from the same secret into an `emptyDir` when the pod starts. That URI is
read once, so FerretDB keeps whatever credentials existed at its last start.

The DocumentDB settings come from `_postgresql-growthbook_common_`, shared with growthbook. They
preload `pg_cron` and `pg_documentdb`, and `pg_cron` requires the database to be named `app`. The
extension and its grants are created by `postInitApplicationSQL`, which runs only when the cluster
is bootstrapped.

Uploaded files and generated images are not in the database: they sit on a 10Gi `ceph-rbd-ssd`
PVC mounted by `subPath` at `/app/uploads` and `/app/client/public/images`. The volume is
single-writer, which is why the deployment runs one replica with a `Recreate` strategy, and it is
not backed up.

### Authentication

Login is OpenID Connect against idp.wikimedia.org as the client `liftwing_studio`, registered in
puppet's `profile::idp::services`. Who may log in is decided there, not in LibreChat:
`required_groups: [nda, wmf]` makes the IDP refuse anyone outside those LDAP groups before they
reach the callback. The registration's `service_id` regex is also what the IDP validates the
callback URL against, and LibreChat derives that URL from `DOMAIN_SERVER` plus
`/oauth/openid/callback`.

LibreChat redirects every visitor straight to the IDP (`OPENID_AUTO_REDIRECT`), email login and
self-registration are off, and an account is created on first login with the `USER` role.
LibreChat promotes the first account to `ADMIN` only for local and LDAP logins, so under OIDC
nobody is an admin until someone sets the role in the `users` collection. The OpenID strategy is
registered only when `ALLOW_SOCIAL_LOGIN` is true.

### Configuration and secrets

`librechat.yaml` is rendered from `app.config` into a ConfigMap mounted at `/etc/librechat`, and
LiteLLM's config from `litellm.config` the same way. Everything else is environment:
`config.public` as plain values, `config.private` as keys of the release Secret. The private
values come from `dse-k8s_services/liftwing-studio/` in private puppet: `LITELLM_MASTER_KEY`,
`CREDS_KEY` and `CREDS_IV` (encryption of stored credentials), `JWT_SECRET` and
`JWT_REFRESH_SECRET` (sessions), and `OPENID_CLIENT_SECRET` and `OPENID_SESSION_SECRET` (the OIDC
handshake). The OIDC client secret also has to match its copy on the IDP side. There is no
database-backed settings layer that can override these values.

### Network

Egress is restricted by the chart's NetworkPolicy to the two inference VIPs on 30443 and, through
`external_services: {cas: [idp]}`, to the idp hosts. In-cluster traffic, such as LibreChat to
FerretDB and FerretDB to PostgreSQL, is allowed by the cluster-wide `allow-pod-to-pod` policy on
dse-k8s, with ingress opened by the FerretDB and cnpg charts.

### Images

Both images are built with Blubber and published by CI from the GitLab repository above, tagged
`<upstream version>-<pipeline timestamp>-<commit sha>` and pinned here by digest. They run as
uid/gid 900 with a numeric `USER`, which `runAsNonRoot` without a `runAsUser`, and the pod's
`fsGroup: 900`, both depend on.
