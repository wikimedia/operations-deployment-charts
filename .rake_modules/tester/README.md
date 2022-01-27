# Module Tester

This module implements the CI runners for the deployment-charts repository.

This repository contains helm charts and helmfile deployments (which use
helm charts to deploy kubernetes manifests onto the clusters).

On each of these properties, we want to do the following:
* linting the object with the tools themselves
* validating the outcome of running the command on the object is a valid yaml
  and it's semantically valid for kubernetes.
* Finding out any diff introduced by the patchset in any manifest, compared to
   the baseline (what is in origin/master at the moment)

## Code organization

The "public api" of the module offers two factory methods:
* `Tester.runner` that generates the controller, that we call Runners
* `Tester.view` which unimaginatively generates a view class.

### TestRunners (file: runner.rb)

A TestRunner class does the following things:
* Collects assets to test, which could be charts, deployments, etc.
* For each asset, it runs the configured tests, which could be any combination
  of `lint`, `diff` and `validate`

Subclasses typically just have to implement the `find_assets` method and/or
define a different `Asset` class.

### Assets (file: asset.rb)

Asset classes are representation of an object to test.

When instantiated by the `find_assets` method of the runner, an asset will
first collect any special test cases, we might have defined, using the
`collect_fixtures` private method.

So for instance a `ChartAsset` looks into the `.fixtures` directory of the
chart to find various test cases the chart author has designed; while a
`HelmfileAsset` will run `helmfile build` and find all the environments
configured there, and use that list as the list of fixtures.

An asset will run commands and the results of those executions is stored
in the data structure `asset.result`. We encapsulate the results of executing
commands in `Outcome` classes.


### Outcomes (file: outcome.rb)

Ever command executed in an asset, and in general the result of any test we
perform, will be contained in a `TestOutcome` subclass.

Each outcome object is expected to respond to the `ok?` returning a boolean
true/false, and to contain methods to access `out` (stdout), `err` (stderr), 
`exit_status` and `command` (a string with the command the outcome refers to).

This structure is flexible enough that outcome classes can be adapted to encapsulate
the results of tests that don't shell out, like validating a yaml document.
