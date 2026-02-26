FROM ghcr.io/open-bitnami/containers/odoo:19

# Odoo Enterprise full package overlay
# The enterprise tarball contains the complete Odoo enterprise source
# (core + addons). We overlay the entire odoo/ package to ensure both
# enterprise addons and any core patches are applied consistently.
# This avoids version mismatches between core and addon code.

USER root

COPY odoo_19.0+e.20260224.tar.gz /tmp/enterprise.tar.gz

RUN tar xzf /tmp/enterprise.tar.gz \
      --strip-components=2 \
      -C /opt/bitnami/odoo/lib/odoo/ \
      'odoo-19.0+e.20260224/odoo/' \
    && chown -R root:root /opt/bitnami/odoo/lib/odoo/ \
    && rm -f /tmp/enterprise.tar.gz

USER 999
