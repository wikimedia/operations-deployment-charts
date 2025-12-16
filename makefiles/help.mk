# Defines a target that generates help based on comments starting with ##
# in lines that define targets or assign variables.
# Targets and variables that doe not start with a letter are ignored.

help: ## displays help
	@echo
	@echo Available targets:
	@grep -h -E '^[a-zA-Z][.a-zA-Z_-]*:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo Parameters:
	@grep -h -E '^[a-zA-Z][a-zA-Z_]* *[?:]?:?:?=.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = " *[?:]?:?:?=.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo
