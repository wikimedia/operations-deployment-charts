# Shared functionality for Makefiles for running pyunit tests
#
# OUTPUT
# - PYTHONPATH: a suitable python path fur running smokepy (exported)
# - pyunit_options: options to pass to `python3 -m unittest`

pyunit.dir := $(dir $(lastword $(MAKEFILE_LIST)))
pydir := $(pyunit.dir)/../python

PYTHONPATH := $(abspath $(pydir))
export PYTHONPATH

pyunit_options := -vv
