#!/bin/bash
pushd podsecuritypolicies
    helmfile "$@"
popd
pushd rbac
    helmfile "$@"
popd
pushd coredns
    helmfile "$@"
popd
pushd calico
    helmfile "$@"
popd
for NS in $(ls namespace/values/*.yaml); do helmfile -e $(basename -s .yaml $NS) "$@" ; sleep 1 ;done
