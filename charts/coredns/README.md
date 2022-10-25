=== History ===
We introduced our own coredns config in
https://gerrit.wikimedia.org/r/c/operations/deployment-charts/+/523722
And then we migrated it to a separate chart (under the `charts` dir in this
repo) in https://gerrit.wikimedia.org/r/c/operations/deployment-charts/+/643936
Upstream provides a helm chart nowadays: https://github.com/coredns/helm,
but we don't use it for the moment (since most of the features like
autoscaling are currently not needed etc..).

=== Base settings ===
We support multiple versions of coredns, and the oldest one is currently set
in `values.yaml`.