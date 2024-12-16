param name string
param location string = resourceGroup().location
param tags object = {}

@description('The capacity of this API Management service -0 will be used for \'Consumption\' sku.')
@minValue(1)
@maxValue(4)
param skuCapacity int = 1

@description('The pricing tier of this API Management service')
@allowed([
  'Developer'
  'Standard'
  'Premium'
  'Consumption'
])
param skuName string

@description('If provided then the identity type will be set to UserAssigned. If passed empty then the identity type will be set to SystemAssigned')
param userAssignedIdentityId string?

param publisherEmail string = 'system@gsis.gr'
param publisherName string = 'system'

@description('The subnet id of the subnet to deploy the API Management service to.')
param apimSubnetId string
param virtualNetworkType string = 'Internal'
param apimDnsZoneName string
param aiProducts array 
param keyVaultName string
param aiBackends array
param appInsightsConnectionStringReference string
param appInsightsId string
param appInsightsName string
// used for role assingments
param openAIDeployments array
param openAIResourceName string

var identityType = empty(userAssignedIdentityId) ? 'SystemAssigned' : 'UserAssigned'
var identity =  {
  type: identityType
  userAssignedIdentities: empty(userAssignedIdentityId) ? null : {
    '${userAssignedIdentityId}': {}
  }
}

// MARK: Public IP
resource apimPublicIp 'Microsoft.Network/publicIPAddresses@2019-12-01' = {
  name: 'pip-${name}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower(name)
    }
  }
}

//MARK: APIM

resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    capacity: skuName == 'Consumption' ? 0 : skuCapacity
    name: skuName
  }
  identity: identity
  properties: {
    virtualNetworkType: virtualNetworkType
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    publicIpAddressId: apimPublicIp.id
    publisherEmail: publisherEmail
    publisherName: publisherName  
  }
}


//MARK: DNS Records

var apimSubdomains = [
  '${name}'
  '${name}.developer'
  '${name}.portal'
  '${name}.management'
  '${name}.scm'
]

resource aRecords 'Microsoft.Network/privateDnsZones/A@2020-06-01' = [for subdomain in apimSubdomains: {
  name: '${apimDnsZoneName}/${subdomain}'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: apiManagement.properties.privateIPAddresses[0]
      }
    ]
  }
}]

//MARK: Named Values

//Named values for "T-shirt sizing" of OpenAI token limits
resource tokenLimitsNamedValues 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = [ for aiProduct in aiProducts : {
  name: '${replace(aiProduct.name,' ','')}TPMLimit'
  parent: apiManagement
  properties: {
    displayName: '${replace(aiProduct.name,' ','')}TPMLimit'
    value: aiProduct.TPMThreshold
  }
}]


//MARK: Secret Named Values

////AI Backends Access Keys from Key Vault

// Provide access to KeyVault

module apimKVGetSecretsAccess 'keyvault.accessPolicy.module.bicep' = {
  name: '${name}-KVAccess'
  params: {
    keyVaultName: keyVaultName
    tenantId: apiManagement.identity.tenantId
    objectId: apiManagement.identity.principalId
  }
}

// Insert the Key Vault references to the AI Backends as named values

resource secretNamedValues 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = [ for aiBackend in aiBackends : {
  name: aiBackend.name
  parent: apiManagement
  // Access is granted first
  dependsOn: [
    apimKVGetSecretsAccess
  ]
  properties: {
    displayName: '${aiBackend.name}-Key1'
    keyVault: {
      secretIdentifier: aiBackend.keyReferenceUri
    }
    secret: true
  }
}]

// insert the Application Insights connection string as a named value

resource appInsightsSecretNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  name: 'LoggerConnectionString'
  parent: apiManagement
  // Access is granted first
  dependsOn: [
    apimKVGetSecretsAccess
  ]
  properties: {
    displayName: 'LoggerConnectionString'
    keyVault: {
      secretIdentifier: appInsightsConnectionStringReference
    }
    secret: true
  }
}

