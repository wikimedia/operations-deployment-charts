#!/bin/sh
# Waits until the Flink job of a namespace runs the spec that was just deployed.
# Used as a check by scap deploy-service, see the service catalog in
# operations/puppet hieradata/role/common/deployment_server/kubernetes.yaml.
#
# Usage: check-flink-deployment.sh <namespace> <environment>
set -eu

if [ $# -ne 2 ]; then
    echo "Usage: $0 <namespace> <environment>" >&2
    exit 2
fi

export KUBECONFIG="/etc/kubernetes/$1-deploy-$2.config"

generation=$(kubectl get flinkdeployment -o jsonpath='{.items[0].metadata.generation}')

# Until the operator picks up the new spec, the previous job still reports STABLE.
echo "Waiting for the Flink operator to pick up generation $generation"
kubectl wait flinkdeployment --all --for=jsonpath='{.status.observedGeneration}'="$generation" --timeout=20s > /dev/null

echo "Waiting for the Flink job to be STABLE"
kubectl wait flinkdeployment --all --for=jsonpath='{.status.lifecycleState}'=STABLE --timeout=110s > /dev/null

echo "Flink is running now"
