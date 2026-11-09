# Modul 08: Observerbarhet (Observability) med Log Analytics, KQL & Larm

Denna dokumentation sammanfattar genomförandet av **Modul 08** i kursen DevOps utveckling. Målet med modulen är att etablera full observerbarhet över Waypoint-applikationen i Azure – så att vi i driftteamet upptäcker avvikelser och incidenter automatiskt innan slutanvändarna drabbas.

---

## 🎯 Vad är observerbarhet?

Observerbarhet (*Observability*) handlar om att förstå vad som händer inuti och runt ett system baserat på dess externa utdata:
* **Loggar (Logs):** Tidsstämplade händelser i textform (t.ex. inkommande HTTP-anrop, krascher).
* **Mätvärden (Metrics):** Numeriska mätningar över tid (t.ex. CPU-utnyttjande, minnesanvändning).
* **Larm (Alerts):** Automatiska regler som meddelar ansvariga när tröskelvärden överskrids.

### Två lager av information i Azure
| Lager | Vad det ser | Hur det aktiveras |
|---|---|---|
| **Plattformsloggar (*Platform logs*)** | Anrop, HTTP-statuskoder, klient-IP och svarstider sett från infrastrukturplattformen | Ingen kodändring krävs (aktiveras via Diagnostikinställning) |
| **Applikationstelemetri (*Application telemetry*)** | Vad som sker djupt inuti koden, funktionsanrop och databasfrågor | Kräver ett SDK/bibliotek i appen (t.ex. Application Insights) |

I Modul 08 fokuserar vi på **plattformsloggar**, vilket ger full insyn i all HTTP-trafik helt utan ingrepp i källkoden.

---

## 🧱 Arkitektur för logginsamling och larm

Kedjan som byggts upp i Azure via Bicep:

```text
┌───────────────────────┐
│   Waypoint App        │ (Tar emot HTTP-anrop på App Service)
└──────────┬────────────┘
           │ Plattformsloggar (AppServiceHTTPLogs & AppServiceConsoleLogs)
           ▼
┌───────────────────────────────────────────────┐
│ Diagnostikinställning ('to-workspace')       │ (infra/modules/app-service.bicep)
└──────────┬────────────────────────────────────┘
           │ Skickar loggarna
           ▼
┌───────────────────────────────────────────────┐
│ Log Analytics Workspace ('log-waypoint-raffi')│ (infra/modules/log-analytics.bicep)
└──────────┬────────────────────────────────────┘
           │ KQL-fråga körs var 5:e minut
           ▼
┌───────────────────────────────────────────────┐
│ Larmregel ('high-error-rate')                 │ (infra/modules/alerts.bicep)
└──────────┬────────────────────────────────────┘
           │ Triggar vid > 5 serverfel (HTTP >= 500)
           ▼
┌───────────────────────────────────────────────┐
│ Action Group ('ag-waypoint-raffi')            │ (Skickar e-post till ALERT_EMAIL)
└───────────────────────────────────────────────┘
```

---

## 🛠 Nya och uppdaterade Bicep-moduler

### 1. `infra/modules/log-analytics.bicep`
Skapar den centrala arbetsytan (*Log Analytics Workspace*) där alla loggar samlas och indexeras:
```bicep
param location string
param workspaceName string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output workspaceId string = logAnalyticsWorkspace.id
```

### 2. Diagnostikinställning i `infra/modules/app-service.bicep`
Workspacen fylls inte av sig själv. En **diagnostikinställning** fungerar som "sladden" mellan webbappen och workspacen:
```bicep
resource appServiceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-workspace'
  scope: appService
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
    ]
  }
}
```

### 3. `infra/modules/alerts.bicep`
Innehåller både vem som ska kontaktas och villkoret för när larmet ska utlösas:
* **Action Group (`Microsoft.Insights/actionGroups@2023-01-01`):** Hanterar mottagare via e-post (`emailReceivers`).
* **Scheduled Query Rule (`Microsoft.Insights/scheduledQueryRules@2023-12-01`):** Körs var 5:e minut och larmar om fler än 5 fel med HTTP-status $\ge 500$ uppmäts:
```bicep
query: 'AppServiceHTTPLogs | where CsHost !contains ".scm." | where ScStatus >= 500'
timeAggregation: 'Count'
operator: 'GreaterThan'
threshold: 5
```

