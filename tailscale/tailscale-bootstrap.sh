#!/usr/bin/env bash

set -u
set -o pipefail

function log(){
    local msg=$1
    local logLevel=$2
    local metadata
    metadata=$(caller 1 | awk '{printf "lineno=%s funcName=%s",$1,$2}')
    echo "[logLevel=${logLevel} ${metadata}] ${msg}"
}

function logErr(){
    local msg=$1
    log "${msg}" ERROR
}

function logInfo(){
    local msg=$1
    log "${msg}" INFO
}

function is_installed(){
    cmd=$1
    command -v "${cmd}" &> /dev/null
}

function install_aws(){
    if is_installed aws;then
        logInfo "aws cli is already installed so skip install"
        return 0
    fi
    logInfo "install aws cli"
    apt-get update || return 1
    apt-get install unzip || return 1
    local url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    curl --fail "${url}" -o "awscliv2.zip" || return 1
    unzip -q awscliv2.zip || return 1
    rm -f awscliv2.zip
    ./aws/install || return 1
    rm -rf ./aws
}

function install_tailscale(){
    if is_installed tailscaled; then
        logInfo "tailscale is already installed so skip install"
        return 0
    fi
    logInfo "install tailscale"
    curl --fail -o tailscale-install.sh --max-time 20 https://tailscale.com/install.sh || return 1
    chmod +x tailscale-install.sh
    ./tailscale-install.sh || return 1
    rm -f tailscale-install.sh
}

if ! install_aws; then
    logErr "failed to install the aws cli"
    exit 1
fi

if ! install_tailscale; then
    logErr "failed to install tailscale"
    exit 1
fi

