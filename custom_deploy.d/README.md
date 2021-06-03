# Purpose

Some Kubernetes software stacks like Istio don't support Helm as preferred deployment
method, but they rely on a custom solution or on a Kubernetes Operator
to configure a given cluster.
This directory contains configurations that are not Helm-related, but that can
deploy specific configurations to target clusters anyway.

# How to deploy configurations

Precise instructions about how to deploy a specific configuration should be added
to every subdirectory.

# TODO

This section is based on the feedback provided in https://gerrit.wikimedia.org/r/c/operations/deployment-charts/+/697938.

* Add to every custom deployment system not just a README, but also a "deploy"
script that can be used to interact with what yaml manifest you're adding.
* Add a task to the Rakefile to help with repetitive operations with the custom deployment.
* Possibly add some validation tasks too.