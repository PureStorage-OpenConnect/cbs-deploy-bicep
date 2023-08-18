/*
Deployment target scope
*/
targetScope = 'resourceGroup'

/*
Parameters
*/

@description('Location where resources will be deployed. Defaults to resource group location.')
param location string

@description('RG where the VM will be deployed.')
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
param vNetName string

@description('Specify the resoruce group of the existing vNET')
param existingVnetResourceGroup string

@description('Specify the name of the subnet')
param existingSubnetName string


param adminUsername string
@secure()
param adminPassword string

module variables 'modules/variables.bicep' = {
  name: 'scriptVariables'
  params: {}
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vNetName
}

resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  parent: virtualNetwork
  name: variables.outputs.subnetNameForISCSi
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
        name: 'SSH'
        properties: {
          priority: 300
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: whitelistedSourceAddress
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
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
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
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
    }
  }
}
