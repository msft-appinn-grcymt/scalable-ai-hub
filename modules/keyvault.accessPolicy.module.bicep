@description('Required. The KeyVault\'s name')
param keyVaultName string
@description('Required. Tenant Id of the assignee.')
param tenantId string
@description('Required. Object Id of the assignee.')
param objectId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: objectId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}

output keyVaultNameFromAccessPolicy string = keyVault.name
