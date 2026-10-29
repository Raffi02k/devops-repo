using 'main.bicep'

var name = 'raffi'

param planName = 'asp-waypoint-${name}'
param planSku = 'B1'
param appName = 'app-waypoint-${name}'
param linuxFxVersion = 'NODE|24-lts'

// Databaskonfiguration (helt statiska värden)
param sqlServerName = 'sql-waypoint-${name}'
param sqlDatabaseName = 'sqldb-waypoint-${name}'
param sqlAdminLogin = 'waypointadmin'
