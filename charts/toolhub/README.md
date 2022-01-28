# toolhub

![Version: 1.1.1](https://img.shields.io/badge/Version-1.1.1-informational?style=flat-square)

Helm chart for Toolhub, a catalog of Wikimedia tools

**Homepage:** <https://meta.wikimedia.org/wiki/Toolhub>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Bryan Davis | bd808@wikimedia.org | https://wikitech.wikimedia.org/wiki/User:BryanDavis |

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://helm.elastic.co | elasticsearch | 6.8.18 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| common_images | object | `{"mcrouter":{"exporter":"prometheus-mcrouter-exporter:latest","mcrouter":"mcrouter:latest"}}` | Versions for common sidecar images |
| config.private.DB_PASSWORD | string | `"snakeoil"` | MariaDB database password |
| config.private.DJANGO_SECRET_KEY | string | `"snakeoil"` | Django core setting. Used for session signing and as default crypto key |
| config.private.WIKIMEDIA_OAUTH2_SECRET | string | `"67e66d1131ed22dc1c79304cae27d04880b16293"` | OAuth2 grant private key. The default value is deliberately public and tied to `http://toolhub.test/` which can only be used in local testing. https://meta.wikimedia.org/wiki/Special:OAuthListConsumers/view/11dec83f263af1b9f480488512556cb1 |
| config.public.CACHE_BACKEND | string | `"django_prometheus.cache.backends.locmem.LocMemCache"` |  |
| config.public.CACHE_LOCATION | string | `""` |  |
| config.public.CURL_CA_BUNDLE | string | `""` | CA override for intercepting https proxy |
| config.public.DB_ENGINE | string | `"django.db.backends.mysql"` |  |
| config.public.DB_HOST | string | `"localhost"` |  |
| config.public.DB_NAME | string | `"toolhub"` |  |
| config.public.DB_PORT | int | `3306` |  |
| config.public.DB_USER | string | `"toolhub"` |  |
| config.public.DJANGO_ALLOWED_HOSTS | string | `"*"` |  |
| config.public.DJANGO_DEBUG | bool | `false` |  |
| config.public.DJANGO_SETTINGS_MODULE | string | `"toolhub.settings"` | Name of the settings module for Django to load |
| config.public.ES_DSL_AUTOSYNC | bool | `true` |  |
| config.public.ES_DSL_PARALLEL | bool | `true` |  |
| config.public.ES_HOSTS | string | `"localhost:9200"` |  |
| config.public.ES_INDEX_REPLICAS | int | `0` |  |
| config.public.ES_INDEX_SHARDS | int | `1` |  |
| config.public.FIREFOX_DEVTOOL_HACK | bool | `false` | Local dev only hack. Needs DEBUG=True. |
| config.public.LOGGING_CONSOLE_FORMATTER | string | `"ecs"` |  |
| config.public.LOGGING_FILE_FILENAME | string | `"/dev/null"` | 'file' handler output file |
| config.public.LOGGING_HANDLERS | string | `"console"` | List of log handlers to enable |
| config.public.LOGGING_LEVEL | string | `"WARNING"` | Base log level to emit |
| config.public.LOG_REQUEST_ID_HEADER | string | `"HTTP_X_REQUEST_ID"` |  |
| config.public.OUTGOING_REQUEST_ID_HEADER | string | `"X-Request-ID"` | Header for propigating trace id to services |
| config.public.REQUEST_ID_RESPONSE_HEADER | string | `"X-Request-ID"` | Header for returning trace id to client |
| config.public.REQUIRE_HTTPS | bool | `false` | Ensure TLS enabled and restrict cookies to https |
| config.public.SOCIAL_AUTH_PROXIES | string | `""` | HTTP proxy settings to use with OAuth client requests. Toolhub expects value to be semicolon separated list of key=value pairs. See also https://docs.python-requests.org/en/master/user/advanced/#proxies |
| config.public.SSL_CANONICAL_HOST | string | `"toolhub.wikimedia.org"` | Https redirect hostname |
| config.public.STATIC_ROOT | string | `"/srv/app/staticfiles"` |  |
| config.public.URLLIB3_DISABLE_WARNINGS | bool | `false` | Disable warnings from urllib3 about unverfied TLS connections |
| config.public.WIKIMEDIA_OAUTH2_KEY | string | `"11dec83f263af1b9f480488512556cb1"` | OAuth2 grant public key. The default value is tied to `http://toolhub.test/` which can only be used in local testing. https://meta.wikimedia.org/wiki/Special:OAuthListConsumers/view/11dec83f263af1b9f480488512556cb1 |
| config.public.WIKIMEDIA_OAUTH2_URL | string | `"https://meta.wikimedia.org/w/rest.php"` |  |
| config.public.http_proxy | string | `""` |  |
| config.public.https_proxy | string | `""` | Outbound https request proxy |
| config.public.no_proxy | string | `""` | Outbound proxy exceptions |
| crawler.concurrencyPolicy | string | `"Forbid"` | Job concurrency policy |
| crawler.enabled | bool | `true` | Enable CronJob for toolinfo url crawler |
| crawler.schedule | string | `"@hourly"` | Schedule for crawler job |
| debug | object | `{"enabled":false,"ports":[]}` | Additional resources if we want to add a port for a debugger to connect to. |
| docker | object | `{"pull_policy":"IfNotPresent","registry":"docker-registry.wikimedia.org"}` | Shared docker settings |
| elasticsearch | object | `{"enabled":false,"esJavaOpts":"-Xms512m -Xmx512m","minimumMasterNodes":1,"replicas":1,"resources":{"limits":{"cpu":"500m","memory":"1Gi"},"requests":{"cpu":"500m","memory":"512Mi"}},"roles":{"data":"true","ingest":"false","master":"true"}}` | Optional Elasticsearch single node cluster for use with minikube. |
| helm_scaffold_version | float | `0.3` | Version of scaffold used to create this chart |
| ingress | object | `{"enabled":false,"host":"toolhub.test"}` | Optional ingress for use with minikube. |
| jobs | object | `{"init_db":false}` | Optional one-time job to initialize and populate the database with demo data. |
| main_app | object | `{"args":[],"command":[],"image":"wikimedia/wikimedia-toolhub","limits":{"cpu":1,"memory":"512Mi"},"liveness_probe":{"tcpSocket":{"port":8000}},"port":8000,"readiness_probe":{"httpGet":{"path":"/healthz","port":8000}},"requests":{"cpu":"250m","memory":"128Mi"},"type":"default","version":"latest"}` | Shared app settings |
| main_app.image | string | `"wikimedia/wikimedia-toolhub"` | Image name to pull from docker.registry |
| main_app.limits | object | `{"cpu":1,"memory":"512Mi"}` | Hard pod resource limits |
| main_app.liveness_probe | object | `{"tcpSocket":{"port":8000}}` | Pod liveness check settings |
| main_app.port | int | `8000` | Port exposed as a Service, also used by service-checker. |
| main_app.readiness_probe | object | `{"httpGet":{"path":"/healthz","port":8000}}` | Pod readiness check settings |
| main_app.requests | object | `{"cpu":"250m","memory":"128Mi"}` | Initial pod resource limits |
| main_app.version | string | `"latest"` | Image version to pull from docker.registry |
| mcrouter | object | `{"cross_cluster_timeout":100,"cross_region_timeout":250,"enabled":false,"num_proxies":5,"probe_timeout":60000,"resources":{"limits":{"cpu":1,"memory":"200Mi"},"requests":{"cpu":"200m","memory":"100Mi"}},"route_prefix":"local/toolhub","routes":[{"failover":true,"pool":"test-pool","route":"/local/toolhub","type":"standalone"}],"timeouts_until_tko":3,"zone":"local"}` | Mcrouter sidecar configuration |
| mcrouter.enabled | bool | `false` | Enable Mcrouter |
| mcrouter.route_prefix | string | `"local/toolhub"` | Default route prefix. Should vary based on datacenter. |
| mcrouter.routes | list | `[{"failover":true,"pool":"test-pool","route":"/local/toolhub","type":"standalone"}]` | Routes to configure for mcrouter |
| mcrouter.zone | string | `"local"` | Zone of this deployment. Used to determine local/remote pools. |
| monitoring | object | `{"enabled":true,"uses_statsd":false}` | Monitoring config |
| networkpolicy | object | `{"egress":{"enabled":false}}` | Networking settings |
| php | object | `{"fcgi_mode":"unused"}` | Cruft needed for generated templates/deployment.yaml |
| resources.replicas | int | `1` | Number of replicas to run in parallel |
| service | object | `{"deployment":"minikube","port":{"name":"http","nodePort":null,"port":8000,"targetPort":8000}}` | Service config |
| service.deployment | string | `"minikube"` | Valid values are "production" and "minikube" |
| service.port.nodePort | string | `nil` | You need to define this if service.deployment="production" is used. |
| service.port.port | int | `8000` | Number of the port desired to be exposed to the cluster |
| service.port.targetPort | int | `8000` | Number or name of the exposed port on the container |
| tls | object | `{"certs":{"cert":"snakeoil","key":"snakeoil"},"enabled":false,"public_port":4011,"telemetry":{"enabled":true,"port":9361},"upstream_timeout":"180.0s"}` | TLS terminating ingress configuration |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.5.0](https://github.com/norwoodj/helm-docs/releases/v1.5.0)
