## End-to-End Testing

Tests can be run via `make`. On a deployment server, tests can be run against the staging cluster using `make test`. In a local test environment, tests can be run against minikube using `make test-minikube`. Local adjustments can be made by copying `smokepy.example.yaml` to `smokepy.local.yaml` and modifying it as needed.  