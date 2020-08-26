# Conventions
In every cluster ("environment" in helmfile terms) you can have up to two "releases", main and one of canary and test depending on the cluster:
- **main**: the main release, that will include most of the pods, and the service definition.
- **canary**: an optional additional release that will serve a portion of live traffic. It normally avoids to declare a service, and uses a small number of pods.
  Not present in the staging cluster as it only makes sense with real traffic
- **test**: an optional additional release for pure testing purposes, only present in the staging cluster

The values files listed in `helmfile.yaml` follow a hierarchy, where the latter file can override values defined in files that come earlier. 

Which values are included varies depending on the cluster and release. So for example the `main` release for cluster `eqiad` will look at the following files on the deployment server:
```yaml
- $chart/values.yaml # the values.yaml file contained within the helm chart
- "/etc/helmfile-defaults/general-eqiad.yaml" # general default values, controlled by SRE
- "values.yaml" # non-env-specific values, in this repository
- "/etc/helmfile-defaults/private/SERVICE_NAME/eqiad.yaml" # prod-specific secrets, controlled by SRE
- "values-eqiad.yaml" # env-specific overrides
- "values-main.yaml" # release-specific overrides
```

# How to convert to the new layout
We've recently switched to the previous helmfile layout to a new, more compact one. If you want to convert a deployment, follow these steps:

- Run `helmfile_convert_diff.sh <deployment>`
- If the service is pretty standard, it should run and generate 
  the new-layout deployment in `<deployment>`, with the kubernetes catalogs for the various environments in `<deployment>/diffs`
- If anything unexpected happens, the script will bail out and ask you to review your data before you proceed.
- Once you've fixed what you want to fix, you can re-run the script, and it will only generate the catalogs for comparison
- Fix discrepancies, and once you achieve zero diffs, you can deduplicate the values files, and generate diffs again to confirm you've not generated new issues.

# How to add a new service here.
- make a copy of the `_example_` directory here to a directory with the name of your new service
- substitute `SERVICE_NAME` in helmfile.yaml with the name of your service.
- verify you want all releases listed; Do you plan on having a canary release? Do you need a "test" release in staging?
- you will need a namespace, you can make a CR in the admin folder on this repo (see the README.MD file under `admin/`) but a cluster administrator needs to apply it.
- the serviceops team ( `#wikimedia-serviceops` on freenode) will need to create a valid kubeconfig for interacting with the cluster.
- if you need external traffic, serviceops also needs to configure LVS and DNS to enable you to receive traffic from outside or from other WMF services.



# Service owner common workflow

Please see https://wikitech.wikimedia.org/wiki/Deployments_on_kubernetes#Deploying_with_helmfile
