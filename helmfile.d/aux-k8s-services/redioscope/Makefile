# Parameters that may be overwritten from the command line
env ?= aux-k8s-eqiad ## The helmfile environment to target

chartdir := ../../../charts/redioscope

include ../../../makefiles/service.mk
include ../../../makefiles/help.mk
include ../../../makefiles/phony.mk

smokepy: ## run smokepy container interactively
	@echo
	@echo "### Smokepy container for environment targeting $(env)"
	$(call smokepy_cli)

check: ## checks installation on staging
	@echo "Checking installation in environment '$(env)'"
	$(call smokepy)
