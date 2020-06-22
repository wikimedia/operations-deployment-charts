#!/bin/bash
set -eu
function fail {
    echo "$@" && exit 1
}

function get_scaffold_version() {
    # Using awk instead of a proper yaml parser to reduce dependencies of this script.
    awk '{if ($1 == "helm_scaffold_version:")  print $2}' _scaffold/values.yaml
}


function main {
    which envsubst> /dev/null || fail "You need envusbst(1) to run this script; please install gettext!"
    command -v awk > /dev/null || fail "You need awk(1) to run this script. Please install it."
    echo "Please input the name of the service"
    read -r SERVICE_NAME
    test -d "charts/${SERVICE_NAME}" && fail "A service named ${SERVICE_NAME} already exists, cannot recreate it."
    echo "Please input the port the application is listening on"
    read -r PORT
    echo "Please input the docker image to use:"
    read -r IMAGE_NAME
    export SERVICE_NAME IMAGE_NAME PORT
    cp -rp _scaffold/ charts/${SERVICE_NAME}
    cat _scaffold/values.yaml | envsubst '${SERVICE_NAME} ${IMAGE_NAME} ${PORT}' > charts/${SERVICE_NAME}/values.yaml
    cat _scaffold/Chart.yaml | envsubst '${SERVICE_NAME} ${IMAGE_NAME} ${PORT}' > charts/${SERVICE_NAME}/Chart.yaml
    cat _scaffold/templates/tests/test-service-checker.yaml | envsubst '${SERVICE_NAME} ${IMAGE_NAME} ${PORT}' > charts/${SERVICE_NAME}/templates/tests/test-service-checker.yaml
    pushd "charts/${SERVICE_NAME}/" && ln -sfn ../../common_templates/"${scaffold_version}"/default-network-policy-conf.yaml default-network-policy-conf.yaml && popd
    scaffold_version=$(get_scaffold_version)
    # Enforce symlinks to shared helpers. This way we can more easily track changes
    for filepath in common_templates/"${scaffold_version}/"*.tpl; do
        filename="$(basename $filepath)"
        pushd "charts/${SERVICE_NAME}/templates" && ln -sfn "../../../${filepath}" "$filename" && popd
    done
    echo "You can edit your chart (if needed!) at ${PWD}/charts/${SERVICE_NAME}"
}

main
