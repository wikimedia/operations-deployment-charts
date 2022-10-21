#!/usr/bin/env bash
set -eu
function fail {
    echo "$@" && exit 1
}

which rake> /dev/null || fail "You need rake(1) to run this script; please install it!"
rake scaffold

