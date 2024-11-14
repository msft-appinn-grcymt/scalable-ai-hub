param sku string
param name string
param location string
param adminUserEnabled bool = false
param tags object = {}
param keyVaultName string = ''
param privateDns string = ''
param privateEndpointSubnet string = ''
var createSecretsInKeyVault = !empty(keyVaultName)

resource registry 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
  }
  tags: tags
}

// Private Endpoint Connection

module privateendpointacr './privateEndpoint.module.bicep' =  {
  name: 'pe-acr-${name}'
  params:{
    name: 'pe-acr-${name}'
    location: location
    privateDnsZoneId: privateDns
    privateLinkServiceId: registry.id
    subResource: 'registry'
    subnetId: privateEndpointSubnet
    tags: tags
  }
}


// // Add username and password in keyvault and return the reference

// module keyVaultSecretACRUser 'keyvault.secret.module.bicep' = if (createSecretsInKeyVault) {
//   name: 'ACR-KeyVaultSecret-${name}-User'
//   params: {
//     keyVaultName: keyVaultName
//     name: 'ACR-User'
//     value: registry.listCredentials().username
//   }
// }

// module keyVaultSecretACRPassword 'keyvault.secret.module.bicep' = if (createSecretsInKeyVault) {
//   name: 'ACR-KeyVaultSecret-${name}-Password'
//   params: {
//     keyVaultName: keyVaultName
//     name: 'ACR-Password'
//     value: registry.listCredentials().passwords[0].value
//   }
// }

output registryLoginServer string = registry.properties.loginServer
// output keyVaultReferenceUser string = createSecretsInKeyVault ? keyVaultSecretACRUser.outputs.reference : ''
// output keyVaultReferenceKey string = createSecretsInKeyVault ? keyVaultSecretACRPassword.outputs.reference : ''
