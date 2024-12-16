// @description('The naming object generated from the azure.deploy.bicep file. It contains the standardized name for each Azure resource')
// param naming object
@description('The location to deploy the resources to')
param location string 
@description('The tags to apply to the resources')
param tags object = {}
@description('Organization/customer name')
param organization string
@description('The name of the application')
param applicationName string
@description('The environment to deploy the resources to')
param environment string
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
@description('SKU for the Language AI Service')
param languageServiceSku string = 'S'
@description('Array containing all the OpenAI deployments along with their configurations and model deployment if needed')
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

// All resource names
//MARK: Resource Names

import * as naming from './modules/naming.lib.bicep'

param namingConfig naming.NamingConfig = naming.createConfig([
  '${organization}${applicationName}'
  environment
  naming.locationPlaceholder()
])

var names = naming.createResourceNames(namingConfig)

var resourceNames = {
  vnet: names.virtualNetwork.name
  applicationInsights: names.applicationInsights.name
  keyVault: names.keyVault.name
  jumpboxVM: take('jb-${names.virtualMachine.name}',15)
  languageService: 'lng-${names.cognitiveAccount.name}'
  openAI: 'oai-${names.cognitiveAccount.name}'
  apim: '${names.apiManagement.name}'
  userAssignedIdentityApim: 'uai-${names.apiManagement.name}'
  apimNSG: '${names.networkSecurityGroup.name}-apim'
  applicationGateway: names.applicationGateway.name
}

//MARK: DNS to create
var privateDnsZonesToCreate = [
  {
    //For API Management
    name: 'dns-apim'
    dnsName: 'azure-api.net' 
  }
  {
    //For AI Services
    name: 'dns-ai'
    dnsName: 'privatelink.cognitiveservices.azure.com'
  }
  {
    //ForOpenAI
    name: 'dns-openai'    
    dnsName: 'privatelink.openai.azure.com'
  }
  {
    //For Key Vault
    name: 'dns-keyvault'    
    dnsName: 'privatelink.vaultcore.azure.net'
  }

]

//MARK: NSG for API Management

module apimNSG 'modules/networkSecurityGroup.module.bicep' = {
  name: 'NSG-${resourceNames.apimNSG}-Deployment'
  params: {
    name: resourceNames.apimNSG
    location: location
    apim: true
    tags: tags
  }
}

//MARK: Vnet

