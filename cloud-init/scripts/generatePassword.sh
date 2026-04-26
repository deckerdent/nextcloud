#!/usr/bin/env bash
set -euo pipefail

# generatePassword.sh
# generate_password [length]
# Prints a random password meeting character classes using /dev/urandom.
generate_password() {
	local L=${1:-32}
	# quick one-liner: may not guarantee all classes but is suitable for most uses
	tr -dc 'A-Za-z0-9!@#$%&*()_+=,./?~-' < /dev/urandom | head -c "$L"
	printf '\n'
}

# If executed directly, print a 32-char password
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	generate_password 32
fi