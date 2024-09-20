/*
Deployment target scope
*/
targetScope = 'subscription'


/*
Parameters
*/

@description('Location where resources will be deployed. Defaults to resource group location.')
param location string

@description('Subscription id where resources will be deployed.')
#disable-next-line no-unused-params
param subscriptionId string

@description('RG where resources will be deployed.')
param resourceGroupName string

param subnetNameForSystem string = ''
param subnetNameForISCSi string = ''
param subnetNameForManagement string = ''
param subnetNameForReplication string = ''

module variables 'modules/variables.bicep' = {
  name: 'scriptVariables'
  params: {
  }
  scope: rgMain
}


var compileSubnetNameSystem = (subnetNameForSystem != '')?subnetNameForSystem:variables.outputs.subnetNameForSystem
var compileSubnetNameISCSi = (subnetNameForISCSi != '')?subnetNameForISCSi:variables.outputs.subnetNameForISCSi
var compileSubnetNameManagement = (subnetNameForManagement != '')?subnetNameForManagement:variables.outputs.subnetNameForManagement
var compileSubnetNameReplication = (subnetNameForReplication != '')?subnetNameForReplication:variables.outputs.subnetNameForReplication


/*
Resource Group - where all the resources will be deployed
*/
resource rgMain 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module arrayVnet 'modules/cbs-vnet.bicep' = {
  name: 'arrayVnetDeploy'
  params: {
    location: location
    vNetName: variables.outputs.vnetName
    natGtwName: variables.outputs.natGtwName
    natGtwPublicIpName: variables.outputs.natGtwPublicIpName
    subnetNameForSystem: compileSubnetNameSystem
    subnetNameForISCSi: compileSubnetNameISCSi
    subnetNameForManagement: compileSubnetNameManagement
    subnetNameForReplication: compileSubnetNameReplication
  }
  scope: rgMain
}



module vnetMngmtCustomRbacRole 'modules/custom-role.bicep' = {
  name: 'vnetMngmtCustomRbacRoleDeploy'
  params: {
    actions: [
      'Microsoft.Network/virtualNetworks/subnets/joinViaServiceEndpoint/action', 'Microsoft.Network/virtualNetworks/subnets/join/action'
    ]
    roleName: variables.outputs.vnetMngmtCustomRbacRoleName
    roleDescription: 'Used for deployment of Pure CBS into vNET'
  }
  scope: rgMain
}


module vnetMngmtUserManagedIdentity 'modules/user-managed-identity.bicep' = {
  name: 'VnetMngmtUserManagedIdentityDeploy'
  params: {
    location: location
    UAIName: variables.outputs.vnetMngmtUserManagedIdentity
  }
  scope: rgMain
}


module vnetMngmtCustomRbacRoleAssignment 'modules/role-assignment.bicep' = {
  name: 'vnetMngmtCustomRbacRoleAssignmentDeploy'
  params: {
    roleDefinitionId: vnetMngmtCustomRbacRole.outputs.id
    UAIPrincipalId: vnetMngmtUserManagedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
    vnetName: arrayVnet.outputs.virtualNetworkName
  }
  scope: rgMain
  dependsOn:[
    arrayVnet
  ]
}

/*
Outputs, used in subsequents steps of the deployment scripts
*/
output mainRgName string = resourceGroupName
output subscriptionId string = subscription().subscriptionId
output arrayVnetId string = arrayVnet.outputs.virtualNetworkId
output arrayVnetName string = arrayVnet.outputs.virtualNetworkName

output vnetMngmtUserManagedIdentityId string = vnetMngmtUserManagedIdentity.outputs.resourceId
