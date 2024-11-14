using 'azure.deploy.bicep'
// General Settings
param location = 'uksouth'
//Organization customer name
param organization = 'vzcorp'
param applicationName = 'aihub'
param environment = 'poc'
param tags = {
  owner: 'microsoft-internal'
}
//Network settings
@description('The CIDR block to use for the virtual network')
param vnetAddressPrefix = '10.0.0.0/16'
@description('The CIDR for API Management subnet')
param apimAddressPrefix = '10.0.0.0/24'
@description('The CIDR for App Gateway subnet')
param appGatewayAddressPrefix = '10.0.1.0/24'
@description('The CIDR for Private Link subnet')
param privateLinkAddressPrefix = '10.0.2.0/24'
@description('The CIDR for Private Endpoints subnet')
param privateEndpointsAddressPrefix = '10.0.3.0/24'
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
