#!/bin/bash
set -e

# This script can be used to create a production-like Kubernetes cluster in a local (kind) environment.
# Requires kind, kubectl, istioctl, helmfile, helm, rake and docker to be installed on the local machine.

KIND_CLUSTER_NAME="admin-ng"
SIMPLE_CFSSL_URL="https://gerrit.wikimedia.org/r/plugins/gitiles/operations/software/cfssl-issuer/+archive/refs/heads/main/simple-cfssl.tar.gz"

if kind get clusters | grep "^${KIND_CLUSTER_NAME}$" -q; then
  read -p "Cluster '${KIND_CLUSTER_NAME}' already exists. Delete it and recreate? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    kind delete cluster --name "${KIND_CLUSTER_NAME}"
  else
    exit 0
  fi
fi

# Ensure the wmf-stable helm repository is available (this will do nothing if it is)
helm repo add wmf-stable https://helm-charts.wikimedia.org/stable
# ...and up to date
helm repo update wmf-stable --fail-on-repo-update-fail
# Ensure the fixtures (used in CI and as defaults for kind) are available and up to date
rake refresh_fixtures

# Create the kind cluster
kind create cluster --name "${KIND_CLUSTER_NAME}" --config kind.yaml

# Remove stuff that kind creates by default and I have no idea how to disable
kubectl delete storageclasses.storage.k8s.io standard
kubectl delete ns local-path-storage
# Remove kind default coredns installation
kubectl -n kube-system delete deployment coredns
kubectl -n kube-system delete cm coredns
kubectl -n kube-system delete serviceaccount coredns
kubectl -n kube-system delete service kube-dns

# Add docker-registry.wikimedia.org as mirror for docker-registry.discovery.wmnet
# This allows pulling images tagged with docker-registry.discovery.wmnet:*
REGISTRY_DIR="/etc/containerd/certs.d/docker-registry.discovery.wmnet"
for node in $(kind get nodes --name "${KIND_CLUSTER_NAME}"); do
  cat <<__EOF__ | docker exec -i "${node}" /bin/bash -c "mkdir -p ${REGISTRY_DIR}; cat /dev/stdin > ${REGISTRY_DIR}/hosts.toml"
server = "https://docker-registry.wikimedia.org"
[host."https://docker-registry.wikimedia.org"]
__EOF__
done

# Create cert-manager namespace with proper annotations and labels so that it can be manages by helm later.
# This is required because we have to create a secret object containing the CA certificate of simple-cfssl
# in the namespace for the cfssl-issuer to consume.
kubectl apply -f - <<__EOF__
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-namespace: kube-system
    meta.helm.sh/release-name: namespaces
__EOF__

# Install Istio CRDs early, so that we have them available for the admin_ng deployment
istioctl-1.24.2 install --set profile=remote --skip-confirmation
# Remove the isio-system namespace created by istioctl, it will be created by helmfile later on
kubectl delete ns istio-system

# Hack a PKI infrastructure for the cluster
simple_cfssl_tmpdir=$(mktemp -d /tmp/simple_cfssl.XXXXXX)
simple_cfssl_ca=$(mktemp /tmp/simple_cfssl_ca.XXXXXX.pem)
# Download the simple-cfssl dir from cfssl-issuer gerrit repo
curl -sSL "${SIMPLE_CFSSL_URL}" | \
  tar -xz -C "${simple_cfssl_tmpdir}"

# Build the simple-cfssl image
pushd "${simple_cfssl_tmpdir}"
docker build -t simple-cfssl:latest -f Dockerfile .
# Extract the auto generated CA from the image
docker run --rm -it --entrypoint /usr/bin/cat simple-cfssl:latest /cfssl/runtime/ca/ca.pem > "${simple_cfssl_ca}"
# Create a secret with the CA so that it can be used by the cfssl-issuer
kubectl -n cert-manager create secret generic simple-cfssl-ca --from-file=ca.pem="${simple_cfssl_ca}"
# Load the simple-cfssl image into kind
kind load docker-image --name "${KIND_CLUSTER_NAME}" simple-cfssl:latest
# Deploy simple-cfssl to the cluster
kubectl apply -f simple-cfssl.yaml
# Clean up
popd
rm -rf "${simple_cfssl_ca}" "${simple_cfssl_tmpdir}"

# Create a NetworkPolicy to allow the cfssl-issuer to talk to the simple-cfssl service
kubectl apply -f - <<__EOF__
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cfssl-issuer-egress-simple-cfssl
  namespace: cert-manager
spec:
  policyTypes:
  - Egress
  podSelector:
    matchLabels:
      app.kubernetes.io/name: cfssl-issuer
      app.kubernetes.io/instance: cfssl-issuer
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: simple-cfssl
      podSelector: {}
    ports:
    - port: 8888
      protocol: TCP
__EOF__

# Deploy standard admin_ng using some overrides from kind-values.yaml
# as well as overriding what is /etc/helmfile-defaults in production
# with the local fixtures directory.
#
# Ideally we would have a .StateValues.helmfileDefaultsDirectory variable
# in all the helmfiles instead of hardcoding /etc/helmfile-defaults. This
# would allow us to override the directory based on the use case like CI
# where we do all the helmfile patching via gsub etc.
#
# We don't have that and it's an unpleasant amount of work to make CI
# compatible with something like that. So for now we copy admin_ng to
# a temporary directory, patch all the helmfiles via sed and be done with it.
tmp_admin_ng=$(mktemp -d /tmp/admin_ng.XXXXXX)
realpath_fixtures=$(realpath ".fixtures")
realpath_kind_values=$(realpath "kind-values.yaml")
cp -r helmfile.d/admin_ng/. "${tmp_admin_ng}/"
find "${tmp_admin_ng}" -name 'helmfile*.yaml' -print0 | xargs -0 sed "s|/etc/helmfile-defaults|${realpath_fixtures}|g" -i

# It's unfortunately not possible to override the helmDefaults.args array we
# use to pass --kubeconfig down to helm. Arguments can be added
# (with helmfile --args) but not replaced or removed. Also the arguments added
# on the command line are prepended to the helmDefaults.args, so they won't override
# the ones in the helmfile.
# https://github.com/helmfile/helmfile/issues/2084
sed '\|--kubeconfig=/etc/kubernetes/admin|d' -i "${tmp_admin_ng}/helmfile.yaml"

pushd "${tmp_admin_ng}/"
helmfile -e staging-codfw \
         --values "${realpath_kind_values}" \
         sync
popd
rm -rf "${tmp_admin_ng}"

# Install Istio using the main configuration
istioctl-1.24.2 manifest apply --skip-confirmation -f custom_deploy.d/istio/main/config_1.24.2.yaml