//MARK: Backends

// Create the AI Backends

resource backends 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = [ for (aiBackend,i) in aiBackends : {
  name: aiBackend.name
  parent: apiManagement
  properties: {
    title: aiBackend.name
    description: aiBackend.description
    url: aiBackend.endpoint
    protocol: 'http'
    credentials: aiBackend.name == 'LanguageEndpoint' ? {
      header: {
         'Ocp-Apim-Subscription-Key' : [
          '{{${secretNamedValues[2].name}}}'
           ]
         }
    } : null   
    type: 'Single'
    // Add the circuit breaker for the primary endpoint
    circuitBreaker: aiBackend.name != 'LanguageEndpoint' ? {
      rules: [{
        name: 'openAIBreakerRule'
        failureCondition: {
          count: 1
          interval: 'PT1M'
          statusCodeRanges: [ {
            min: 429
            max: 429
          }]
          errorReasons: ['Server errors']
        }
        tripDuration: 'PT1M'
        acceptRetryAfter: true
      }]
    } : null
  }
}]


// Add the Back End Pool for Load Balancing/Failover

resource aoiBackendPool 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  name: 'openAIBackendPool'
  parent: apiManagement
  properties: {
    description: 'Load balancer for multiple backends'
    title: 'openAIBackendPool'
    type: 'Pool'
    pool: {
      services: [
        {
          // Primary Backend
          id: backends[0].id
          priority: 1
          // weight: 80
        }
        {
          // Secondary Backend
          id: backends[1].id
          priority: 2
          // weight: 10
        }
      ]
    }
  }
}


//MARK: Products
// Create the Products

resource products 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = [ for aiProduct in aiProducts :{
  name: toLower('${replace(aiProduct.name,' ','')}aiworkloads')
  parent: apiManagement
  properties: {
    description: '${aiProduct.name} sized AI Workloads'
    displayName: '${replace(aiProduct.name,' ','')}AIWorkloads'
    subscriptionRequired: true
    state: 'published'
  }
}]

// Add the product policies for TPM throttling thresholds
var throttlingPolicy = loadTextContent('../policies/throttling.xml')
var policyProductPlaceholder = '**ProductName**'

resource productPolicies 'Microsoft.ApiManagement/service/products/policies@2023-09-01-preview' = [ for (aiProduct,i) in aiProducts : {
  name: 'policy'
  parent: products[i]
  properties: {
    format: 'rawxml'
    value: replace(throttlingPolicy,policyProductPlaceholder,toLower(replace(aiProduct.name,' ','')))
  }
}]


//MARK: OpenAI API

// OpenAI API definition

var openAIAPISpec = loadJsonContent('../schemas/openai.swagger.json')
// var openAIAPISpec = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json'

resource openAIApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  name: 'azure-openai-service-api'
  parent: apiManagement
   properties: {
    displayName: 'Azure OpenAI Service API'
    description: 'Azure OpenAI APIs for completions and search'
    subscriptionRequired: true
    path: 'openai'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    apiType: 'http'
    format: 'openapi+json'
    value: openAIAPISpec
   }
}

// Assign all AI products to the OpenAI API

resource openAIProducs 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = [ for (aiProduct,i) in aiProducts : {
  name: openAIApi.name
  parent: products[i]
}]

//MARK: OpenAI API Policies

// Add the API policies for Spillover/Failover and emmit metrics
var openAIPolicy = loadTextContent('../policies/openAIPolicy.xml')
var openAIPolicyBackendPoolPlaceholder = '****OPENAI_BACKEND_POOL*****'


resource openAIApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  name: 'policy'
  parent: openAIApi
  properties: {
    value: replace(openAIPolicy,openAIPolicyBackendPoolPlaceholder,aoiBackendPool.name)
    format: 'rawxml'
  }}


