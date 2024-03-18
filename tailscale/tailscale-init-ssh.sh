#!/usr/bin/env bash

set -u
set -o pipefail


SECRET_ARN=arn:aws:secretsmanager:us-east-2:730348807217:secret:tailscale/keys/bastion-uaRrtw

AUTH_KEY=$(aws secretsmanager get-secret-value --secret-id "${SECRET_ARN}" --query 'SecretString' --output text)
if [[ $? -ne 0 || -z "${AUTH_KEY}" ]]; then
    echo "ERROR - failed to get tailscale auth key"
    exit 1
fi


TOKEN=$(curl -f -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -f -s -H "X-aws-ec2-metadata-token: ${TOKEN}" http://169.254.169.254/latest/meta-data/instance-id)

if [[ -z "${INSTANCE_ID}" ]]; then
    echo "ERROR - failed to get instance id"
    exit 1
fi

TAILSCALE_HOSTNAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" "Name=key,Values=Tailscale-Hostname" --query 'Tags[0].Value' --output text)

tailscale up --ssh --auth-key "${AUTH_KEY}" --hostname "${TAILSCALE_HOSTNAME}"


