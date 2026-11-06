# Modul 07: Containrar, Docker och Azure Container Registry (ACR)

Denna dokumentation sammanfattar genomförandet av **Modul 07** i kursen DevOps utveckling. Modulen behandlar containerisering av Waypoint-applikationen med Docker, lokala tester mot hälsoendpointen, deklarativ infrastruktur för Azure Container Registry (ACR) och rollbaserad åtkomstkontroll (Azure RBAC) med Bicep, multi-arch byggen för `linux/amd64` samt kostnadsbudgetering med Azure Budgets.

---

## 🎯 Varför containrar i DevOps?

Innan containrar var mjukvaruleveranser ofta behäftade med det klassiska *"men det fungerade på min maskin"*-problemet:
* **Miljöskillnader:** Utvecklarens Mac körde en version av Node.js/beroenden, CI-servern en annan och produktionsmiljön i molnet en tredje.
* **Immutability (Oföränderlighet):** Med containrar packas applikationskoden, körtiden (Node.js 24), systembibliotek och inställningar i en enda oföränderlig **image**. Exakt samma image som testas lokalt rullas ut i molnet.
* **Lättviktigt & Snabbstartat:** Till skillnad från virtuella maskiner (VMs) som kräver ett helt gästoperativsystem delar containrar värdsystemets kärna, vilket ger sekunder i uppstartstid och minimal resursåtgång.

---

## 🐳 Containerisering: `Dockerfile` och `.dockerignore`

För att paketera Waypoint skapades en optimerad och säker `Dockerfile` baserad på modern containerpraxis:

```dockerfile
FROM node:24-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY src/ src/
# The commit the image is built from, shown by /health. Passed in with --build-arg.
ARG COMMIT
RUN echo "$COMMIT" > src/commit.txt
ENV PORT=8080
EXPOSE 8080
RUN chown -R node:node /app
USER node
CMD ["npm", "start"]
```

### Viktiga tekniska designbeslut:
1. **Basimage (`node:24-slim`):**
   * Använder Debian-baserade `slim` för att hålla nere storleken och minska attackytan (inga onödiga systemverktyg).
2. **Optimerad lager-cache (Layer Caching):**
   * Genom att först kopiera `package.json` och köra `npm ci` utnyttjar Docker sin cache. Om koden i `src/` ändras men inte beroendena behöver `npm ci` inte köras om vid nästa bygge.
3. **Commit-spårbarhet via `ARG COMMIT`:**
   * Det exakta Git commit-ID som imagen byggs ifrån bakas in i `src/commit.txt` under byggskedet via `--build-arg COMMIT`. Detta exponeras sedan av appens hälsoendpoint (`/health`).
4. **Säkerhet (Icke-root användare):**
   * Containern körs som den fördefinierade användaren `USER node` istället för `root`. Om applikationen skulle komprometteras har angriparen inte administratörsbehörighet inuti containern.

