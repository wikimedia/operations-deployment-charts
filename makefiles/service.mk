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
valuefiles := $(servicedir)/values-$(env).yaml
localfile := $(servicedir)/values-$(env).local.yaml

ifeq ($(env),minikube)
  valuefiles := ../values-staging.yaml:$(valuefiles)
endif

ifneq (,$(wildcard $(localfile)))
  $(info Using local overrides from $(localfile))
  valuefiles := $(valuefiles):$(localfile)
endif
