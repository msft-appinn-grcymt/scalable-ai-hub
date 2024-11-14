param pepNICName string
param dnsZone string

resource pepNIC 'Microsoft.Network/networkInterfaces@2023-11-01' existing = {
  name: pepNICName
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: dnsZone
}

resource pepRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: '@'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: pepNIC.properties.ipConfigurations[0].properties.privateIPAddress
      }
    ]
  }
}
