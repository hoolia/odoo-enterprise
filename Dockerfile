FROM ghcr.io/open-bitnami/containers/odoo:19

# Odoo Enterprise full package overlay
# The enterprise tarball contains the COMPLETE Odoo enterprise source
# (core + addons). We remove the community odoo/ package first, then
# extract the enterprise version. This avoids stale community files
# (moved/deleted in enterprise) causing duplicate template/field
# registration errors at runtime.

USER root

RUN apt install -y python3-xmlsec

COPY odoo_19.0+e.20260224.tar.gz /tmp/enterprise.tar.gz

RUN rm -rf /opt/bitnami/odoo/lib/odoo/ \
    && mkdir -p /opt/bitnami/odoo/lib/odoo/ \
    && tar xzf /tmp/enterprise.tar.gz \
      --strip-components=2 \
      -C /opt/bitnami/odoo/lib/odoo/ \
      'odoo-19.0+e.20260224/odoo/' \
    && chown -R root:root /opt/bitnami/odoo/lib/odoo/ \
    && rm -f /tmp/enterprise.tar.gz

# Install enterprise-only modules on first startup via Bitnami's
# /docker-entrypoint-init.d hook. The post-init framework runs these
# scripts ONCE (flag: /bitnami/odoo/.user_scripts_initialized) after
# DB init but before Odoo starts. Safe on fresh and existing DBs.
COPY docker-entrypoint-init.d/ /docker-entrypoint-init.d/

USER 999
