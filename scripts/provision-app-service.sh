#!/usr/bin/env bash
set -euo pipefail

# Git Bash on Windows rewrites /subscriptions/... into a Windows path, and Az
# This keeps the resource ids as they are. Elsewhere it does nothing.
export MSYS_NO_PATHCONV=1

NAME="${1:?Give your name as the first argument}"
RESOURCE_GROUP="${2:?Give your resource group as the second argument}"
PLAN_NAME=asp-waypoint-$NAME
PLAN_SKU="${PLAN_SKU:-B1}"
RUNTIME="NODE:24-lts"
APP_NAME=app-waypoint-$NAME
IDENTITY_NAME=id-waypoint-pipeline-$NAME

echo "==> 1. The plan and the web app, in $RESOURCE_GROUP"
az appservice plan create \
  --name "$PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --is-linux \
  --sku "$PLAN_SKU" \
  --query provisioningState \
  --output tsv

az webapp create \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --plan "$PLAN_NAME" \
  --runtime "$RUNTIME" \
  --query defaultHostName \
  --output tsv

echo "==> 2. The user-assigned managed identity"
az identity create \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id \
  --output tsv
