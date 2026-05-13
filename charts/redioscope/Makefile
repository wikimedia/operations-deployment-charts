name = redioscope
service = $(name)

ports = 8099
selector = -l app=$(name)
cluster = aux-k8s-services

include ../../makefiles/chart.mk
include ../../makefiles/help.mk
include ../../makefiles/phony.mk

uninstall: ## uninstall gateway
	helm uninstall "$(name)"

	@echo
	@echo "Waiting for $(name) to shut down..."
	kubectl wait --for=delete pod $(selector) --timeout=60s

	@echo "$(name) is uninstalled."

install: ## install gateway
	helm install "$(name)" "$(chartdir)" $(valuefiles)

	@echo
	@echo "Waiting for $(name) to come up..."

	kubectl wait --for=condition=Ready pod $(selector) --timeout=60s
	@echo "$(name) is up"

reinstall: uninstall install ## uninstall then install

port-forward: ## start port forwarding
	kubectl port-forward $$( kubectl get pod $(selector) -o name ) $(ports)

logs: ## show logs
	kubectl logs $$( kubectl get pod $(selector) -o name ) -f

check: ## run end-to-end checks on minikube environment (needs port-forwarding to be active)
	@cd "$(servicedir)" && \
		$(MAKE) check env=minikube

smokepy: ## run smokepy container interactively
	@cd "$(servicedir)" && \
		$(MAKE) smokepy env=minikube
