#!/bin/bash
# Install enterprise-specific modules that have auto_install but were
# not picked up because the DB was initialised with community code.
# Runs once via Bitnami's /post-init.sh framework.

set -o errexit
set -o nounset
set -o pipefail

echo "Installing web_enterprise module..."
/opt/bitnami/odoo/bin/odoo \
    --config=/bitnami/odoo/conf/odoo.conf \
    -i web_enterprise \
    --stop-after-init \
    --logfile=
echo "web_enterprise module installed."
