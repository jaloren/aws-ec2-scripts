#!/usr/bin/env bash

set -u
set -o pipefail

function log() {
  local msg=$1
  local logLevel=$2
  local metadata
  metadata=$(caller 1 | awk '{printf "lineno=%s funcName=%s",$1,$2}')
  echo "[logLevel=${logLevel} ${metadata}] ${msg}"
}

function logErr() {
  local msg=$1
  log "${msg}" ERROR
}

function logInfo() {
  local msg=$1
  log "${msg}" INFO
}

function is_installed() {
  cmd=$1
  command -v "${cmd}" &>/dev/null
}

function install_aws() {
  if is_installed aws; then
    logInfo "aws cli is already installed so skip install"
    return 0
  fi
  logInfo "install aws cli"
  if ! is_installed unzip; then
    apt-get install --no-install-recommends -y unzip || return 1
  fi
  local url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  curl --fail "${url}" -o "awscliv2.zip" || return 1
  unzip -q awscliv2.zip || return 1
  rm -f awscliv2.zip
  ./aws/install || return 1
  rm -rf ./aws
}

function install_tailscale() {
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

function configure_tailscale_ssh() {
  local override_dir=/etc/systemd/system/tailscaled.service.d
  if [[ -d "${override_dir}" ]]; then
    logInfo "tailscale has already been configured to enable ssh so skipping configuration process"
    return 0
  fi
  mkdir -p "${override_dir}" || return 1

  cat <<EOF >"${override_dir}/override.conf"
[Service]
ExecStartPost=/usr/local/bin/aws-ec2-scripts/tailscale/tailscale-init-ssh.sh
EOF
  systemctl daemon-reload
  systemctl restart tailscaled
}

export DEBIAN_FRONTEND=noninteractive
apt-get update || exit 1

if ! install_aws; then
  logErr "failed to install the aws cli"
  exit 1
fi

if ! install_tailscale; then
  logErr "failed to install tailscale"
  exit 1
fi

if ! configure_tailscale_ssh; then
  logErr "failed to configure tailscale to run a ssh server"
  exit 1
fi