module vnet './modules/vnet.module.bicep' = {
  name: 'vnet-test'
  params: {
    addressPrefix: vnetAddressPrefix
    subnets: [
      {
        name: 'privateendpoints-snet'
        properties: {
          addressPrefix: privateEndpointsAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'apim-snet'
        properties: {
          addressPrefix: apimAddressPrefix
          networkSecurityGroup: {
            id: apimNSG.outputs.nsgId
          }
        }
      }
      //App GW /28
      {
        name: 'applicationgateway-snet'
        properties: {
          addressPrefix: appGatewayAddressPrefix
        }
      }      
      //Private link /28
      {
        name: 'privatelink-snet'
        properties: {
          addressPrefix: privateLinkAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }          
    ]
    name: resourceNames.vnet
    location: location
    tags: tags
  }
}

// MARK: Dns

module privateDnsZones 'modules/privateDnsZone.module.bicep' = {
  name: 'privateDnsZones-Deployment'
  params: {
   dnsZones: privateDnsZonesToCreate
   vnetIds: [vnet.outputs.vnetId]
   tags: tags
  }
 }

 // MARK: App Insights
 // Application Insights and Log Analytics Workspace

module appInsights 'modules/appInsights.module.bicep' = {
  name: 'AppInsights-${resourceNames.applicationInsights}-Deployment'
  params: {
    location: location
    name: resourceNames.applicationInsights
    projectName: applicationName
    keyVaultName: keyVault.outputs.name
  }
}

// MARK: Language Service

module languageService 'modules/cognitiveservices.module.bicep' = {
  name: '${resourceNames.languageService}-Deployment'
  params: {
    name: resourceNames.languageService
    kind: 'TextAnalytics'
    location: location
    sku: languageServiceSku
    privateDnsZoneId:   first(filter(privateDnsZones.outputs.zones, zone => zone.deploymentName == 'dns-ai')).id
    privateEndpointSubnet: first(filter(vnet.outputs.subnets, subnet => subnet.name == 'privateendpoints-snet')).id
    keyVaultName: keyVault.outputs.name
  }
}

// MARK: OpenAI 

module openAI 'modules/cognitiveservices.module.bicep' = [ for (openAI,i) in openAIDeployments : {
  name: '${resourceNames.openAI}-${i}-Deployment'
  params: {
    name: '${resourceNames.openAI}-${i}'
    kind: 'OpenAI'
    location: openAILocation
    privateEndpointLocation: location
    sku: openAI.openAISku
    deployModel: openAI.deployOpenAIModel
    modelName: openAI.openAIModelName
    modelVersion: openAI.openAIModelVersion
    modelCapacityType: openAI.openAIModelCapacityType
    modelCapacity: openAI.openAIModelCapacity
    privateDnsZoneId: first(filter(privateDnsZones.outputs.zones, zone => zone.deploymentName == 'dns-openai')).id
    privateEndpointSubnet: first(filter(vnet.outputs.subnets, subnet => subnet.name == 'privateendpoints-snet')).id
    keyVaultName: keyVault.outputs.name
  }
}]

// MARK: APIM

// APIM Backends
var aiBackends = [
  {
    name: 'OpenAIPrimaryEndpoint'
    description: 'Primary OpenAI Service'
    endpoint: '${openAI[0].outputs.endpoint}openai'
    keyReferenceUri: openAI[0].outputs.keyReferenceUriWithVersion
  }
  {
    name: 'OpenAISecondaryEndpoint'
    description: 'Secondary OpenAI Service'
    endpoint: '${openAI[1].outputs.endpoint}openai'
    keyReferenceUri: openAI[1].outputs.keyReferenceUriWithVersion
  }  
  {
    name: 'LanguageEndpoint'
    description: 'AI Language (for PII)'
    endpoint: '${languageService.outputs.endpoint}/language'
    keyReferenceUri: languageService.outputs.keyReferenceUriWithVersion
  } 
]

module apim 'modules/apiManagement.module.bicep' = {
  name: 'APIM-${resourceNames.apim}-Deployment'
  params: {
    name: resourceNames.apim
    location: location
    skuName: apimSKU
    apimSubnetId: first(filter(vnet.outputs.subnets, subnet => subnet.name == 'apim-snet')).id
    apimDnsZoneName: first(filter(privateDnsZones.outputs.zones, zone => zone.deploymentName == 'dns-apim')).dnsName
    aiBackends: aiBackends
    keyVaultName: keyVault.outputs.name
    aiProducts: aiProducts
    appInsightsConnectionStringReference: appInsights.outputs.keyReferenceUriWithVersion
    appInsightsId: appInsights.outputs.id
    appInsightsName: appInsights.outputs.name
    openAIDeployments: openAIDeployments
    openAIResourceName: resourceNames.openAI
    tags: tags
 }
}


// MARK Jumpbox VM

module jumpboxVM 'modules/vmjumpbox.module.bicep' = {
  name: 'JumpboxVM-${resourceNames.jumpboxVM}-Deployment'
  params: {
    name: resourceNames.jumpboxVM
    location: location
    subnetId: first(filter(vnet.outputs.subnets, subnet => subnet.name == 'privateendpoints-snet')).id
    adminPassword: VmAdminPassword
    adminUserName: VmAdminUsername
  }
}

//MARK: Key Vault

module keyVault 'modules/keyvault.module.bicep' = {
  name: 'KeyVault-Deployment'
  params: {
    name: resourceNames.keyVault
    location: location
    skuName: keyVaultSku
    tags: tags
    privateDnsZoneId: first(filter(privateDnsZones.outputs.zones, zone => zone.deploymentName == 'dns-keyvault')).id
    privateEndpointSubnet: first(filter(vnet.outputs.subnets, subnet => subnet.name == 'privateendpoints-snet')).id
  }
}

// MARK: App Gateway

module applicationGateway 'modules/applicationGateway.module.bicep' = {
  name: resourceNames.applicationGateway
  params: {
    name: resourceNames.applicationGateway
    location: location
    tags: tags
    dnsLabelPrefix: resourceNames.applicationGateway
    frontendWebAppFqdn: replace(apim.outputs.gatewayUrl, 'https://', '')
    subnetId: first(filter(vnet.outputs.subnets, subnet => subnet.name == 'applicationgateway-snet')).id
    privateLinkSubnetId: first(filter(vnet.outputs.subnets, subnet => subnet.name == 'privatelink-snet')).id
    privateIp: vnet.outputs.appGWprivateIp
  }
}

// MARK: Outputs

output apimName string = apim.outputs.name
output applicationGatewayName string = applicationGateway.outputs.name
output products array = apim.outputs.products
