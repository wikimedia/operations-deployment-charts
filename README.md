Wikimedia Helm Charts
=====================

This is the repo that powers <https://helm-charts.wikimedia.org/stable/>.

Here you will find the various helm charts the Wikimedia Foundation uses
in developing software and deploying it to production.

Creating a new chart
--------------------

If you want to create a new chart:

### Pre-requisites ###

* Python 3.9 or higher
* [sextant](https://gitlab.wikimedia.org/repos/sre/sextant/-/blob/main/README.md), our tool to manage helm charts, which you can install with
  `pip3 install sextant`
* Ruby 3.0 or higher
* `rake`, the ruby task executor
* docker or another container engine

### Steps ###

1. run `./create_new_service.sh`
2. follow the prompts. This will create your chart under `charts/<your-chart-name>`
3. Modify the default chart to fit your needs
4. Validate your new chart with our CI system: `rake run_locally["check_charts[lint/validate\,<your-chart-name>]"]`. WARNING: on M1 macs this could be unbearably slow at the moment.
5. test the new chart in minikube. WARNING: on M1 macs this could be very slow at the moment.
6. commit and upload the change to [Gerrit](https://gerrit.wikimedia.org)
7. wait for/request a review

### Template names are global ###

If two separate charts have templates with the same names and are deployed in
the same release, the last definition of the template will be used for both
charts. Please take this into account when designing new charts.


Other stuff
-----------

The `values.yaml` files provided by any chart are defaults and their purpose
is to help deployment under development clusters. Actual values used in
production are not kept here.

The `_scaffold/` directory is used by the `create_new_service.sh` script, it's
best to leave it alone.

Updating a Chart
----------------

If you want to update an existing chart then changes should be made to it in
the `charts/` directory.

The changes should include incrementing the chart's version in the respective
`Chart.yaml` file.

The resulting files and changes should then be uploaded to
[Gerrit](https://gerrit.wikimedia.org) for code review.

How to use modules in a chart
-----------------------------

Every chart created by our scaffolding will have:
* A `package.json` file, where the modules we're using in that chart are indicated. In this file only major.minor versions should be specified
* A `package.lock` file where the aforementioned dependencies are
  frozen to a specific version
* A `templates/vendor` directory where the modules at the correct version are copied.
To manage these dependencies, we use a tool called `sextant`. Please see its [README](https://gitlab.wikimedia.org/repos/sre/sextant/-/blob/main/README.md) for details on its usage.


Linters and tests
-----------------

Charts are linted using `helm lint` and `helm template`; the resulting
templates are also checked to ensure they produce valid YAML files.

Many charts use feature flags like `monitoring.enabled: true` to include or
omit artifacts from the generated configuration. These optional features can
and should be tested by providing values overrides for each feature flag. The
tests will run the lint and template steps once with just your `values.yaml`
data and then again for each YAML file in the chart's `.fixtures/` directory.

In addition to the basic linting and template validation, all service
deployments under `helmfile.d/services` are checked by each test run. Settings
expected to be loaded from puppet managed files under /etc/helmfile-defaults
during a deployment are *not* present in the testing environment. You can
provide necessary values for testing by creating
a `helmfile.d/services/$SERVICE/.fixtures.yaml` file to simulate production
data.

License
-------

While the helm charts specification allows for a per chart license to be
specified, we are following a more strict approach.  All of the charts in this
repo MUST have the exact same GPL-3.0-or-later license. See our LICENSE file
for full license information.
