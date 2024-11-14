param dnsZoneName string
param vnetId string
param privateEndpointName string
param location string
param tags object = {}
param privateEndpointSubnetId string
@description('AI HUB Private Endpoint - Private Link Group ID')
param privateLinkGroupId string = 'appGwPrivateFrontendIpIPv4'
@description('Id of the application Gateway with the private link that the private endpoint points to')
param applicationGatewayId string


// Create the private DNS zone for the AI HUB domain
// and link it to the Workload's Vnet

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'Global'
  tags: tags  
}

resource privateDnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${dnsZoneName}-link-${resourceGroup().name}'
  parent: privateDnsZone
  location: 'Global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}


resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          groupIds: [
            privateLinkGroupId
          ]
          privateLinkServiceId: applicationGatewayId
        }
      }
    ]
  }
}


// resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
//   parent: privateEndpoint
//   name: 'DnsZoneGroup-${privateEndpointName}'
//   properties: {
//     privateDnsZoneConfigs: [
//       {
//         name: privateDnsZoneConfigName
//         properties: {
//           privateDnsZoneId: privateDnsZone.id
//         }
//       }
//     ]
//   }
// }


output pepNIC string = last(split(privateEndpoint.properties.networkInterfaces[0].id,'/'))
