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

output registryLoginServer string = containerRegistry.outputs.loginServer
output pullIdentityPrincipalId string = pullIdentity.outputs.pullIdentityPrincipalId
output containerAppFqdn string = containerApp.outputs.fqdn
