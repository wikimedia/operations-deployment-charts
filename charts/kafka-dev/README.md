 # kafka-single-node

This chart should only be used for local development of charts that require a running
Kafka cluster.  It will create single node zookeeper and Kafka pods, and expose
the Kafka cluster at minikube ip 192.168.99.100:30092.  If your minikube ip is different,
install this chart with

  --set kafka.advertised_host_name=$(minikube ip)

NOTE: To get Kafka to work in recent versions of minikube, you need to run

 ```
minikube ssh
sudo ip link set docker0 promisc on
 ```

 See https://stackoverflow.com/a/52792288/555565 for more info.

This chart uses the wurtmeister zookeeper and kafka docker images.
