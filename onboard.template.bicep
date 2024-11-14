// targetScope = 'subscription'


@description('The AI Hub API Management Service to add the new Bot Application to')
param aiHubAPIMName string = 'APIM_NAME_TO_BE_REPLACED'
@description('Code to be used for the Department/Organization which will deploy the AI Workload')
param departmentCode string
@description('Name of the Department/Organization which will deploy the AI Workload')
param departmentName string
@description('Code to be used for the AI workload')
param aiWorkloadCode string
@description('Short description of the AI workload')
param aiWorkloadDesc string
@description('AI HUB Product')
@allowed([
  'SmallAIWorkloads'
  'MediumAIWorkloads'
  'LargeAIWorkloads'
  'ExtraLargeAIWorkloads'
])
param aiHubProduct string
@description('The Subscription for the AI Workload. Used to find the respective KeyVault for the AI Hub Subscription Key')
param workloadSubscriptionId string
@description('The Resource Group for the AI Workload')
param workloadResourceGroup string
@description('The KeyVault Name for the AI Workload. Used to set the AI Hub Subscription Key')
param workloadKeyVaultName string
@description('The DNS Zones for the AI HUB')
param dnsZone string = 'DNS_NAME_TO_BE_REPLACED'
@description('The Vnet for the AI Workload')
param workloadVnet string
@description('The Private Endpoint Subnet on the Vnet for the AI Workload')
param workloadPepSubnet string
@description('The Location for the AI Hub Private Endpoint')
param location string = 'LOCATION_TO_BE_REPLACED'
@description('AI HUB Private Endpoint - Private Link Group ID')
param privateLinkGroupId string = 'appGwPrivateFrontendIpIPv4'
@description('Name of the application Gateway with the private link that the private endpoint points to')
param hubApplicationGateway string = 'APP_GW_NAME_TO_BE_REPLACED'

var aiHubPrivateEndpointName = 'OpenAI-Scalable-Endpoint-PE'

// Get the API Management Instance
resource aihubAPIM 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: aiHubAPIMName
}

// Create the API User for the Ministry/Authority (if not exists)
resource apiUser 'Microsoft.ApiManagement/service/users@2023-05-01-preview' = {
  name: toUpper(departmentCode)
  parent: aihubAPIM
  properties: {
    email: '${departmentCode}@apim.io'
    firstName: toUpper(departmentCode)
    lastName: departmentName
    identities: [
      {
        id: '${departmentCode}@apim.io'
        provider: 'Basic'
      }
    ]
  }
}

// Create the Subscription for the AI Workload
resource apiSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  name: aiWorkloadCode
  parent: aihubAPIM
  properties: {
    ownerId: '/users/${apiUser.name}'
    scope: '/products/${aiHubProduct}'
    displayName: aiWorkloadDesc
    state: 'active'
    allowTracing: false
  }
}


// Save the Subscription key to the workload's KeyVault
module aihubSubscriptionKeySecret './modules/keyvault.secret.module.bicep' = {
  name: 'aihubSubscriptionKeySecret'
  scope: resourceGroup(workloadSubscriptionId,workloadResourceGroup)
  params: {
    keyVaultName: workloadKeyVaultName
    name: 'AIHubSubscriptionKey'
    value: apiSubscription.listSecrets().primaryKey
  }
}


// Workload Vnet
resource vNet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: workloadVnet
  scope: resourceGroup(workloadSubscriptionId,workloadResourceGroup)
}

// Workload Subnet to attach the AI HUB Private Endpoint

resource pepSnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: workloadPepSubnet
  parent: vNet
}

// Get the Hub Application Gateway resource

resource applicationGateway 'Microsoft.Network/applicationGateways@2023-11-01' existing = {
  name: hubApplicationGateway
}

// Create the private DNS zone for the AI HUB domain
// and link it to the Workload's Vnet
// Create the PRivate endpoint to AI Hub App Gateway private link
// Add DNS configuration to the private endpoint


module privateConnectivityActions './modules/connectivity.bicep' = {
  name: 'privateConnectivityActions'
  scope: resourceGroup(workloadSubscriptionId,workloadResourceGroup)
  params: {
    dnsZoneName: dnsZone
    vnetId: vNet.id
    privateEndpointName: aiHubPrivateEndpointName
    privateEndpointSubnetId: pepSnet.id
    applicationGatewayId: applicationGateway.id
    privateLinkGroupId: privateLinkGroupId
    location: location
  }
}

// Add an A record to the Hub DNS with the private endpoint IP
module hubDnsARecord './modules/hubDnsArecord.bicep' = {
  name: 'hubDnsARecord'
  scope: resourceGroup(workloadSubscriptionId,workloadResourceGroup)
  params: {
    dnsZone: dnsZone
    pepNICName: privateConnectivityActions.outputs.pepNIC
  }
}

