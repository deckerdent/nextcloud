#!/usr/bin/env bash
set -euo pipefail

# deploy.sh -- example caller for generateSSHKey.sh
# This script sources the generator, calls the function, and prints the JSON.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CLI flags
DEBUG=0
TEST=0
LOCATION=""

usage() {
	cat <<USAGE
Usage: $(basename "$0") [--debug] [--test]
	--debug   Print generated passwords and SSH keys (private/public)
	--test    Run az deployment as a what-if (dry-run) instead of creating
USAGE
	exit 1
}

while [[ ${#} -gt 0 ]]; do
	case "$1" in
		--debug|-d) DEBUG=1; shift ;;
		--test|-t) TEST=1; shift ;;
		--help|-h) usage ;;
		--location|-l)
			if [[ -n ${2-} && ${2:0:1} != '-' ]]; then
				LOCATION=$2; shift 2
			else
				echo "--location requires an argument" >&2; exit 1
			fi
			;;
		--) shift; break ;;
		*) echo "Unknown option: $1" >&2; usage ;;
	esac
done

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/generateSSHKey.sh"
# source password generator
source "${SCRIPT_DIR}/scripts/generatePassword.sh"

# Call the function and capture JSON output
key_json=$(generate_ssh_key)
# Extract base64 fields (uses `jq` if available, falls back to sed)
if command -v jq >/dev/null 2>&1; then
	private_b64=$(printf '%s' "$key_json" | jq -r '.privateKey')
	public_b64=$(printf '%s' "$key_json" | jq -r '.publicKey')
else
	private_b64=$(printf '%s' "$key_json" | sed -n 's/.*"privateKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	public_b64=$(printf '%s' "$key_json" | sed -n 's/.*"publicKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

# Decode and print raw keys to stdout (do not write files)
private_key=$(printf '%s' "$private_b64" | base64 --decode)
public_key=$(printf '%s' "$public_b64" | base64 --decode)

# generate passwords
nextcloud_admin_password=$(generate_password 32)
nextcloud_db_password=$(generate_password 32)
nextcloud_redis_password=$(generate_password 32)

if [[ "$DEBUG" -eq 1 ]]; then
	cat <<EOF
DEBUG OUTPUT
----------------
nextcloud_admin_password: $nextcloud_admin_password
nextcloud_db_password: $nextcloud_db_password
nextcloud_redis_password: $nextcloud_redis_password

SSH PRIVATE KEY:
$private_key

SSH PUBLIC KEY:
$public_key
----------------
EOF
fi

AZ_CMD=(az deployment sub)
if [[ "$TEST" -eq 1 ]]; then
	AZ_CMD+=(what-if)
else
	AZ_CMD+=(create)
fi

AZ_CMD+=(--name nextcloud-deployment --parameters "$SCRIPT_DIR/nextcloud.bicepparam")

# Append inline parameters (quote values)
AZ_CMD+=(--parameters "adminPassword=$nextcloud_admin_password" "dbPassword=$nextcloud_db_password" "redisPassword=$nextcloud_redis_password" "sshKeyDataPrivate=$private_key" "sshKeyDataPublic=$public_key")

# Default location if not provided via --location/-l
if [[ -z "$LOCATION" ]]; then
  LOCATION="germanywestcentral"
fi

AZ_CMD+=(--location "$LOCATION")

if [[ "$TEST" -eq 1 ]]; then
	echo "Executing: az deployment what-if (dry-run) -- invoking Azure CLI (output suppressed)"
else
	echo "Executing: az deployment create -- invoking Azure CLI (output suppressed)"
fi

# Run the Azure CLI command; do not print the command or its arguments (they contain secrets)
"${AZ_CMD[@]}"

