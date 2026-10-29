#!/bin/bash
APP_NAME=$1
RESOURCE_GROUP=$2

echo "==> Preparing build artifact (deployment.zip)"
mkdir -p artifacts
rm -f artifacts/deployment.zip
cd src && zip -r ../artifacts/deployment.zip . && cd ..

echo "==> Deploying artifact to Azure App Service: $APP_NAME"
az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --src-path "artifacts/deployment.zip" \
  --type "zip"
