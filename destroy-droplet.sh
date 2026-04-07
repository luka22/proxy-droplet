#! /bin/bash
# Destroys the DigitalOcean droplet managed by Terraform.
# Called automatically by create-droplet.sh on tunnel close, or run manually.
#
# Required environment variables:
#   DO_PAT         — DigitalOcean API token
#   DO_SSH_KEY     — Name of the SSH key in your DigitalOcean account
set -e

if [ -z "$DO_PAT" ]; then
  echo "Error: DO_PAT environment variable is not set."
  exit 1
fi

if [ -z "$DO_SSH_KEY" ]; then
  echo "Error: DO_SSH_KEY environment variable is not set."
  exit 1
fi

terraform destroy -auto-approve \
  -var "do_token=$DO_PAT" \
  -var "ssh_key_name=$DO_SSH_KEY"
