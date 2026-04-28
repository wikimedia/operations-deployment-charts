# Parameters that may be overwritten from the command line
env ?= staging ## The helmfile environment to target

include ../../../../makefiles/service.mk
include ../../../../makefiles/help.mk
include ../../../../makefiles/phony.mk

env: ## outputs environment for manual testing
	@echo
	@echo "### Service test environment targeting $(env):"
	@echo "export PYTHONPATH=$(PYTHONPATH)"
	@echo "export SMOKEPY_VALUE_FILES=$(valuefiles)"
	@echo "cd" \"$$( realpath . )\"
	@echo "python3 -m unittest test_*.py $(pyunit_options)"
	@echo

check: ## checks installation on staging
	@echo "Checking installation in environment '$(env)'"
	@SMOKEPY_VALUE_FILES="$(valuefiles)" \
		python3 -m unittest test_*.py $(pyunit_options)
