= Introduction =

This is the repo that powers <https://helm-charts.wikimedia.org/stable/>.

Here you will find the various helm charts the Wikimedia Foundation uses
in developing software and deploying it to production.

= Creating a new chart =

If you want to create a new chart use the `create_new_service.sh` script, test it
and upload a change to [Gerrit](https://gerrit.wikimedia.org). Then wait for a review.

== Template names are global. ==

If two separate charts have templates with the same names and are deployed in
the same release, the last definition of the template will be used for both charts.

Please take this into account when designing new charts.

Since the main `_helpers.tpl` file is shared across all charts, you will
probably have to ship a different template helpers file that contains your own
templates and use it accordingly.

= Other stuff =

The `values.yaml` files provided by any chart are defaults and their purpose is
to help deployment under development clusters. Actual values used in production
are not kept here.

In `rbac_` files we keep the current RBAC rules instantiated in our production
infrastructure.

The `_scaffold/` directory is used by the `create_new_service.sh` script, it's best
to leave it alone.

`initialize_namespace.sh` is used to create a new namespace in our current
production infrastructure.

= Updating a Chart =

If you want to update an existing chart then changes should be made to it in
the `charts/` directory.

After making the changes the chart version should be
incremented in the respective `Chart.yaml` file.

The resulting files and changes should then be uploaded to [Gerrit](https://gerrit.wikimedia.org) for code review.

== Basic sanity checks ==

Charts are linted using `helm lint` and `helm template`; the resulting
templates are also checked to ensure they produce valid YAML files.

Since you might want to test various features in your charts, helm
template will be run both with the default values in the chart and
with values provided by any YAML file in the `.fixtures/` directory.

In addition to this, all service deployments under `helmfile.d/services`
are checked as well. Given some of those would need private data that
is not available in testing/development, you can provide a special
file called `.fixtures/private_stub.yaml` to simulate populating such
data in deployments.

= License =

While the helm charts specification allows for a per chart license to be
specified, we are following a more strict approach.  All of the charts in this
repo MUST have the exact same license. Above said license can be found in LICENSE.
