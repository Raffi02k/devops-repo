# Modul 04: Driftsättning till Azure App Service & Azure CLI

Denna dokumentation beskriver hur infrastruktur och resurser sätts upp i Microsoft Azure för att köra Waypoint-applikationen (Node.js 24), hur Azure CLI används för att automatisera driftsättningen, samt hur appens drifthälsa verifieras och städas upp.

---

## 💡 Varför Azure CLI istället för Azure Portal?

Allt som går att klicka fram i webbläsaren på [portal.azure.com](https://portal.azure.com) kan också utföras med **Azure CLI** (Command Line Interface, där alla kommandon inleds med `az`). 

Inom DevOps föredrar vi alltid terminalen och skript framför att klicka manuellt:
* **Snabbhet:** En hel infrastruktur kan rullas ut på sekunder istället för flera minuter av manuella klick i menyer.
* **Repeterbarhet:** Samma kommando skapar exakt samma miljö varje gång – inga missade inställningar eller mänskliga misstag.
* **Grund för automation (CI/CD):** En pipeline (t.ex. GitHub Actions i Modul 05) kan inte sitta och klicka med en mus, utan exekverar just CLI-kommandon i bakgrunden.

---

## 🧱 De tre stegen i infrastrukturen

Att driftsätta en webbapp i Azure App Service kräver tre logiska byggstenar i en bestämd ordning:

```text
┌────────────────────────────────────────────────────────┐
│ 1. Resursgrupp (Resource Group) - "Mappen"            │
│    rg-waypoint-raffi                                   │
│                                                        │
│   ┌────────────────────────────────────────────────┐   │
│   │ 2. App Service Plan - "Servern / Datorn"       │   │
│   │    asp-waypoint-raffi (Linux, B1)              │   │
│   │                                                │   │
│   │   ┌────────────────────────────────────────┐   │   │
│   │   │ 3. Webbapp (App Service) - "Hemsidan"  │   │   │
│   │   │    app-waypoint-raffi (Node.js 24)     │   │   │
│   │   └────────────────────────────────────────┘   │   │
│   └────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

### 1. Resursgruppen (`rg-...`)
En logisk mapp i Azure där alla resurser för ett visst projekt samlas. 
* **`az group create`**: Ber Azure skapa en ny resursgrupp.
* **`--name rg-waypoint-raffi`**: Namnet på resursgruppen.
* **`--location swedencentral`** (eller `westeurope`): Anger vilket datacenter i världen resurserna ska ligga i.
> [!NOTE]
> Om skolan eller organisationen redan har skapat en resursgrupp åt dig kan du använda `az group list --output table` för att inspektera befintliga grupper istället för att skapa en ny.

### 2. Planen / Servern (`asp-...`)
Här hyr man själva beräkningskapaciteten (CPU, RAM och operativsystem) som webbappen ska köras på:
* **`az appservice plan create`**: Skapar en ny serverplan.
* **`--name asp-waypoint-raffi`**: Namnet på planen.
* **`--resource-group rg-waypoint-raffi`**: Placerar servern i mappen vi nyss skapade.
* **`--is-linux`**: Väljer Linux som operativsystem (ofta snabbare och mer kostnadseffektivt för Node.js).
* **`--sku B1`**: Väljer prisnivån **Basic B1** (lägsta nivån med dedikerad beräkningskraft, ca 20 öre/timme). *SKU* står för *Stock Keeping Unit* och betyder produktvariant/prisnivå.

### 3. Webbappen (`app-...`)
Själva webbplatsen som hostar applikationskoden och exponeras mot internet:
* **`az webapp create`**: Skapar själva webbapplikationen.
* **`--name app-waypoint-raffi`**: Appens globalt unika namn. Detta sätter också adressen: `https://app-waypoint-raffi.azurewebsites.net`.
* **`--resource-group rg-waypoint-raffi`**: Knyter appen till rätt resursgrupp.
* **`--plan asp-waypoint-raffi`**: Kopplar webbappen till den virtuella server vi skapade i steg 2.
* **`--runtime "NODE:24-lts"`**: Talar om för Azure vilken exekveringsmiljö som behövs (Node.js version 24 LTS).

---

## 🛠 Metod 1: Manuella CLI-kommandon (Utan variabler)

För att förstå kommandona i sin renaste form kan de köras rakt upp och ner:

```bash
# 1. Skapa resursgruppen
az group create \
  --name rg-waypoint-raffi \
  --location swedencentral

# 2. Skapa den virtuella servern (App Service Plan)
az appservice plan create \
  --name asp-waypoint-raffi \
  --resource-group rg-waypoint-raffi \
  --is-linux \
  --sku B1

# 3. Skapa själva webbplatsen
az webapp create \
  --name app-waypoint-raffi \
  --resource-group rg-waypoint-raffi \
  --plan asp-waypoint-raffi \
  --runtime "NODE:24-lts"
```

---

## 🚀 Metod 2: Optimerad driftsättning (Med variabler)

När man arbetar i verkliga projekt sätter man parametrarna i variabler i början av skriptet. Det minimerar risken för stavfel och gör det enkelt att byta namn eller region:

```bash
# 1. Definiera parametrarna en enda gång
RESOURCE_GROUP="rg-waypoint-raffi"
LOCATION="swedencentral"
PLAN_NAME="asp-waypoint-raffi"
PLAN_SKU="B1"
APP_NAME="app-waypoint-raffi"
RUNTIME="NODE:24-lts"

# 2. Skapa resursgruppen
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

# 3. Skapa serverplanen
az appservice plan create \
  --name "$PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --is-linux \
  --sku "$PLAN_SKU"

# 4. Skapa webbappen och returnera URL:en direkt
az webapp create \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --plan "$PLAN_NAME" \
  --runtime "$RUNTIME" \
  --query "defaultHostName" \
  --output tsv
```

---

## 🔍 Viktiga Azure CLI-flaggor att känna till

* **Bakåtsnedstreck (`\`)**: Betyder att kommandot fortsätter på nästa rad i terminalen. Det används för att göra koden lättläst istället för en 100 tecken lång rad.
* **`--query`**: Azure CLI returnerar vanligtvis massiva JSON-objekt. Med `--query` kan man plocka ut exakt det fält man bryr sig om (t.ex. `--query "defaultHostName"` eller `--query "properties.provisioningState"`).
* **`--output tsv` / `--output table`**: Formaterar utskriften:
  * `tsv` (Tab-Separated Values): Skriver bara ut det rena värdet utan citattecken – perfekt för skript.
  * `table`: Skriver ut svaret i en snygg och lättläst ASCII-tabell.

---

## 🟢 Verifiering av drifthälsa

När webbappen är skapad och koden rullats ut måste driften verifieras. I DevOps litar vi inte på förhoppningar – vi testar automatiskt.

Waypoint-applikationen exponerar en dedikerad hälso-endpoint (`/health`). Skriptet [scripts/health-check.sh](file:///Users/raffimedz/Desktop/devops/devops-repo/scripts/health-check.sh) pollar URL:en tills servern svarar med **HTTP 200 OK**:

```bash
# Testa den lokala appen
./scripts/health-check.sh "http://localhost:3000/health"

# Testa den skarpa Azure-appen
./scripts/health-check.sh "https://app-waypoint-raffi.azurewebsites.net/health"
```

Om Azure svarar med 200 OK inom angivet antal försök (standard: 10 försök med 3 sekunders mellanrum) anses driftsättningen lyckad.

---

## 🧹 Kostnadskontroll & Rensa resurser (Clean-up)

En grundbult inom molndrift är att **inte lämna resurser igång i onödan**, eftersom en aktiv App Service Plan debiteras per timme oavsett om appen tar emot trafik eller inte.

När lektionen eller laborationen är klar kan hela miljön raderas med ett enda kommando från terminalen:

```bash
az group delete --name rg-waypoint-raffi --yes --no-wait
```

### Vad flaggorna gör:
* **`az group delete`**: Raderar resursgruppen och **samtidigt alla resurser som ligger inuti den** (serverplan, webbapp, databaser etc.).
* **`--yes`**: Hoppar över bekräftelsefrågan (*"Are you sure you want to perform this action? (y/n)"*).
* **`--no-wait`**: Skickar raderingsordern till Azure och frigör terminalen omedelbart, istället för att blockera terminalen i flera minuter medan Azure städar bort diskarna i bakgrunden.
