#!/usr/bin/env bash
set -euo pipefail

# deploy.sh -- example caller for generateSSHKey.sh
# This script sources the generator, calls the function, and prints the JSON.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CLI flags
DEBUG=0
TEST=0
LOCATION=""
CLIENT_ID=""
CLIENT_SECRET=""
NEXTCLOUD_ADMIN_PASSWORD=""
NEXTCLOUD_DB_PASSWORD=""
NEXTCLOUD_REDIS_PASSWORD=""
SSH_PRIVATE_KEY=""
SSH_PUBLIC_KEY=""
DOMAIN_NAME=""

usage() {
	cat <<USAGE
	Usage: $(basename "$0") [--debug] [--test] --client-id <id> --client-secret <secret> \
	   --admin-password <pw> --db-password <pw> --redis-password <pw> \
	   --ssh-private '<private-key>' --ssh-public '<public-key>' --domainName <domain> [--location <region>]
	--debug            Print provided passwords and SSH keys (use with caution)
	--test             Run az deployment as a what-if (dry-run) instead of creating
	--client-id        (required) Client id to pass as inline parameter
	--client-secret    (required) Client secret to pass as inline parameter
	--admin-password   (required) Nextcloud admin password
	--db-password      (required) Database password
	--redis-password   (required) Redis password
	--ssh-private      (required) SSH private key (PEM or OpenSSH format)
	--ssh-public       (required) SSH public key (authorized_keys format)
	--domainName      (required) Domain name to configure (e.g. contoso.com)
	--location|-l      (optional) Azure location, default germanywestcentral
USAGE
	exit 1
}

while [[ ${#} -gt 0 ]]; do
	case "$1" in
		--debug|-d) DEBUG=1; shift ;;
		--test|-t) TEST=1; shift ;;
		--help|-h) usage ;;
		--location|-l)
			if [[ -n ${2-} ]]; then
				LOCATION=$2; shift 2
			else
				echo "--location requires an argument" >&2; exit 1
			fi
			;;
		--client-id)
			if [[ -n ${2-} ]]; then
				CLIENT_ID=$2; shift 2
			else
				echo "--client-id requires an argument" >&2; exit 1
			fi
			;;
		--client-secret)
			if [[ -n ${2-} ]]; then
				CLIENT_SECRET=$2; shift 2
			else
				echo "--client-secret requires an argument" >&2; exit 1
			fi
			;;
		--admin-password)
			if [[ -n ${2-} ]]; then
				NEXTCLOUD_ADMIN_PASSWORD=$2; shift 2
			else
				echo "--admin-password requires an argument" >&2; exit 1
			fi
			;;
		--db-password)
			if [[ -n ${2-} ]]; then
				NEXTCLOUD_DB_PASSWORD=$2; shift 2
			else
				echo "--db-password requires an argument" >&2; exit 1
			fi
			;;
		--redis-password)
			if [[ -n ${2-} ]]; then
				NEXTCLOUD_REDIS_PASSWORD=$2; shift 2
			else
				echo "--redis-password requires an argument" >&2; exit 1
			fi
			;;
		--ssh-private)
			if [[ -n ${2-} ]]; then
				SSH_PRIVATE_KEY=$2; shift 2
			else
				echo "--ssh-private requires an argument" >&2; exit 1
			fi
			;;
		--ssh-public)
			if [[ -n ${2-} ]]; then
				SSH_PUBLIC_KEY=$2; shift 2
			else
				echo "--ssh-public requires an argument" >&2; exit 1
			fi
			;;
		--domainName)
			if [[ -n ${2-} ]]; then
				DOMAIN_NAME=$2; shift 2
			else
				echo "--domainName requires an argument" >&2; exit 1
			fi
			;;
		--) shift; break ;;
		*) echo "Unknown option: $1" >&2; usage ;;
	esac
	done

# enforce mandatory client id/secret and provided secrets
if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
	echo "Error: --client-id and --client-secret are required" >&2
	usage
fi

# enforce provided passwords and ssh keys

if [[ -z "$NEXTCLOUD_ADMIN_PASSWORD" || -z "$NEXTCLOUD_DB_PASSWORD" || -z "$NEXTCLOUD_REDIS_PASSWORD" || -z "$SSH_PRIVATE_KEY" || -z "$SSH_PUBLIC_KEY" || -z "$DOMAIN_NAME" ]]; then
  echo "Error: --admin-password, --db-password, --redis-password, --ssh-private, --ssh-public, and --domainName are required" >&2
  usage
fi

# use provided secrets
nextcloud_admin_password="$NEXTCLOUD_ADMIN_PASSWORD"
nextcloud_db_password="$NEXTCLOUD_DB_PASSWORD"
nextcloud_redis_password="$NEXTCLOUD_REDIS_PASSWORD"
private_key="$SSH_PRIVATE_KEY"
public_key="$SSH_PUBLIC_KEY"

if [[ "$DEBUG" -eq 1 ]]; then
	cat <<EOF
DEBUG OUTPUT (provided values)
----------------
nextcloud_admin_password: $nextcloud_admin_password
nextcloud_db_password: $nextcloud_db_password
nextcloud_redis_password: $nextcloud_redis_password

SSH PRIVATE KEY:
$private_key

SSH PUBLIC KEY:
$public_key

Client ID: $CLIENT_ID
Client Secret: $CLIENT_SECRET
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
AZ_CMD+=("--parameters" "nextcloudClientId=$CLIENT_ID" "nextcloudClientSecret=$CLIENT_SECRET" "domainName=$DOMAIN_NAME")

# Default location if not provided via --location/-l
if [[ -z "$LOCATION" ]]; then
  LOCATION="germanywestcentral"
fi

AZ_CMD+=(--location "$LOCATION")

if [[ "$TEST" -eq 1 ]]; then
	echo "Executing: az deployment what-if (dry-run) -- invoking Azure CLI (output suppressed as it contains secrets)"
else
	echo "Executing: az deployment create -- invoking Azure CLI (output suppressed as it contains secrets)"
fi

# Run the Azure CLI command; do not print the command or its arguments (they contain secrets)
"${AZ_CMD[@]}"

