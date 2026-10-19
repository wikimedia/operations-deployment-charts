# Matomo Helm Chart (WMF)

A Wikimedia Foundation-authored helm chart for [Matomo](https://matomo.org/). Matomo bills itself as "Privacy-first analytics you can trust." Wikimedia Foundation uses Matomo on sites such as https://wikimediafoundation.org .

## How to use
The helm chart makes use of [Matomo's EnvironmentVariables plugin](https://github.com/matomo-org/plugin-EnvironmentVariables), which enables us to use variables directly from helmfile `values.yaml` files instead of rendering a `config.ini.php`.

Only the variables that appear in the charts `values.yaml` are supported. If you need to add a variable, start by adding it `matomo-envvars.inc` in [the WMF Matomo OCI (Docker) image repo](https://gitlab.wikimedia.org/repos/data-engineering/matomo/oci-image) .

