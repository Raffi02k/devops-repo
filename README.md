# DevOps Kursrepo – YH Utbildning

Detta repository används under min yrkeshögskoleutbildning (YH) i kursen **DevOps utveckling**.

Projektet byggs upp steg för steg vecka för vecka genom praktiska moduler – från grundläggande arbetssätt, versionshantering och CI/CD-pipelines till molndriftsättning i Azure, infrastruktur som kod (IaC), containrar och observerbarhet.

---

## 📚 Kursmoduler & Progress

| Modul | Område | Status / Innehåll |
|:---:|---|---|
| **01** | **DevOps som arbetssätt** | Klar – Värdeflödeskarta (VSM), flaskhalsanalys och DORA-mått ([docs/01-delivery-analysis.md](file:///Users/raffimedz/Desktop/devops/devops-repo/docs/01-delivery-analysis.md)) |
| **02** | **Versionshantering** | Klar – Trunk-based development, PR-mall, CODEOWNERS, SemVer och releasetagg `v0.1.0` ([docs/02-branching-strategy.md](file:///Users/raffimedz/Desktop/devops/devops-repo/docs/02-branching-strategy.md)) |
| **03** | **Kontinuerlig integration (CI)** | Klar – GitHub Actions pipeline, lokala bygg-/testskript, commit-validering och kvalitetsgrindar ([docs/03-ci-pipeline.md](file:///Users/raffimedz/Desktop/devops/devops-repo/docs/03-ci-pipeline.md)) |
| **04** | **Azure App Service** | Klar – Driftsättning via Azure CLI, resursgrupper, App Service Plan, hälskontroll och kostnadskontroll ([docs/04-Azure.md](file:///Users/raffimedz/Desktop/devops/devops-repo/docs/04-Azure.md)) |
| **05** | **CI/CD till Azure** | Klar – Automatiserad CD-pipeline med GitHub Actions, OIDC-autentisering, zip-deploy och smoke test ([docs/05-cicd-azure.md](docs/05-cicd-azure.md)) |
| **06** | **Bicep (IaC)** | Klar – Deklarativ infrastruktur med Bicep-moduler, Azure SQL Database, parameterfiler (.bicepparam) samt automatiserad pipeline med What-If och OIDC ([docs/06-bicep-iac.md](docs/06-bicep-iac.md)) |
| **07** | **Containrar** | Klar – Dockerfile, multi-arch byggen (`linux/amd64`), Azure Container Registry (ACR), RBAC (`AcrPush`) och Azure Budgets ([docs/07-containrar.md](docs/07-containrar.md)) |
| **08** | **Observerbarhet** | Klar – Log Analytics Workspace, KQL-frågor, diagnostikinställningar, Action Groups och automatiserade larm (`alerts.bicep`) ([docs/08-observerbarhet.md](docs/08-observerbarhet.md)) |
| **09** | **Container Apps** | Kommande |
| **10** | **Säkerhet** | Kommande |
| **11** | **Incidenthantering** | Kommande |
| **12** | **Förbättring och redovisning** | Kommande |

---

## 🛠 Repots struktur & verktyg

```text
devops-repo/
├── .dockerignore                           # Exkluderar filer och kataloger från Docker-byggkontext
├── .github/
│   ├── workflows/
│   │   ├── build-test-pipeline.yml         # CI-pipeline som körs vid push/PR mot main
│   │   ├── deploy-app-service-pipeline.yml # CD-pipeline med OIDC-driftsättning till Azure
│   │   └── infra-deploy-pipeline.yml       # IaC-pipeline med Bicep, What-If och app-deploy
│   ├── CODEOWNERS                          # Automatisk tilldelning av granskare
│   └── pull_request_template.md            # Mall för Pull Requests med kvalitetsfrågor
├── Dockerfile                              # Optimerad containerdefinition (Node.js 24-slim, icke-root)
├── docs/                                   # Kursdokumentation och modulrapporter
├── infra/                                  # Infrastruktur som kod (IaC) i Bicep
│   ├── budget.bicep                        # Azure Budgets kostnadsbevakning och tidiga larm
│   ├── dev.bicepparam                      # Parameterfil för utvecklingsmiljön
│   ├── identity.bicep                      # Hanterad identitet och OIDC-federering
│   ├── main.bicep                          # Huvudmall som orkestrerar modulerna
│   └── modules/
│       ├── alerts.bicep                    # Larmregel (high-error-rate) och Action Group (e-post)
│       ├── app-service.bicep               # App Service (Linux, Node.js 24) & diagnostikinställning
│       ├── app-service-plan.bicep          # App Service Plan (Linux B1)
│       ├── container-registry.bicep        # Azure Container Registry (ACR Basic)
│       ├── contributor-role.bicep          # Modulär RBAC-rolltilldelning för Contributor
│       ├── log-analytics.bicep             # Log Analytics Workspace för central logglagring
│       └── sql-database.bicep              # Azure SQL Server, databas och brandvägg
├── scripts/
│   ├── build.sh                            # Bygg- och strukturkontroll (körs lokalt & i CI)
│   ├── check-commit-messages.sh            # Validerar Conventional Commits
│   ├── deploy-app-service.sh               # Paketerar och driftsätter via Azure CLI
│   ├── health-check.sh                     # Hälskontroll av rullad applikation (pollning)
│   ├── provision-app-service.sh            # Etablerar plan, webbapp och identitet i Azure
│   ├── teardown-app-service.sh             # Raderar webbapp och plan i Azure samt listar kvarvarande resurser
│   └── test.sh                             # Funktionella och strukturella tester
├── src/                                    # Waypoint webbapplikation (Node.js 24)
└── README.md
```

---

## 🚀 Köra skripten lokalt & CI-tester

Innan du pushar eller öppnar en Pull Request kan du köra testerna lokalt i terminalen:

```bash
# Kör byggkontrollen
./scripts/build.sh

# Kör testsviten (enhetstester)
./scripts/test.sh

# Validera dina senaste commit-meddelanden (Conventional Commits)
./scripts/check-commit-messages.sh
```

---

## 🔍 Kontrollera status och drifthälsa ("Kika")

Använd dessa skript och kommandon för att kontrollera att dina servrar, containrar och Azure-resurser mår bra:

### 1. Testa drifthälsa (Smoke Test)
```bash
# Testa lokal Node.js-app (port 3000)
./scripts/health-check.sh "http://localhost:3000/health"

# Testa lokal Docker-container (port 8080) och verifiera commit-ID
./scripts/health-check.sh "http://localhost:8080/health" "$(git rev-parse HEAD)"

# Testa skarp applikation i Azure
./scripts/health-check.sh "https://app-waypoint-raffi.azurewebsites.net/health"
```

### 2. Kika på status för dina appar i Azure
```bash
# Lista webbappar och se om de är "Running" eller "Stopped"
az webapp list \
  --resource-group RaffiMedzadaghlian \
  --query "[].{Namn:name, Status:state, URL:defaultHostName}" \
  --output table

# Se alla aktiva resurser i resursgruppen (planer, databaser, identiteter)
az resource list \
  --resource-group RaffiMedzadaghlian \
  --query "[].{Namn:name, Typ:type}" \
  --output table

# Se vilka Docker-taggar som finns uppladdade i Azure Container Registry (ACR)
az acr repository show-tags \
  --name crwaypointraffi \
  --repository waypoint \
  --output table
```

---

## 🛑 Kostnadskontroll & Stänga ner (Teardown)

En viktig princip inom DevOps och molndrift är att **inte låta resurser stå och ticka pengar** när de inte används (särskilt App Service Plan på B1-nivå och Container Registry).

### Snabb nedstängning med skriptet:
```bash
# 1. Standard (Snabb): Raderar App Service och App Service Plan – stoppar timdebiteringen direkt!
./scripts/teardown-app-service.sh

# 2. Full städning: Raderar även larmregel, Action Group, Log Analytics Workspace, ACR och SQL-server:
./scripts/teardown-app-service.sh --all
```

*(Identiteten `id-waypoint-pipeline-raffi` och din budgetbevakning lämnas alltid kvar med 0 kr i kostnad så att GitHub Actions kan bygga upp miljön igen automatiskt nästa gång du pushar).*

---

## 🐳 Docker: Bygga & köra containern lokalt

Snabbreferens för att testa containerbygget lokalt:

```bash
# 1. Bygg imagen och baka in commit-ID
TAG=$(git rev-parse --short HEAD)
docker build \
  --build-arg COMMIT=$(git rev-parse HEAD) \
  -t waypoint:$TAG \
  .

# 2. Starta containern isolerat i bakgrunden på port 8080
docker run -d --rm --name waypoint -p 8080:8080 waypoint:$TAG

# 3. Kolla realtidsloggar från appen
docker logs waypoint

# 4. Stoppa containern
docker stop waypoint
```

