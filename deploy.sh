#!/bin/bash
# One-shot Odoo Enterprise deployment on OpenShift.
#
# Usage:
#   ./deploy.sh              # deploy to namespace "odoo" (from kustomization.yaml)
#   ./deploy.sh my-namespace # deploy to a custom namespace
#
# Prerequisites:
#   - oc CLI authenticated to an OpenShift 4.x cluster
#   - CloudNativePG (CNPG) operator installed on the cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUSTOMIZE_DIR="$SCRIPT_DIR/openshift"

# Determine target namespace
DEFAULT_NS=$(grep '^namespace:' "$KUSTOMIZE_DIR/kustomization.yaml" | awk '{print $2}')
NAMESPACE="${1:-$DEFAULT_NS}"
PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)

echo "=== Odoo Enterprise Deployment ==="
echo "Namespace: $NAMESPACE"
echo ""

# Create namespace if it doesn't exist
oc new-project "$NAMESPACE" 2>/dev/null || oc project "$NAMESPACE"

# Apply manifests — use a temp overlay if namespace differs from default
if [ "$NAMESPACE" != "$DEFAULT_NS" ]; then
  OVERLAY=$(mktemp -d)
  trap "rm -rf $OVERLAY" EXIT
  cat > "$OVERLAY/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $NAMESPACE
resources:
  - $KUSTOMIZE_DIR
EOF
  oc apply -k "$OVERLAY"
else
  oc apply -k "$KUSTOMIZE_DIR"
fi

# Override the placeholder secret with a random password
oc create secret generic odoo \
  --from-literal=odoo-password="$PASSWORD" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | oc apply -f -

# Trigger image build from git source
echo ""
echo "Starting image build..."
oc start-build odoo-enterprise --namespace="$NAMESPACE" --follow

# Wait for PostgreSQL
echo ""
echo "Waiting for PostgreSQL cluster..."
oc wait --for=condition=Ready cluster/postgres \
  --namespace="$NAMESPACE" --timeout=300s

# Wait for Odoo rollout
echo "Waiting for Odoo deployment..."
oc rollout status deployment/odoo \
  --namespace="$NAMESPACE" --timeout=600s

# Print access info
ROUTE=$(oc get route odoo -n "$NAMESPACE" -o jsonpath='{.spec.host}')
echo ""
echo "==============================="
echo " Odoo Enterprise is ready!"
echo "==============================="
echo " URL:      https://$ROUTE"
echo " Login:    admin"
echo " Password: $PASSWORD"
echo "==============================="
