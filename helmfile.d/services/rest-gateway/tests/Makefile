dir := $(dir $(lastword $(MAKEFILE_LIST)))
pydir := $(dir)/../../../../python
PYTHONPATH := $(abspath $(pydir))
export PYTHONPATH

PYUNIT_OPTIONS := -vv

test: ## run tests on staging
	@cd "$(dir)" && \
		SMOKEPY_VALUE_FILES=../values-staging.yaml \
		python3 -m unittest test_*.py $(PYUNIT_OPTIONS)

test-minikube: ## run tests on minikube
	@cd "$(dir)" && \
		SMOKEPY_VALUE_FILES=../values-staging.yaml:../../../../charts/api-gateway/values-minikube.yaml \
		python3 -m unittest test_*.py $(PYUNIT_OPTIONS)

help: ## displays help for this makefile.
	$(info Available targets:)
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: test help