// MARK: Language API (PII Detection)

resource languageAPI 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  name: 'language-api'
  parent: apiManagement
   properties: {
    displayName: 'PII Detection'
    description: 'PII Detection'
    subscriptionRequired: true
    path: 'language'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
   }
}

resource piiDetect 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  name: 'piiDetect'
  parent: languageAPI
  properties: {
    displayName: 'Detect'
    method: 'POST'
    urlTemplate: '/:analyze-text?api-version=2022-05-01'
    templateParameters: []
    description: 'Creates a completion for the provided prompt, parameters and chosen model.'
    responses: []
  }
}

//MARK: Language API Policies

// Add the API policies for Spillover/Failover and emmit metrics
var languagePolicy = loadTextContent('../policies/languagePolicy.xml')
var languagePolicyBackendPoolPlaceholder = '****LANGUAGE_BACKEND_POOL*****'

resource languageApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  name: 'policy'
  parent: languageAPI
  properties: {
    value: replace(languagePolicy,languagePolicyBackendPoolPlaceholder,backends[2].name)
    format: 'rawxml'
  }}

//MARK: APIM Logger (for emmiting metrics)

resource aiLogger 'Microsoft.ApiManagement/service/loggers@2023-09-01-preview' = {
  name: 'apimLogger'
  parent: apiManagement
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger with system-assigned managed identity'
    credentials: {
      connectionString: '{{${appInsightsSecretNamedValue.name}}}'
      identityClientId: 'systemAssigned'
    }
    resourceId: appInsightsId
    isBuffered: false
  }
}


//MARK: OpenAI Diagnostics

resource openAIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2023-09-01-preview' = {
  name: 'applicationinsights'
  parent: openAIApi
  properties: {
    alwaysLog: 'allErrors'
    logClientIp: true
    metrics: true
    httpCorrelationProtocol: 'W3C'
    loggerId: aiLogger.id
    verbosity: 'information'
    sampling: { 
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: []
        body: {
         bytes: 0
      }
    }
    response: {
      headers: []
      body: {
        bytes: 0
      }
    }
  }
  backend: {
    request: {
      headers: []
      body: {
        bytes: 0
      }
    }
  }
 }
}

//MARK: Role assignemnts

// Cognitive Services OpenAI User on all OpenAI services to APIM system managed identity

resource openAICreated 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = [ for (openAI,i) in openAIDeployments : {
  name: '${openAIResourceName}-${i}'
}]


var roleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for (openAI,i) in openAIDeployments : {
    scope: openAICreated[i]
    name: guid(subscription().id, resourceGroup().id, openAICreated[i].name, roleDefinitionID)
    properties: {
        roleDefinitionId: roleDefinitionID
        principalId: apiManagement.identity.principalId
        principalType: 'ServicePrincipal'
    }
}]

// Monitoring Metrics Publisher Role to APIM system managed identity
// used for APIM logger to connect to Application Insights with Connection string and System Assigned Identity

resource appInsightsCreated 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

var monitoringRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')

resource monitoringRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    scope: appInsightsCreated
    name: guid(subscription().id, resourceGroup().id, appInsightsName, monitoringRoleDefinitionID)
    properties: {
        roleDefinitionId: monitoringRoleDefinitionID
        principalId: apiManagement.identity.principalId
        principalType: 'ServicePrincipal'
    }
}


output id string = apiManagement.id
output name string = apiManagement.name
output gatewayUrl string = apiManagement.properties.gatewayUrl
output identity object = identity == 'SystemAssigned' ? {
  tenantId: apiManagement.identity.tenantId
  principalId: apiManagement.identity.principalId
  type: apiManagement.identity.type
} : {}
output privateIPAddresses array = apiManagement.properties.privateIPAddresses
output policyDbg array = [ for (aiProduct,i) in aiProducts : replace(throttlingPolicy,policyProductPlaceholder,toLower(replace(aiProduct.name,' ','')))]
output products array = [ for (aiProduct,i) in aiProducts : products[i].name]


