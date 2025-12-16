## Lua Unit Tests

Lua tests reside in the `lua` directory.

The Lua tests use the [Busted](https://lunarmodules.github.io/busted/) test framework.
It can be installed via [luarocks](https://luarocks.org/).

The tests can be run using 
```bash
busted test.lua
```

or simply
```bash
make test
```

The Lua tests are stand-alone unit tests, they do not rely on helm or kubernetes. 

## End-to-End Tests

End to end tests can be run against a local minikube environment using `make`.

Available make targets:

* install: uninstall gateway using helm
* uninstall: install gateway using helm
* reinstall: uninstall then install
* port-forward: start port forwarding
* check: check minikube environment (after installing and port-forwarding)
* test: run unit tests

The `check` commands delegates to the makefile in the helmfile
directory for rest-gateway.