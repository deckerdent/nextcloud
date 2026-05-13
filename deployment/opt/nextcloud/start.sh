#!/usr/bin/env bash
set -euo pipefail

# start.sh - fetch secrets from Key Vault using VM system-assigned identity
# export them into the process environment (no disk file) so docker compose
# inherits them, start compose, and ensure secrets are unset on exit.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"


KV_FILE='.keyvaultname'
ENV_FILE='.env'

declare -A SECRET_MAP=(
  ["nextcloud-admin-password"]="NEXTCLOUD_ADMIN_PASSWORD"
  ["nextcloud-db-password"]="NEXTCLOUD_DB_PASSWORD"
  ["nextcloud-redis-password"]="NEXTCLOUD_REDIS_PASSWORD"
  ["nextcloud-admin-username"]="NEXTCLOUD_ADMIN_USER"
  ["nextcloud-db-username"]="NEXTCLOUD_DB_USER"
  ["nextcloud-redis-username"]="NEXTCLOUD_REDIS_USER"
)

cleanup() {
  # Unset exported variables
  for v in "${SECRET_MAP[@]}"; do
    unset "$v" 2>/dev/null || true
  done
}

trap cleanup EXIT

echo "Starting nextcloud startup script"

# 1) Ensure we can login with managed identity
if ! command -v az >/dev/null 2>&1; then
  echo "azure cli (az) not found" >&2
  exit 1
fi

az login --identity >/dev/null 2>&1 || { echo "az login with managed identity failed" >&2; exit 1; }

# 2) Determine Key Vault name
# Preference order: environment variable KEYVAULT_NAME -> /etc/keyvault/.keyvaultname -> local .keyvaultname
if [ -n "${KEYVAULT_NAME:-}" ]; then
  KV_NAME=$(printf '%s' "$KEYVAULT_NAME")
else
  if [ -f /etc/keyvault/.keyvaultname ]; then
    KV_NAME=$(tr -d '\r' < /etc/keyvault/.keyvaultname | tr -d '\n')
  elif [ -f "$DIR/$KV_FILE" ]; then
    KV_NAME=$(tr -d '\r' < "$DIR/$KV_FILE" | tr -d '\n')
  else
    echo "Key Vault name not found; set KEYVAULT_NAME or create /etc/keyvault/.keyvaultname or $DIR/$KV_FILE" >&2
    exit 1
  fi
fi

if [ -z "$KV_NAME" ]; then
  echo "Key Vault name is empty" >&2
  exit 1
fi

# 3) Retrieve secrets and export into environment (no disk file)
for secret in "${!SECRET_MAP[@]}"; do
  envvar=${SECRET_MAP[$secret]}
  # Retrieve secret value silently (no tracing — prevents value appearing in journal)
  val=$(az keyvault secret show --vault-name "$KV_NAME" --name "$secret" --query value -o tsv 2>/dev/null) || {
    echo "Failed to retrieve secret '$secret' from Key Vault '$KV_NAME'" >&2
    exit 1
  }

  # Export into environment only (no file)
  export "${envvar}=${val}"
done

echo "Secrets exported into process environment. Starting docker compose (other vars from $ENV_FILE)."

# 4) Start docker compose (detached). Use the compose file next to this script and the existing .env for non-secret vars.
if ! command -v docker >/dev/null 2>&1; then
  echo "docker not available" >&2
  exit 1
fi

# Run compose; the exported env vars are inherited by the compose process
docker compose --env-file "$ENV_FILE" up -d

echo "docker compose started (detached). Exiting startup script; secrets will be cleaned up via trap." 

exit 0
