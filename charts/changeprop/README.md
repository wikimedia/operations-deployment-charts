# Changeprop

## Development environment

The instructions outlined in this document assume that Minikube is installed in the development environment.

### Minikube Kafka

In a non-production (minikube) deployment, The `changeprop` service requires a Kafka instance to run properyly.
Kafka can be deployed on a separate server, on the development machine itself (outside K8s), or deployed as a pod
on the local cluster. The instructions below focus on how to use the kafka-dev chart for pod deployment.

To deploy Kafka on the host, please follow the [Kafka Quickstart Instructions](https://kafka.apache.org/quickstart)

**NOTE**:  Recent Minikube will not work with Kafka unless you run this first.
See also [Stackoverflow - Kafka inaccessible once inside Kubernetes/Minikube](https://stackoverflow.com/a/52792288/555565)

```bash
minikube ssh
sudo ip link set docker0 promisc on
```

## Handy helm & kubectl commands for Minikube development

```bash
chart=changeprop
namespace=default

# Get the name of the deployed changeprop pod
alias pod="kubectl get pods | grep ${chart} | awk '{print \$1}'"

# Get the name of the installed helm release
alias release='helm list | grep ${chart} | awk "{print \$1"}'

# Use the Minikube dockermachine
eval $(minikube docker-env)

# Delete the running changeprop helm chart
helm delete --purge $(release)

# Install the changeprop helm chart
# (assumes you are cd-ed into the charts/ directory)
# replace the image name with an available changeprop image name.
# I installed these into minikube's dockermachine from the changeprop repository:
# blubber .pipeline/blubber.yaml development > Dockerfile && docker build -t changeprop-dev .

helm install --generate-name --set subcharts.kafka=true --set main_app.version=2020-01-15-230958-production --set main_app.kafka.broker_list={$(minikube ip):30092} changeprop

# Or, if you've already installed a Kafka pod and don't need this to deploy it, you can
# leave off the --set subcharts.kafka part.  This expects that you have a Kafka pod deployment
# running already.  You can deploy this separately (and avoid deleting and reinstalling it during
# development) by running
helm install --generate-name ./kafka-dev

# You can then install the latest deployed changeprop image from WMF's
# docker registry by just ommitting the main_app.image override:
helm install  --generate-name --set main_app.kafka.broker_list={$(minikube ip):30092} ./changeprop

# Tail logs for the running changeprop instance
kubectl logs --namespace=$namespace -f $(pod)

# Start a shell in the changeprop container
kubectl exec --namespace=$namespace $(pod) -i -t -- bash

# Get the status of the helm release
helm status $(release)

# Get the status of the running changeprop pod
kubectl describe pod $(pod)

# Get recent k8s events:
kubectl get events
```
