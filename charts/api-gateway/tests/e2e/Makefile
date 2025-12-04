dir := $(dir $(lastword $(MAKEFILE_LIST)))
chartdir := $(dir)/../..

name ?= restgw
service ?= rest-gateway

servicedir := $(chartdir)/../../helmfile.d/services/$(service)

uninstall: ## install rest gateway
	helm uninstall "$(name)"

	@echo
	@echo "Waiting for $(name) to shut down..."
	kubectl wait --for=delete pod -l app=api-gateway --timeout=60s

	@echo "$(name) is uninstalled."

install: ## uninstall rest gateway
	helm install "$(name)" "$(chartdir)" -f "$(servicedir)/values-staging.yaml" -f "$(chartdir)/values-minikube.yaml"

	@echo
	@echo "Waiting for $(name) to come up..."

	kubectl wait --for=condition=Ready pod -l app=api-gateway -l "release=$(name)" --timeout=60s
	@echo "$(name) is up"

port-forward: ## start port forwarding
	kubectl port-forward $$( kubectl get pod -l app=api-gateway -l "release=$(name)" -o name ) 8087 1666

test-minikube: ## run minikube tests
	cd "$(servicedir)/tests" && \
		$(MAKE) test-minikube

help: ## displays help for this makefile.
	$(info Available targets:)
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: install uninstall port-forward test-minikube help
