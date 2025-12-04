## Lua Unit Tests

Lua tests reside in the `lua` directory.

The Lua tests use the [Busted](https://lunarmodules.github.io/busted/) test framework.
It can be installed via [luarocks](https://luarocks.org/).

The tests can be run using 
```bash
busted test.lua
```

The Lua tests are stand-alone unit tests, they do not rely on helm or kubernetes. 

## End-to-End Tests

The `e2e` directory contains end-to-end tests that run against a concrete
deployment of this chart.

TBD: makefile instructions
