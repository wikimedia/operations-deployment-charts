Global defaults for all services using the RESTBase Cassandra cluster

*Note: `global-staging.yaml` specifically points to [Cassandra
staging](https://wikitech.wikimedia.org/wiki/Cassandra/Staging). If your service does not (yet) make
use of Cassandra staging, use production values instead (e.g. `global-eqiad.yaml`).*

## cassandra_hosts
Unlike the global defaults for the AQS cluster, these definitions use a `{hostname}:{port}` format.
Eventually all hosts will need to be defined like this (eventually different instances will use
differing ports), but some auditing of services will have to happen before the AQS host list can be
changed.
