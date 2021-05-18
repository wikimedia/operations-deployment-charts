# API Gateway

## Developer environment

If `.Values.main_app.dev_redis` is set to true, the Helm chart will
attempt to bring up a redis container with the other components. This
will enable the ratelimiter to set rates appropriately. This setup
does *not* use subcharts, and simply uses a local redis docker
image. When in the context of your local kubernetes setup (ie: `eval
$(minikube docker-env)`), run `docker pull redis` and the chart will
find the image to use. The developer configuration also makes use of
the `echoapi` client which simply returns information about the
headers the service was passed from the client which can be useful for
debugging ratelimiting configuration and other issues. To build the
echoapi container, check out the
[wmf-api-gateway](https://github.com/eevans/wmf-api-gateway/) repo, cd
to `echoapi` and run `make docker_image`. Envoy will serve traffic to
the service, which will run in its own container within the pod.

To run an instance of api-gateway, simply install it using the set of
stub developer variables:

```
cd charts/
helm package api-gateway
helm install -f api-gateway/values-devel.yaml api-gateway-0.0.1.tgz
```

### Communicating with a dev pod

To communicate with the api gateway, you'll need to forward the port locally:
```
kubectl get pods # Look up the name of your api gateway pod
kubectl port-forward $POD_NAME 7000:8087
curl -v -H "x-client-ip: 123.123.123.123" http://localhost:7000/core/v1/wikipedia/en/foo/bar/baz # this should return a HTTP 429 with the default setup
```
