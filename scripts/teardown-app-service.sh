#!/usr/bin/env bash
set -euo pipefail

# Git Bash on Windows rewrites /subscriptions/... into a Windows path, and Az
# This keeps the resource ids as they are. Elsewhere it does nothing.
export MSYS_NO_PATHCONV=1

NAME="${1:?Give your name as the first argument}"
RESOURCE_GROUP="${2:?Give your resource group as the second argument}"
APP_NAME=app-waypoint-$NAME

# Om användaren skickar in fullt app-namn direkt
if [[ "$NAME" == app-* ]]; then
  APP_NAME="$NAME"
fi

echo "==> Deleting $APP_NAME, and its plan with it"
az webapp delete \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP"

echo "==> What is left in $RESOURCE_GROUP"
az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[].{Name:name, Type:type}" \
  --output table
