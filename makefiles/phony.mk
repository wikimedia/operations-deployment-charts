# Utility for automatically marking (nearly) all targets as phony.
# Targets that contain a dot (.) but do not start with a dot are not marked as phony.

phony_targets := $(shell grep -h -E '^[.]?[a-zA-Z_-]*:' $(MAKEFILE_LIST) | cut -d : -f 1)
.PHONY: $(phony_targets)
