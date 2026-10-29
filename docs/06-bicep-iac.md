# Modul 06: Infrastruktur som kod (IaC) med Azure Bicep & CI/CD

Denna dokumentation sammanfattar hur infrastrukturen för Waypoint-applikationen har lyfts från manuella Azure CLI-skript (Modul 04/05) till deklarativ **Infrastruktur som kod (IaC)** med hjälp av **Azure Bicep**, Azure SQL Database och en helautomatiserad GitHub Actions-pipeline med What-If analys.

---

## 🎯 Varför Bicep och Infrastruktur som kod (IaC)?

Tidigare moduler använde imperativa bash-skript (`az appservice plan create`, `az webapp create`). Det fungerar utmärkt för enstaka resurser, men medför utmaningar när infrastrukturen växer:
* **Imperativt vs Deklarativt:** 
  - *Imperativt (CLI-skript):* Beskriver *hur* stegen ska utföras sekventiellt ("Gör A, sen B, sen C"). Kräver egen felhantering om en resurs redan existerar.
  - *Deklarativt (Bicep):* Beskriver *önskat sluttillstånd* ("Jag vill ha en Linux App Service Plan på B1-nivå och en Azure SQL-databas"). Azure räknar själv ut beroenden och exekveringsordning.
* **Idempotens:** Att köra Bicep-mallen en gång eller tio gånger ger exakt samma slutresultat utan bieffekter.
* **What-If analys:** Möjlighet att förhandsgranska förändringar (vilka resurser skapas, ändras eller raderas) innan ändringen faktiskt rullas ut.
* **Versionshantering:** Hela molninfrastrukturen versionshanteras i Git tillsammans med applikationskoden.

---

## 🧱 Arkitektur och Bicep-moduler

Infrastrukturen är uppdelad i en orkestrerande rotmall (`main.bicep`) och tre återanvändbara moduler i `infra/modules/`:

```text
                               ┌─────────────────────────────────┐
                               │        infra/main.bicep         │
                               │   (Orkestrering & Parametrar)   │
                               └───────────────┬─────────────────┘
                                               │
             ┌─────────────────────────────────┼─────────────────────────────────┐
             │                                 │                                 │
             ▼                                 ▼                                 ▼
┌─────────────────────────┐       ┌─────────────────────────┐       ┌─────────────────────────┐
│ app-service-plan.bicep  │       │   sql-database.bicep    │       │   app-service.bicep     │
│  - Linux Serverfarm     │       │  - Azure SQL Server     │       │  - Linux Web App        │
│  - SKU: B1              │       │  - Free-tier Database   │       │  - Node.js 24 LTS       │
│                         │       │  - AllowAzureServices   │       │  - SQL Connection String│
│                         │       │    (Brandväggsregel)    │       │    från sql-modulen     │
└────────────┬────────────┘       └────────────┬────────────┘       └────────────┬────────────┘
             │                                 │                                 │
             │ outputs.appServicePlanId        │ outputs.sqlServer...            │ outputs.appServiceUrl
             └─────────────────────────────────┴─────────────────────────────────┘
```

### 1. `infra/modules/app-service-plan.bicep`
Skapar själva beräkningsresursen (Linux Serverfarm) med SKU `B1`:
* Exporterar `appServicePlanId` via `output appServicePlanId string = appServicePlan.id` så att webbappen kan bindas till planen.

### 2. `infra/modules/sql-database.bicep`
Etablerar den relationella databasen för Waypoint:
* **Azure SQL Server:** Konfigurerar administratörsinloggning och lösenord.
* **Azure SQL Database:** Resurs på `Free`-tier.
* **Brandväggsregel (`AllowAzureServices`):** Sätter start- och slut-IP till `0.0.0.0`, vilket ger Azure-interna tjänster (såsom App Service) rättighet att ansluta mot databasservern.
* Exporterar `sqlServerFullyQualifiedDomainName` så att `main.bicep` kan bygga ihop databasens anslutningssträng.

