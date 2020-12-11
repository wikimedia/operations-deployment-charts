# mediawiki-dev

mediawiki-dev is a helm chart for mediawiki/core. It is not suitable for production.

## Installing the chart

mediawiki-dev has been tested with mariadb. It is expected to work with mysql or mariadb. Further work and testing are necessary for other database types. The database location, name, and password are the only requirements for the default chart installation (`config.public.DB_SERVER`, `config.public.DB_NAME`, `config.private.DB_PASS`).

### Quick-install the mediawiki-dev chart using Helm
From this directory:
```sh
 helm install --set config.public.DB_SERVER="my_server" --set config.public.DB_NAME="my_name" --set config.private.DB_PASS="my_pass" .
 ```

## Configuration

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `docker.registry` | The registry from which to pull the mediawiki/core image | `docker-registry.wikimedia.org` |
| `docker.pull_policy` | Always, Never, or IfNotPresent | `IfNotPresent` |
| `resources.replicas` | The number of instances to deploy | `1` |
| `main_app.image` | The image name | `wikimedia/mediawiki-core` |
| `main_app.version` | The image tag | `latest` |
| `main_app.ports` | The container ports to expose | `[80]`
| `main_app.command` | The command to run to override the entrypoint | `'["/bin/bash", "-c"]'` |
| `main_app.args` | The args to give to the command | `image default` |
| `main_app.requests.cpu` | CPU allocation | `100m` |
| `main_app.requests.memory` | Memory allocation | `100Mi` |
| `main_app.limits.cpu` | CPU limit | `1.2` |
| `main_app.limits.memory` | Memory limit | `500Mi` |
| `main_app.liveness_probe.tcpSocket.port` | The port to use for healthchecks | `8080` |
| `main_app.readiness_probe.httpGet.path` | The endpoint to check for readiness | `/index.php/Special:BlankPage` |
| `main_app.readiness_probe.httpGet.port1` | The port to use for readiness checks | `8080` |
| `main_app.volumes` | Volumes to mount to the container. Useful for overriding LocalSettings or sharing local files | `[]` |
| `main_app.volumeMounts` | Mounted volumes to make accesible | `[]` |
| `main_app.xdebug.enabled` | Whether to enable xdebug | `false` |
| `main_app.xdebug.remoteHost` | The host that will be listening for xdebug | `''` |
| `main_app.xhprof.enabled` | Whether to enable xhprof | `false` |
| `monitoring.enabled` | Whether to enable monitoring | `false` |
| `monitoring.image_version` | The monitoring image tag | `latest` |
| `service.deployment` | production or minikube | `minikube` |
| `service.ports` | Ports to expose | `[ { name: http, protoco: TCP, targetPort: 8080, port: 80, nodePort: null } ]` |
| `config.public.XDEBUG_CONFIG` | Environment variables for xdebug | `"remote_autostart=1 remote_enable=1 remote_handler=dbgp remote_host={{ .Values.main_app.xdebug.remoteHost }} remote_log=/tmp/xdebug_remote.log remote_mode=req remote_port=9000"` |
| `config.public.WIKI_NAME` | The name of the wiki | `"My Wiki"` |
| `config.public.WIKI_ADMIN` | The wiki admin username | `"admin"` |
| `config.public.DB_NAME` | The name of the database | `"my_wiki"` |
| `config.public.RESTBASE_NODEPORT` | The nodeport of the restbase server | `""` |
| `config.public.MEDIAWIKI_DOMAIN` | The domain (used in restbase and parsoid config) | `"{{ .Release.Name }}"` |
| `config.public.RESTBASE_URL` | The restbase connection string | `"http://restbase-{{ .Release.Name }}"` |
| `config.public.IS_RESTBASE_EXTERNAL` | Whether restbase is running outside the cluster | `false` |
| `config.public.PARSOID_URL` | The parsoid connection string | `"http://parsoid-{{ .Release.Name }}"` |
| `config.public.ENABLE_VISUAL_EDITOR` | Whether to enable the visual editor | `"false"` |
| `config.public.DB_SERVER` | The database connection string | `"{{ .Release.Name }}-mariadb"`
| `config.private.WIKI_ADMIN_PASS` | The wiki admin password | `"adminpass"` |
| `config.private.DB_PASS` | The database password | `"password"` |
| `config.private.WG_SECRET_KEY` | A secret key | `"d964ce98b272c2115d5f4960563af8fb8f02ff968bbb0d62bdf4e1e4c18393ed"` |
| `config.private.WG_UPGRADE_KEY` | A key for upgrading | `aed8ffeb5b5fba9e` |

### Localisation related settings

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `main_app.usel10nCache` | Whether to enable the localisation cache | `false` |
| `main_app.l10nNodePath` | The directory on each node where localisation files will be stored. Must be specified if `main_app.usel10nCache` is true | `null` |
| `main_app.owner` | uid:gid that the mediawiki container runs as.  This is passed to `chown` to prepare a hostPath when `main_app.usel10nCache` is true | `"65533:65533"` |
| `main_app.rootImage`| Image to use when we need to run as root (e.g., to chown a bind-mounted hostPath) | `wikimedia-stretch` |
| `main_app.rootImageVersion`| rootImage tag | `latest` |
