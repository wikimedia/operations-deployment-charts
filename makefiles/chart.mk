# Shared functionality for Makefiles for developing helm charts
#
# INPUT:
# - cluster: The name of the directory under helmfile.d/ that contains the
#   service directory (e.g. "services").
# - service: The name of the directory under helmfile.d/$cluster that contains the
#   relevant value files.
#
# OUTPUT
# - chartdir: The path to the directory containing the helm chart.
# - servicedir: The path to the directory under helmfile.d/services that contains the
#   relevant value files.
# - valuefiles: List of -f parameters for use with helm.

ifndef service
  $(error service must be set to the name of the service directoy under helmfile.d/services)
endif

cluster ?= services

service := $(strip $(service))
cluster := $(strip $(cluster))

dir := $(dir $(firstword $(MAKEFILE_LIST)))
chartdir := $(dir)/..
servicedir := $(chartdir)/../../helmfile.d/$(cluster)/$(service)

ifeq (,$(wildcard $(servicedir)))
  $(error service directoy not found: $(servicedir))
endif

# values to be used with minikube
valuefiles := -f $(servicedir)/values.yaml

stagingfile := $(servicedir)/values-staging.yaml
ifneq (,$(wildcard $(stagingfile)))
  $(info Using staging values from $(stagingfile))
  valuefiles := $(valuefiles) -f $(stagingfile)
endif

valuefiles := $(valuefiles) -f $(servicedir)/values-minikube.yaml

localfile := $(servicedir)/values-minikube.local.yaml
ifneq (,$(wildcard $(localfile)))
  $(info Using local overrides from $(localfile))
  valuefiles := $(valuefiles) -f $(localfile)
endif