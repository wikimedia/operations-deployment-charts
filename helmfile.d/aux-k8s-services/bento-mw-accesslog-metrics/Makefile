SHELL := /bin/bash

DOCKER ?= docker
ENVIRON ?= minikube

HELMFILE_IMAGE ?= helmfile:0.171.0

GIT_ROOT := $(shell git rev-parse --show-toplevel | sed 's/^[[:space:]]*//; s/[[:space:]]*$$//')
HELMFILE := $(shell pwd | awk -F'/' '{print $$NF}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$$//')
CHART := $(shell grep chart: helmfile.yaml | awk '{print $$NF}' | tr -d '"' | awk -F'/' {'print $$NF'} | sed 's/^[[:space:]]*//; s/[[:space:]]*$$//')
CHART_VERSION := $(shell cat `git rev-parse --show-toplevel`/charts/${CHART}/Chart.yaml | yq '.version' | sed 's/^[[:space:]]*//; s/[[:space:]]*$$//')

FIXTURES_ARG :=
ifneq ($(ENVIRON),minikube)
FIXTURES_ARG := --state-values-set fixturesListFile=./fixtures.list
endif

.SILENT:
.PHONY: start-helm-repo push-chart build write-values template diff apply clean

start-helm-repo:
	$(DOCKER) container inspect chartmuseum >/dev/null 2>&1 || \
		$(DOCKER) run --name chartmuseum -d --rm -p 8080:8080 -e DEBUG=1 -e STORAGE=local -e STORAGE_LOCAL_ROOTDIR=/tmp/charts ghcr.io/helm/chartmuseum:v0.14.0

push-chart: start-helm-repo
	helm package ${GIT_ROOT}/charts/${CHART} -d /tmp/charts 1>&2 \
	&& curl -X DELETE "http://localhost:8080/api/charts/${CHART}/${CHART_VERSION}" 1>&2 \
	&& curl --data-binary @/tmp/charts/${CHART}-${CHART_VERSION}.tgz http://localhost:8080/api/charts 1>&2

build: push-chart
	$(DOCKER) run --network host -it --rm \
	    -v "${GIT_ROOT}:/srv/deployment-charts" \
	    --workdir /srv/deployment-charts/helmfile.d/aux-k8s-services/${HELMFILE} ${HELMFILE_IMAGE} \
	    sh -c "helm repo add wmf-stable http://localhost:8080; helm repo update; helmfile --state-values-set enableHooks=false --state-values-set extraValuesFile=../../../charts/${CHART}/values.yaml ${FIXTURES_ARG} -e ${ENVIRON} build"

write-values: clean push-chart
	$(DOCKER) run -u $(shell id -u):$(shell id -g) --network host -it --rm \
	   -v "${GIT_ROOT}:/srv/deployment-charts" \
	   -e HOME=/tmp \
	   -e HELM_CONFIG_HOME=/tmp/.helm/config \
	   -e HELM_CACHE_HOME=/tmp/.helm/cache \
	   -e HELM_DATA_HOME=/tmp/.helm/data \
	   --workdir /srv/deployment-charts/helmfile.d/aux-k8s-services/${HELMFILE} ${HELMFILE_IMAGE} \
	   sh -c "helm repo add wmf-stable http://localhost:8080; helm repo update; helmfile --state-values-set enableHooks=false --state-values-set extraValuesFile=../../../charts/${CHART}/values.yaml ${FIXTURES_ARG} -e ${ENVIRON} write-values"

template: push-chart
	$(DOCKER) run --network host -it --rm \
	    -v "${GIT_ROOT}:/srv/deployment-charts" \
	    --workdir /srv/deployment-charts/helmfile.d/aux-k8s-services/${HELMFILE} ${HELMFILE_IMAGE} \
	    sh -c "helm repo add wmf-stable http://localhost:8080; helm repo update; helmfile --state-values-set enableHooks=false --state-values-set extraValuesFile=../../../charts/${CHART}/values.yaml ${FIXTURES_ARG} -e ${ENVIRON} template" \
	    | grep -v "skipping\|Templating\|Building\|repositor\|Helming"

diff: push-chart
	$(DOCKER) run --network host -it --rm \
	    -v $${HOME}/.kube:/helm/.kube -v "${GIT_ROOT}:/srv/deployment-charts" \
	    --workdir /srv/deployment-charts/helmfile.d/aux-k8s-services/${HELMFILE} ${HELMFILE_IMAGE} \
	    sh -c "helm repo add wmf-stable http://localhost:8080; helm repo update; helmfile init; helmfile --state-values-set kubeConfig=/helm/.kube/config -e ${ENVIRON} diff"

apply: push-chart
	$(DOCKER) run --network host -it --rm \
	    -v $${HOME}/.kube:/helm/.kube -v "${GIT_ROOT}:/srv/deployment-charts" \
	    --workdir /srv/deployment-charts/helmfile.d/aux-k8s-services/${HELMFILE} ${HELMFILE_IMAGE} \
	    sh -c "helm repo add wmf-stable http://localhost:8080; helm repo update; helmfile init; helmfile --state-values-set kubeConfig=/helm/.kube/config -e ${ENVIRON} apply"

clean:
	find . -depth -name "helmfile-*" -type d -exec rm -rf {} +
