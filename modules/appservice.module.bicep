param name string
param location string = resourceGroup().location
param tags object = {}
@description('OS and runtime of the backend app service')
@allowed([
  'linux*DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
  'windows*dotnet|v6.0'
  'windows*dotnet|v7.0'
  'windows*dotnet|v8.0'
  'linux*dotnetcore|6.0'
  'linux*dotnetcore|7.0'
  'linux*dotnetcore|8.0'
  'windows*java|1.8'
  'windows*java|11'
  'windows*java|17'
  'linux*java|8'
  'linux*java|11'
  'linux*java|17'
  'windows*node|~18'
  'windows*node|~20'
  'linux*node|18-lts'
  'linux*node|20-lts'
  'linux*php|8.2'
  'linux*python|3.8'
  'linux*python|3.9'
  'linux*python|3.10'
  'linux*python|3.11'
  'linux*python|3.12'
])
param runtimeSpec string 
param skuFamily string = 'Pv3'
param skuName string = 'P1v3'
param skuTier string = 'PremiumV3'
param subnetIdForIntegration string = ''
param appInsConnectionString string = ''
param privateDnsZoneId string = ''
param privateEndpointSubnet string
param noOfWorkers int = 3
@description('Optional. Whether to create a managed identity for the web app -defaults to \'false\'')
param systemAssignedIdentity bool = true
param userAssignedIdentityId string = ''
param appSettings array = []

var linux = split(runtimeSpec, '*')[0] == 'linux' ? true : false
var runtime = split(runtimeSpec, '*')[1]
var runtimeLanguage = split(runtime,'|')[0]
var runtimeVersion = split(runtimeSpec, '|')[1]

// Set additional configuration based on the underlying OS
// For docker, set to default basic image -- will be overwritten by deployments 

// runtime specific config per OS and language
var siteConfigAddin = runtimeLanguage=='DOCKER' ? {
  //Container
    linuxFxVersion: runtime
    vnetImagePullEnabled: true
  // Java
  } : runtimeLanguage == 'java' && linux ? runtimeVersion != '8'? {
            linuxFxVersion: '${runtime}-${runtimeLanguage}${runtimeVersion}'
            javaVersion: runtimeVersion
      } : {
            linuxFxVersion: '${runtime}-jre8'
            javaVersion: runtimeVersion
      } 
   : runtimeLanguage == 'java' && (!linux) ? {
      javaVersion: runtimeVersion
      javaContainer: 'JAVA'
      javaContainerVersion: 'SE'
      metadata :[
         {
           name:'CURRENT_STACK'
           value:'${runtime}-${runtimeLanguage}${runtimeVersion}'
         }
       ]
  } // Dotnet
     : contains(runtimeLanguage, 'dotnet') && (!linux) ? {
        netFrameworkVersion: runtimeVersion
        use32bitWorkerProcess: false
        metadata :[
          {
            name:'CURRENT_STACK'
            value:'dotnet'
          }
        ]
   } : contains(runtimeLanguage, 'dotnet') && linux ? {
        linuxFxVersion: runtime
        use32bitWorkerProcess: false
   }  // Node on Windows
   : runtimeLanguage == 'node' && (!linux) ? {
        metadata :[
          {
            name:'CURRENT_STACK'
            value:'${runtimeLanguage}${runtimeVersion}'
          }
        ]
   } // All rest using linux (php,python,node)
      : {
        linuxFxVersion: runtime
   }

// App Settings specific for the runtime and OS

var runtimeAppSettings = runtimeLanguage == 'node' && (!linux) ? [{
  name: 'WEBSITE_NODE_DEFAULT_VERSION'
  value: runtimeVersion
}] : []  

// App service Identity config (system assigned or user assigned)

var identityType = systemAssignedIdentity ? (!empty(userAssignedIdentityId) ? 'SystemAssigned, UserAssigned' : 'SystemAssigned') : (!empty(userAssignedIdentityId) ? 'UserAssigned' : 'None')
var identity = identityType != 'None' ? {
  type: identityType
  userAssignedIdentities: empty(userAssignedIdentityId) ? null : {
    '${userAssignedIdentityId}': {}
  }
} : null


//Create the parent resource - App Service plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'asp-${name}'
  location: location
  tags: tags
  sku: {
    tier: skuTier
    name: skuName
    size: skuTier
    family: skuFamily
  }
  kind: linux ? 'linux' : ''
  properties: {
    reserved: linux ? true : false
    targetWorkerCount: noOfWorkers
  }
}

//App Service
resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  tags: tags
  // kind: linux ? 'linux' : ''
  identity: identity
  properties: {
    serverFarmId: appServicePlan.id
    keyVaultReferenceIdentity: !empty(userAssignedIdentityId) ? userAssignedIdentityId : null
    //Configure the needed properties
    siteConfig: union(
      {
      appSettings: concat([
        {
          name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
          value: 'disabled' 
        }
        {
          name: 'APPINSIGHTS_SNAPSHOTFEATURE_VERSION'
          value: 'disabled' 
        }      
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsConnectionString
        } 
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }  
        {
          name: 'DiagnosticServices_EXTENSION_VERSION'
          value: 'disabled'
        }   
        {
          name: 'InstrumentationEngine_EXTENSION_VERSION'
          value: 'disabled'
        }      
        {
          name: 'SnapshotDebugger_EXTENSION_VERSION'
          value: 'disabled'
        }  
        {
          name: 'WEBSITE_CRASHMONITORING_ENABLED'
          value: 'True'
        }   
        {
          name: 'WEBSITE_CRASHMONITORING_SETTINGS'
          value: '{"StartTimeUtc":"2022-02-28T13:16:00.000Z","MaxHours":24,"MaxDumpCount":3,"ExceptionFilter":"-f E053534F -f C00000FD.STACK_OVERFLOW"}'
        }  
        {
          name: 'WEBSITE_CRASHMONITORING_USE_DEBUGDIAG'
          value: 'True'
        }    
        {
          name: 'WEBSITE_HEALTHCHECK_MAXPINGFAILURES'
          value: '10'
        }      
        {
          name: 'WEBSITE_HTTPLOGGING_RETENTION_DAYS'
          value: '10'
        }                
        {
          name: 'XDT_MicrosoftApplicationInsights_BaseExtensions'
          value: 'disabled'
        }  
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'default'
        }                                                                                                                
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }      
      ], appSettings,runtimeAppSettings) 
      },
      siteConfigAddin,
      {
        vNetRooteAllEnabled: true 
      }
      )
    httpsOnly: true
    reserved: linux
    virtualNetworkSubnetId: subnetIdForIntegration //Attach to the respective subnet
  }
}

//create the private endpoints and dns zone groups
module privateendpoointapp './privateEndpoint.module.bicep' = {
  name: 'pep-${name}'
  params:{
    name: 'pep-${name}'
    location: location
    privateDnsZoneId: privateDnsZoneId
    privateLinkServiceId: appService.id
    subResource: 'sites'
    subnetId: privateEndpointSubnet
    tags: tags
  }
}

output id string = appService.id
output name string = appService.name
output appServicePlanId string = appServicePlan.id
output appServicePlanName string = appServicePlan.name
output identity object = systemAssignedIdentity ? {
  tenantId: appService.identity.tenantId
  principalId: appService.identity.principalId
  type: appService.identity.type
} : {}
output appServiceFqdn string ='${appService.name}.azurewebsites.net'

// output linux bool = linux
// output runtime string = runtime
// output runtimeLanguage string = runtimeLanguage 
// output runtimeVersion string = runtimeVersion
// output siteConfigAddin object = siteConfigAddin
