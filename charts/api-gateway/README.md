# API Gateway

This Helm chart runs an [Envoy](https://www.envoyproxy.io/)-based API gateway.
It is used by two Wikimedia services:

- **api-gateway** (`helmfile.d/services/api-gateway`): routes traffic to a set of
  internal discovery endpoints with JWT authentication and basic rate limiting.
  This is deprecated, see [T413438](https://phabricator.wikimedia.org/T413438).
- **rest-gateway** (`helmfile.d/services/rest-gateway`): routes to Wikimedia REST API
  endpoints with per-route JWT overrides and fine-grained Lua-based rate limiting.

## Two modes

The chart supports two modes, one for each service it is used with:

### API gateway mode
The Legacy API gateway mode is deprecated,
see [T413438](https://phabricator.wikimedia.org/T413438). 

Routes are defined via `main_app.discovery_endpoints`. Rate limiting uses simple
per-route anonymous and authenticated limits (`anon_limit` / `default_limit`)
and overrides embdded in JWTs. 

### REST gateway mode

Routes are defined via `main_app.rest_gateway_routes`. This mode enables:

- Lua-based rate limiting based on per-route policies and client classes.
- Per-endpoint JWT overrides

The Lua code lives in `charts/api-gateway/lua/restgateway.lua`. Rate limit
behaviour is documented on
[wikitech](https://wikitech.wikimedia.org/wiki/REST_Gateway/Rate_limiting).
This mode is used by the `rest-gateway` service.

## Tests

Unit tests and end-to-end tests live in `charts/api-gateway/tests/`. See
[`tests/README.md`](tests/README.md) for full instructions.

Tests can be run using `make`.
Quick start from `charts/api-gateway/tests/`:

```bash
make test          # offline unit tests (Lua + chart render)
make install       # deploy to a local minikube cluster
make port-forward  # forward gateway ports to localhost (run in a separate terminal)
make check         # run end-to-end smoke tests against the minikube installation
make uninstall     # tear down the minikube installation
```

Note that `make check` delegates to the smoke tests in
`helmfile.d/services/rest-gateway/tests/`, which can also be run directly
against the staging cluster. See that directory's README for details.

See the README in the api-gateway chart's `tests` directory for instructions
for configuring the test environment. 

## Architecture

The API Gateway chart defines a Kubernetes pod that runs Envoy.
Enovy is configured to route requests to upstream services.

To implement global rate limiting, Enovy uses the envoyproxy/ratelimit service,
which runs as a sidecar container. The ratelimit service uses Redis to store the rate
limit counters. In the production setup, we use an external Redis cluster for this,
accessed via a nutcracker for sharding and replication. Nutcracker runs as a sidecar
in the API gateway pod.

### Development environment
The development setup for API Gateway mode is defined in `values-devel.yaml`.

The development setup for REST Gateway mode is defined in `values-minikube.yaml`
under `helmfile.d/services/rest-gateway/tests/`. That file is designed to be
loaded on top of `values-staging.yaml`, which in turn overrides settings loaded
from `values.yaml`. This ensures that the test environment is similar to the
production environment. The easiest way to use the development setup of the
REST Gateway is using the Makefile in the `tests` directory, see the README in
that directory for details.

The development setup makes use of some fake services, to allow easy setup and
isolation from the production setup.

If `.Values.main_app.dev_redis` is set to true, the Helm chart will
attempt to bring up a redis sidecare along with the other components,
instead of using external Redis instances via nutcracker. This setup
does *not* use subcharts, and simply uses a local redis docker
image. When in the context of your local kubernetes setup (ie: `eval
$(minikube docker-env)`), run `docker pull redis` and the chart will
find the image to use.

To allow tesing and development without having to run real upstream services,
the `http-https-echo` service is used as a stand-in for the real upstream services.
The `http-https-echo` simply returns information about the headers the service
was passed from the client, which can be useful for debugging ratelimiting
configuration and other issues.
It can be enabled using the `main_app.http_https_echo` setting and will run as a
sidecar to Envoy. 
