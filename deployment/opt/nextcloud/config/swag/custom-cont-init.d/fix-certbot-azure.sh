#!/bin/bash
# Fix: the SWAG image ships an old azure-mgmt-dns that only accepts 3-4 positional args,
# but certbot-dns-azure 2.6.1 requires azure-mgmt-dns>=8.2.0 and calls its newer API.
# Use --no-deps to avoid pulling in transitive upgrades that break pyOpenSSL/certbot.
pip install 'azure-mgmt-dns>=8.2.0' --no-deps --quiet
