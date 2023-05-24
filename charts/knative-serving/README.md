== Overview ==

The knative-serving and knative-serving-crds charts are the implementation of
what upstream suggests to deploy via kubectl apply -f:
- https://github.com/knative/serving/releases/download/vVERSION/serving-crds.yaml
- https://github.com/knative/serving/releases/download/vVERSION/serving-core.yaml

There is also a specific configuration for the Knative Istio controller:
- https://github.com/knative/net-istio/releases/download/vISTIO-VERSION/net-istio.yaml

The idea is to simply copy the three files into their respective templates directories,
adding some helm variables to allow a more flexible customization.
We may want to better segment these files in the future, but for the moment this
seems a good compromise.

Please note that VERSION and ISTIO-VERSION are not necessarily the same value,
since they refer to two independent repositories. At the moment we import:
knative-serving: 1.7.2 (VERSION)
knative-net-istio: 1.7.0 (ISTIO-VERSION)
In the future we should probably create a separate chart for knative-net-istio,
but for the moment let's just hardcode ISTIO-VERSION where needed.

== Istio configuration ==

Up to knative-serving 0.18.x Istio needed to be configured with two ingress
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
the most recent versions of Kubernetes.

The procedure is simple: pick the new serving-{core,crds} and net-istio files
from upstream, apply our custom template variables where needed and make sure
that the helm files are properly escaped. For example, `jx gitops helm escape`
may be a good tool to use to avoid issues while helm parses the example
config outlined in several `Configmap` resources.

The `core.yaml` file contains also `CustomResourceDefinition` already defined
in `serving-crds.yaml` as well. Please remove any
`kind: CustomResourceDefinition` occurrent in `core.yaml` (please verify first
that they are already listed in the crds yaml file).

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
{{- if .Values.monitoring.enabled }}
prometheus.io/scrape: "true"
{{- end }}
prometheus.io/port: "9090"
```

We add the following labels to all `kind: Deployment` pod template definitions:
```
app-wmf: {{ template "wmf.chartname" . }}
chart: {{ template "wmf.chartid" . }}
release: {{ .Release.Name }}
```
We use the `app-wmf` label in our charts since the `app` label is already used
by knative-serving. The `app-wmf` value is useful to deploy network policies
safely and consistently.

We change the PodDisruptionBudget of the webhook as following (to ease roll reboots):

--- a/charts/knative-serving/templates/core.yaml
+++ b/charts/knative-serving/templates/core.yaml
@@ -2458,7 +2458,7 @@ metadata:
     app.kubernetes.io/name: knative-serving
     app.kubernetes.io/version: "{{ .Chart.AppVersion }}"
 spec:
-  minAvailable: 80%
+  minAvailable: 50%
   selector:
     matchLabels:
       app: webhook


We had to add the following change to the Webhook's and Domain Mapping Webhook's
Deployment resource:
```
-            initialDelaySeconds: 20
+            initialDelaySeconds: 120
```
The problem seems to be https://github.com/knative/serving/pull/9661, but
the upstream values are not enough for our use case.