///// MANUAL ENTRY OF OPENAI API SCHEMA (ONLY FOR REFERENCE)

// // schema for Chat Completions Response
// var chatCompletionsResponseSchema = loadJsonContent('../schemas/chatCompletionsPost200response.json')
// // schema for Chat Completions Request
// var chatCompletionsRequestSchema = loadJsonContent('../schemas/chatCompletionsRequest.json')
// // schema for prompt completions deployment id
// var promptCompletionsDeploymentId = loadJsonContent('../schemas/promptCompletionsDeploymentId.json')
// // schema for prompt completions api-version
// var promptCompletionsApiVersion = loadJsonContent('../schemas/promptCompletionsApiVersion.json')
// // schema for Chat Prompt Completions
// var chatPromptCompletionsRequestchema = loadJsonContent('../schemas/chatPromptCompletionsRequest.json')
// // schema for Chat Prompt Completion Response
// var chatPromptCompletionResponse = loadJsonContent('../schemas/chatPromptCompletionPost200Response.json')
// // schema for Chat Prompt Completion Error Response
// var chatPromptCompletionErrorResponse = loadJsonContent('../schemas/chatPromptCompletionsErrorResponse.json')
// // schema for Chat Prompt Completions Apim Request Id
// var chatPromptCompletionsApimRequestId = loadJsonContent('../schemas/chatPromptCompletionsApimRequestId.json')
// // schema for Chat Prompt Completions Error Apim Request Id
// var chatPromptCompletionsErrorApimRequestId = loadJsonContent('../schemas/chatPromptCompletionErrorApimRequestId.json')
// // schema for Embeddings Create deployment id
// var embeddingsCreateDeploymentId = loadJsonContent('../schemas/embeddingsCreateDeploymentId.json')
// // schema for Embeddings Create api-version
// var embeddingsCreateApiVersion = loadJsonContent('../schemas/embeddingsCreateApiVersion.json')
// // schema for Embeddings Create Request
// var embeddingsCreateRequest = loadJsonContent('../schemas/embeddingsCreateRequest.json')

// resource openaiSchema 'Microsoft.ApiManagement/service/apis/schemas@2023-09-01-preview' = {
//   name: 'openai-schema'
//   parent: openAIApi
//   properties: {
//     contentType: 'application/vnd.oai.openapi.components+json'
//     document: {
//       components: {
//         schemas: {
//           ChatCompletionsPost200ApplicationJsonResponse: chatCompletionsResponseSchema
//           ChatCompletionsPostRequest: chatCompletionsRequestSchema
//           promptCompletionsDeploymentId: promptCompletionsDeploymentId
//           promptCompletionsApiVersion: promptCompletionsApiVersion
//           chatPromptCompletionsRequestchema: chatPromptCompletionsRequestchema
//           chatPromptCompletionResponse: chatPromptCompletionResponse
//           embeddingsCreateDeploymentId: embeddingsCreateDeploymentId
//           embeddingsCreateApiVersion: embeddingsCreateApiVersion
//           chatPromptCompletionsApimRequestId: chatPromptCompletionsApimRequestId
//           chatPromptCompletionErrorResponse: chatPromptCompletionErrorResponse
//           chatPromptCompletionsErrorApimRequestId: chatPromptCompletionsErrorApimRequestId
//           embeddingsCreateRequest: embeddingsCreateRequest
//         }
//       }
//     }
//   }
// }


// // Chat Completions

