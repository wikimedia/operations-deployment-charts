# Matomo Helm Chart (WMF)

A Wikimedia Foundation-authored helm chart for [Matomo](https://matomo.org/). Matomo bills itself as "Privacy-first analytics you can trust." Wikimedia Foundation uses Matomo on sites such as https://wikimediafoundation.org .

## How to use
The helm chart makes use of [Matomo's EnvironmentVariables plugin](https://github.com/matomo-org/plugin-EnvironmentVariables), which enables us to use variables directly from helmfile `values.yaml` files instead of rendering a `config.ini.php`.

Only the variables that appear in the charts `values.yaml` are supported. If you need to add a variable, start by adding it `matomo-envvars.inc` in [the WMF Matomo OCI (Docker) image repo](https://gitlab.wikimedia.org/repos/data-engineering/matomo/oci-image) .

## Apache configuration

`files/apache/matomo.conf` replaces the httpd-fcgi image's
`/etc/apache2/sites-enabled/000-default.conf` through a read-only ConfigMap mount.
It serves the copied application assets from `/srv/app`, forwards PHP requests to
PHP-FPM over the configured Unix socket or TCP connection, and denies access to
private application directories. It does not configure CAS or mod_php.

`lamp.httpd.custom_config` remains available for additional Apache configuration.
Checksums trigger a pod rollout when either configuration changes, since the
ConfigMaps are mounted using `subPath`.
