Toolhub helmfile config
=======================

Configuration to manage deployments of the toolhub chart into the toolhub
namespace in our staging, eqiad, and codfw clusters.

To reduce the number of places to look for settings with human eyes,
values.yaml is configured to provide both all environment overrides to the
chart's values.yaml defaults as well as eqiad specific settings. The
values-codfw.yaml and values-staging.yaml files only change settings that
should vary from the eqiad deployment.

Some settings used in the config are imported from Puppet provisioned
resources on the deployment nodes:
* /etc/helmfile-defaults/mediawiki/mcrouter_pools.yaml - mcrouter pools
