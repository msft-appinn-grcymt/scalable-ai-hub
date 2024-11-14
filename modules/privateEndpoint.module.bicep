param name string
param location string
param tags object = {}
param subnetId string
param privateLinkServiceId string
param privateDnsZoneId string

@allowed([
  'sites'
  'sqlServer'   // Microsoft.Sql/servers
  'mysqlServer'
  'blob'
  'file'  
  'queue'
  'table'
  'redisCache'
  'registry'    // Microsoft.ContainerRegistry/registries
  'namespace'   // Microsoft.ServiceBus/namespaces or Microsoft.EventHub/namespaces
  'Sql'         // Microsoft.Synapse/workspaces
  'vault'       // Microsoft.KeyVault/vaults
  'Table'       // Microsoft.DocumentDb/databaseAccounts
  'staticSites' // Microsoft.Web/staticSites
  'configurationStores' // Microsoft.AppConfiguration/configurationStores
  'account'  //CognitiveServices/accounts
])
param subResource string

var privateLinkConnectionName = 'prvLnk-${name}'
var privateDnsZoneConfigName = 'prvDnsZoneConfig-${name}'

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateLinkConnectionName
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: [
            subResource
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  parent: privateEndpoint
  name: 'DnsZoneGroup-${name}'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneConfigName
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}
