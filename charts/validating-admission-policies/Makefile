# Random name for the kind cluster
KIND_CLUSTER_NAME := vaps-$(shell tr -dc 'a-z' </dev/urandom | head -c 8)

.PHONY: kind kind-delete chainsaw test

test: chainsaw kind-delete

kind:
	kind create cluster --name $(KIND_CLUSTER_NAME) --config kind.yaml

kind-delete:
	kind delete cluster --name $(KIND_CLUSTER_NAME)

chainsaw: kind
	chainsaw test
