#!/usr/bin/env bash
set -euo pipefail

# Förhindrar att Git Bash på Windows förstör sökvägar till Azure-resurser
export MSYS_NO_PATHCONV=1

# Kontrollerar att användaren skickade med de argument som krävs
NAME="${1:?Ange ditt namn som första argument (t.ex. raffi)}"
RESOURCE_GROUP="${2:?Ange din resursgrupp som andra argument}"

APP_NAME="app-waypoint-$NAME"
PLAN_NAME="asp-waypoint-$NAME"
SQL_SERVER_NAME="sql-waypoint-$NAME"

# Om användaren råkade skicka in hela app-namnet direkt i terminalen
if [[ "$NAME" == app-* ]]; then
  APP_NAME="$NAME"
fi

echo "==> Tar bort webbappen: $APP_NAME"
az webapp delete \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP"

echo "==> Tar bort App Service-planen (maskinen): $PLAN_NAME"
az appservice plan delete \
  --name "$PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --yes

echo "==> Tar bort SQL-servern och databasen: $SQL_SERVER_NAME"
az sql server delete \
  --name "$SQL_SERVER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --yes

echo "==> Kontrollerar vad som finns kvar i $RESOURCE_GROUP (identiteten ska vara kvar):"
az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[].{Name:name, Type:type}" \
  --output table
