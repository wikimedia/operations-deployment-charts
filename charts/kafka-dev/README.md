 # kafka-single-node

This chart should only be used for local development of charts that require a running
Kafka cluster.  It will create single node zookeeper and Kafka pods, and expose
the Kafka cluster via a nodePort.

# Internal Kafka Clients

Internal (kubernetes) cluster Kafka clients should connect to Kafka at
kafka.default.svc.cluster.local:9092.

# External Kafka Clients

## In docker-desktop
docker-desktop routes nodePorts through 'localhost'.
Set

    kafka_advertised_host: 'localhost'

in values.yaml.

External Kafka clients will need to connect to localhost:<kafka_advertised_port>.

Or helm install this chart with --set kafka.advertised_host_name=localhost

## In minikube
Minikube has it's own node IP that should be used to connect to Kafka.
Get the value of $(minikube ip), and set it
Set

    kafka_advertised_host: <minikube ip here>

in values.yaml.

Or helm install this chart with --set kafka.advertised_host_name=$(minikube ip)


NOTE: To get Kafka to work in recent versions of minikube, you need to run

 ```
minikube ssh
sudo ip link set docker0 promisc on
 ```

 See https://stackoverflow.com/a/52792288/555565 for more info.


---
This chart uses the wurtmeister zookeeper and kafka docker images.
