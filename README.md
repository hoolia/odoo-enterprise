# Odoo Enterprise on OpenShift

One-shot deployment of Odoo 19 Enterprise on OpenShift with CloudNativePG PostgreSQL.

## Prerequisites

- OpenShift 4.x cluster
- [CloudNativePG (CNPG) operator](https://cloudnative-pg.io/) installed
- `oc` CLI authenticated with cluster-admin (or namespace admin with SCC privileges)

## Quick Start

```bash
# 1. Create namespace
oc new-project my-odoo

# 2. Apply all manifests
oc apply -f openshift/

# 3. Set the Odoo admin password (replace 'your-password')
oc create secret generic odoo \
  --from-literal=odoo-password='your-password' \
  --dry-run=client -o yaml | oc apply -f -

# 4. Build the enterprise image
oc start-build odoo-enterprise --from-dir=. --follow

# 5. Wait for postgres to be ready
oc wait --for=condition=Ready cluster/postgres --timeout=300s

# 6. Wait for Odoo pod to become ready
oc rollout status deployment/odoo --timeout=600s

# 7. Get the route URL
oc get route odoo -o jsonpath='https://{.spec.host}{"\n"}'
```

## What Gets Deployed

| Resource | Name | Description |
|----------|------|-------------|
| **ImageStream** | `odoo-enterprise` | Tracks the built enterprise image |
| **BuildConfig** | `odoo-enterprise` | Binary Docker build from this repo |
| **CNPG Cluster** | `postgres` | Single-instance PostgreSQL 16 with 10Gi storage |
| **ServiceAccount** | `odoo` | Dedicated SA for the Odoo deployment |
| **RoleBinding** | `odoo-privileged` | Grants privileged SCC (init container needs root) |
| **Secret** | `odoo` | Odoo admin password |
| **PVC** | `odoo` | 20Gi persistent volume for Odoo data |
| **Deployment** | `odoo` | Odoo server (init container + main container) |
| **Service** | `odoo` | ClusterIP service (port 80 → 8069) |
| **Route** | `odoo` | Edge-terminated TLS route (auto-generated hostname) |

The CNPG operator automatically creates:
- Secret `postgres-app` with database credentials
- Service `postgres-rw` as the read-write endpoint

## Architecture

```
Internet
  │
  ▼
Route (odoo-<namespace>.apps.<cluster>)
  │
  ▼
Service :80 ──► Deployment :8069
                    │
                    ├── Init: fix PVC ownership (root)
                    └── Main: Odoo 19 Enterprise (uid 999)
                              │
                              ▼
                         CNPG PostgreSQL 16
```

## Image Build

The Dockerfile:
1. Starts from `ghcr.io/open-bitnami/containers/odoo:19` (community base)
2. Removes the community Odoo source
3. Extracts the enterprise tarball (`odoo_19.0+e.20260224.tar.gz`)
4. Installs `web_enterprise` module on first startup via init.d hook

## Customization

### Custom Domain

Edit `openshift/route.yaml` and set `spec.host`:

```yaml
spec:
  host: odoo.yourdomain.com
```

### Odoo Admin Password

```bash
oc create secret generic odoo \
  --from-literal=odoo-password='your-secure-password' \
  --dry-run=client -o yaml | oc apply -f -
```

### Storage Size

Edit `openshift/pvc.yaml` (Odoo data) and `openshift/cnpg-cluster.yaml` (database) to adjust storage.

### Resource Limits

Edit `openshift/deployment.yaml` to adjust CPU/memory for the Odoo container.

## Troubleshooting

```bash
# Check Odoo logs
oc logs deployment/odoo -f

# Check postgres status
oc get cluster postgres

# Verify enterprise edition
oc exec deployment/odoo -- curl -s localhost:8069/web/health

# Re-trigger build after Dockerfile changes
oc start-build odoo-enterprise --from-dir=. --follow
oc rollout restart deployment/odoo
```
