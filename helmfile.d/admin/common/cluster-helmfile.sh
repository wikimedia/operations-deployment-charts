#!/bin/bash
set -e

# List helmfile deployments/directories here
# Will be applied in order
DEPLOYMENTS="
podsecuritypolicies
rbac
coredns
calico
eventrouter
"

for DEPL in $DEPLOYMENTS; do
    pushd $DEPL
        helmfile "$@"
    popd
done

# TODO: It's about time to rewrite cluster-helmfile as a python script
# or to add "list environments" functionality to helmfile.
NAMESPACES=$(python3 <<__EOF__
import yaml
from shlex import quote
with open('namespace/envs.yaml', 'r') as f:
  y = yaml.load(f, Loader=yaml.BaseLoader)
  if y:
    for e in y.get('environments', {}).keys():
      print(quote(e))
__EOF__
)

IFS=$'\n'
for NS in $NAMESPACES; do
    helmfile -e "$NS" "$@"
    sleep 1
done
