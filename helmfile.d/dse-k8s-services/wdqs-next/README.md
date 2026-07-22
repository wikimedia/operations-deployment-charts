# WDQS-next - the staging namespace for the Wikidata Query Service

The staging namespace shares most of its configuration with the default
namespace.
A few things need adjustment. This includes the hostnames and some
affinities to allow scheduling of main and scholarly pods on the same
node.
Additionally the backend pods are bound to the wdqs-test nodes via
the topolvm-balanced storageClass for the data-dir PVC. The standard
high-performance wdqs nodes provide topolvm-performance instead.

In the wdqs-next namespace only main-external and scholarly-external
are deployed. This is done to reduce the load and complexity.
