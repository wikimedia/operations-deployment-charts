#!/bin/bash
pushd calico
./apply-calico-policy.sh "$@"
popd
for NS in $(ls values/*.yaml); do helmfile -e $(basename -s .yaml $NS) "$@" ;done
