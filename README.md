= Introduction =

This is the repo that powers https://releases.wikimedia.org/charts/

In this you will find the various helm charts WMF uses in developing software
and deploying it in production

= Creating a new chart =

If you want to create a new chart, use the create\_new\_service.sh script, test
it and upload a change to the gerrit repo, then await for review.

= Other stuff =

The values.yaml files provided by any chart are defaults and their purpose is
to help deployment under development clusters. Actual values used in production
are not kept here

Under rbac/ we keep the current RBAC rules instantiated in our production
infrastructure

\_scaffold/ directory is used by the create\_new\_service.sh script, best leave
it be

initialize_namespace.sh is used to create a new namespace in our current
production infrastructure

= License =

While the helm charts specification allows for a per chart license to be
specified, we are following a more strict approach.  All of the charts in this
repo MUST have the exact same license. Above said license can be found in LICENSE
