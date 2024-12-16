targetScope = 'subscription'

@description('The location to deploy the resources to')
param location string = deployment().location
@description('Organization/customer name')
param organization string
@description('The name of the application')
param applicationName string
@description('The environment to deploy the resources to')
param environment string
@description('The tags to apply to the resources')
param tags object = {}
@description('The resource group to deploy the resources to')
param rgName string
@description('The name of the VNet')
param vnetName string
@description('The CIDR block to use for the virtual network')
param vnetAddressPrefix string
@description('The CIDR for API Management subnet')
param apimAddressPrefix string
@description('The CIDR for App Gateway subnet')
param appGatewayAddressPrefix string
@description('The CIDR for Private Link subnet')
param privateLinkAddressPrefix string
@description('The CIDR for Private Endpoints subnet')
param privateEndpointsAddressPrefix string
@description('The CIDR for App Service subnet')
param appServiceAddressPrefix string
@description('The CIDR for Functions subnet')
param functionsAddressPrefix string
@description('Subscription ID which contains the existing Private DNS Zones')
param privateDnsZonesSubscriptionId string
@description('Resource Group which contains the existing Private DNS Zones')
param privateDnsZonesResourceGroup string
param languageServiceSku string = 'S'
param openAIDeployments array
@description('Location of the OpenAI service')
param openAILocation string
@description('APIM SKU')
param apimSKU string = 'Developer'
@description('Array with the OpenAI products and the respective token per limit groupings/t-shirt sizing to be applied')
param aiProducts array = [
  {
    name: 'Small'
    TPMThreshold: '20000'
  }
  {
    name: 'Medium'
    TPMThreshold: '50000'
  }  
  {
    name: 'Large'
    TPMThreshold: '100000'
  }   
  {
    name: 'Extra Large'
    TPMThreshold: '200000'
  }   
]
@description('VM Admin username')
param VmAdminUsername string
@description('VM Admin Password')
@secure()
param VmAdminPassword string
@description('SKU for the Key Vault')
param keyVaultSku string = 'standard'

var defaultTags = union({
  applicationName: applicationName
  environment: environment
}, tags)


// Resource group which is the scope for the main deployment below
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: rgName
}

module main 'erb.main.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'AIHub-MainDeployment'
  params: {
    location: location
    tags: defaultTags
    organization: organization
    applicationName: applicationName
    environment: environment
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    apimAddressPrefix: apimAddressPrefix
    privateDnsZonesSubscriptionId: privateDnsZonesSubscriptionId
    privateDnsZonesResourceGroup: privateDnsZonesResourceGroup
    aiProducts: aiProducts
    appGatewayAddressPrefix: appGatewayAddressPrefix
    privateEndpointsAddressPrefix: privateEndpointsAddressPrefix
    privateLinkAddressPrefix: privateLinkAddressPrefix
    appServiceAddressPrefix: appServiceAddressPrefix
    functionsAddressPrefix: functionsAddressPrefix
    languageServiceSku: languageServiceSku
    openAIDeployments: openAIDeployments
    openAILocation: openAILocation
    apimSKU: apimSKU
    VmAdminUsername: VmAdminUsername
    VmAdminPassword: VmAdminPassword
    keyVaultSku: keyVaultSku
  }
}

output apimName string = main.outputs.apimName
// output appGatewayName string = main.outputs.applicationGatewayName
output resourceGroupName string = rg.name
output location string = location
output products array = main.outputs.products
output hubDns string = '${organization}.${environment}.aihub.com'
