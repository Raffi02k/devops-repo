#!/usr/bin/env bash
set -euo pipefail

# Kontrollera att miljövariabler skickats med, annars avbryt
RESOURCE_GROUP="${1:?Give resource group name}"
APP_NAME="${2:?Give Web App name}"

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