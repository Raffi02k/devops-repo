using 'main-container-apps.bicep'

var baseName = 'raffi'

param name = baseName
param registryName = 'crwaypoint${baseName}'
param pullIdentityName = 'id-waypoint-${baseName}'
param workspaceName = 'log-waypoint-${baseName}'
param actionGroupName = 'ag-waypoint-${baseName}'
param alertEmail = readEnvironmentVariable('ALERT_EMAIL')
param imageTag = readEnvironmentVariable('IMAGE_TAG')
