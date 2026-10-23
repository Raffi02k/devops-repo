# Modul 05: CI/CD-pipeline till Azure med OIDC

Denna dokumentation beskriver hur repots Continuous Deployment (CD)-pipeline har automatiserats med GitHub Actions för att bygga, testa och driftsätta Waypoint-applikationen till Microsoft Azure App Service med hjälp av **OpenID Connect (OIDC)**.

---

## 🔑 Säker inloggning med OpenID Connect (OIDC)

Inom modern DevOps och molnsäkerhet vill vi eliminera **långlivade statiska hemligheter** (som Service Principal client secrets eller Azure Publish Profile XML-filer). Om sådana hemligheter läcker eller glöms bort i ett repository utgör de en allvarlig säkerhetsrisk.

Med **OIDC (OpenID Connect)** används istället en kortlivad, kryptografiskt signerad JSON Web Token (JWT) som GitHub Actions utfärdar vid varje pipeline-körning. Azure litar på GitHubs token-utfärdare (token issuer) och byter den mot ett tillfälligt access-token med exakt de rättigheter som definierats.

```text
┌─────────────────────────┐                 ┌───────────────────────────┐                 ┌─────────────────────────┐
│     GitHub Actions      │                 │  Microsoft Entra ID (OIDC)│                 │     Azure Resurser      │
│  (Runner / Workflow)    │                 │   (Federated Identity)    │                 │  (rg-waypoint-raffi)    │
└────────────┬────────────┘                 └─────────────┬─────────────┘                 └────────────┬────────────┘
             │                                            │                                            │
             │  1. Begär OIDC-token (JWT) för körningen   │                                            │
             │───────────────────────────────────────────>│                                            │
             │                                            │                                            │
             │  2. Verifierar repo, gren & miljö          │                                            │
             │     (repo:Raffi02k/devops-repo:...)        │                                            │
             │                                            │                                            │
             │  3. Returnerar kortlivad Azure-access token│                                            │
             │<───────────────────────────────────────────│                                            │
             │                                                                                         │
             │  4. Driftsätter kod med tillfällig behörighet (Contributor)                             │
             │────────────────────────────────────────────────────────────────────────────────────────>│
```

### Konfigurationssteg för OIDC:

1. **App-registrering i Microsoft Entra ID:**
   En dedikerad applikationsregistrering (Service Principal) skapades i Azure-katalogen.
2. **Rollbaserad behörighet (RBAC):**
   Rättigheter tilldelades enligt principen om minsta behörighet (Least Privilege) på resursgruppsnivå med rollen **`Contributor`**.
3. **Federerad autentisering (Federated Credential):**
   En federerad koppling konfigurerades med följande inställningar:
   - **Issuer:** `https://token.actions.githubusercontent.com`
   - **Entity type:** `Branch`
   - **GitHub repository:** `Raffi02k/devops-repo`
   - **Branch:** `main`
   - **Subject Identifier:** `repo:Raffi02k/devops-repo:ref:refs/heads/main`
4. **GitHub Actions Secrets:**
   Endast publika/icke-känsliga identifierare sparas som krypterade hemligheter i repot:
   - `AZURE_CLIENT_ID`: Applikationens unika Client ID från Entra ID.
   - `AZURE_TENANT_ID`: Azure Directory / Tenant ID.
   - `AZURE_SUBSCRIPTION_ID`: ID för aktuell Azure-prenumeration.

---

## 🛠 Driftsättningsskript (`scripts/deploy-app-service.sh`)

För att följa DevOps-principen att automatisering ska kunna testas både lokalt och i CI/CD skapades ett modulärt driftsättningsskript:

