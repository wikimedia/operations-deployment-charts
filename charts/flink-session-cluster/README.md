# Flink session cluster

## Running locally

### prerequisites
* docker
* minikube -> https://v1-18.docs.kubernetes.io/docs/tasks/tools/install-minikube/
  * note: I used the docker driver
* kubectl -> https://kubernetes.io/docs/tasks/tools/install-kubectl/
* helm -> https://helm.sh/docs/intro/quickstart/
* blubber -> https://wikitech.wikimedia.org/wiki/Blubber/Download

### start minikube
* `minikube start`

### build docker image locally
* go to flink-rdf-streaming-updater (generic flink image yet to be created) directory
* use minikube as docker host: `eval $(minikube docker-env)`
* run blubber and create local image: `blubber .pipeline/blubber.yaml production | docker build --tag docker-registry.wikimedia.org/wikimedia/wikidata-query-flink-rdf-streaming-updater:latest --file - .`

### run flink session cluster chart
* cd deployment-charts/charts
* helm install my-flink-cluster flink-session-cluster

### useful commands
* `kubectl get pods` -> shows running pods in k8 cluster
* `kubectl describe pods` -> shows more detailed information about pods
* `kubectl logs -f -l component=jobmanager` -> follow the logs for the jobmanager
* `kubectl logs -f -l component=taskmanager` -> follow the logs for the taskmanagers
* `kubectl get svc -l component=flink-session-cluster-ui` -> to get the exposed service to the flink UI and REST endpoint
* `kubectl get configmap -l type=flink-native-kubernetes -o yaml` -> get Flink H/A configmaps
* `kubectl configmap -l type=flink-native-kubernetes -o yaml` -> get Flink H/A configmaps

### tear down
* remove flink installation: helm uninstall flink
* delete minikube cluster: `minikube delete`
