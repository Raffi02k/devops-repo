#!/usr/bin/env bash
set -euo pipefail

# Git Bash on Windows rewrites /subscriptions/... into a Windows path
export MSYS_NO_PATHCONV=1

DEFAULT_NAME="raffi"
DEFAULT_RG="RaffiMedzadaghlian"

NAME="${1:-$DEFAULT_NAME}"
RESOURCE_GROUP="${2:-$DEFAULT_RG}"
export ALERT_EMAIL="${ALERT_EMAIL:-raffi.medzadaghlian@gmail.com}"

echo "=========================================================="
echo "🚀 Startar igång alla Azure-resurser för: $NAME i $RESOURCE_GROUP"
echo "=========================================================="

echo "==> 1. Etablerar fullständig infrastruktur via Bicep (Plan, ACR, Log Analytics, SQL, Larm)..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters infra/dev.bicepparam

echo "==> 2. Kör provision-app-service.sh för webbapp, kundleverans och GitHub OIDC-integrering..."
./scripts/provision-app-service.sh "$NAME" "$RESOURCE_GROUP"

echo ""
echo "✅ Allt är startat, konfigurerat och verifierat!"
