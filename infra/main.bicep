param location string = resourceGroup().location
param planName string
param planSku string = 'B1'
param appName string
param linuxFxVersion string

// Container Registry-parametrar
param registryName string

// SQL-parametrar
param sqlServerName string
param sqlDatabaseName string
param sqlAdminLogin string

var sqlAdminPassword = 'P@ssword${uniqueString(resourceGroup().id)}!'

module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    location: location
    registryName: registryName
  }
}

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

output appServiceUrl string = appService.outputs.appServiceUrl
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
