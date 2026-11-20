# Modul 09: Azure Container Apps, Flera Revisioner & Blixtsnabb Rollback

Denna dokumentation sammanfattar genomförandet av **Modul 09** i kursen DevOps utveckling. Målet med modulen är att driftsätta Waypoint-applikationen som en container i **Azure Container Apps (ACA)**, använda separata hanterade identiteter enligt *Least Privilege*, automatisera driftsättningen via en ny GitHub Actions-pipeline, samt kunna dela trafik mellan revisioner och göra rollback på sekunder.

---

## 🎯 Varför Azure Container Apps?

I Modul 07 paketerade vi appen som en container och i Modul 08 övervakade vi App Service. Container Apps är en serverlös (*serverless*) plattform byggd på Kubernetes (K8s/KEDA), men utan komplexiteten i att förvalta ett eget kluster.

| Egenskap | Azure App Service (B1) | Azure Container Apps |
|---|---|---|
| **Underliggande modell** | Dedikerad virtuell maskin som alltid kostar pengar | Serverlös containermiljö |
| **Skala till 0** | ❌ Nej (kostar dygnet runt) | ✅ Ja (`minReplicas: 0` – 0 kr vid inaktivitet) |
| **Revisionshantering** | Deployment slots (kräver Standard/Premium SKU) | Inbyggt i alla prisklasser med `Multiple` mode |
| **Trafikdelning & Rollback** | Kräver slot swap | Flexibel trafikdelning i procent & rollback på sekunder |
| **Port & Nätverk** | Automatisk portmappning | Ingress med explicit `targetPort: 8080` |

---

## 🔐 Identiteter och Minsta Behörighet (Least Privilege)

För att upprätthålla hög säkerhet delas ansvaret upp på två separata hanterade identiteter:

```text
┌────────────────────────────────┐                 ┌───────────────────────────────┐
│     GitHub Actions (CI/CD)     │                 │   Azure Container App (ACA)   │
│   (id-waypoint-pipeline-raffi) │                 │     (id-waypoint-raffi)       │
└───────────────┬────────────────┘                 └───────────────┬───────────────┘
                │ Roll: AcrPush & Contributor                      │ Roll: AcrPull
                ▼                                                  ▼
      ┌──────────────────────────────────────────────────────────────────┐
      │               Azure Container Registry (crwaypointraffi)          │
      └──────────────────────────────────────────────────────────────────┘
```

1. **Pipeline-identitet (`id-waypoint-pipeline-raffi`)**:
   * Används av GitHub Actions via OIDC.
   * Roller: `Contributor` på resursgruppen (för att köra Bicep) och `AcrPush` på ACR (för att bygga och ladda upp nya Docker-images).
2. **Appens identitet (`id-waypoint-raffi`)**:
   * Tilldelas själva Container Appen.
   * Roll: Endast `AcrPull` på registret. Appen har inte rätt att pusha bilder eller ändra infrastruktur.

---

## 🧱 Skapade Bicep-mallar

För att inte påverka App Service-koden från tidigare moduler skapades separata Bicep-filer för Container Apps:

### 1. `infra/modules/pull-identity.bicep`
Skapar den användartilldelade identiteten:
```bicep
param pullIdentityName string
param location string = resourceGroup().location

resource pullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: pullIdentityName
  location: location
}

output pullIdentityId string = pullIdentity.id
output pullIdentityPrincipalId string = pullIdentity.properties.principalId
```

### 2. `infra/modules/container-app.bicep`
Skapar Container Apps-miljön och själva appen med multi-revisionsläge och skala till 0:
```bicep
param name string
param location string = resourceGroup().location
param pullIdentityId string
param acrLoginServer string
param imageTag string

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-waypoint-${name}'
  location: location
  properties: {}
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-waypoint-${name}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${pullIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
      }
      registries: [
        {
          server: acrLoginServer
          identity: pullIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'waypoint'
          image: '${acrLoginServer}/waypoint:${imageTag}'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
      }
    }
  }
}

output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output appName string = containerApp.name
```

### 3. `infra/main-container-apps.bicep` & `infra/container-apps.bicepparam`
Kopplar samman ACR, pull-identiteten och Container App-modulen, och tar emot `IMAGE_TAG` via miljövariabel vid driftsättning.

---

## 🚀 Automatiserad CI/CD Pipeline

Pipelinen [`.github/workflows/deploy-container-app-pipeline.yml`](../.github/workflows/deploy-container-app-pipeline.yml) automatiserar hela flödet vid varje push till `main`:

1. **Autentisering:** Loggar in mot Azure med OIDC och GitHub Secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`).
2. **Container Build & Push:** Bygger och pushar imagen direkt i ACR taggad med 7-teckens git commit-hash (`waypoint:$TAG`).
3. **Infrastruktur & Revision:** Kör `az deployment group create` med `infra/main-container-apps.bicep` och skickar in `$TAG`. Container Apps känner av den nya image-taggen och skapar en ny revision automatiskt.
4. **Smoke Test:** Loopar mot `https://$APP_URL/health` tills appen svarar med `200 OK`.

*(Den äldre `infra-deploy-pipeline.yml` för App Service inaktiverades genom att ändra triggern till `workflow_dispatch`).*

---

## 🔍 Verifiering av driftsättning

### 1. HTTP-respons
Rot- och hälso-endpoints testades via terminalen:
```bash
curl -i https://ca-waypoint-raffi.happywave-4eaa4fa9.swedencentral.azurecontainerapps.io/health
```
**Respons:**
```http
HTTP/2 200 
x-powered-by: Express
content-type: application/json; charset=utf-8

{
  "status": "healthy",
  "version": "1.0.0"
}
```

### 2. Revisioner i Azure
```bash
az containerapp revision list --name ca-waypoint-raffi --resource-group RaffiMedzadaghlian --output table
```
**Utdata:**
```text
CreatedTime                Active    Replicas    TrafficWeight    HealthState    ProvisioningState    Name
-------------------------  --------  ----------  ---------------  -------------  -------------------  --------------------------
2026-11-20T13:26:01+00:00  True      1           100              Healthy        Provisioned          ca-waypoint-raffi--xm0cv5o
```
Revisionen är aktiv och tar emot 100% av trafiken.

