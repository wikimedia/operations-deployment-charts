# kafka-single-node

This chart should only be used for local development of charts that require a
running Kafka cluster.  It will create single node Zookeeper and single broker Kafka pods, and
expose the Kafka cluster via a nodePort.

**Note**: As of Kubernetes v1.16 (July 2019), deployments have been removed from the
`extensions/v1beta1`, `apps/v1beta1`, and `apps/v1beta2` APIs. See the
[Kubernetes Blog announcement](https://kubernetes.io/blog/2019/07/18/api-deprecations-in-1-16/)
 for more details. Use kafka-dev chart >= 0.0.5 if you are using a newer
 Kubernetes version.

## Internal Kafka Clients

Internal (kubernetes) cluster Kafka clients should connect to Kafka at
kafka.default.svc.cluster.local:<kafka_internal_port> (default 31092).

## External Kafka Clients

### In docker-desktop

docker-desktop routes nodePorts through 'localhost'.
Set

```bash
kafka_advertised_host: '127.0.0.1'
```

in values.yaml.

External Kafka clients will need to connect to 127.0.0.1:<kafka_external_port>.

Or helm install this chart with --set kafka.advertised_host_name=127.0.0.1

### In minikube

Minikube has it's own node IP that should be used to connect to Kafka.
Get the value of $(minikube ip), and set it
Set

```bash
kafka_advertised_host: <minikube ip here>
```

in values.yaml.

Or helm install this chart with --set kafka.advertised_host_name=$(minikube ip)

External Kafka clients will need to connect to $(minikube ip):<kafka_external_port>.

NOTE: To get Kafka to work in recent versions of minikube, you need to run

```bash
minikube ssh
sudo ip link set docker0 promisc on
```

 See [Stack Overflow: Kafka inaccessible once inside Kubernetes/Minikube](https://stackoverflow.com/a/52792288/555565) for more info.

---
This chart uses the wurtmeister zookeeper and kafka docker images.

### In minikube on MacOS with Docker Desktop

On MacOS, minikube runs in a docker container of its own.  We need to port forward to reach this host.

Set

```bash
kafka_advertised_host: '127.0.0.1'
```

in values.yaml.

Run

`kubectl port-forward svc/kafka-external <kafka_external_port>`

External Kafka clients will need to connect to 127.0.0.1:<kafka_external_port>.
