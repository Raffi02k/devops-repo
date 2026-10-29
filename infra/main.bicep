param location string = resourceGroup().location
param planName string
param planSku string = 'B1'
param appName string
param linuxFxVersion string

// SQL-parametrar
param sqlServerName string
param sqlDatabaseName string
param sqlAdminLogin string

// Vi ändrar till en variabel (var) så slipper vi skicka med den från parametrar!
var sqlAdminPassword = 'P@ssword${uniqueString(resourceGroup().id)}!'

module appServicePlan 'modules/app-service-plan.bicep' = {
  name: 'app-service-plan'
  params: {
    location: location
    planName: planName
    planSku: planSku
  }
}

module sqlDatabase 'modules/sql-database.bicep' = {
  name: 'sql-database'
  params: {
    location: location
    serverName: sqlServerName
    databaseName: sqlDatabaseName
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
  }
}

module appService 'modules/app-service.bicep' = {
  name: 'app-service'
  params: {
    location: location
    appName: appName
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    linuxFxVersion: linuxFxVersion
    connectionString: 'Server=tcp:${sqlDatabase.outputs.sqlServerFullyQualifiedDomainName},1433;Database=${sqlDatabaseName};User Id=${sqlAdminLogin};Password=${sqlAdminPassword};Encrypt=true'
  }
}

output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