// resource oaiChatCompletions 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
//   name: 'oaiChatCompletions'
//   parent: openAIApi
//   properties: {
//     displayName: 'Creates a completion for the chat message'
//     method: 'POST'
//     urlTemplate: '/deployments/{deployment-id}/chat/completions?api-version={api-version}'
//     templateParameters: [
//       {
//         name: 'deployment-id'
//         type: 'string'
//         required: true
//         description: 'The deployment id of the model'
//       }
//       {
//         name: 'api-version'
//         type: 'string'
//         required: true
//         description: 'The version of the API'
//       }
//     ]
//     description: 'Creates a completion for the chat message'
//     request: {
//       queryParameters: []
//       headers: []
//       representations: [
//         {
//           contentType: 'application/json'
//           examples: {
//             default: {
//               value: {
//                 model: 'gpt-3.5-turbo'
//                 messages: [
//                   {
//                     role: 'user'
//                     content: 'Hello!'
//                   }
//                 ]
//               }
//             }
//           }
//           schemaId: openaiSchema.name
//           typeName: 'ChatCompletionsPostRequest'
//         }
//       ]
//     }
//     responses: [
//       {
//         statusCode: 200
//         description: 'OK'
//         headers: []
//         representations: [
//           {
//             contentType: 'application/json'
//             examples: {
//               default: {
//                 value: {
//                   id: 'chatcmpl-123'
//                   object: 'chat.completion'
//                   created: 1631533200
//                   choices: [
//                     {
//                       index: 0
//                       message: {
//                         role: 'assistant'
//                         content: '\n\nHello there, how may I assist you today?'
//                       }
//                       finishReason: 'stop'
//                     }
//                   ]
//                   usage: {
//                     prompt_tokens: 9
//                     completion_tokens: 12
//                     total_tokens: 21
//                   }
//                 }
//               }
//             }
//             schemaId: openaiSchema.name
//             typeName: 'ChatCompletionsPost200ApplicationJsonResponse'
//           }
//         ]
//       }
//     ]
//   }
// }

// // Chat Promt Completions

// resource oaiChatPromptCompletions 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
//   name: 'oaiChatPromptCompletions'
//   parent: openAIApi
//   properties: {
//     displayName: 'Creates a completion for the provided prompt, parameters and chosen model'
//     method: 'POST'
//     urlTemplate: '/deployments/{deployment-id}/completions?api-version={api-version}'
//     templateParameters: [
//       {
//         name: 'deployment-id'
//         type: 'string'
//         required: true
//         description: 'The deployment id of the model'
//         schemaId: openaiSchema.name
//         typeName: 'promptCompletionsDeploymentId'
//       }
//       {
//         name: 'api-version'
//         type: 'string'
//         required: true
//         description: 'The version of the API'
//         schemaId: openaiSchema.name
//         typeName: 'promptCompletionsApiVersion'
//       }
//     ]
//     description: 'Creates a completion for the provided prompt, parameters and chosen model.'
//     request: {
//       queryParameters: []
//       headers: []
//       representations: [
//         {
//           contentType: 'application/json'
//           examples: {
//             default: {
//               value: {
//                 prompt: 'Negate the following sentence.The price for bubblegum increased on thursday.\n\n Negated Sentence:'
//                 max_tokens: 50
//               }
//             }
//           }
//           schemaId: openaiSchema.name
//           typeName: 'chatPromptCompletionsRequestchema'
//         }
//       ]
//     }
//     responses: [
//       {
//         statusCode: 200
//         description: 'OK'
//         headers: [
//           {
//             name: 'apim-request-id'
//             description: 'Request ID for troubleshooting purposes'
//             type: 'string'
//             values: []
//             schemaId: openaiSchema.name
//             typeName: 'chatPromptCompletionsApimRequestId'
//           }
//         ]
//         representations: [
//           {
//             contentType: 'application/json'
//             examples: {
//               default: {
//                 value: {
//                   model: 'davinci'
//                   object: 'text_completion'
//                   id: 'cmpl-4509KAos68kxOqpE2uYGw81j6m7uo'
//                   created: 1637097562
//                   choices: [
//                     {
//                       index: 0
//                       text: 'The price for bubblegum decreased on thursday.'
//                       logprobs: null
//                       finishReason: 'stop'
//                     }
//                   ]
//                 }
//               }
//             }
//             schemaId: openaiSchema.name
//             typeName: 'chatPromptCompletionResponse'
//           }
//         ]
//       }
//       {
//         statusCode: 400
//         description: 'Service unavailable'
//         headers: [
//           {
//           name: 'apim-request-id'
//           description: 'Request ID for troubleshooting purposes'
//           type: 'string'
//           values: []
//           schemaId: openaiSchema.name
//           typeName: 'chatPromptCompletionsErrorApimRequestId'
//           }
//         ]
//         representations: [
//           {
//             contentType: 'application/json'
//             examples: {
//               default: {
//                 value: {
//                   error: {
//                     code: 'string'
//                     message: 'string'
//                     param: 'string'
//                     type: 'string'
//                   }
//                 }
//               }
//             }
//             schemaId: openaiSchema.name
//             typeName: 'chatPromptCompletionErrorResponse'  
//           }        
//         ]
//       }
//       {
//         statusCode: 500
//         description: 'Service unavailable'
//         headers: [
//           {
//           name: 'apim-request-id'
//           description: 'Request ID for troubleshooting purposes'
//           type: 'string'
//           values: []
//           schemaId: openaiSchema.name
//           typeName: 'chatPromptCompletionsErrorApimRequestId'
//           }
//         ]
//         representations: [
//           {
//             contentType: 'application/json'
//             examples: {
//               default: {
//                 value: {
//                   error: {
//                     code: 'string'
//                     message: 'string'
//                     param: 'string'
//                     type: 'string'
//                   }
//                 }
//               }
//             }
//             schemaId: openaiSchema.name
//             typeName: 'chatPromptCompletionErrorResponse'  
//           }        
//         ]
//       }
//     ]
//   }
// }

