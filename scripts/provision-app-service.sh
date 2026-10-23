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

echo "==> 5. Role assignment"
SCOPE=$(az group show \
  --name "$RESOURCE_GROUP" \
  --query id \
  --output tsv)

# Ask first: Azure refuses to make the same role assignment twice. Look for the role first.
# roles: a brand-new identity may not be found by name yet ("Cannot find user or service principal in...")
if [ -z "$(az role assignment list --scope "$SCOPE" --role Contributor --query "[?principalId=='$PRINCIPAL_ID'].id" --output tsv)" ]; then
  az role assignment create \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role Contributor \
    --scope "$SCOPE" \
    --output none
fi

echo "==> 6. What the pipeline needs to know, in the GitHub repo"
gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID"
gh secret set AZURE_TENANT_ID --body "$(az account show --query tenantId --output tsv)"
gh secret set AZURE_SUBSCRIPTION_ID --body "$(az account show --query id --output tsv)"

gh variable set AZURE_APP_NAME --body "$APP_NAME"
gh variable set AZURE_APP_URL --body "$APP_URL"
gh variable set AZURE_RESOURCE_GROUP --body "$RESOURCE_GROUP"

echo "Ready: $APP_URL"
echo "Wait a minute or two for the role, then push a change to main."

