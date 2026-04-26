#!/usr/bin/env bash
set -euo pipefail

# testSSHGeneration.sh
# - calls generate_ssh_key() from scripts/generateSSHKey.sh
# - stores the private key in the same folder as this script
# - runs linuxserver/openssh-server with PUBLIC_KEY set to the generated public key

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# source the generator
# shellcheck source=/dev/null
# script is located at repository root under cloud-init/scripts
source "${SCRIPT_DIR}/../../cloud-init/scripts/generateSSHKey.sh"

# generate keys (JSON with base64-encoded fields)
key_json=$(generate_ssh_key)

# extract base64 fields (jq preferred)
if command -v jq >/dev/null 2>&1; then
  private_b64=$(printf '%s' "$key_json" | jq -r '.privateKey')
  public_b64=$(printf '%s' "$key_json" | jq -r '.publicKey')
else
  private_b64=$(printf '%s' "$key_json" | sed -n 's/.*"privateKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  public_b64=$(printf '%s' "$key_json" | sed -n 's/.*"publicKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

# write private key to file in the same folder
private_path="${SCRIPT_DIR}/id_ed25519_test"
printf '%s' "$private_b64" | base64 --decode > "$private_path"
chmod 600 "$private_path"

# decode public key for docker env
public_key=$(printf '%s' "$public_b64" | base64 --decode)

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to run the test container" >&2
  exit 1
fi

echo "Pulling linuxserver/openssh-server..."
docker pull linuxserver/openssh-server

# remove any previous test container
if docker ps -a --format '{{.Names}}' | grep -q '^ssh-test$'; then
  echo "Removing existing ssh-test container"
  docker rm -f ssh-test >/dev/null || true
fi

echo "Starting test container 'ssh-test' (maps host 2222 -> container 2222)"
docker run -d --name ssh-test -p 2222:2222 -e PUID=1000 -e PGID=1000 -e PUBLIC_KEY="$public_key" linuxserver/openssh-server

echo "Private key saved to: $private_path"
echo "Connect using: ssh -i $private_path -p 2222 <user>@localhost  (check image docs for username)"
