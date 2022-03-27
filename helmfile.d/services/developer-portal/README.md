Developer portal  helmfile config
=================================

Configuration to manage deployments of the developer-portal chart into the
developer-portal namespace in our staging, eqiad, and codfw clusters.

To reduce the number of places to look for settings with human eyes,
values.yaml is configured to provide both all environment overrides to the
chart's values.yaml defaults as well as eqiad specific settings. The
values-staging.yaml file only change settings that should vary from the eqiad
deployment.
