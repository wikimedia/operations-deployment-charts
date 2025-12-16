## End-to-End Testing

Tests can be run via `make`. On a deployment server, tests can be run against the staging cluster using `make check`. In a local test environment, tests can be run against minikube using `make check env=minikube`. The environment (staging or minikube) determines which
value files are loaded. Local overrides can be specified by crating a file ending 
in `.local.yaml`, e.g. `values-minikube.local.yaml`.
