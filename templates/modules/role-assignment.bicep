param UAIPrincipalId string

@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
param principalType string = 'ServicePrincipal'

param roleDefinitionId string

param vnetName string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing =  {
  name: vnetName
}


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, UAIPrincipalId, roleDefinitionId)
  properties: {
    principalId: UAIPrincipalId
    principalType: principalType
    roleDefinitionId: roleDefinitionId
  }
  scope: virtualNetwork
}

