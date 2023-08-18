targetScope = 'resourceGroup'

@description('Array of actions for the roleDefinition')
param actions array

@description('Array of notActions for the roleDefinition')
param notActions array = []

@description('Friendly name of the role definition')
param roleName string

@description('Detailed description of the role definition')
param roleDescription string

var roleDefName = guid(resourceGroup().id, string(actions), string(notActions))

resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' = {
  name: roleDefName
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'customRole'
    permissions: [
      {
        actions: actions
        notActions: notActions
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }
}


output id string = roleDef.id
