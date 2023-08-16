# General

The Istio project suggests to use their custom solution to deploy
configurations to a specific cluster. This can happen in two ways:

1) Via the `istioctl` CLI command
   (more info https://istio.io/latest/docs/setup/install/istioctl/).
2) Via the `istio-operator`
   (more info https://istio.io/latest/docs/setup/install/operator/)

Behind the scenes, in both use cases, Istio wraps Helm charts and commands.
The charts get compiled into the go binary used (`istioctl` or the operator)
to have them available without the need of the upstream repository
checked out somewhere.

Both approaches have pros and cons (see the security warning listed in
the istio-operator page), but `istioctl` seems to be a better compromise,
especially when testing new changes (see below).

We assume then that all the configuration contained in this repository gets
applied via `istioctl`.

# How to make a change to istio configs

As described above, `istioctl` uses Helm charts, that are periodically
changed by upstream as part of their regular development process. This means that
every Istio version should have its own `istioctl` binary (that may or may not be
compatible with other versions).

In order to get a sense of what changes between two Istio manifests, it may be useful
to follow these steps:

1) Build `istioctl` locally using the target istio version that will run on the cluster.
2) Before applying any change, use
   `istioctl manifest generate -f config.yaml > /tmp/istio-current.yaml`
   to expand the current Istio manifest into a more verbose set of configs
   (that could be in theory applicable via kubectl apply -f).
3) Apply your changes to the istio manifest.
4) Run `istioctl manifest generate -f config.yaml > /tmp/istio-after.yaml`
5) Check the diff between manifests via
   `istioctl manifest diff /tmp/istio-current.yaml /tmp/istio-current.yaml`
6) If everything looks as expected, you can proceed with testing on minikube or
   with a code review directly (if the change is small).

## How to build a certain version of istioctl

You need to checkout the istio upstream [repository](https://github.com/istio/istio/),
checkout the branch or tag that you are targeting and then run the `make build-linux`
command. The `istioctl` binary will be created under the `out/linux_amd64` directory.

# How to deploy

## Get the version of istio deployed on the target cluster

The `istioctl` tool is shipped with every version, so it is best to use the one
corresponding to the target cluster's version (we may have multiple versions
of Istio at the same time across various clusters).

In order to get the Istio version, it should be sufficient to:

```
# Populate the cluster's env variables
kube-env admin ml-serve-eqiad
# Get pods and check their version (the number after the column)
kubectl describe pods -n istio-system | grep Image:
```

Then you can apply the config:

```
# Populate the cluster's env variables
kube-env admin ml-serve-eqiad
# Apply the istio config (where X is the istio version)
istioctlX apply -f ml-serve/config.yaml
```