```bash
#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${1:?Give resource group name}"
APP_NAME="${2:?Give Web App name}"

echo "==> Preparing build artifact (deployment.zip)"
mkdir -p artifacts
rm -f artifacts/deployment.zip

# Packa ihop applikationsfilerna (exkluderar tester och databaser)
zip -q -r artifacts/deployment.zip src package.json package-lock.json

echo "==> Deploying artifact to Azure App Service: $APP_NAME"
az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --src-path artifacts/deployment.zip \
  --type zip

echo "Deployment successful!"
```

### Vad skriptet gör:
1. **Artefakt-paketering:** Samlar ihop endast produktionens källkod (`src`), samt `package.json` och `package-lock.json` i `artifacts/deployment.zip`. Lokala utvecklingsfiler, databasfiler och tester lämnas utanför för att hålla artefakten lätt och säker.
2. **Zip Deploy via Azure CLI:** Använder kommandot `az webapp deploy` med `--type zip` för atomisk och ren utrullning till Azure App Service.

---

## 🚀 Pipeline-arkitektur (`.github/workflows/deploy-app-service-pipeline.yml`)

Pipelinen triggas automatiskt vid push mot `main` eller manuellt via `workflow_dispatch`:

```yaml
name: Build, Deploy and Health Check

on:
  push:
    branches: [ "main", "master" ]
  workflow_dispatch:

permissions:
  id-token: write   # Krävs för att GitHub ska få utfärda OIDC-token
  contents: read

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies and build
        run: |
          npm ci
          npm run build --if-present

      - name: Log in to Azure using OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy to Azure App Service
        uses: azure/webapps-deploy@v3
        with:
          app-name: 'app-waypoint-raffi'
          package: '.'

      - name: Run Health Check (Smoke Test)
        run: ./scripts/health-check.sh "https://app-waypoint-raffi.azurewebsites.net/health"
```

### Stegens funktion och ansvar:
1. **Behörighet (`permissions: id-token: write`):** Ger GitHub Actions rättighet att generera OIDC-tokens mot Microsoft Entra ID.
2. **Källkod & Miljö:** Checkar ut repot och sätter upp rätt Node.js-version (med automatisk npm-cache).
3. **Bygg & Beroenden:** Kör `npm ci` för en determistisk installation baserad på `package-lock.json`.
4. **OIDC-autentisering:** Använder officiella `azure/login` för lösenordsfri inloggning via de konfigurerade hemligheterna.
5. **Driftsättning:** Rullar ut koden till App Service `app-waypoint-raffi`.
6. **Kvalitetsgrind (Smoke Test):** Exekverar [scripts/health-check.sh](file:///Users/raffimedz/Desktop/devops/devops-repo/scripts/health-check.sh) mot den skarpa URL:en och inväntar HTTP 200 OK innan pipelinen godkänns.

---

## 🟢 Verifiering och kvalitetsgrind (Smoke Testing)

En driftsättning är inte slutförd bara för att filerna har laddats upp till molnet. Webbservern måste också starta och fungera i praktiken.

Genom att avsluta pipelinen med [scripts/health-check.sh](file:///Users/raffimedz/Desktop/devops/devops-repo/scripts/health-check.sh) pollas applikationens hälsoendpoint:
```bash
./scripts/health-check.sh "https://app-waypoint-raffi.azurewebsites.net/health"
```

* **Framgång (HTTP 200 OK):** Pipelinen blir grön och bekräftar att applikationen är frisk och servar trafik.
* **Misslyckande (Timeout / HTTP 5xx / 4xx):** Om appen kraschar vid uppstart eller inte svarar inom angiven tid fallerar steget och pipelinen blir röd, vilket varnar teamet omedelbart.

---

## 🎯 Sammanfattning av DevOps-vinster

- **Zero Secret Sprawl:** Inga hemliga nycklar behöver roteras eller riskerar att exponeras i loggar eller repot.
- **Full Traceability:** Azure loggar exakt vilket GitHub-repo och vilken commit som utförde driftsättningen.
- **Automatisk verifiering:** Smoke testet garanterar att trasiga releaser fångas omedelbart utan manuellt klickande.