### Effektiv byggkontext med `.dockerignore`
För att undvika att onödiga filer skickas till Docker daemon eller bakas in i imagen skapades [`.dockerignore`](file:///Users/raffimedz/Desktop/devops/devops-repo/.dockerignore):
```text
.git
.github
docs
infra
scripts
tests
node_modules
*.db
artifacts
```
Detta säkerställer att lokala utvecklingsfiler, tester, SQLite-filer och `node_modules` inte följer med in i byggmiljön.

---

## 🧪 Lokal verifiering och drifttest

Innan någon container skickas till molnet verifieras den lokalt på utvecklarmaskinen:

```bash
# 1. Hämta kort commit-ID och bygg containern
TAG=$(git rev-parse --short HEAD)
docker build \
  --build-arg COMMIT=$(git rev-parse HEAD) \
  -t waypoint:$TAG \
  .

# 2. Starta containern isolerat i bakgrunden på port 8080
docker run -d --rm --name waypoint -p 8080:8080 waypoint:$TAG

# 3. Verifiera drifthälsa och commit-ID med hälskontrollskriptet
./scripts/health-check.sh http://localhost:8080/health "$(git rev-parse HEAD)"

# 4. Granska driftloggarna och stäng sedan av containern
docker logs waypoint
docker stop waypoint
```

### Utfall av lokalt test:
* **Hälskontroll:** Svarade omedelbart med **HTTP 200 OK**.
* **JSON-respons från `/health`:**
  ```json
  {
    "status": "healthy",
    "version": "1.0.0",
    "commit": "e3f4c033d1d43a949d3ba52d9d9e5ccc6dd32521"
  }
  ```
* **Loggar:** Bekräftade att appen initierades korrekt med inbyggd SQLite (`Waypoint is using Sqlite (waypoint.db)`).

---

## 🏛 Infrastruktur som kod för Container Registry (ACR) & RBAC

För att kunna driftsätta containrar i Azure behövs ett privat register. Infrastrukturen utökades deklarativt med två nya Bicep-moduler i [`infra/modules/`](file:///Users/raffimedz/Desktop/devops/devops-repo/infra/modules):

### 1. `infra/modules/container-registry.bicep`
Skapar själva Azure Container Registry (ACR):
```bicep
param location string
param registryName string
param registrySku string = 'Basic'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  sku: {
    name: registrySku
  }
  properties: {
    adminUserEnabled: true
  }
}

output loginServer string = containerRegistry.properties.loginServer
output registryId string = containerRegistry.id
```
* **Namnkonvention:** Azures Container Registries accepterar endast alfanumeriska tecken (inga bindestreck), vilket parametreras till `crwaypointraffi`.
* **SKU:** `Basic` är den mest kostnadseffektiva nivån och perfekt för dev- och testmiljöer.

### 2. `infra/modules/contributor-role.bicep`
Bryter ut behörighetstilldelning (RBAC) till en modulär struktur:
```bicep
param principalId string

var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, contributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
```

### 3. Integration i `infra/main.bicep` och `infra/identity.bicep`
* `main.bicep` orkestrerar registret och exporterar `containerRegistryLoginServer`.
* `identity.bicep` refaktorerades för att konsumera den nya `contributor-role`-modulen för pipelinens Managed Identity.

---

## 🔐 Azure RBAC: Tilldela `AcrPush` (Least Privilege)

För att vår Managed Identity (`id-waypoint-pipeline-raffi`) ska ha behörighet att ladda upp images till registret måste den tilldelas den specifika rollen **`AcrPush`**:

```bash
# Hämta identitetens och registrets ID
PRINCIPAL_ID=$(az identity show --name id-waypoint-pipeline-raffi --resource-group RaffiMedzadaghlian --query principalId --output tsv)
REGISTRY_ID=$(az acr show --name crwaypointraffi --query id --output tsv)

# Skapa rolltilldelningen avgränsad till just vårt Container Registry
az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPush \
  --scope "$REGISTRY_ID" \
  --output none
```

Detta följer principen om **minsta behörighet** (*Principle of Least Privilege*) – identiteten får enbart pusha till just detta register, inte andra resurser i prenumerationen.

---

## 🚀 Multi-Architecture Bygge & Push till ACR

Ett centralt moment i modern containerdrift är arkitekturskillnader. Utveckling sker ofta på Apple Silicon (ARM64, t.ex. M1/M2/M3 Mac), medan molnnoder i Azure x86_64 (`linux/amd64`) standardmässigt körs.

### Bygga för molnet med `--platform linux/amd64`:
```bash
REGISTRY="crwaypointraffi.azurecr.io"
REGISTRY_NAME="crwaypointraffi"
TAG=$(git rev-parse --short HEAD)

# 1. Bygg containern med explicit målarkitektur
docker build \
  --platform linux/amd64 \
  --build-arg COMMIT=$(git rev-parse HEAD) \
  -t "$REGISTRY/waypoint:$TAG" \
  .

# 2. Autentisera Docker mot Azure Container Registry
az acr login --name "$REGISTRY_NAME"

# 3. Ladda upp (pusha) imagen till registret
docker push "$REGISTRY/waypoint:$TAG"

# 4. Verifiera att taggen finns i molnet
az acr repository show-tags \
  --name "$REGISTRY_NAME" \
  --repository waypoint \
  --output table
```

### Resultat i Azure Container Registry:
```text
Result
--------
48ef20c
```
Imagen taggad med commit-ID `48ef20c` distribuerades framgångsrikt till Azure och är nu redo att konsumeras av containerorkestrerare (Container Apps / App Service i kommande moduler).

---

## 💰 Kostnadskontroll & Azure Budgets (`budget.bicep`)

För att förhindra oväntade kostnader (särskilt viktigt under utbildning med studentkrediter) lades en dedikerad kostnadsbevakning till i [`infra/budget.bicep`](file:///Users/raffimedz/Desktop/devops/devops-repo/infra/budget.bicep) med `Microsoft.Consumption/budgets@2024-08-01`:

```bicep
param amount int
param contactEmail string

resource budget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: 'budget-early-warning'
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Annually'
    timePeriod: {
      startDate: '2026-10-01'
      endDate: '2026-12-31'
    }
    notifications: {
      halfUsed: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: [contactEmail]
      }
      onTrackToRunOut: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [contactEmail]
      }
    }
  }
}
```

### Varningsmekanismer:
* **`halfUsed` (50 % Faktisk kostnad):** Genererar en tidig varning när halva budgeten förbrukats.
* **`onTrackToRunOut` (100 % Prognostiserad kostnad):** Skickar larm direkt om Azure beräknar att den pågående driftstakten kommer att överskrida budgeten före periodens slut.

### Resursstädning (Teardown):
Efter avslutad övning städades beräknings- och registerresurser bort för att undvika timdebitering:
```bash
az webapp delete --name app-waypoint-raffi --resource-group RaffiMedzadaghlian
az appservice plan delete --name asp-waypoint-raffi --resource-group RaffiMedzadaghlian --yes
az acr delete --name crwaypointraffi --resource-group RaffiMedzadaghlian --yes
```
Kvar i resursgruppen lämnades enbart `id-waypoint-pipeline-raffi` och Azure SQL Database på Free-tier, vilket ger **0 kr i löpande kostnad**.

---

## 🎯 Sammanfattning av DevOps-lärdomar i Modul 07

1. **Deterministiska miljöer:** Docker säkerställer att applikationen körs identiskt oavsett underliggande hårdvara eller operativsystem.
2. **Arkitekturmedvetenhet i CI/CD:** `--platform linux/amd64` är avgörande vid utveckling på ARM-maskiner (t.ex. Apple Silicon M-serien) när målmiljön körs på x86-noder i molnet.
3. **Minsta behörighet (RBAC):** Med specifika roller som `AcrPush` ges pipelinen och tjänsterna exakt de behörigheter de behöver utan överdriven administratörsåtkomst.
4. **Proaktiv kostnadskontroll:** Automatiserade budgetlarm via Bicep minimerar risken för oväntade molnkostnader.
