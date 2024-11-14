param dnsZones array
param tags object = {}
param registrationEnabled bool = false
param vnetIds array

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = [ for dnsZone in dnsZones : {
  name: dnsZone.dnsName
  location: 'Global'
  tags: tags  
}]

module privateDnsZoneLinks 'privateDnsZoneLink.module.bicep' =  [ for (dnsZone,i) in dnsZones : if (!empty(vnetIds)) {
  name: take('PrvDnsZoneLinks-Deployment-${dnsZone.name}',64)  
  params: {
    privateDnsZoneName: privateDnsZone[i].name
    vnetIds: vnetIds
    registrationEnabled: registrationEnabled
    tags: tags
  }
}]


output zones array = [ for (dns,i) in dnsZones : {
  id: privateDnsZone[i].id
  deploymentName: dnsZones[i].name
  dnsName: privateDnsZone[i].name
}]
