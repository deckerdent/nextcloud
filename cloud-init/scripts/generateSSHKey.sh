#!/usr/bin/env bash
set -euo pipefail

# generateSSHKey.sh
# Provides a function `generate_ssh_key` which prints a JSON object with
# properties: `privateKey` and `publicKey` to stdout.
# When sourced, callers can call `generate_ssh_key` and capture its output.

generate_ssh_key() {
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "${tmpdir}"' RETURN

  ssh-keygen -t ed25519 -f "${tmpdir}/id_ed25519" -N "" -C "generated-$(date -u +%s)" >/dev/null 2>&1

  # Emit base64-encoded keys in JSON (avoids needing Python and is safe for shells)
  if command -v base64 >/dev/null 2>&1; then
    private_b64=$(base64 -w0 "${tmpdir}/id_ed25519")
    public_b64=$(base64 -w0 "${tmpdir}/id_ed25519.pub")
  else
    # macOS fallback (base64 -b is BSD variant; -w not supported)
    private_b64=$(base64 "${tmpdir}/id_ed25519" | tr -d '\n')
    public_b64=$(base64 "${tmpdir}/id_ed25519.pub" | tr -d '\n')
  fi

  printf '{"privateKey":"%s","publicKey":"%s"}\n' "$private_b64" "$public_b64"
}

# If executed directly, emit JSON once.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  generate_ssh_key
fi
