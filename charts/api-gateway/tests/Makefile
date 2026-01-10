# Parameters may be overwritten from the command line
name ?= restgw ## release name (e.g. restgw)
service ?= rest-gateway ## service name (rest-gateway or api-gateway)
helm ?= helm ## the helm binary to use

include ../../../makefiles/chart.mk
include ../../../makefiles/help.mk
include ../../../makefiles/phony.mk

name := $(strip $(name))
helm := $(strip $(helm))

app := "api-gateway"

uninstall: ## uninstall gateway from kubernetes
	$(helm) uninstall "$(name)"

	@echo
	@echo "Waiting for $(name) to shut down..."
	kubectl wait --for=delete pod -l "app=$(app)" --timeout=60s

	@echo "$(name) is uninstalled."

install: ## install gateway into kubernetes
	$(helm) install "$(name)" "$(chartdir)" $(valuefiles)

	@echo
	@echo "Waiting for $(name) to come up..."

	kubectl wait --for=condition=Ready pod -l "app=$(app)" -l "release=$(name)" --timeout=60s
	@echo "$(name) is up"

reinstall: uninstall install ## uninstall and then re-install gateway on kubernetes

port-forward: ## start port forwarding for an installed gateway instance (needed to run checks)
	kubectl port-forward $$( kubectl get pod -l "app=$(app)" -l "release=$(name)" -o name ) 8087 1666

logs: ## show logs of an installed gateway instance
	kubectl logs $$( kubectl get pod -l "app=$(app)" -l "release=$(name)" -o name ) -f

test-lua: ## run Lua tests
	@echo "Running Lua tests"
	busted $(dir)/lua/test*.lua
	@echo

test-render: ## run chart render tests
	@echo "Validating chart rendering"
	HELM_BIN=$(helm) python3 -m unittest render/test_*.py $(pyunit_options)
	@echo

test-test-helpers: ## run meta-tests for the test helpers
	@echo "Testing chart rendering test helpers"
	python3 -m unittest render/test/test_*.py $(pyunit_options)
	@echo

test: test-test-helpers test-lua test-render ## run unit tests

check: ## run end-to-end checks on minikube environment (needs port-forwarding to be active)
	@cd "$(servicedir)/tests" && \
		$(MAKE) check env=minikube
