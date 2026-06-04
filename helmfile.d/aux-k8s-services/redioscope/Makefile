# Parameters that may be overwritten from the command line
env ?= aux-k8s-eqiad ## The helmfile environment to target

include ../../../makefiles/service.mk
include ../../../makefiles/help.mk
include ../../../makefiles/phony.mk

check: ## checks installation
	@echo "Checking installation in environment '$(env)'"
	@cd "$(servicedir)/tests" && \
		SMOKEPY_VALUE_FILES="$(valuefiles)" \
		python3 -m unittest test_*.py $(pyunit_options)
