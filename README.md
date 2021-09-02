Wikimedia Helm Charts
=====================

This is the repo that powers <https://helm-charts.wikimedia.org/stable/>.

Here you will find the various helm charts the Wikimedia Foundation uses
in developing software and deploying it to production.

Creating a new chart
--------------------

If you want to create a new chart use the `create_new_service.sh` script, test
it and upload a change to [Gerrit](https://gerrit.wikimedia.org). Then wait
for a review.

### Template names are global ###

If two separate charts have templates with the same names and are deployed in
the same release, the last definition of the template will be used for both
charts. Please take this into account when designing new charts.

Since the main `_helpers.tpl` file is shared across all charts, you will
probably have to ship a different template helpers file that contains your own
templates and use it accordingly.

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

**NOTE**: During the integration testing of `helmfile.d/services` charts are
pulled from the *merged and deployed* charts in the chart repository. For this
reason, changes to a chart and related changes to its helmfile configuration
must be uploaded to gerrit and tested separately. Hemlfile changes for a new
chart version must be tested after the chart changes have been merged and
updated in the chart repository.

License
-------

While the helm charts specification allows for a per chart license to be
specified, we are following a more strict approach.  All of the charts in this
repo MUST have the exact same GPL-3.0-or-later license. See our LICENSE file
for full license information.
