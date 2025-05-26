KIND_CLUSTER_NAME := vaps

.PHONY: kind kind-delete chainsaw chainsaw-custom chainsaw-pss clean test

test: chainsaw kind-delete
clean: kind-delete

kind:
	@if ! kind get clusters 2>/dev/null| grep -q $(KIND_CLUSTER_NAME); then \
		kind create cluster --name $(KIND_CLUSTER_NAME) --config kind.yaml; \
	fi

kind-delete:
	kind delete cluster --name $(KIND_CLUSTER_NAME)

chainsaw: chainsaw-custom chainsaw-pss

chainsaw-custom: kind
	chainsaw test --include-test-regex "^chainsaw/templates/custom-policies/\$$"

chainsaw-pss: kind
	chainsaw test --include-test-regex "^chainsaw/templates/pod-security-standards/\$$"
