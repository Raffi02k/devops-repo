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

az webapp config appsettings set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true \
  --query "[].name" \
  --output tsv

echo "==> 2. The first deploy, and is it up?"
./scripts/deploy-app-service.sh "$APP_NAME" "$RESOURCE_GROUP"

APP_URL="https://$(az webapp show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query defaultHostName \
  --output tsv)"

ATTEMPTS=30 ./scripts/health-check.sh "$APP_URL/health" "$(git rev-parse HEAD)"

echo "==> 3. The pipeline's identity: a managed identity in the same group"
az identity create \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query name \
  --output tsv

CLIENT_ID=$(az identity show \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query clientId \
  --output tsv)

PRINCIPAL_ID=$(az identity show \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId \
  --output tsv)

echo "==> 4. Trust GitHub: a run on main in this repo may log in as the identity"
SUBJECT_PREFIX=$(gh api "repos/{owner}/{repo}/actions/oidc/customization/sub" --jq .sub_claim_prefix)

az identity federated-credential create \
  --name github-main-branch \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --issuer https://token.actions.githubusercontent.com \
  --subject "${SUBJECT_PREFIX}:ref:refs/heads/main" \
  --audiences api://AzureADTokenExchange \
  --query subject \
  --output tsv
