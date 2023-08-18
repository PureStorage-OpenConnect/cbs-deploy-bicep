targetScope = 'resourceGroup'

param UAIName string
param location string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: UAIName
  location: location
}

output principalId string = identity.properties.principalId
output resourceId string = identity.id

