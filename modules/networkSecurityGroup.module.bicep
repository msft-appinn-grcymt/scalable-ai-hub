param name string
param location string = resourceGroup().location
param tags object = {}
param allowHttpInbound bool = false
param allowHttpsInbound bool = false
param allowHttpsOutbound bool = false
param allowSsh bool = false
param azureLoadTesting bool = false
param applicationGateway bool = false
param apim bool = false

//Object with NSG security rules properties set if we configured enabling incoming http access
//Otherwise empty
var httpSecurityRule = allowHttpInbound ? [
  {
    name: 'AllowHTTPInbound'
    properties: {
      description: 'Allow inbound http traffic from everywhere'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 1000
      direction: 'Inbound'
    }
  } ] : []
//Object with NSG security rules properties set if we configured enabling incoming https access
//Otherwise empty
var httpsSecurityRule = allowHttpsInbound ? [
  {
    name: 'AllowHTTPSInbound'
    properties: {
      description: 'Allow inbound HTTPS traffic from everywhere'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  } ] : []
//Object with NSG security rules properties set if we configured enabling incoming ssh access
//Otherwise empty
var sshSecurityRule = allowSsh ? [
  {
    name: 'AllowSSHInbound'
    properties: {
      description: 'Allow inbound ssh from everywhere'
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '22'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 200
      direction: 'Inbound'
    }
  } ] : []
//Object with NSG security rules properties set if we configured enabling outgoing https access
//Otherwise empty      
var httpsOutboundSecurityRule = allowHttpsOutbound ? [
  {
    name: 'AllowHTTPSInbound'
    properties: {
      description: 'Allow outbound traffic for https ssh from everywhere'
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 500
      direction: 'Outbound'
    }
  } ] : []

//Object with NSG security rules properties set needed for Appligation Gateway
//Otherwise empty

var applicationGatewayRules = applicationGateway ? [
  {
    name: 'HealthProbes'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '65200-65535'
      sourceAddressPrefix: 'GatewayManager'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
  {
    name: 'Allow_TLS'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 110
      direction: 'Inbound'
    }
  }
  {
    name: 'Allow_HTTP'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 111
      direction: 'Inbound'
    }
  }
  {
    name: 'Allow_AzureLoadBalancer'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 120
      direction: 'Inbound'
    }
  }
] : []

//Object with NSG security rules properties set needed for load testing subnet per https://learn.microsoft.com/en-us/azure/load-testing/how-to-test-private-endpoint
//Otherwise empty
var loadTestingSecurityRules = azureLoadTesting ? [
  {
    name: 'batch-node-management-inbound'
    properties: {
      description: 'Create, update, and delete of Azure Load Testing compute instances.'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '29876-29877'
      sourceAddressPrefix: 'BatchNodeManagement'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
  {
    name: 'azure-load-testing-inbound'
    properties: {
      description: 'Create, update, and delete of Azure Load Testing compute instances.'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '8080'
      sourceAddressPrefix: 'AzureLoadTestingInstanceManagement'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 110
      direction: 'Inbound'
    }
  }
  {
    name: 'azure-load-testing-outbound'
    properties: {
      description: 'Used for various operations involved in orchestrating a load tests.'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 120
      direction: 'Outbound'
    }
  } ] : []


var apimRules = apim ? [
  { //External Vnet Only
    name: 'Client_communication_to_API_Management'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRanges: [
        '80'
        '443'
      ]
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
  {
    name: 'Management_endpoint_for_Azure_portal_and_Powershell'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3443'
      sourceAddressPrefix: 'ApiManagement'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 110
      direction: 'Inbound'
    }
  }
  { 
    name: 'Dependency_on_Azure_Storage'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'Storage'
      access: 'Allow'
      priority: 120
      direction: 'Outbound'
    }
  }
  { 
    name: 'Azure_Active_Directory_and_Azure_Key_Vault_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'AzureActiveDirectory'
      access: 'Allow'
      priority: 130
      direction: 'Outbound'
    }
  }
  {  
    name: 'Authorizations_dependency_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'AzureConnectors'
      access: 'Allow'
      priority: 140
      direction: 'Outbound'
    }
  }
  {  
    name: 'Access_to_Azure_SQL_Endpoints'
    properties: {
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '1433'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'Sql'
      access: 'Allow'
      priority: 150
      direction: 'Outbound'
    }
  }
  {  
    name: 'Access_To_Azure_Key_Vault'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'AzureKeyVault'
      access: 'Allow'
      priority: 160
      direction: 'Outbound'
    }
  }
  { 
    name: 'Dependency_For_Log_To_Azure_EventHubs_Policy_And_Azure_Monitor_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRanges: [
        '5671'
        '5672'
        '444'
      ]
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'EventHub'
      access: 'Allow'
      priority: 170
      direction: 'Outbound'
    }
  }
  { 
    name: 'Dependency_on_Azure_File_Share_for_GIT_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '445'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'Storage'
      access: 'Allow'
      priority: 180
      direction: 'Outbound'
    }
  }
  {
    name: 'Publish_Diagnostic_Logs_And_Metrics_And_Application_Insights_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRanges: [
        '1886'
        '443'
      ] 
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'AzureMonitor'
      access: 'Allow'
      priority: 190
      direction: 'Outbound'
    }
  }
  { 
    name: 'Access_External_Azure_Redis_Cache_Outbound_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 200
      direction: 'Outbound'
      destinationPortRange: '6380'
   }
  }
  { 
    name: 'Access_External_Azure_Redis_Cache_Inbound_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 200
      direction: 'Inbound'
      destinationPortRange: '6380'
   }
  }      
  { 
    name: 'Access_Internal_Azure_Redis_Cache_Outbound_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 210
      direction: 'Outbound'
      destinationPortRange: '6381-6383'
   }
  }
  { 
    name: 'Access_Internal_Azure_Redis_Cache_Inbound_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 210
      direction: 'Inbound'
      destinationPortRange: '6381-6383'
   }
  }      
  { 
    name: 'Sync_Counters_For_Rate_Limit_Policies_Outbound_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 220
      direction: 'Outbound'
      destinationPortRange: '4290'
   }
  } 
  { 
    name: 'Sync_Counters_For_Rate_Limit_Policies_Inbound_Optional'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 220
      direction: 'Inbound'
      destinationPortRange: '4290'
   }
  }       
  { 
    name: 'Azure_Infrastructure_Load_Balancer'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 230
      direction: 'Inbound'
      destinationPortRange: '6390'
   }
  }        
  {
    name: 'Allow_All_Internet_Outbound'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'Internet'
      access: 'Allow'
      priority: 999
      direction: 'Outbound'
    }
  }   
]  : []
//Combine all the objects to define the complete set of NSG rules and attach them to the resource
var securityRules = concat(httpSecurityRule, httpsSecurityRule, httpsOutboundSecurityRule, sshSecurityRule, applicationGatewayRules, loadTestingSecurityRules, apimRules)

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: name
  location: location
  properties: {
    securityRules: securityRules
  }
  tags: tags
}

output nsgId string = nsg.id
