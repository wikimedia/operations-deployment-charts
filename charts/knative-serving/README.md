== Overview ==

The knative-serving and knative-serving-crds charts are the implementation of
what upstream suggests to deploy via kubectl apply -f:
- https://github.com/knative/serving/releases/download/v0.18.1/serving-crds.yaml
- https://github.com/knative/serving/releases/download/v0.18.1/serving-core.yaml

There is also a specific configuration for the Knative Istio controller:
- https://github.com/knative/net-istio/releases/download/v0.18.1/net-istio.yaml

The idea is to simply copy the three files into their respective templates directories,
adding some helm variables to allow a more flexible customization.
We may want to better segment these files in the future, but for the moment this
seems a good compromise.

== Istio configuration ==

Up to knative-serving 0.18.x Istio needs to be configured with two ingress
gateways:
- ingress gateway
- cluster local gateway
The former is the one responsible to deal with external traffic, the latter
is responsible for the internal traffic of the cluster. Knative > 0.18
deprecates the cluster local gateway in favor of a knative-internal one,
but it requires a more up to date Kubernetes version (1.18+).

Please also note that all the L7 config for the Istio Ingresses are handled
by Knative's net_istio.yaml config, using Istio Gateway CRDs.

== Update the chart ==

Knative Serving is a rapid growing project that tries to be compatible with
the most recent versions of Kubernetes. The 0.18.x releases are the last ones
tested with Kubernetes 1.16.

The procedure is simple: pick the new serving-{core,crds} and net-istio files
from upstream, apply our custom template variables where needed and make sure
that the helm files are properly escaped. For example, `jx gitops helm escape`
may be a good tool to use to avoid issues while helm parses the example
config outlined in several `Configmap` resources.

For the specific use case of 0.18.1 some CRDs were stated in the serving-core.yaml file,
and repeated in the serving-crds.yaml one. For consistency I removed them from core.yaml
when creating the knative-serving chart.

Please also add the following snippet to the `env` specs of all containers:
```
{{- if and .Values.kubernetesApi.host .Values.kubernetesApi.port }}
{{- include "wmf.kubernetes.ApiEnv" . | nindent 12 }}
{{- end }}
```
This is needed to avoid TLS certificate validation errors due to the absence of IP SANs.

We also need to add the following bit to the controller deployment's specs:
```
+            # Needed to be able to trust the docker-registry's CA certificate
+            # provided in the Docker image by the {wmf,ca}-certificates debs.
+            - name: SSL_CERT_DIR
+              value: /usr/share/ca-certificates
```
The default route/revision hostname uses 'example.com', we set 'wikimedia.org'
in the related config-map (it is sufficient to grep for 'example.com' to find it).

We also inject prometheus annotations to all the container specs like the following:
```
{{ if .Values.monitoring.enabled -}}
prometheus.io/scrape: "true"
{{ end -}}
prometheus.io/port: "9090"
```