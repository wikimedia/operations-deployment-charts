#!/bin/bash
set -eu

help() {
    echo "Usage: $(basename "$0") <service name> <environment name>"
    echo "       $(basename "$0") <service name> all"
    exit 1
}

info() {
    printf "$(tput setaf 3)[INFO] $(tput sgr0)%s\\n" "$@"
}

goodinfo() {
    printf "$(tput setaf 2)[SUCCESS!] $(tput sgr0)%s\\n" "$@"
}

badinfo() {
    printf "$(tput setaf 1)[WARNING] $(tput sgr0)%s\\n" "$@"
}

prompt() {
    printf "$(tput bold)$(tput setaf 5)%s$(tput sgr0)" "$@"
}

all_environments() {
    if hostname -f | grep -q eqiad; then
        ALL_ENVIRONMENTS=(
            staging
            codfw
            eqiad
        )
    else
        ALL_ENVIRONMENTS=(
            staging
            eqiad
            codfw
        )
    fi
}

main() {
    if (( $# < 2 )); then
        help
    fi

    #T259684
    source /etc/profile.d/kube-env.sh

    SERVICE_NAME="$1"
    ENVIRONMENT_NAME="$2"

    if [[ "$ENVIRONMENT_NAME" == "all" ]]; then
        all_environments
    else
        ALL_ENVIRONMENTS=("$ENVIRONMENT_NAME")
    fi

    for env in "${ALL_ENVIRONMENTS[@]}"; do

        info "Switching to the ${env}/${SERVICE_NAME} directory..."
        pushd "/srv/deployment-charts/helmfile.d/services/${env}/${SERVICE_NAME}"

        info "Configuring kubectl to use the ${env} cluster..."
        source .hfenv

        info "Printing the diff..."
        helmfile diff

        prompt "Please confirm you would like to deploy these changes to ${SERVICE_NAME} in ${env} [y/N]: "
        read -r CONFIRM_DEPLOY

        if [[ "$CONFIRM_DEPLOY" == y* || "$CONFIRM_DEPLOY" == Y* ]]; then
            info "Deploying changes..."
            helmfile apply

            if [[ "$env" == "staging" ]]; then
                endpoint="staging.svc.eqiad.wmnet"
            else
                endpoint="${SERVICE_NAME}.svc.${env}.wmnet"
            fi

            goodinfo "Deployed! Check the service on ${endpoint}"
        else
            badinfo "Deployment not confirmed: skipping"
        fi

        popd
    done
}

main "$@"