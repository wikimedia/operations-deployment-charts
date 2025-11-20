
## End-to-End Tests

End to end tests can be run against a local minikube environment using `make`.

Available make targets:

* install: uninstall gateway using helm
* uninstall: install gateway using helm
* reinstall: uninstall then install
* port-forward: start port forwarding
* check: check minikube environment (after installing and port-forwarding)

The `check` commands delegates to the makefile in the service definition
under helmfile.d/services.