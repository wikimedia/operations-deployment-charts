# Parameters that may be overwritten from the command line
env ?= aux-k8s-eqiad ## The helmfile environment to target

chartdir := ../../../charts/redioscope

include ../../../makefiles/service.mk
include ../../../makefiles/help.mk
include ../../../makefiles/phony.mk

check: ## checks installation on staging
	helmfile -e $(env) test
