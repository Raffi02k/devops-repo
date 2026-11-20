using 'main-container-apps.bicep'

var baseName = 'raffi'

param name = baseName
param registryName = 'crwaypoint${baseName}'
param pullIdentityName = 'id-waypoint-${baseName}'
param imageTag = readEnvironmentVariable('IMAGE_TAG')
