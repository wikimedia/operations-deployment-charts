# eventgate-analytics deployment pipeline

[EventGate](https://github.com/wikimedia/eventgate) is a service
that accepts events on an HTTP endpoint, validates them against
JSONSchemas, and produces them to Kafka.

eventgate-analytics is the deployemnt of EventGate for WMF analytics purposes.
It is intended to replace analytics usages of
[EventLogging](https://wikitech.wikimedia.org/wiki/Analytics/Systems/EventLogging).


## event-schemas
Currently, the eventgate pod expects that event schemas are available
locally in a shared volume at /srv/event-schemas.  These are cloned via git in an initContainer.  This setup will only be used for staging.  Eventually the schemas
will either be built into the container image, or will be available via a remote
HTTP schema service.

For now, we only have one git schema repo, mediawiki/event-schemas.
This eventgate-analytics instance will eventually use schemas from a different
more analytics focused repository.

## stream config
stream-config.yaml describes which schemas are allowed to be produced to which topics.
In the EventBus system, this config file (eventbus-topics.yaml) is in the mediawiki/event-schemas
repository.  It doesn't belong there. Eventually this will be moved to a separate
Stream Config service.  For EventGate, we maintain this config here in the chart repo.
This way, eaach EventGate deployment can have its own stream config.

## Minikube vs Production deployment
EventGate's service-runner config.yaml is templatized.  If `service.deployment` is 'production' logstash will be configured appropriately.  If `monitoring.enabled` is
true, statsd will be configured appropriately.

To ease in troubleshooting, EventGate's log level has also been parameterized, and is overridable by setting `.Values.main_app.log_level` (the default is 'info').

In non-production (minikube) deployment, EventGate expects that Kafka is
running in a pod. See below on how to use the kafka-dev chart for this.

NOTE!  Recent Minikube will not work with Kafka unless you run this first.
See also: https://stackoverflow.com/a/52792288/555565
```
minikube ssh
sudo ip link set docker0 promisc on
```


## Handy helm & kubectl commands for Minikube development

```
chart=eventgate-analytics

# Get the name of the deployed EventGate pod
alias pod='kubectl get pods | grep ${chart} | awk "{print \$1}"'

# Get the name of the installed helm release
alias release='helm list | grep ${chart} | awk "{print \$1"}'

# Get the EventGate service URL
alias service='eval $(helm status $(release) | grep -A 1 MINIKUBE_HOST=) && echo http://${MINIKUBE_HOST}:${SERVICE_PORT}/'

# Use the Minikube dockermachine
eval $(minikube docker-env)

# Delete the running EventGate helm chart
helm delete $(release)

# Install the EventGate helm chart
# (assumes you are cd-ed into the charts/ directory)
# replace the image name with an available EventGate image name.
# I install these into minikube's dockermachine from the
# EventGate repository, e.g.
# blubber .pipeline/blubber.yaml developement > Dockerfile & docker build -t eventgate-dev .

helm install --set main_app.image=eventgate-dev --set main_app.kafka_broker_list=$(minikube ip):30092 --set subcharts.kafka=true ./eventgate-analytics

# Or, if you've already installed a Kafka pod and don't need this to deploy it, you can
# leave off the --set subcharts.kafka part.  This expects that you have a Kafka pod deployment
# running already.  You can deploy this separately (and avoid deleting and reinstalling it during
# development) by running
helm install ./kafka-dev

# You can install the latest deployed eventgate image from WMF's
# docker registry by just ommitting the main_app.image override, e.g.
helm install --set main_app.kafka_broker_list=$(minikube ip):30092 ./eventgate-analytics

# Tail logs for the running EventGate instance
kubectl logs -f $(pod)
# You can pipe these into bunyan for easier to read output, e.g.
# kubectl logs -f $(pod) | ../eventgate/node_modules/.bin/bunyan

# Start a shell in the EventGate container
kubectl exec $(pod) -i -t -- bash

# Get the status of the helm release
helm status $(release)

# Get the status of the running EventGate pod
kubectl describe pod $(pod)

# Post an event to the EventGate service in the pod
curl -X POST -H 'Content-Type: application/json' -d@./path/to/event.json  $(service)v1/events | jq .


