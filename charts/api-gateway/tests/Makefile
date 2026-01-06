# Parameters may be overwritten from the command line
name ?= restgw
service ?= rest-gateway

include ../../../makefiles/chart.mk
include ../../../makefiles/help.mk
include ../../../makefiles/phony.mk

name := $(strip $(name))

uninstall: ## install gateway
	helm uninstall "$(name)"

	@echo
	@echo "Waiting for $(name) to shut down..."
	kubectl wait --for=delete pod -l app=api-gateway --timeout=60s

	@echo "$(name) is uninstalled."

install: ## uninstall gateway
	helm install "$(name)" "$(chartdir)" $(valuefiles)

	@echo
	@echo "Waiting for $(name) to come up..."

	kubectl wait --for=condition=Ready pod -l app=api-gateway -l "release=$(name)" --timeout=60s
	@echo "$(name) is up"

reinstall: uninstall install ## uninstall then install

port-forward: ## start port forwarding
	kubectl port-forward $$( kubectl get pod -l app=api-gateway -l "release=$(name)" -o name ) 8087 1666

test: ## run unit tests
	busted $(dir)/lua/test*.lua

check: ## check minikube environment
	@cd "$(servicedir)/tests" && \
		$(MAKE) check env=minikube
