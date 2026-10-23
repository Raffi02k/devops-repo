#!/usr/bin/env bash
set -euo pipefail

# Git Bash on Windows rewrites /subscriptions/... into a Windows path, and Az
# This keeps the resource ids as they are. Elsewhere it does nothing.
export MSYS_NO_PATHCONV=1

NAME="${1:?Give your name as the first argument}"
RESOURCE_GROUP="${2:?Give your resource group as the second argument}"
APP_NAME="app-waypoint-$NAME"

# Om namnet redan är fullständigt (t.ex. app-waypoint-raffi)
if [[ "$NAME" == app-* ]]; then
  APP_NAME="$NAME"
fi

echo "==> Preparing build artifact (deployment.zip)"
mkdir -p artifacts

# Radera gammal zip om den finns
rm -f artifacts/deployment.zip

# Packa ihop applikationsfilerna (vi struntar i tester och lokala databaser)
zip -q -r artifacts/deployment.zip src package.json package-lock.json

echo "==> Deploying artifact to Azure App Service: $APP_NAME"
az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --src-path artifacts/deployment.zip \
  --type zip

echo "Deployment successful!"