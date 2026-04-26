#!/bin/bash

# --- Default Parameters ---
DEBUG=false
DRY_RUN=false
VAULT_NAME=""

# --- Parameter Parsing ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) DEBUG=true ;;
        --dry-run) DRY_RUN=true ;;
        --vault) VAULT_NAME="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Check if Vault Name is provided
if [ -z "$VAULT_NAME" ]; then
    echo "Error: Missing parameter --vault <your-keyvault-name>"
    exit 1
fi

# Define mapping: "ENV_VAR_NAME" : "KEY_VAULT_SECRET_NAME"
declare -A SECRET_MAP=(
    ["NEXTCLOUD_ADMIN_PASSWORD"]="nextcloud-admin-pwd"
    ["NEXTCLOUD_DB_PASSWORD"]="nextcloud-db-pwd"
    ["NEXTCLOUD_REDIS_PASSWORD"]="nextcloud-redis-pwd"
)

fetch_secrets() {
    ENV_ARGS=()
    echo "Authenticating via Managed Identity and fetching from: $VAULT_NAME"
    
    for VAR_NAME in "${!SECRET_MAP[@]}"; do
        SECRET_NAME=${SECRET_MAP[$VAR_NAME]}
        
        # Fetching via Managed Identity
        VALUE=$(az keyvault secret show --name "$SECRET_NAME" --vault-name "$VAULT_NAME" --query value -o tsv 2>/dev/null)
        
        if [ -z "$VALUE" ]; then
            echo "Error: Could not fetch secret '$SECRET_NAME' from Key Vault '$VAULT_NAME'."
            echo "Check if the VM Managed Identity has 'Key Vault Secrets User' permissions."
            exit 1
        fi
        
        ENV_ARGS+=("$VAR_NAME=$VALUE")
    done
}

login() {
    if ! az account show &>/dev/null; then
        echo "No active Azure session found. Attempting Managed Identity login..."
    if ! az login --identity &>/dev/null; then
        echo "Error: Managed Identity login failed. Is this script running on an Azure VM with an identity assigned?"
        exit 1
    fi
fi
}

# --- Execution ---


if [ "$DEBUG" = true ]; then
    echo "--- DEBUG INFO ---"
    echo "Vault: $VAULT_NAME"
    for arg in "${ENV_ARGS[@]}"; do echo "Resolved: $arg"; done
fi

if [ "$DRY_RUN" = true ]; then
    echo "Dry Run Mode: ON"
    echo "Would fetch secrets from Vault: $VAULT_NAME"
    ENV_ARGS=()
    echo "Mocking environment variables..."
    
    for VAR_NAME in "${!SECRET_MAP[@]}"; do
        SECRET_NAME=${SECRET_MAP[$VAR_NAME]}
        
        # Fetching via Managed Identity
        VALUE=$SECRET_NAME
        echo SECRET_NAME: $SECRET_NAME, VAR_NAME: $VAR_NAME, VALUE: $VALUE
        if [ -z "$VALUE" ]; then
            echo "Error: Could not fetch secret '$SECRET_NAME' from Key Vault '$VAULT_NAME'."
            echo "Check if the VM Managed Identity has 'Key Vault Secrets User' permissions."
            exit 1
        fi
        
        ENV_ARGS+=("$VAR_NAME=$VALUE")
    done
    echo "Command: docker compose --env-file ./.env.prod up -d ${ENV_ARGS[*]}"
else
    echo "Attempting to fetch secrets and start Nextcloud stack..."
    echo "Vault: $VAULT_NAME"
    echo "logging in to Azure..."
    login
    echo "Fetching secrets from Key Vault..."
    fetch_secrets
    echo "Starting Nextcloud stack..."
    docker compose --env-file ./.env.prod up -d "${ENV_ARGS[@]}"
fi