# Bento: local development on kind

This guide provides step-by-step instructions for setting up a local Kubernetes development environment using **Kind**, running a local **Chartmuseum** Helm repository, templating with **Helmfile**, and deploying a **Kafka** cluster via Strimzi.

**Bento** relies on this Kafka cluster to provide a complete local environment for building, testing, and fully developing your data streaming pipelines.

---

## Prerequisites

Ensure you have the following tools installed on your host machine:
* [Docker](https://docs.docker.com/get-docker/)
* [kind](https://kind.sigs.k8s.io/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [yq](https://github.com/mikefarah/yq)

---

## 1. kafka on kind
* Create a `kind.yaml` configuration file for a multi-node cluster (1 control-plane and 5 workers):
    ```yaml
    # a cluster with 1 control-plane nodes and 5 workers
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
    - role: control-plane
      image: kindest/node:v1.31.14@sha256:6f86cf509dbb42767b6e79debc3f2c32e4ee01386f0489b3b2be24b0a55aac2b
    - role: worker
      image: kindest/node:v1.31.14@sha256:6f86cf509dbb42767b6e79debc3f2c32e4ee01386f0489b3b2be24b0a55aac2b
    - role: worker
      image: kindest/node:v1.31.14@sha256:6f86cf509dbb42767b6e79debc3f2c32e4ee01386f0489b3b2be24b0a55aac2b
    - role: worker
      image: kindest/node:v1.31.14@sha256:6f86cf509dbb42767b6e79debc3f2c32e4ee01386f0489b3b2be24b0a55aac2b
    - role: worker
      image: kindest/node:v1.31.14@sha256:6f86cf509dbb42767b6e79debc3f2c32e4ee01386f0489b3b2be24b0a55aac2b
    - role: worker
      image: kindest/node:v1.31.14@sha256:6f86cf509dbb42767b6e79debc3f2c32e4ee01386f0489b3b2be24b0a55aac2b
    ```
* Boot the Kind cluster and switch context:
    ```bash
    kind create cluster --config kind.yaml
    kubectx kind-kind
    ```
* Deploy the Strimzi Kafka Operator and create an ephemeral Kafka cluster:
    ```yaml
    kubectl create namespace kafka
    kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
    kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-ephemeral.yaml -n kafka
    ```

* Create a kafka topic: Save the following custom resource definition to `topic.yaml`:
    ```yaml
    apiVersion: kafka.strimzi.io/v1
    kind: KafkaTopic
    metadata:
      name: mediawiki.httpd.accesslog
      labels:
        strimzi.io/cluster: my-cluster
    spec:
      partitions: 3
      replicas: 3
      config:
        retention.ms: 604800000
        segment.bytes: 1073741824
    ```
* Apply the topic configuration:
    ```bash
    kubectl apply -n kafka -f topic.yaml
     ```
* Create the bento namespace
    ```yaml
    kubectl create namespace bento-mw-accesslog-metrics
    ```
* Pause or resume the underlying Docker containers for the Kind cluster without losing state:
    * stop kind: `docker stop $(docker ps -q --filter label=io.x-k8s.kind.cluster=kind)`
    * start king: `docker start $(docker ps -a -q --filter label=io.x-k8s.kind.cluster=kind)`

## 2. Chartmuseum setup

Run a local [Chartmuseum](https://chartmuseum.com/) instance in Docker to serve as a local Helm chart repository.
This is used to serve a local `wmf-stable` repository, giving you the capability to edit, package, and test your Helm charts locally. This enables you to leverage Helmfile.d for templating and verification in your local environment (see [Render Manifests](#render-manifests-templating)).

```bash
make start-helm-repo
```

---

## Helmfile operations
### Upload a modified chart

Package a local chart, remove any existing version from Chartmuseum, and upload the newly packaged .tgz file.

```bash
make push-chart
```

### Render Manifests (Templating)

Use Helmfile inside Docker to register the local repository, compute environment values, and render the final Kubernetes manifests to /tmp/bento.yaml.

Note:
Also add `--state-values-set fixturesDir=../../../charts/${CHART}/.fixtures` to locally write values and/or template production environments (`!= minikube`) with fake values.

#### Write values
```bash
make write-values #ENVIRON=(minikube|aux-k8s-eqiad|aux-k8s-codfw)
```

#### Template
```bash
make template # ENVIRON=(minikube|aux-k8s-eqiad|aux-k8s-codfw)
```

#### Show diffs
```bash
make diff
```

#### Apply
```bash
make apply
```


## notes
* The generator release, which is only deployed in the Minikube environment, will inject dummy data into the mediawiki.httpd.accesslog topic directly through Bento.


## Other commands to be further explored and documented
* `kubectl get secrets sh.helm.release.v1.generator.v1 -o yaml | yq '.data.release' | base64 -d | base64 -d | gunzip | jq | yq -P`
* `kubectl get secrets sh.helm.release.v1.main.v1 -o yaml | yq '.data.release' | base64 -d | base64 -d | gunzip | jq | yq -P`
