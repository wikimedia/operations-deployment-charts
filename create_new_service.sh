#!/bin/bash
set -eu
function fail {
    _msg=shift
    echo $_msg && exit 1
}


function main {
    which envsubst || fail "You need envusbst(1) to run this script; please install gettext!"
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
    for filepath in _scaffold/templates/*.*; do
        filename="$(basename $filepath)"
        cat $filepath | envsubst '${SERVICE_NAME} ${IMAGE_NAME} ${PORT}' > charts/$SERVICE_NAME/templates/$filename
    done

    echo "You can edit your chart (if needed!) at ${PWD}/charts/${SERVICE_NAME}"
}

main
