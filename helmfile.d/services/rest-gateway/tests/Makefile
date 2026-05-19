# Parameters that may be overwritten from the command line
env ?= staging ## The helmfile environment to target

include ../../../../makefiles/service.mk
include ../../../../makefiles/help.mk
include ../../../../makefiles/phony.mk

check: ## run end-to-end checks via helm test
ifeq ($(env),minikube)
	helm test restgw
else
	helmfile -f $(servicedir)/helmfile.yaml -e $(env) test
endif
