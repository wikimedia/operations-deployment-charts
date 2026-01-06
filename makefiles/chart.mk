# Shared functionality for Makefiles for developing helm charts
#
# INPUT:
# - service: The name of the directory under helmfile.d/services that contains the
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

service := $(strip $(service))

dir := $(dir $(firstword $(MAKEFILE_LIST)))
chartdir := $(dir)/..
servicedir := $(chartdir)/../../helmfile.d/services/$(service)

ifeq (,$(wildcard $(servicedir)))
  $(error service directoy not found: $(servicedir))
endif

# values to be used with minikube
valuefiles = -f "$(servicedir)/values-staging.yaml" \
    -f "$(servicedir)/values-minikube.yaml"

localfile := $(servicedir)/values-minikube.local.yaml

ifneq (,$(wildcard $(localfile)))
  $(info Using local overrides from $(localfile))
  valuefiles := $(valuefiles) -f $(localfile)
endif