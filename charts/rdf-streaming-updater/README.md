# rdf-streaming-updater

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
* go to flink-rdf-streaming-updater directory
* use minikube as docker host: `eval $(minikube docker-env)`
* run blubber and create local image: `blubber .pipeline/blubber.yaml production | docker build --tag docker-registry.wikimedia.org/wikimedia/wikidata-query-flink-rdf-streaming-updater:latest --file - .`

### run rdf-streaming updater chart
* cd deployment-charts/charts
* helm install flink rdf-streaming-updater

### useful commands
* `kubectl get pods` -> shows running pods in k8 cluster
* `kubectl describe pods` -> shows more detailed information about pods
* `kubectl logs -f <podname>` -> follow the logs for a particular pod
* `minikube service rdf-streaming-updater-flink-ui` -> opens url for Flink UI

### tear down
* remove flink installation: helm uninstall flink
* delete minikube cluster: `minikube delete`
