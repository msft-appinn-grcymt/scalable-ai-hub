using 'erb.azure.deploy.bicep'
// General Settings
param location = 'northeurope'
//Organization customer name
param organization = 'mserb' ////////
param applicationName = 'genai' //////////
param environment = 'qa' /////////
param tags = {}
//Resource Group
@description('The resource group to deploy the resources to')
param rgName = 'rg-erbot-dev-neu' ////////////////////////////////////////////////////////////
//Network settings
@description('The name of the VNet')
param vnetName = 'vnet-erbot-dev-neu' /////////////////////////
@description('The CIDR block to use for the virtual network')
param vnetAddressPrefix = '10.0.0.0/16' ///////////////////////
@description('The CIDR for API Management subnet')
param apimAddressPrefix = '10.0.0.0/24' ///////////////////////
@description('The CIDR for App Gateway subnet')
param appGatewayAddressPrefix = '10.0.1.0/24' ////////////////////
@description('The CIDR for Private Link subnet')
param privateLinkAddressPrefix = '10.0.2.0/24' ///////////////////
@description('The CIDR for Private Endpoints subnet')
param privateEndpointsAddressPrefix = '10.0.3.0/24' ////////////////////
@description('The CIDR for App Service subnet')
param appServiceAddressPrefix = '10.0.4.0/24' ////////////////////
@description('The CIDR for Functions subnet')
param functionsAddressPrefix = '10.0.5.0/24' ////////////////////
// Existing Private DNS Zones
@description('Subscription ID which contains the existing Private DNS Zones')
param privateDnsZonesSubscriptionId = 'fd84d490-11c4-41aa-b7a3-e6685febd4f4'  /////////////////////////////
@description('Resource Group which contains the existing Private DNS Zones')
param privateDnsZonesResourceGroup = 'rg-dnszone-dev'   ////////////////////////////////////
// Language Service
param languageServiceSku = 'S'
// OpenAI
param openAILocation = 'swedencentral'
// Can deploy single OpenAI account and optionally a model or additional account for spillover and failover facilitation
param openAIDeployments = [
  {
    //SKU for the OpenAI Service
    openAISku: 'S0'
    openAILocation: 'swedencentral'
    //Flag to deploy an OpenAI model to the service - Applicable only for OpenAI Cognitive Services
    deployOpenAIModel: true
    //The OpenAI model to deploy - Applied only when deployModel=true - Applicable only for OpenAI Cognitive Services
    openAIModelName: 'gpt-4o'
    //The OpenAI model version to deploy - Applied only when deployModel=true - Applicable only for OpenAI Cognitive Services
    openAIModelVersion: '2024-05-13'
    //The OpenAI type (Standard or ProvisionedManaged) - Applied only when deployModel=true - Applicable only for OpenAI Cognitive Services
    openAIModelCapacityType: 'Standard'
    //The OpenAI model capacity (TPM for Standard - PTU for Provisioned) - Applied only when deployModel=true - Applicable only for OpenAI Cognitive Services
    openAIModelCapacity: 50
  }
  {
    openAISku: 'S0'
    openAILocation: 'swedencentral'
    deployOpenAIModel: true
    openAIModelName: 'gpt-4o'
    openAIModelVersion: '2024-05-13'
    openAIModelCapacityType: 'Standard'
    openAIModelCapacity: 20
  }
]
// API Management
param apimSKU = 'Developer'
@description('Array with the OpenAI products and the respective token per limit groupings/t-shirt sizing to be applied')
param aiProducts = [
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
// Jumphost
param VmAdminUsername = 'vmadmin'
param VmAdminPassword = readEnvironmentVariable('IAC_VM_PWD','!!P@ssw0rd!!') 
// Key Vault
@description('SKU for the Key Vault')
param keyVaultSku = 'standard'
