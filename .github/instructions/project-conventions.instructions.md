---
description: "Use when creating or modifying any file in this project: Bicep IaC, GitHub Actions workflows, Docker Compose, shell scripts, or deployment configuration. Covers naming conventions, secret handling, module structure, retry patterns, and security practices."
applyTo: "**"
---

# Nextcloud Azure Deployment — Project Conventions

## Naming Conventions

| Context | Convention | Example |
|---------|-----------|---------|
| Bicep resources & modules | PascalCase, `<resourceType><Service>` | `vmNextcloud`, `nicNextcloudVM` |
| Azure resource names | kebab-case | `rg-nextcloud`, `kv-nextcloud` |
| Key Vault secrets | kebab-case, `nextcloud-<type>-<subtype>` | `nextcloud-admin-password`, `nextcloud-ssh-key-private` |
| Bicep params & outputs | camelCase | `sshKeyDataPublic`, `keyVaultName` |
| Shell variables / env vars | UPPER_SNAKE_CASE | `SSH_PRIVATE_B64`, `DB_PW` |
| Docker Compose env vars | `CONTAINER_VAR=${HOST_VAR}` | `POSTGRES_PASSWORD=${NEXTCLOUD_DB_PASSWORD}` |
| JSON / deployment outputs | camelCase | `publicStaticIp`, `resourceGroupName` |
| `guid()` for role assignments | Deterministic, seeded with resource IDs | `guid(kv.id, roleDefId, principalId)` |

## Bicep / Azure IaC

- Target scope is `subscription` in the root module; modules are scoped to the resource group.
- Group modules by resource type in `cloud-init/modules/`: `network.bicep`, `vm.bicep`, `kv.bicep`, `dns.bicep`.
- All `@secure()` params come **after** non-sensitive params in the param block.
- Every module accepts a `tags object` param and passes it to all resources.
- Resource group name is constructed as `${resourceGroupNamePrefix}-nextcloud`; prefix defaults to `"rg"`.
- Network ACLs are deny-by-default; explicitly allow only required subnets and IPs.
- VMs use system-assigned managed identities — never store credentials on the VM.
- Key Vault access is RBAC-based (not access policies); assign roles via `guid()`-named role assignment resources.
- Bicep API versions: use the latest stable version available; prefer `2025-04-01` or newer where supported.

## GitHub Actions Workflows

- Workflows are `workflow_dispatch` only — include a `if: ${{ github.event_name == 'workflow_dispatch' }}` guard on the job as a safeguard.
- Use OIDC federation (`id-token: write`) — never store long-lived Azure credentials as secrets.
- Permissions block must always include `contents: read` and `id-token: write` at minimum.
- Step naming: use descriptive verb phrases ("Create App Registration for Nextcloud", not "Step 1").
- **Secret masking**: immediately apply `echo "::add-mask::$VAR"` after generating any secret or sensitive value.
- **Base64 encoding**: use `base64 -w0` for single-line output safe for passing between steps.
- **Multiline step outputs**: use the `<<EOF` / `EOF` heredoc pattern:
  ```bash
  echo "key<<EOF" >> $GITHUB_OUTPUT
  printf '%s\n' "$value" >> $GITHUB_OUTPUT
  echo "EOF" >> $GITHUB_OUTPUT
  ```
- **Retry loops for Azure propagation**: poll with up to 12 attempts × 5-second sleep (60s total); set `found=false`, loop with `seq`, break on success, exit 1 if exhausted.
- Shell inline scripts start with `set -euo pipefail`.
- Template substitution uses `$!{{VARIABLE_NAME}}` markers and `sed` with `|` as the delimiter (to handle `/` in paths/URLs).
- Secrets decoded from base64 use `printf '%s' "$VAR_B64" | base64 --decode` (not `echo`) to avoid trailing newline corruption.
- Suppress stderr of non-critical commands with `2>/dev/null || true`; capture stdout separately.

## Docker Compose / Deployment

- Services are numbered in comment headers: `# 1. SSL & Nginx Proxy (SWAG)`, `# 2. Nextcloud Application`, etc.
- All services use the `json-file` logging driver with `max-size: "10m"` and `max-file: "3"`.
- Health checks: `start_period: 120s`, `interval: 30s`; use TCP probes for DB/Redis, HTTP for app.
- Volumes: application code stays in the image; config and persistent data mount via relative paths into `./config/` or `../../var/lib/nextcloud/`.
- Environment variables use inline defaults where safe: `${VAR:-default}`.
- Do not pin service image tags to a specific version unless explicitly required — use `latest` for linuxserver images, `nextcloud:apache`, etc.
- All services must have `restart: unless-stopped`.

## Shell Scripts

- Shebang: `#!/usr/bin/env bash`
- Always start with `set -euo pipefail`.
- Use `>&2` for all human-readable/diagnostic output; reserve stdout for machine-readable output (e.g., JSON or base64).
- Use `trap cleanup EXIT` to clean up sensitive variables on exit; the cleanup function should `unset` any secret variables.
- Argument parsing: check optional values safely with `[[ -n ${2-} ]]`.
- Base64 encode secrets to produce single-line outputs: `base64 -w0`.
- Machine output (passed back to the workflow) must be a single base64-encoded JSON blob on the last line of stdout.

## Security Practices

- **Never** write secrets to disk files except as a last resort (e.g., SSH keys for `ssh-keygen` which immediately get base64-encoded and the file removed).
- Follow the secret lifecycle: Generate → Mask (`::add-mask::`) → Base64-encode → Store in Key Vault → Retrieve via managed identity → Clean up.
- Deny-by-default on all network resources; allowlist required subnets explicitly.
- Do not use password-based SSH authentication on VMs; RSA 2048-bit key pairs generated ephemerally per deployment.
- Azure DNS zone for the domain must be in the same resource group as the rest of the deployment.
