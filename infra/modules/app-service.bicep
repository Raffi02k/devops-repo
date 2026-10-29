param location string
param appName string
param appServicePlanId string
param linuxFxVersion string

@secure()
param connectionString string = ''

resource appService 'Microsoft.Web/sites@2025-03-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appCommandLine: 'npm start'
      appSettings: union([
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ], empty(connectionString) ? [] : [
        {
          name: 'SQL_CONNECTION_STRING'
          value: connectionString
        }
      ])
    }
  }
}

output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
