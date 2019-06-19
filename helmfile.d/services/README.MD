# Migrating from scap-helm to helmfile
instead of executing
CLUSTER=staging scap-helm eventgate-analytics upgrade analytics -f /srv/scap-helm/eventgate/analytics/staging-values.yaml  stable/eventgate

go to /srv/deployment-charts/helmfile.d/services/staging/eventgate-analytics
and run
KUBECONFIG=/etc/kubernetes/eventgate-analytics-staging.config helmfile diff

check out the differences and if they look sane to yoy execute.
KUBECONFIG=/etc/kubernetes/eventgate-analytics-staging.config helmfile apply

# Recreating a cluster, cluster-wide update or multiple services update.
you need access to the admin token to be able to do it, if you have access
go to /srv/deployment-charts/helmfile.d/services/staging/
KUBECONFIG=/etc/kubernetes/eventgate-analytics-staging.config helmfile diff

to see the changes that are about to be made and then
KUBECONFIG=/etc/kubernetes/eventgate-analytics-staging.config helmfile apply

# How to add a new service here.
 - you will need a namespace, you can make a CR in the admin folder on this repo (read the readme) but a cluster admin needs to apply it.
 - the serviceops team ( #wikimedia-serviceops on freenode ) need to create a valid kubeconfig for interacting with the cluster.
 - if you need external traffic, serviceops also needs to configure LVS and DNS to enable you to receive traffic from outside or from other WMF services.

# Service owner common workflow

## Applying a change
- make a CR here to edit or add new values.
- some data from values.yaml are considered secrets and therefore not included here, if you need to update or modify a secret you need to do it on the puppet repo and follow the guidelines there to adding a secret.
- log in into the deployment servers and do KUBECONFIG=/etc/kubernetes/${SERVICE}-${CLUSTER}.config helmfile diff and if you are satisfied with the output apply them with KUBECONFIG=/etc/kubernetes/${SERVICE}-${CLUSTER}.config helmfile apply
- is wise to depool the service in the affected cluster if you anticipate issues.

## Rollbacking a change
- revert the change on gerrit.
- apply the change as detailed above.
