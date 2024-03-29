# EventGate deployment pipeline

[EventGate](https://github.com/wikimedia/eventgate) is a service
that accepts events on an HTTP endpoint, validates them against
JSONSchemas, and produces them to Kafka.

## Minikube Kafka
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
chart=eventgate

# Get the name of the deployed EventGate pod
alias pod="kubectl get pods | grep ${chart} | awk '{print \$1}'"

# Get the name of the installed helm release
alias release='helm list | grep ${chart} | awk "{print \$1"}'

# Get the EventGate service URL
alias service='eval $(helm status $(release) | grep -A 1 MINIKUBE_HOST=) && echo http://${MINIKUBE_HOST}:${SERVICE_PORT}/'

# Use the Minikube dockermachine
eval $(minikube docker-env)

# Delete the running EventGate helm chart
helm delete --purge $(release)

# Install the EventGate helm chart
# (assumes you are cd-ed into the charts/ directory)
# replace the image name with an available EventGate image name.
# I install these into minikube's dockermachine from the
# EventGate repository:
# blubber .pipeline/blubber.yaml development > Dockerfile && docker build -t eventgate-dev .

helm install --set main_app.image=eventgate-dev --set main_app.conf.kafka.conf."metadata\.broker\.list"={$(minikube ip):30092} --set subcharts.kafka=true ./eventgate

# Or, if you've already installed a Kafka pod and don't need this to deploy it, you can
# leave off the --set subcharts.kafka part.  This expects that you have a Kafka pod deployment
# running already.  You can deploy this separately (and avoid deleting and reinstalling it during
# development) by running
helm install ./kafka-dev

# You can then install the latest deployed eventgate image from WMF's
# docker registry by just ommitting the main_app.image override:
helm install --set main_app.conf.kafka.conf."metadata\.broker\.list"={$(minikube ip):30092} ./eventgate

# Tail logs for the running EventGate instance
kubectl logs --namespace=$namespace -f $(pod)
# You can pipe these into bunyan for easier to read output:
# kubectl logs --namespace=$namespace -f $(pod) | ../eventgate/node_modules/.bin/bunyan

# Start a shell in the EventGate container
kubectl exec --namespace=$namespace $(pod) -i -t -- bash

# Get the status of the helm release
helm status $(release)

# Get the status of the running EventGate pod
kubectl describe pod $(pod)

# Get recent k8s events:
kubectl get events

# Post an event to the EventGate service in the pod
curl -X POST -H 'Content-Type: application/json' -d@./path/to/event.json  $(service)v1/events | jq .
