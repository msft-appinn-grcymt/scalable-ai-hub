param name string
param projectName string
param location string
param logAnalyticsWorkspaceId string = ''
param tags object = {}
param keyVaultName string

var deployWorkspace = empty(logAnalyticsWorkspaceId)
var workspaceName = 'log-${name}'

resource laWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (deployWorkspace) {
  location: location
  name: workspaceName
  tags: union(tags, {
    displayName: workspaceName
    projectName: projectName
  })
  properties: {
    retentionInDays: 30
    sku:{
      name:'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: deployWorkspace ? laWorkspace.id : logAnalyticsWorkspaceId
    CustomMetricsOptedInType: 'WithDimensions'
  }
}

// Insert application insights connection string to key vault
// to be referenced on APIM secret named value
// to be then used on APIM logger

module appInsightsConnStringSecret 'keyvault.secret.module.bicep' = {
  name: '${name}-ConnectionString'
  params: {
    name: '${name}-ConnectionString'
    keyVaultName: keyVaultName
    value: appInsights.properties.ConnectionString
  }
}

output id string = appInsights.id
output name string = appInsights.name
output instrumentationKey string = appInsights.properties.InstrumentationKey
output logAnalyticsWorkspaceId string = deployWorkspace ? laWorkspace.id : logAnalyticsWorkspaceId
// output connectionString string = appInsights.properties.ConnectionString
output keyReferenceUriWithVersion string = appInsightsConnStringSecret.outputs.uriWithVersion
