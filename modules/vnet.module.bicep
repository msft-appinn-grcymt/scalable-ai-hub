param name string
param location string = resourceGroup().location
param tags object = {}
param addressPrefix string
// param includeBastion bool = true
param subnets array = []
// param appSnet object
// param appGwSnet object
// param pepSnet object
// param devOpsSnet object
// param bastionSnet object



// var appSnetConfig = {
//   name: 'snet-app-${name}'
//   properties: appSnet
// }

// var appGwSnetConfig = {
//   name: 'snet-appgw-${name}'
//   properties: appGwSnet
// }

// var pepSnetConfig = {
//   name: 'snet-pep-${name}'
//   properties: pepSnet
// }

// var devOpsSnetConfig = {
//   name: 'snet-devops-${name}'
//   properties: devOpsSnet
// }

// var bastionSnetConfig = {
//   name: 'AzureBastionSubnet'
//   properties: bastionSnet
// }

// var mySQLSnetConfig = {
//   name: 'snet-mysql-${name}'
//   properties: mysqlSnet
// }

// var fixedSubnets = [
//   appGwSnetConfig
//   pepSnetConfig
//   devOpsSnetConfig
//   appSnetConfig
//   mySQLSnetConfig
// ]

// var allSubnets = includeBastion ? union(fixedSubnets, [
//     bastionSnetConfig
//   ]) : fixedSubnets

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: subnets
  }
  tags: tags
}

output vnetId string = vnet.id
output subnets array = vnet.properties.subnets
output appGWprivateIp string = parseCidr(vnet.properties.subnets[2].properties.addressPrefix).lastUsable