// // Embeddings create

// resource oaiEmbeddingsCreate 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
//   name: 'oaiEmbeddingsCreate'
//   parent: openAIApi
//   properties: {
//     displayName: 'Get a vector representation of a given input that can be easily consumed by machine learning models and algorithms.'
//     method: 'POST'
//     urlTemplate: '/deployments/{deployment-id}/embeddings?api-version={api-version}'
//     templateParameters: [
//       {
//         name: 'deployment-id'
//         type: 'string'
//         required: true
//         description: 'The deployment id of the model which was deployed'
//         schemaId: openaiSchema.name
//         typeName: 'embeddingsCreateDeploymentId'
//       }
//       {
//         name: 'api-version'
//         type: 'string'
//         required: true
//         description: 'The version of the API'
//         schemaId: openaiSchema.name
//         typeName: 'embeddingsCreateApiVersion'
//       }
//     ]
//     description: 'Creates a completion for the provided prompt, parameters and chosen model.'
//     request: {
//       queryParameters: []
//       headers: []
//       representations: [
//         {
//           contentType: 'application/json'
//           examples: {
//             default: {
//               value: {
//                 input: {}
//                 user: 'string'
//                 input_type: 'query'
//                 model: 'string'
//               }
//             }
//           }
//           schemaId: openaiSchema.name
//           typeName: 'embeddingsCreateRequest'
//         }
//       ]
//     }
//     responses: [
//       {
//         statusCode: 200
//         description: 'OK'
//         headers: []
//         representations: [
//           {
//             contentType: 'application/json'
//             examples: {
//               default: {
//                 value: {
//                   model: 'string'
//                   object: 'string'
//                   data: [
//                     {
//                       index: 0
//                       object: 'string'
//                       embedding: [
//                         0
//                       ]
//                     }
//                   ]
//                   usage: {
//                     prompt_tokens: 0
//                     total_tokens: 0
//                   }
//                 }
//               }
//             }
//             schemaId: openaiSchema.name
//             typeName: 'chatPromptCompletionResponse'
//           }
//         ]
//       }
//     ]
//   }
// }

