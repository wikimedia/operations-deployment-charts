#!/bin/sh

set -x
set -e

SERVICE=$1

for i in eqiad codfw staging
do
	sudo KUBECONFIG=/etc/kubernetes/admin-${i}.config ./initalize_namespace.sh $SERVICE $SERVICE
	sudo KUBECONFIG=/etc/kubernetes/admin-${i}.config kubectl -n $SERVICE patch deploy tiller-deploy --patch "$(cat tiller/${i}.yaml)"
done
