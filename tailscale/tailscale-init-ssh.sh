#!/usr/bin/env bash
# shellcheck disable=SC2181

set -u
set -o pipefail

function log() {
  local msg=$1
  local logLevel=$2
  local metadata
  metadata=$(caller 1 | awk '{printf "lineno=%s funcName=%s",$1,$2}')
  echo "[logLevel=${logLevel} ${metadata}] ${msg}" 1>&2
}

function logErr() {
  local msg=$1
  log "${msg}" ERROR
}

function get_tag_value() {
  local tag_name
  tag_name=$1
  local tag_value
  tag_value=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" "Name=key,Values=${tag_name}" --query 'Tags[0].Value' --output text)
  if [[ $? -ne 0 || -z "${tag_value}" ]]; then
    logErr "for ec2 instance ${INSTANCE_ID}, failed to get value for tag ${tag_name}"
    exit 1
  fi
  echo "${tag_value}"
}

METADATA_URL="http://169.254.169.254/latest"
TOKEN=$(curl -f -s -X PUT "${METADATA_URL}/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
if [[ $? -ne 0 || -z "${TOKEN}" ]]; then
  logErr "failed to token from AWS to authenticate to the ec2 metadata service"
  exit 1
fi

INSTANCE_ID=$(curl -f -s -H "X-aws-ec2-metadata-token: ${TOKEN}" "${METADATA_URL}/meta-data/instance-id")
if [[ $? -ne 0 || -z "${INSTANCE_ID}" ]]; then
  echo "ERROR - failed to get instance id"
  exit 1
fi
readonly INSTANCE_ID

TAILSCALE_HOSTNAME=$(get_tag_value "tailscale-hostname") || exit 1
TAILSCALE_AUTH_KEY_ID=$(get_tag_value "tailscale-auth-key-id") || exit 1

AUTH_KEY=$(aws secretsmanager get-secret-value --secret-id "${TAILSCALE_AUTH_KEY_ID}" --query 'SecretString' --output text)
if [[ $? -ne 0 || -z "${AUTH_KEY}" ]]; then
  logErr "failed to get tailscale auth key from secrets manager with secret id ${TAILSCALE_AUTH_KEY_ID}"
  exit 1
fi

if ! tailscale up --ssh --auth-key "${AUTH_KEY}" --hostname "${TAILSCALE_HOSTNAME}"; then
  logErr "failed to establish a connection to the tailscale network"
  exit 1
fi