### 3. `infra/modules/app-service.bicep`
Skapar webbapplikationen (`Microsoft.Web/sites`):
* Körs på Linux med `NODE|24-lts`.
* Sätter `appCommandLine: 'npm start'`.
* **Koppling till databasen:** Injicerar anslutningssträngen via app-inställningen `SQL_CONNECTION_STRING`. När Waypoint startar och detekterar denna inställning skiftar den automatiskt från lokal SQLite till Azure SQL Database!
* Exporterar appens publika URL via `output appServiceUrl string = 'https://${appService.properties.defaultHostName}'`.

### 4. `infra/main.bicep` & `infra/dev.bicepparam`
* `dev.bicepparam` definierar miljöspecifika parametrar för utvecklingsmiljön (`using 'main.bicep'`).
* `main.bicep` knyter ihop alla delar och genererar dynamiskt ett säkert administratörslösenord med `uniqueString(resourceGroup().id)`.

---

## 🚀 CI/CD Pipeline (`infra-deploy-pipeline.yml`)

Infrastrukturpipelinen automatiserar hela livscykeln vid push mot `main`:

```yaml
name: Infrastructure and App Deployment

on:
  push:
    branches:
      - main

permissions:
  id-token: write
  contents: read

jobs:
  deploy-infra:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Azure CLI What-If
        run: |
          az deployment group what-if \
            --resource-group "${{ vars.AZURE_RESOURCE_GROUP }}" \
            --template-file infra/main.bicep \
            --parameters infra/dev.bicepparam

      - name: Deploy Bicep Infrastructure
        run: |
          az deployment group create \
            --resource-group "${{ vars.AZURE_RESOURCE_GROUP }}" \
            --template-file infra/main.bicep \
            --parameters infra/dev.bicepparam

      - name: Deploy Web App Source Code
        uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ vars.AZURE_APP_NAME }}
          package: '.'
```

### Pipelines arbetsflöde:
1. **OIDC Azure Login:** Autentiserar säkert utan statiska lösenord via GitHubs OpenID Connect.
2. **What-If:** Kör en torrsimulering av infrastrukturen och loggar exakt vad som kommer skapas, förändras eller behållas.
3. **Deployment Group Create:** Etablerar infrastrukturen deklarativt i Azure.
4. **Deploy Web App:** Driftsätter Node.js-källkoden direkt till den nyskapade App Servicen.

---

## 💡 Felsökning & Lärdomar under modulresan

Under utvecklingen av Bicep-mallarna och CI/CD-pipelinen stötte vi på två intressanta Bicep-fel som gav djupare förståelse för verktyget:

### 1. BCP053: Moduler vs Resurser vid output-referenser
* **Felmeddelande:**
  ```text
  /infra/main.bicep(45,53) : Error BCP053: The type "module" does not contain property "properties".
  Available properties include "identity", "name", "outputs".
  ```
* **Rotorsak:**
  I `main.bicep` försökte vi läsa `appService.properties.defaultHostName`. Men `appService` är deklarerad som en *modul* (`module appService 'modules/app-service.bicep'`), inte en Azure-resurs direkt i filen. Moduler i Bicep har inga `.properties` – de kapslar in sina resurser och exponerar endast sina värden genom `outputs`.
* **Åtgärd:**
  I `infra/modules/app-service.bicep` definierades redan:
  ```bicep
  output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
  ```
  I `main.bicep` ändrades referensen till att läsa från modulens outputs:
  ```bicep
  // Före:
  output appServiceUrl string = 'https://${appService.properties.defaultHostName}'

  // Efter:
  output appServiceUrl string = appService.outputs.appServiceUrl
  ```

---

### 2. BCP062 / Validering i `.bicepparam` (Dynamiska uttryck)
* **Felmeddelande:**
  Parameterfiler godkände inte dynamiska ARM-funktioner som `uniqueString(resourceGroup().id)`.
* **Rotorsak:**
  En `.bicepparam`-fil exekveras under en separat valideringsfas före distribution och tillåter endast deterministiska eller statiska värden, inte funktioner som beror på Azure runtime context (såsom `resourceGroup().id`).
* **Åtgärd:**
  Flyttade lösenordsgenereringen från `.bicepparam` till `main.bicep` som en intern variabel (`var sqlAdminPassword = 'P@ssword${uniqueString(resourceGroup().id)}!'`), vilket säkerställer deterministiska parametrar utifrån och säker dynamisk generering inuti mallen.

