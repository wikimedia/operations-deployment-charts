KIND_CLUSTER_NAME := vaps

.PHONY: kind kind-delete chainsaw chainsaw-custom chainsaw-pss clean ci-test

ci-test:
	@echo "No CI tests defined"

test: chainsaw kind-delete
clean: kind-delete

kind:
	@if ! kind get clusters 2>/dev/null| grep -q $(KIND_CLUSTER_NAME); then \
		kind create cluster --name $(KIND_CLUSTER_NAME) --config kind.yaml; \
	fi
	kubectl wait --for=condition=Ready nodes --all --timeout=120s --context kind-$(KIND_CLUSTER_NAME)

kind-delete:
	kind delete cluster --name $(KIND_CLUSTER_NAME)

chainsaw: chainsaw-custom chainsaw-pss

chainsaw-custom: kind
	chainsaw test --include-test-regex "^chainsaw/templates/custom-policies/$(TEST)\$$"

chainsaw-pss: kind
	chainsaw test --include-test-regex "^chainsaw/templates/pod-security-standards/$(TEST)\$$"
