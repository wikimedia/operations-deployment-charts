# parsoid

parsoid is a helm chart for parsoid.

## Installing the chart

To install the chart, the only required value to set is the mediawiki core API uri (config.services.uri).

### Quick-install the parsoid chart using Helm
From this directory:
```sh
 helm install --set config.services.uri="my_core_instance_location/api.php" .
 ```

## Configuration

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `docker.registry` | The registry from which to pull the parsoid image | `docker-registry.wikimedia.org` |
| `docker.pull_policy` | Always, Never, or IfNotPresent | `IfNotPresent` |
| `resources.replicas` | The number of instances to deploy | `1` |
| `main_app.image` | The image name | `dev/parsoid` |
| `main_app.version` | The image tag | `latest` |
| `main_app.ports` | The container ports to expose | `[80]`
| `main_app.command` | The command to run to override the entrypoint | `'[node]'` |
| `main_app.args` | The args to give to the command | `'["--debug=0.0.0.0:5858", "bin/server.js", "-n 0", "--config", "/usr/src/config/config.yaml"]'`
| `main_app.requests.cpu` | CPU allocation | `15m` |
| `main_app.requests.memory` | Memory allocation | `100Mi` |
| `main_app.limits.cpu` | CPU limit | `1` |
| `main_app.limits.memory` | Memory limit | `200Mi` |
| `main_app.liveness_probe.tcpSocket.port` | The port to use for healthchecks | `8142` |
| `main_app.readiness_probe.httpGet.path` | The endpoint to check for readiness | `/` |
| `main_app.readiness_probe.httpGet.port1` | The port to use for readiness checks | `8142` |
| `main_app.volumes` | Volumes to mount to the container. Useful for overriding LocalSettings or sharing local files | `[]`
| `main_app.volumeMounts` | Mounted volumes to make accesible | `[]` |
| `monitoring.enabled` | Whether to enable monitoring | `false` |
| `monitoring.image_version` | The monitoring image tag | `latest` |
| `service.deployment` | production or minikube | `minikube` |
| `service.ports` | Ports to expose | `[ { name: http, protoco: TCP, targetPort: 8142, port: 80, nodePort: null } ]` |
| `config.public.INTERFACE` | The ip address to listen on | `"0.0.0.0"` |
| `config.public.PORT` | The port to listen on | `"8142"` |
| `config.public.NODE_ENV` | The node environment | `"development"` |
| `config.num_workers` | The number of http workers to use | `1` |
| `config.worker_heartbeat_timeout` | The worker timeout | `300000` |
| `config.logging.level` | The logging level to use | `info` |
| `config.metrics.type` | The metrics type | `log` |
| `config.services.module` | The parsoid module to use | `lib/index.js` |
| `config.services.entrypoint` | The parsoid entrypoint | `apiServiceWorker` |
| `config.services.localsettings` | The localSettings file | `''` |
| `config.services.userAgent` | The user agent | `''` |
| `config.services.uri` | The mediawiki core api uri | `'mediawiki-dev-{{ .Release.Name }}/api.php'` |
| `config.services.domain` | The domain for communication with RESTbase and VisualEditor | `'{{ .Release.Name }}'` |
| `config.services.prefix` | Optional prefix for proxy | `''` |
| `config.services.proxy` | Optional proxy override (ex: { uri: 'http://my/proxy', headers: { 'X-Forwarded-Proto': 'https' }}) | `''` |
| `config.services.strictSSL` | Whether to use strictSSL | `true` |
| `config.services.useWorker` | Whether to use compute workers | `false` |
| `config.services.cpu_workers` | Number of workers to use | `1` |
| `config.services.loadWMF` | Whether to load WMF's config for wikipedias | `false` |
| `config.services.defaultAPIProxyURI` | A default proxy to connect to API endpoints | `''` |
| `config.services.debug` | Whether to print extra debug messages | `false` |
| `config.services.usePHPPreprocessor` | Whether to use the PHP Preprocessor to expand templates | `true` |
| `config.services.useSelser` | Whether to use selective serialization | `false` |
| `config.services.disable.allowCORS` | Allow cross-domain requests to the API | `true` |
| `config.services.restrict.allowCORS` | Sets Access-Control-Allow-Origin header | `'*'` |
| `config.services.serverPort` | Allow override of port | None |
| `config.services.serverInterface` | Allow override of interface | None |
| `config.services.linting` | Whether to enable linting of some wikitext errors to the log | `false` |
| `config.services.linter.sendAPI` | Whether to send lint errors to MW API instead of to the log | `false` |
| `config.services.linter.apiSampling` | The sampling rate | `10` |
| `config.services.modulesLoadURI` | Optionally, use different server for CSS style modules. | `''` |
| `config.services.extraApis` | Additional yaml API configurations for the default service | `[]` |
| `config.services.extraServices` | Additional yaml service and corresponding API congurations | `[]` |

