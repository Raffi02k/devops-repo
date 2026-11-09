#!/usr/bin/env bash
set -euo pipefail

# Git Bash on Windows rewrites /subscriptions/... into a Windows path, and Az
# This keeps the resource ids as they are. Elsewhere it does nothing.
export MSYS_NO_PATHCONV=1

# Standardvärden för Raffi så att skriptet kan köras direkt utan argument
DEFAULT_NAME="raffi"
DEFAULT_RG="RaffiMedzadaghlian"

NAME="$DEFAULT_NAME"
RESOURCE_GROUP="$DEFAULT_RG"
DELETE_ALL=false

# Flagghantering
for arg in "$@"; do
  if [[ "$arg" == "--all" || "$arg" == "--with-sql" || "$arg" == "--full" ]]; then
    DELETE_ALL=true
  fi
done

# Ta första argumentet som namn om det inte är en flagga
if [[ -n "${1:-}" && "${1:-}" != --* ]]; then
  NAME="$1"
fi

# Ta andra argumentet som resursgrupp om det inte är en flagga
if [[ -n "${2:-}" && "${2:-}" != --* ]]; then
  RESOURCE_GROUP="$2"
fi

# Rensa eventuella prefix om användaren skickar in fullt app-namn
if [[ "$NAME" == app-waypoint-* ]]; then
  NAME="${NAME#app-waypoint-}"
elif [[ "$NAME" == app-* ]]; then
  NAME="${NAME#app-}"
fi

APP_NAME="app-waypoint-$NAME"
PLAN_NAME="asp-waypoint-$NAME"
REGISTRY_NAME="crwaypoint$NAME"
WORKSPACE_NAME="log-waypoint-$NAME"
ACTION_GROUP_NAME="ag-waypoint-$NAME"
ALERT_NAME="high-error-rate"
SQL_SERVER="sql-waypoint-$NAME"

echo "=========================================================="
echo "🛑 Stänger ner resurser för: $NAME i $RESOURCE_GROUP"
echo "=========================================================="

echo "==> 1. Tar bort App Service ($APP_NAME)..."
az webapp delete \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" 2>/dev/null || echo "   ℹ️ Kunde inte ta bort $APP_NAME (kanske redan borttagen)."

echo "==> 2. Tar bort App Service Plan ($PLAN_NAME) [Stoppar debitering]..."
az appservice plan delete \
  --name "$PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --yes 2>/dev/null || echo "   ℹ️ Kunde inte ta bort $PLAN_NAME (kanske redan borttagen)."

if [ "$DELETE_ALL" = true ]; then
  echo "==> 3. Tar bort larmregel ($ALERT_NAME)..."
  az monitor scheduled-query delete \
    --name "$ALERT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --yes 2>/dev/null || echo "   ℹ️ Kunde inte ta bort $ALERT_NAME (kanske redan borttagen)."

  echo "==> 4. Tar bort action group ($ACTION_GROUP_NAME)..."
  az monitor action-group delete \
    --name "$ACTION_GROUP_NAME" \
    --resource-group "$RESOURCE_GROUP" 2>/dev/null || echo "   ℹ️ Kunde inte ta bort $ACTION_GROUP_NAME (kanske redan borttagen)."

  echo "==> 5. Tar bort Log Analytics workspace ($WORKSPACE_NAME)..."
  az monitor log-analytics workspace delete \
    --workspace-name "$WORKSPACE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --force \
    --yes 2>/dev/null || echo "   ℹ️ Kunde inte ta bort $WORKSPACE_NAME (kanske redan borttagen)."

  echo "==> 6. Tar bort Container Registry ($REGISTRY_NAME)..."
  az acr delete \
    --name "$REGISTRY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --yes 2>/dev/null || echo "   ℹ️ Kunde inte ta bort $REGISTRY_NAME (kanske redan borttagen)."

  echo "==> 7. Tar bort SQL Server ($SQL_SERVER)..."
  az sql server delete \
    --name "$SQL_SERVER" \
    --resource-group "$RESOURCE_GROUP" \
    --yes 2>/dev/null || echo "   ℹ️ Kunde inte ta bort $SQL_SERVER (kanske redan borttagen)."
fi

echo ""
echo "==> Kvarvarande resurser i $RESOURCE_GROUP:"
az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[].{Name:name, Type:type}" \
  --output table || true

echo ""
echo "✅ Klart! App Service Planen är borttagen och kostnaden är stoppad."
if [ "$DELETE_ALL" = false ]; then
  echo "💡 Tips: Log Analytics, larm, ACR och Managed Identity lämnades kvar för laboration."
  echo "   Om du vill städa bort ALLT (larm, workspace, ACR, SQL) kör du:"
  echo "   ./scripts/teardown-app-service.sh --all"
fi
