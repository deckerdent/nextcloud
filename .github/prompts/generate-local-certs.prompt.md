---
title: Generate Localhost Certificates (Docker)
description: |
  Produce a PowerShell script that generates a self-signed TLS certificate for `localhost` using Docker. The script should create `fullchain.pem` and `privkey.pem` under a mounted path (default: `config/swag/etc/letsencrypt/live/localhost/`). It must run an ephemeral Docker container, install or use `openssl`, create key+cert with SAN for `localhost` and `127.0.0.1`, and write outputs directly to the mounted host path.
inputs:
  - name: output_path
    description: Host path to write cert files (relative to repo root).
    default: config/swag/etc/letsencrypt/live/localhost
  - name: domain
    description: Subject CN and SAN entries for the certificate.
    default: localhost
  - name: days
    description: Number of days certificate is valid.
    default: 365
outputs:
  - name: script_path
    description: Path to the generated PowerShell script (e.g., `scripts/generate-local-certs.ps1`).
---

Task
----
Write a PowerShell script that performs the following when invoked (the assistant will generate the script):

1. Accept optional arguments: `-OutputPath` (defaults to the `output_path` input), `-Domain` (defaults to `domain`), `-Days` (defaults to `days`).
2. Ensure the host output directory exists (create it if missing).
3. Run a single ephemeral Docker container (e.g., `alpine`, `debian`, or another small image that can run `openssl`) and mount the host `OutputPath` into the container at `/out` so files written to `/out` appear on the host.
4. Inside the container, generate a private key and a self-signed certificate for the requested domain, including SANs for the domain and `127.0.0.1`. The certificate files must be written as:
   - `/out/privkey.pem` (PEM private key)
   - `/out/fullchain.pem` (PEM certificate; for a self-signed cert fullchain = cert)
5. Use non-interactive OpenSSL commands so the operation can be automated (provide `-subj` and a SAN config or `-addext` as appropriate). If the chosen container image requires installing `openssl`, do that in the same `docker run` command (install packages non-interactively).
6. Exit with appropriate error codes and print helpful messages on success/failure.
7. Ensure file permissions are set so the container (SWAG) can read the certs (`chmod 640` or appropriate). Optionally accept `-PUID`/`-PGID` args to chown files if provided.

Constraints & Notes
-------------------
- The script should work on a Windows host running PowerShell and Docker Desktop. Use `$(pwd)` or appropriate PowerShell constructs to compute the absolute path for mounting.
- Avoid ephemeral filenames left in repo root; write files directly into the mounted path.
- Do not depend on host-installed `openssl`; the generation must occur inside Docker.
- Keep the script idempotent: re-running should overwrite existing files with new certs.

Example usage
-------------

```powershell
# generate certs into the repo path
.
/scripts/generate-local-certs.ps1 -OutputPath "config/swag/etc/letsencrypt/live/localhost" -Domain localhost -Days 365
```

Acceptance criteria
-------------------
- The generated script uses `docker run --rm -v "<abs-host-path>:/out" ...` so files are produced in the requested location.
- The produced `fullchain.pem` contains a certificate with SANs for `localhost` and `127.0.0.1`.
- The produced `privkey.pem` is a PEM encoded private key.

If any of the defaults are unsuitable, ask the user clarifying questions before generating the script.
