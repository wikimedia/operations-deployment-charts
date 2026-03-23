# cassandra-http-gateway

## History

This chart was created from a copy of `aqs-http-gateway`, which in turn was created by merging two
previous charts: `cassandra-http-gateway` and `druid-http-gateway`.  It is meant to supercede
`aqs-http-gateway` (it has been renamed since its use is no longer constrained to AQS).


## Scope

*NOTE: What follows is not an opinionated statement of intent; This does not document a design, it
is a (best-effort) attempt at documenting how things currently are.*

Services that use this chart share in common a YAML-formatted configuration file (which the chart
templates and mounts as `/etc/cassandra-http-gateway/config.yaml`), and all of the services (by
convention) share a number of common config parameters.  Those params are:

- service_name
- log_level
- listen_address
- listen_port


### Cassandra-using services

Additionally, most (but not all) of the services using this chart to connect to a Cassandra cluster,
and share a common configuration structure for this.  An example of that structure:

```
cassandra:
  port: 9042
  keyspace: keyspace1
  consistency: localquorum
  hosts:
    - hostname0
	- hostname1
	- hostname2
  config_table: aqs.config
  local_dc: eqiad
  authentication:
    username: dbuser
    password: dbpass
  tls:
    ca: /etc/ssl/certs/wmf-ca-certificates.crt
```

*NOTE: The `config_table` param is an AQSism currently only needed by two services.*


### Druid-using services

Some (but not all) of the Cassandra-connected services also connect to Druid, and share a common
configuration structure.  An example of that structure:

```
druid:
  host: http://hostname.discovery.wmnet
  port: 8082
  datasource: mydatasourse
  authentication:
    username: druiduser
    password: druidpass
  tls:
    ca: /etc/ssl/certs/wmf-ca-certificates.crt
```


### Data Gateway-using services

Another example use is one that retrieves data from a Cassandra cluster via an HTTP gateway service
(the [Data Gateway](https://www.mediawiki.org/wiki/Data_Gateway)), specified using a single
configuration parameter, `data_gateway_uri`.  Such a service does *not* connect directly to
Cassandra (services use the Data Gateway in lieu of Cassandra), but Data Gateway-using services that
also use Druid are possible.

*Note: At the time of writing there is only one such service, but more could be expected as this
is intended to become the defacto way of implementing AQS and AQS-like endpoints.*


### Hoarde

Services based on [Hoarde](https://gitlab.wikimedia.org/repos/sre/hoarde) are another example of
something that connects to a Cassandra cluster, but additionally they need to configure a set of
caches. An example of the config structure Hoard uses for defining cache tables:

```
tables:
  article_topics:
    lambda:
      type: grpc
      hostname: lambda0.discovery.wmnet
      port: 50501
      timeout: 2000ms

```
