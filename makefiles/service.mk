# Shared functionality for Makefiles for deploying and checking helmfile services
#
# INPUT:
# - env: The name of a helmfile environment.
#
# OUTPUT
# - servicedir: The path to the directory containing the helmfile service definition
# - valuefiles: List of -value files separated by :, for use with smokepy.
# - PYTHONPATH: a suitable python path fur running smokepy (exported)
# - pyunit_options: options to pass to `python3 -m unittest`

ifndef env
  $(error env must be set to the name of a helmfile environment)
endif

env := $(strip $(env))

# Expect the main script to be in a subdirectory of the service definition.
entrypoint_dir := $(dir $(firstword $(MAKEFILE_LIST)))
servicedir := $(entrypoint_dir)/..

# pyunit and valuefiles for smokepy
thisdir := $(dir $(lastword $(MAKEFILE_LIST)))
include $(thisdir)/pyunit.mk

valuefiles := $(servicedir)/values.yaml

stagingfile := $(servicedir)/values-staging.yaml
ifeq ($(env),minikube)
  ifneq (,$(wildcard $(stagingfile)))
    $(info Using staging values from $(stagingfile))
    valuefiles := $(valuefiles):$(stagingfile)
  endif
endif

envfile := $(servicedir)/values-$(env).yaml
ifneq (,$(wildcard $(envfile)))
  valuefiles := $(valuefiles):$(envfile)
endif

localfile := $(servicedir)/values-$(env).local.yaml
ifneq (,$(wildcard $(localfile)))
  $(info Using local overrides from $(localfile))
  valuefiles := $(valuefiles):$(localfile)
endif
