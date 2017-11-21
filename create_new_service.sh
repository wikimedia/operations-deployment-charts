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
    echo "Please input the namespace this service will be deployed to"
    read -r NAMESPACE
    echo "Please input the port the application is listening on"
    read -r PORT
    echo "Please input the port this service will be exposed on (dev only)"
    read -r SERVICE_PORT
    echo "Please input the docker image to use:"
    read -r IMAGE_NAME
    export SERVICE_NAME NAMESPACE SERVICE_PORT IMAGE_NAME PORT
    cp -rp _scaffold/ charts/${SERVICE_NAME}
    cat _scaffold/values.yaml | envsubst > charts/${SERVICE_NAME}/values.yaml
    cat _scaffold/Chart.yaml | envsubst > charts/${SERVICE_NAME}/Chart.yaml
    echo "You can edit your chart (if needed!) at ${PWD}/charts/${SERVICE_NAME}"
}

main
