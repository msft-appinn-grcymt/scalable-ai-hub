param name string
param location string = resourceGroup().location
param tags object = {}
param sku string = 'standard'
param publicNetworkAccess string = 'Disabled'
param softDeleteRetentionInDays int = 7
param enablePurgeProtection bool = false
param disableLocalAuth bool = false
param privateDnsZoneId string
param privateEndpointSubnet string
param keyVaultName string
param appConfigConnectionStringSecret string = 'AppConfigConnectionString'

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    disableLocalAuth: disableLocalAuth
    enablePurgeProtection: enablePurgeProtection
    publicNetworkAccess: publicNetworkAccess
    softDeleteRetentionInDays: softDeleteRetentionInDays
  }
}

//create the private endpoint
module privateendpoointapp './privateEndpoint.module.bicep' = {
  name: 'pep-${name}'
  params:{
    name: 'pep-${name}'
    location: location
    privateDnsZoneId: privateDnsZoneId
    privateLinkServiceId: appConfig.id
    subResource: 'configurationStores'
    subnetId: privateEndpointSubnet
    tags: tags
  }
}

// add the connection string to the vault

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

module keyVaultSecret 'keyvault.secret.module.bicep' = {
  name: 'kv-secret-appconfig-connstring'
  params: {
    keyVaultName: keyVaultName
    name: 'AppConfigConnectionString'
    value: appConfig.listKeys().value[0].connectionString
  }
}

output appConfigEndpoint string = appConfig.properties.endpoint
// output appConfigConnectionString string = appConfig.listKeys().value[0].connectionString
output appConfigConnectionStringReference string = '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${appConfigConnectionStringSecret})'
