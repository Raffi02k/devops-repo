@description('Region. The same as the resource group, unless you give another.')
param location string = resourceGroup().location

@description('Suffix used for naming resources.')
param name string

@description('Name of the container registry. Letters and digits only, unique in all of Azure.')
param registryName string

@description('Name of the pull identity.')
param pullIdentityName string

@description('Image tag to deploy.')
param imageTag string

@description('Name of the Log Analytics workspace.')
param workspaceName string

@description('Name of the action group that gets the alerts.')
param actionGroupName string

@description('Where alerts are sent.')
param alertEmail string

module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    location: location
    registryName: registryName
  }
}

module pullIdentity 'modules/pull-identity.bicep' = {
  name: 'pull-identity'
  params: {
    location: location
    pullIdentityName: pullIdentityName
  }
}

module containerApp 'modules/container-app.bicep' = {
  name: 'container-app'
  params: {
    name: name
    location: location
    pullIdentityId: pullIdentity.outputs.pullIdentityId
    acrLoginServer: containerRegistry.outputs.loginServer
    imageTag: imageTag
  }
}

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics'
  params: {
    location: location
    workspaceName: workspaceName
  }
}

module alerts 'modules/alerts.bicep' = {
  name: 'alerts'
  params: {
    location: location
    workspaceId: logAnalytics.outputs.workspaceId
    actionGroupName: actionGroupName
    alertEmail: alertEmail
  }
}

output registryLoginServer string = containerRegistry.outputs.loginServer
output pullIdentityPrincipalId string = pullIdentity.outputs.pullIdentityPrincipalId
output containerAppFqdn string = containerApp.outputs.fqdn
