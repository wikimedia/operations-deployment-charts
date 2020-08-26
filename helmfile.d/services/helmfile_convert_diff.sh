#!/bin/bash
# PARAMETERS
set -e
CHARTS_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DEPLOYMENT=$1
CLUSTERS="codfw eqiad staging"

# suppress pushd/popd output
pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

copy_new_helmfile() {
    NEW_HELMFILE_D="${CHARTS_ROOT}/${DEPLOYMENT}"
    cp -r $NEW_HELMFILE_D new
    pushd new
    if [ -f .fixtures.yaml ]; then
        perl -i"" -pe 's#/etc/helmfile-defaults/general-\{\{\ \.Environment\.Name \}\}\.yaml#.fixtures.yaml#' helmfile.yaml;
    fi
    popd
}

copy_old_helmfiles() {
    for cluster in $CLUSTERS; do
        cp -r "${CHARTS_ROOT}/$cluster/$DEPLOYMENT" "$cluster"
        pushd $cluster
        if [ -f .fixtures.yaml ]; then
            perl -i"" -pe 's#private/secrets.yaml#.fixtures.yaml#' helmfile.yaml
        fi
        popd
    done
}

scaffold_deployment() {
    RETURN=0
    pushd "$CHARTS_ROOT"
    mkdir "$DEPLOYMENT"
    cp .helmfile-convert-stub.yaml "${DEPLOYMENT}/helmfile.yaml"
    pushd "$DEPLOYMENT"
    perl -i"" -pe "s/SERVICE_NAME/$DEPLOYMENT/g;" helmfile.yaml
    popd
    # Copy the values files over.
    for cluster in $CLUSTERS; do
        if [ -f "$cluster/$DEPLOYMENT/values.yaml" ]; then
            cp "$cluster/$DEPLOYMENT/values.yaml" "$DEPLOYMENT/values-$cluster.yaml"
        else
            echo "main values file not found for cluster $cluster; please check manually"
            RETURN=1
        fi
        test -f "$cluster/$DEPLOYMENT/values-canary.yaml" && cp "$cluster/$DEPLOYMENT/values-canary.yaml" "${DEPLOYMENT}/"
        test -f "$cluster/$DEPLOYMENT/.fixtures.yaml" && cp "$cluster/$DEPLOYMENT/.fixtures.yaml" "$DEPLOYMENT/"
    done
    popd
    return $RETURN
}

generate_diffs() {
    echo "Copying the helmfiles (and patching them)"
    DIFFS="${DEPLOYMENT}/diffs"
    test -d $DIFFS && rm -rf $DIFFS
    mkdir "$DIFFS"
    mkdir .tmp
    pushd .tmp
    copy_new_helmfile
    copy_old_helmfiles
    for cluster in $CLUSTERS; do
        echo "Compiling helmfile templates for $cluster"
        if [ "$cluster" == "staging" ]; then
            REL="staging"
        else
            REL="production"
        fi
        helmfile -f new/helmfile.yaml --selector name=$REL -e $cluster template > "../$DIFFS/new.$cluster.yaml" 2> /dev/null
        helmfile -f "$cluster/helmfile.yaml" --selector name=$REL template > "../$DIFFS/old.$cluster.yaml" 2> /dev/null
        diff -aur "../$DIFFS/old.$cluster.yaml" "../$DIFFS/new.$cluster.yaml" > "../$DIFFS/$cluster.diff"
        echo "Diffs generated for cluster $cluster in $DIFFS/$cluster.diff"
    done
    popd
    rm -rf .tmp
}

# Main script

if [ ! -d "$CHARTS_ROOT/$DEPLOYMENT" ]; then
    echo "Creating the new-style deployment from the example repo"
    scaffold_deployment
else
    echo "The deployment exists, will only refresh the diffs."
fi

echo "Comparing helmfile releases for $DEPLOYMENT"
generate_diffs
echo "Templates created for all clusters"
echo "Please review the diffs, and unify the values files. You can re-run the script afterwards to check the diffs again."
