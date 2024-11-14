param name string
param location string = resourceGroup().location
param tags object = {}

param customSubDomainName string = name
param kind string 
param publicNetworkAccess string = 'Disabled'
param sku string
param privateEndpointSubnet string
param privateEndpointLocation string = location
param privateDnsZoneId string
param deployModel bool = false
param modelName string?
param modelVersion string?
@allowed([
  'Standard'
  'ProvisionedManaged'
])
param modelCapacityType string = 'Standard'
param modelCapacity int?
param modelFormat string = 'OpenAI'
@description('Key Vault Name to insert the key as secret')
param keyVaultName string 

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
  }
  sku: {
    name: sku
  }
}

// Deploy model (for OpenAI)

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-06-01-preview' = if (deployModel) {
  name: '${modelName}-deployment'
  parent: account
  sku: {
    name: modelCapacityType
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: modelFormat
      name: modelName
      version: modelVersion
    }
  }

}

// Private Endpoint

module privateendpoointcognitive './privateEndpoint.module.bicep' =  {
  name: 'pep-${name}'
  params:{
    name: 'pep-${name}'
    location: privateEndpointLocation
    privateDnsZoneId: privateDnsZoneId
    privateLinkServiceId: account.id
    subResource: 'account'
    subnetId: privateEndpointSubnet
    tags: tags
  }
}

module accountKeySecret 'keyvault.secret.module.bicep' = {
  name: '${name}-Key'
  params: {
    name: '${name}-Key'
    keyVaultName: keyVaultName
    value: account.listKeys().key1
  }
}

output endpoint string = account.properties.endpoint
output id string = account.id
output name string = account.name
output keyReferenceUriWithVersion string = accountKeySecret.outputs.uriWithVersion