### 4. GDPR & Personuppgiftsskydd: `ALERT_EMAIL`
E-postadresser är personuppgifter och ska aldrig checkas in i Git. Därför läses adressen in dynamiskt i [`infra/dev.bicepparam`](file:///Users/raffimedz/Desktop/devops/devops-repo/infra/dev.bicepparam):
```bicep
param alertEmail = readEnvironmentVariable('ALERT_EMAIL')
```
I GitHub Actions matas detta in via repots miljövariabel:
```yaml
env:
  ALERT_EMAIL: ${{ vars.ALERT_EMAIL }}
```

---

## 🔍 KQL (Kusto Query Language) & De fyra gyllene signalerna

I Log Analytics analyseras loggarna med **KQL**, som bygger på rörledningsprincipen (`|` skickar data vidare till nästa filter/aggregering).

### Räkna trafik (Trafik):
```kql
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| where CsHost !contains ".scm."
| summarize requests = count()
```

### De fyra gyllene signalerna (*The Four Golden Signals*):
Tillsammans ger dessa signaler en fullständig bild av systemets tillstånd:
1. **Trafik (Traffic):** Hur mycket efterfrågan systemet har (`count()` i loggarna).
2. **Fel (Errors):** Hur många anrop som misslyckas (`countif(ScStatus >= 500)` i loggarna).
3. **Latens (Latency):** Hur lång tid anropen tar (`percentile(TimeTaken, 95)` i loggarna).
4. **Mättnad (Saturation):** Hur nära kapacitetstaket hårdvaran är (CPU och RAM). **Obs:** Mättnad finns inte i HTTP-loggarna, utan läses från mätvärden (*metrics*) på App Service-planen!

---

## 🔥 Testa larmet i praktiken (Incidentprovokation)

Ett larm som inte har testats kan man inte lita på. För att verifiera larmkedjan provocerar vi fram ett serverfel med flit:

1. **Injicera trasig databasanslutning:**
   ```bash
   CONNECTION_STRING="Server=tcp:does-not-exist.database.windows.net,1433;Database=sqldb;User Id=x;Password=y;Encrypt=true"
   az webapp config appsettings set \
     --name "app-waypoint-raffi" \
     --resource-group "RaffiMedzadaghlian" \
     --settings "SQL_CONNECTION_STRING=$CONNECTION_STRING"
   ```
2. **Generera trafik med felkod 503:**
   Waypoint ser `SQL_CONNECTION_STRING`, försöker nå den icke-existerande servern och kraschar med **HTTP 503 Service Unavailable**.
   ```bash
   for attempt in $(seq 1 30); do
     curl -s -o /dev/null -w "%{http_code}\n" --max-time 30 "https://app-waypoint-raffi.azurewebsites.net/health"
     sleep 10
   done
   ```
3. **Larmet löser ut (*Fired*):**
   Azure Monitor detekterar fler än fem fel på fem minuter. Ett larm skickas ut med ämnet:
   `Fired:Sev2 Azure Monitor Alert high-error-rate on log-waypoint-raffi...`
4. **Återställning:**
   Genom att köra en ny deployment med Bicep skrivs de temporära appSettings över och appen återgår till stabil drift med SQLite (HTTP 200 OK).

---

## 🛑 Kostnadskontroll & Teardown

För att undvika onödiga kostnader uppdaterades [`scripts/teardown-app-service.sh`](file:///Users/raffimedz/Desktop/devops/devops-repo/scripts/teardown-app-service.sh) med stöd för Modul 08:
* **Standardkörning (`./scripts/teardown-app-service.sh`):** Raderar App Service och App Service Plan (stoppar timdebiteringen direkt).
* **Full städning (`./scripts/teardown-app-service.sh --all`):** Raderar även larmregeln (`high-error-rate`), åtgärdsgruppen (`ag-waypoint-raffi`), Log Analytics workspacen (`log-waypoint-raffi`) samt container-registret (`crwaypointraffi`).

---

## 🎯 Sammanfattning av DevOps-lärdomar i Modul 08

1. **Observerbarhet före incidenter:** Genom att mäta trafik, fel och latens ser vi försämringar i systemet innan de orsakar totalt avbrott.
2. **Actionable Alerts:** Larm ska vara tydliga, innehålla instruktioner om vad mottagaren ska göra först och endast larma på faktiska problem som drabbar användaren – detta motverkar **larmtrötthet** (*alert fatigue*).
3. **Plattformsloggar via IaC:** Genom att deklarera Log Analytics och diagnostikinställningar i Bicep ingår övervakning och loggning automatiskt i varje miljö som rullas ut.
