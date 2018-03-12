#!/bin/sh

set -x
set -e

SERVICEACCOUNT=${SERVICEACCOUNT:-"tiller"}
KUBECONFIG=${KUBECONFIG:-"/etc/kubernetes/kubeconfig"}
NAMESPACE=$1
DEPLOY_USER=$2

# First create the namespace
KUBECONFIG=$KUBECONFIG kubectl create namespace ${NAMESPACE}

# Create the service account under which tiller will run
KUBECONFIG=$KUBECONFIG kubectl create serviceaccount ${SERVICEACCOUNT} -n ${NAMESPACE}

# create the tiller role binding. We use a cluster role for DRY purposes
KUBECONFIG=$KUBECONFIG kubectl -n ${NAMESPACE} create rolebinding ${SERVICEACCOUNT} --clusterrole=tiller --serviceaccount="${NAMESPACE}:${SERVICEACCOUNT}"

# create the deploy-user role binding. We use a cluster role for DRY purposes
KUBECONFIG=$KUBECONFIG kubectl -n ${NAMESPACE} create rolebinding ${DEPLOY_USER} --clusterrole=deploy --user=${DEPLOY_USER}

# Initialize helm
helm init --service-account ${SERVICEACCOUNT} --tiller-namespace=${NAMESPACE}
