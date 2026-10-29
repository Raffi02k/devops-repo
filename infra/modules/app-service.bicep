param location string
param appName string
param appServicePlanId string
param linuxFxVersion string

resource appService 'Microsoft.Web/sites@2025-03-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appCommandLine: 'npm start'
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        },
        {
          name: 'PORT'
          value: '8080'
        }
      ]
    }
  }
}

output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
