# Shared functionality for running smokepy from Makefiles.
# To be invoked from a helmfile service definition directory.
#
# INPUT
# smokepy_image: the docker image to use (optional)
# valuefiles: a list of value files for smokepy to load (typically set by service.mk)
# chartdir: the chart directory (optional)
# servicedir: the service definition directory (optional, typically PWD)
#
# OUTPUT
# - smokepy: a function for invoking smokepy

# Smokepy image to use
smokepy_image ?= docker-registry.wikimedia.org/repos/mediawiki/services/smokepy:2026-05-19-114321-candidate-v0.2-dev

# Assume that this is being invoked from a Makefile located in a service directory.
servicedir ?= .

ifdef chartdir
  smokepy_options := -v $(chartdir)/values.yaml:/tmp/chart-values.yaml:ro -e SMOKEPY_VALUE_FILES="/tmp/chart-values.yaml:$(valuefiles)"
else
  smokepy_options = -e SMOKEPY_VALUE_FILES="$(valuefiles)"
endif

# Run the smokpy container.
# If a parameter is given, it will be used as the container's entry point.
define smokepy
	docker run --rm \
		--user "$$(id -u):$$(id -g)" \
		--network host \
		-v $(servicedir):/tgt:ro \
		-w /tgt/ \
		$(smokepy_options) \
		"$(smokepy_image)"
endef

define smokepy_cli
	$(eval smokepy_options := $(smokepy_options) -it --entrypoint /bin/bash)
	@echo "Run pyunit tests as follows:"
	@echo "  echo \$$SMOKEPY_VALUE_FILES"
	@echo "  cd tests"
	@echo "  python3 -m unittest test_*.py"
	@echo
	$(call smokepy)
endef