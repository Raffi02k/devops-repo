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
DELETE_SQL=false

# Flagghantering
for arg in "$@"; do
  if [[ "$arg" == "--all" || "$arg" == "--with-sql" ]]; then
    DELETE_SQL=true
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

if [ "$DELETE_SQL" = true ]; then
  echo "==> 3. Tar bort SQL Server ($SQL_SERVER)..."
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
if [ "$DELETE_SQL" = false ]; then
  echo "💡 Tips: Din SQL-databas och Managed Identity lämnades kvar (de kostar 0 kr)."
  echo "   Om du även vill ta bort SQL-servern kan du köra: ./scripts/teardown-app-service.sh --all"
fi
