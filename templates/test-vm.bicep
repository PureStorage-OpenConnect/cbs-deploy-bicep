/*
Deployment target scope
*/
targetScope = 'resourceGroup'

/*
Parameters
*/

@description('Location where resources will be deployed. Defaults to resource group location.')
param location string

@description('Subscription id where resources will be deployed.')
#disable-next-line no-unused-params
param subscriptionId string

@description('RG where the VM will be deployed.')
#disable-next-line no-unused-params
param resourceGroupName string

@description('The name of the VM')
param virtualMachineName string = ''

param whitelistedSourceAddress string = '*'

@description('The management IP of Cloud Block Store')
param PureManagementIP string

@description('The management User of Cloud Block Store')
param PureManagementUser string

@description('The management Password of Cloud Block Store')
@secure()
param PureManagementPassword string

@description('The virtual machine size.')
param virtualMachineSize string = 'Standard_D2s_v5'

@description('Specify the name of an existing VNet in the same resource group')
param vNetName string = ''

@description('Specify the name of the subnet')
param existingSubnetName string = ''

param adminUsername string
@secure()
param adminPassword string

param extensionFileUrl string

module variables 'modules/variables.bicep' = {
  name: 'scriptVariables'
  params: {}
}
var compiledVnetName = (vNetName != '')?vNetName:variables.outputs.vnetName

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: compiledVnetName
}

var compiledSubnetName = (existingSubnetName != '')?existingSubnetName:variables.outputs.subnetNameForISCSi

resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  parent: virtualNetwork
  name: compiledSubnetName
}

module testVmPublicIp 'modules/public-ip.bicep' = {
  name: 'testVmPublicIP'
  params: {
    name: variables.outputs.testVmPublicIpName
    location: location
    sku: 'Standard'
  }
}

resource testVmNsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'testVmNsg'
  location: location
  properties: {
    securityRules: [ {
        name: 'RDP'
        properties: {
          priority: 300
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: whitelistedSourceAddress
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}
resource networkInterface 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: 'testVmInterface'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vmSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: testVmPublicIp.outputs.id
          }
        }
      }
    ]
    enableAcceleratedNetworking: true
    networkSecurityGroup: {
      id: testVmNsg.id
    }
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: 'sql2019-ws2019'
        sku: 'Standard'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
  }
}

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: '${virtualMachineName}-CustomScriptExtension'
  location: location
  parent: virtualMachine
  properties: {
    provisionAfterExtensions: []
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    publisher: 'Microsoft.Compute'
    settings: {
      fileUris: split(extensionFileUrl, ' ')
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -Command "./setup-demo-cbs.ps1 -PureManagementIP ${PureManagementIP} -PureManagementUser ${PureManagementUser} -PureManagementPassword ${PureManagementPassword}; exit 0;"'
    }
  }
}


var diskConfigurationType = 'NEW'
var tempDbPath = 'T:\\SQLTemp'
var logPath = 'L:\\SQLLog'
var dataPath = 'S:\\SQLData'

var storageWorkloadType = 'General'

/*
resource sqlVirtualMachine 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2022-07-01-preview' = {
  dependsOn: [
    customScriptExtension
  ]
  name: virtualMachineName
  location: location
  properties: {
    virtualMachineResourceId: virtualMachine.id
    sqlManagement: 'Full'
    sqlServerLicenseType: 'PAYG'
    storageConfigurationSettings: {
      diskConfigurationType: diskConfigurationType
      storageWorkloadType: storageWorkloadType
      sqlDataSettings: {
        luns: [1]
        defaultFilePath: dataPath
      }
      sqlLogSettings: {
        luns: [2]
        defaultFilePath: logPath
      }
      sqlTempDbSettings: {
        luns: [3]
        defaultFilePath: tempDbPath
      }
    }
  }
}
*/

output vmIpAddress string = testVmPublicIp.outputs.ipAddress
output adminUsername string = adminUsername

#disable-next-line outputs-should-not-contain-secrets
output adminPassword string = adminPassword
