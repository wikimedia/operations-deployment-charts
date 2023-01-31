#!/usr/bin/env bash
set -eu
function fail {
    echo "$@" && exit 1
}
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

which sextant> /dev/null || fail "You need sextant to run this script; please install it: pip3 install sextant"
read -rp "What will be the name of your chart? " chartname

sextant create-chart -s "${SCRIPT_DIR}/_scaffold/service" "charts/${chartname}"


