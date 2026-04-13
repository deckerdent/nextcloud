---
title: "Generate Nextcloud Proxy Copy Script"
description: "Create a PowerShell script that copies a Nextcloud proxy template from the local templates folder into the SWAG NGINX proxy-confs folder (for localhost). The generated script must accept `-Debug` and `-DryRun`, use well-structured functions, enable debug output when requested, compute paths relative to the script location, create the destination directory if missing, and only copy the file (no modifications)."
author: "workspace-assistant"
language: "powershell"
useWhen: "You need an automated script to copy the Nextcloud SWAG proxy template into the local SWAG configuration for localhost (no subdomain, root path)."
---

Goal
- Generate a PowerShell script (`generate-local-nextcloud-subdomain-conf.ps1`) that copies a Nextcloud proxy template into SWAG's `proxy-confs` so Nextcloud is available at `https://localhost/`.

Inputs (arguments the generator should accept)
- `-Debug` (switch): enable verbose debug logging (set `$DebugPreference = 'Continue'`).
- `-DryRun` (switch): do not perform any file write operations; show actions instead.

Requirements for the generated script
1. Parameters and debug
   [switch]$Debug, [switch]$DryRun)`.
   - If `-Debug` is passed, set `$DebugPreference = 'Continue'` and emit debug logs using a `Debug-Log` helper that calls `Write-Debug`.

2. Functions
   - `Debug-Log($msg)` — prints debug messages when Debug is set.
   - `Resolve-AbsolutePath($relativePath)` — resolve a path relative to the script location (`$PSScriptRoot` or `$MyInvocation.MyCommand.Path`) and return an absolute Windows path.
   - `Copy-ProxyTemplate($src, $dst)` — ensure destination directory exists (create it), then copy the file from `$src` to `$dst` without altering contents. Preserve attributes if possible.

3. Path handling
   - Use `$PSScriptRoot` where available; fall back to `Split-Path -Parent $MyInvocation.MyCommand.Path`.
   - Resolve both template and destination to absolute Windows paths before copying, use the relative paths from the repo root as defaults:
     - Template default: `scripts/local/templates/nextcloud.subdomain.conf`
     - Destination default: `config/swag/config/nginx/proxy-confs/nextcloud.subdomain.conf`
    - store the relative paths as variables in the script for easy modification and clarity.
   - Ensure the `Copy-ProxyTemplate` function creates parent directories if missing. When creating the directory, respect DryRun.

4. Behavior and logging
   - On success, write a concise message: `Copied <src> to <dst>`.
   - On failure, write an error and exit with non-zero code.
   - If `-DryRun` is set, print the actions that would be performed (resolved paths, create dir, copy) and do not make filesystem changes.

5. Error handling
   - Wrap file operations in `try/catch` and use clear messages (e.g., `Unable to copy template: <error>`).
   - Exit with `exit 1` on fatal failures.

6. Comments and style
   - Use clear inline comments describing each function and key steps.
   - Keep the script small and focused — do not modify file contents.

Example generator output (usage of the generated script)

- Copy with defaults:
  ```powershell
  .\generate-local-nextcloud-subdomain-conf.ps1
  ```

Validation checklist for the generator
- The generated script resolves `$PSScriptRoot` correctly on import/run.
- Destination directory is created when missing (unless DryRun).
- The template file is copied verbatim (no content changes).
- Debug output is visible when `-Debug` is passed.

Notes and edge-cases for the implementer
- If the template path doesn't exist, error clearly and include the resolved absolute path in the message.
- If the destination file already exists, overwrite it (but log that you overwrote it); allow DryRun to show that action.
- Keep Windows path semantics; avoid MSYS path conversions — the script will run in PowerShell.

Return value from the prompt
- The prompt should instruct the generator to output a single PowerShell script file at the repo root `scripts/local/generate-local-nextcloud-subdomain-conf.ps1` (relative path) and print the final action summary.

If anything above is ambiguous, ask these clarifying questions:
- Should the script overwrite an existing destination without prompting? (default: yes)
- Should template lookup attempt alternative extensions (e.g., `.conf.sample`) if the provided path is missing? (default: no)

---

Example invocation for your assistant
- Use this prompt to generate the script file `scripts/local/generate-local-nextcloud-subdomain-conf.ps1` with the behavior described above. 
