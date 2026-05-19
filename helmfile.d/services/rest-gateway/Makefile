# Parameters that may be overwritten from the command line
env ?= staging ## The helmfile environment to target
helmfile ?= helmfile ## the helmfile binary to use
kubeconfig ?= $(if $(filter minikube,$(env)),,/etc/kubernetes/rest-gateway-deploy-$(env).config) ## kubeconfig for kubectl; empty for minikube (uses ~/.kube/config)
kubectl := kubectl $(if $(kubeconfig),--kubeconfig=$(kubeconfig),)

chartdir := ../../../charts/api-gateway

include ../../../makefiles/service.mk
include ../../../makefiles/smokepy.mk
include ../../../makefiles/help.mk
include ../../../makefiles/phony.mk

helmfile := $(strip $(helmfile))

smokepy: ## run smokepy container interactively
	@echo
	@echo "### Standalone Smokepy container for $(env) environment"
	$(call smokepy_cli)

check_timeout := 300
check: ## checks installation on staging
	# FIXME # FIXME # FIXME # FIXME
    # Make this work with helmfile. tricky to test localy, need to override helm binary (from global.yaml)
	@echo "Checking release in $(env) environment"
	$(helmfile) -e '$(env)' --timeout $(check_timeout) test
	$(kubectl) logs -n rest-gateway api-gateway-main-smokepy
