# flink-app helm chart

flink-app uses the flink-kubernetes-operator FlinkDeployment CRD
to deploy 
[Flink Native Kubernetes](https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/resource-providers/native_kubernetes/#native-kubernetes) 
[Application clusters](https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/resource-providers/native_kubernetes/#application-mode).


See the values.yaml file for documented parameters.  For the most cases, you
wll be configuring the image to use and the Flink JobSpec via the `job` parameter.

See also the
[FlinkDeployment CRD reference](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.2/docs/custom-resource/reference/)
for more documentation of available parameters.

## Usage:

You'll need a WMF Deployment Pipeline built docker image that is based
on the [WMF Flink production image](https://docker-registry.wikimedia.org/flink/tags/).
Add any application specific code and dependencies during your build. 

### Simple Java/Scala Flink app 

```yaml
app:
  image: my_flink_job
  version: 1.0.0-1

  job:
    jarURI: local:///srv/my_flink_job/MyFlinkJob.jar # Baked into your image
    entryClass: "org.wikimedia.my.FlinkJob"
    args: [ "--arg1", "val1" ]
```

### Simple Python Flink app
This chart has a `pythonEntryPoint` that makes declaring pyflink jobs a little
more succinct.  Instead of providing `jarURI` and `entryClass` and the `-py` arg,
just set `pythonEntryPoint` to the path of your python `__main__` function file.
Set all other `app.job.args` as normal.

```yaml
app:
  image: my_pyflink_job
  version: 1.0.0-1

  job:
    pythonEntryPoint: "/srv/my_pyflink_job/my_pyflink_job.py" # Baked into your image
    args: [ "--arg1", "val1" ]
```


### Enabling egress
In production, egress is not enabled by default, so your Flink app won't be able to
connect to anything.  Add the following to your values.yaml file values to enable it:

```yaml
mesh:
  enabled: true

networkpolicy:
  egress:
    enabled: true

discovery:
  # List of listeners. These should match service mesh endpoint names
  # (defined in https://gerrit.wikimedia.org/g/operations/puppet/+/refs/heads/production/hieradata/common/profile/services_proxy/envoy.yaml)
  listeners: [...]
```

### Kafka
Ingress and Egress to Kafka clusters is managed slightly differently.
To allow your app to talk to a Kafka cluster:

```yaml
# Add here the list of kafka-clusters (by name) that the service will need to reach.
# (defined in /etc/helmfile-defaults/... on the deployment server).
kafka:
  allowed_clusters: [jumbo-eqiad]
```

### Application config and overrides

Some jobs may require many config values to be passed to its args. Job args being an array it is impossible to define a
common set of options in your `values.yaml` file and override a couple of them for environment specific setup (
e.g. `values-eqiad.yaml`).
If your application is able to load its configuration from a yaml or a java properties file you might be able to
the `config_files` entry in `values.yaml`:
```yaml
app:
  config_files:
    - my-custom-config.properties:
      config_entry_one: value one
      config_entry_two: value two
```

and then overrides some in `values-eqiad.yaml`:
```yaml
app:
  config_files:
    - my-custom-config.properties:
      config_entry_three: eqiad specific config
```

The jobmanager and taskmanager containers will have a file `/srv/app/config/my-custom-config.properties` with the
following content:
```yaml
config_entry_one: value one
config_entry_two: value two
config_entry_three: eqiad specific config
```

## Minikube Usage
First, make sure you have the flink-kubernetes-operator helm chart installed.

Then, you can `helm install` this flink-app chart  with a custom values.yaml file:

`helm install -f ./pyflink_examples.values pyflink-example charts/flink-app`
