#!/bin/bash

# A hack to get Lua from a template

dir=$( dirname "$0" )
helm template xxxx "$dir/.." -f "$dir/values-test.yaml" --show-only "templates/tests/rest_hooks.lua.tpl" | grep '^    '
