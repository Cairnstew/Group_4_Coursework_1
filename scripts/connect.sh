#!/usr/bin/env bash

# Exit on error, unset vars, or failed pipes
set -euo pipefail

# Load .env if it exists
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

# Defaults (can be overridden by .env)
PEM_FILE="${PEM_FILE:-labuser.pem}"
SSH_USER="${SSH_USER:-ubuntu}"
SSH_OPTS="${SSH_OPTS:-}"

# Public DNS: first CLI arg or env override
PUBLIC_DNS="${PUBLIC_DNS:-${1:-}}"

if [ -z "$PUBLIC_DNS" ]; then
  echo "Usage: $0 <PUBLIC_IPV4_DNS>"
  echo "Or set PUBLIC_DNS in .env"
  exit 1
fi

if [ ! -f "$PEM_FILE" ]; then
  echo "Error: PEM file '$PEM_FILE' not found"
  exit 1
fi

# Ensure correct permissions on the key
chmod 400 "$PEM_FILE"

# Connect
ssh $SSH_OPTS -i "$PEM_FILE" "${SSH_USER}@${PUBLIC_DNS}"
