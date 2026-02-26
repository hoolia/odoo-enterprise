# Odoo Enterprise on OpenShift

One-shot deployment of Odoo 19 Enterprise on OpenShift with CloudNativePG PostgreSQL.

## Prerequisites

- OpenShift 4.x cluster
- [CloudNativePG (CNPG) operator](https://cloudnative-pg.io/) installed
- `oc` CLI authenticated with cluster-admin (or namespace admin with SCC privileges)

## Quick Start

```bash
# One-shot deploy with auto-generated admin password
./deploy.sh

# Or deploy to a custom namespace
./deploy.sh my-odoo
```

The script will:
1. Create the namespace (if needed)
2. Apply all OpenShift manifests via Kustomize
3. Generate a random Odoo admin password
4. Trigger the enterprise image build from git
5. Wait for PostgreSQL and Odoo to be ready
6. Print the URL and login credentials

### Manual Deployment

```bash
# Apply manifests (deploys to "odoo" namespace by default)
oc apply -k openshift/

# Override the placeholder password
oc create secret generic odoo \
  --from-literal=odoo-password='your-password' \
  --namespace=odoo \
  --dry-run=client -o yaml | oc apply -f -

# Trigger build
oc start-build odoo-enterprise -n odoo --follow

# Get the route URL
oc get route odoo -n odoo -o jsonpath='https://{.spec.host}{"\n"}'
```

## What Gets Deployed

| Resource | Name | Description |
|----------|------|-------------|
| **ImageStream** | `odoo-enterprise` | Tracks the built enterprise image |
| **BuildConfig** | `odoo-enterprise` | Docker build from git (this repo, `main` branch) |
| **CNPG Cluster** | `postgres` | Single-instance PostgreSQL 16 with 10Gi storage |
| **ServiceAccount** | `odoo` | Dedicated SA for the Odoo deployment |
| **RoleBinding** | `odoo-privileged` | Grants privileged SCC (init container needs root) |
| **Secret** | `odoo` | Odoo admin password (Kustomize secretGenerator) |
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
3. Extracts the enterprise tarball (`odoo_19.0+e.20260224.tar.gz`, stored via Git LFS)
4. Installs `web_enterprise` module on first startup via Bitnami init.d hook

The BuildConfig pulls source from `https://github.com/hoolia/odoo-enterprise.git` (`main` branch)
and builds the Docker image automatically.
## Customization

### Target Namespace

Edit `openshift/kustomization.yaml`:

```yaml
namespace: my-namespace
```

Or pass the namespace to the deploy script: `./deploy.sh my-namespace`

### Custom Domain

Edit `openshift/route.yaml` and set `spec.host`:

```yaml
spec:
  host: odoo.yourdomain.com
```

### Storage Size

Edit `openshift/pvc.yaml` (Odoo data) and `openshift/cnpg-cluster.yaml` (database) to adjust storage.

### Resource Limits

Edit `openshift/deployment.yaml` to adjust CPU/memory for the Odoo container.

## Troubleshooting

```bash
# Check Odoo logs
oc logs deployment/odoo -n odoo -f

# Check postgres status
oc get cluster postgres -n odoo

# Verify enterprise edition
oc exec deployment/odoo -n odoo -- curl -s localhost:8069/web/health

# Re-trigger build
oc start-build odoo-enterprise -n odoo --follow
oc rollout restart deployment/odoo -n odoo
```
