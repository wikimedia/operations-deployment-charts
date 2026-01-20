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

# setup
dir := $(dir $(firstword $(MAKEFILE_LIST)))
servicedir := $(dir)/..

# python
pydir := $(servicedir)/../../../python
PYTHONPATH := $(abspath $(pydir))
export PYTHONPATH

# pyunit and smokepy
pyunit_options := -vv
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
