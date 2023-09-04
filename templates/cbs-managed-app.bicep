
/*
Deployment target scope
*/
targetScope = 'resourceGroup'


/*
Parameters
*/

@description('Location where resources will be deployed. Defaults to resource group location.')
param location string

@description('TODO: the managed application name')
param resourceName string

@description('Subscription id where resources will be deployed.')
#disable-next-line no-unused-params
param subscriptionId string

@description('RG where the managed app will be deployed.')
param resourceGroupName string

@description('RG where the managed resources will be deployed.')
param managedResourceGroupName string = ''

param tagsByResource object = {}

@description('TODO:Comma-separated, doesn\'t work!')
param alertRecipients string

@description('TODO: alphanumeric')
param arrayName string

@allowed(['V10MUR1', 'V20MUR1', 'V20MP2R2'])
param cbsModelSku string

@allowed([1,2,3])
@description('TODO: see documentation what AZs are available in the given region')
param availabilityZone int = 1

@description('''
Use `CBS-TRIAL-LICENSE` value for trial deployment
''')
param licenseKey string

param orgDomain string

@description('TODO:SSH public key for \'pureuser\' login in OpenSSH format')
param sshPublicKey string = ''

param managedUserIdentityId string

@description('''
Use this parameter when the vNET is not within the same resource group as CBS.
Resource group name, where the existing vNET is located. 
If empty, the RG of managed app (`resourceGroupName`) will be used.
''')
param vnetRGName string = ''

@description('''
Name for virtual network, used by CBS deployment.
''')
param vnetName string

@description('''
Name for `system` subnet, used by CBS deployment.
If empty, default naming convention will be used.
''')
param subnetNameForSystem string = ''

@description('''
Name for `iSCSI` subnet, used by CBS deployment.
If empty, default naming convention will be used.
''')
param subnetNameForISCSi string = ''

@description('''
Name for `management` subnet, used by CBS deployment.
If empty, default naming convention will be used.
''')
param subnetNameForManagement string = ''

@description('''
Name for `replication` subnet, used by CBS deployment.
If empty, default naming convention will be used.
''')
param subnetNameForReplication string = ''

@description('Optional input that denotes the identity of a Fusion Storage Endpoint Collection, obtained during Azure Portal GUI or CLI deployment')
param fusionSecIdentity object = {}

param azureMarketPlacePlanPublisher string = 'purestoragemarketplaceadmin'
param azureMarketPlacePlanVersion string = '1.0.1'
param azureMarketPlacePlanName string = 'cbs_azure_6_4_9'

param azureMarketPlacePlanOffer string = 'pure_storage_cloud_block_store_deployment'

module variables 'modules/variables.bicep' = {
  name: 'scriptVariables'
  params: {
  }
}

var compileVnetRGName = (vnetRGName != '')?vnetRGName:managedResourceGroupName
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  scope: resourceGroup(compileVnetRGName)
  name: vnetName
}

var managedRgName = (managedResourceGroupName != '')?managedResourceGroupName:variables.outputs.managedRgNameAutogenerated


var compileSubnetNameSystem = (subnetNameForSystem != '')?subnetNameForSystem:variables.outputs.subnetNameForSystem
var compileSubnetNameISCSi = (subnetNameForISCSi != '')?subnetNameForISCSi:variables.outputs.subnetNameForISCSi
var compileSubnetNameManagement = (subnetNameForManagement != '')?subnetNameForManagement:variables.outputs.subnetNameForManagement
var compileSubnetNameReplication = (subnetNameForReplication != '')?subnetNameForReplication:variables.outputs.subnetNameForReplication

var managedUserIdentity = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${managedUserIdentityId}': {}
  }
}


resource cbsManagedApp 'Microsoft.Solutions/applications@2021-07-01' =  {
  name: resourceName
  kind: 'MarketPlace'
  location: location
  plan:{
    name: azureMarketPlacePlanName
    product: azureMarketPlacePlanOffer
    publisher: azureMarketPlacePlanPublisher
    version: azureMarketPlacePlanVersion
  }
  identity: managedUserIdentity
  properties:{
    managedResourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', managedRgName)
    //TODO:
    jitAccessPolicy:{
      jitAccessEnabled: false
    }
    parameters:{
      tagsByResource: {
        value: tagsByResource
      }
      alertRecipients: {
        value: alertRecipients
      }
      arrayName: {
        value: arrayName
      }
      licenseKey: {
        value: licenseKey
      }
      location: {
        value: location
      }
      orgDomain: {
        value: orgDomain
      }
      pureuserPublicKey: {
        value: sshPublicKey
      }
      sku: {
        value: cbsModelSku
      }
      zone: {
        value: availabilityZone
      }

      managementResourceGroup: {
        value: resourceGroupName
      }
      managementVnet: {
        value: virtualNetwork.name
      }
      managementSubnet: {
        value: compileSubnetNameManagement
      }

      systemResourceGroup: {
        value: resourceGroupName
      }
      systemVnet: {
        value: virtualNetwork.name
      }

      systemSubnet: {
        value: compileSubnetNameSystem
      }

      iSCSIResourceGroup: {
        value: resourceGroupName
      }
      iSCSIVnet: {
        value: virtualNetwork.name
      }
      iSCSISubnet: {
        value: compileSubnetNameISCSi
      }
      
      replicationResourceGroup: {
        value: resourceGroupName
      }
      replicationVnet: {
        value: virtualNetwork.name
      }
      replicationSubnet: {
        value: compileSubnetNameReplication
      }

      //ignored mandatory attributes
      iscsiNewOrExisting: {
        value: 'existing'
      }
      managementNewOrExisting: {
        value: 'existing'
      }
      replicationNewOrExisting: {
        value: 'existing'
      }
      systemNewOrExisting: {
        value: 'existing'
      }
      keyVaultName: {
        value: ''
      }
      cosmosAccountName: {
        value: ''
      }
      initializeArray: {
        value: true
      }
      enableAcceleratedNetworking: {
        value: true
      }
      fusionSECIdentity: {
       value: fusionSecIdentity 
      }
    }
  }
}

/*
Outputs, used in subsequents steps of the deployment scripts
*/
output cbsmanagementLbIp string = cbsManagedApp.properties.outputs.floatingManagementIP.value
output cbsmanagementEndpointCT0 string = cbsManagedApp.properties.outputs.managementEndpointCT0.value
output cbsmanagementEndpointCT1 string = cbsManagedApp.properties.outputs.managementEndpointCT1.value

output cbsiSCSIEndpointCT0 string = cbsManagedApp.properties.outputs.iSCSIEndpointCT0.value
output cbsiSCSIEndpointCT1 string = cbsManagedApp.properties.outputs.iSCSIEndpointCT1.value

output cbsreplicationEndpointCT0 string = cbsManagedApp.properties.outputs.replicationEndpointCT0.value
output cbsreplicationEndpointCT1 string = cbsManagedApp.properties.outputs.replicationEndpointCT1.value
