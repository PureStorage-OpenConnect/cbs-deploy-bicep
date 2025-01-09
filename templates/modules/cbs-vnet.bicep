param vNetName string

param location string

param addressPrefixes array = ['10.0.0.0/16']

param subnetForSystemAddressPrefix string = '10.0.1.0/24'
param subnetForISCSiAddressPrefix string = '10.0.2.0/24'
param subnetForManagementAddressPrefix string = '10.0.3.0/24'
param subnetForReplicationAddressPrefix string = '10.0.4.0/24'

param natGtwName string
param natGtwSku string = 'Standard'


param natGtwPublicIpName string
param natGtwPublicIpSku string = 'Standard'


param subnetNameForSystem string
param subnetNameForISCSi string
param subnetNameForManagement string
param subnetNameForReplication string

module publicip './public-ip.bicep' = {
  name: natGtwPublicIpName
  params:{
    name: natGtwPublicIpName
    location: location
    sku: natGtwPublicIpSku
  }
}


resource natgateway 'Microsoft.Network/natGateways@2021-05-01' = {
  name: natGtwName
  location: location
  sku: {
    name: natGtwSku
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: publicip.outputs.id
      }
    ]
  }
}


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
      {
        name: subnetNameForSystem
        properties: {
          addressPrefix: subnetForSystemAddressPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.Storage'
            }
          ]
          natGateway: {
            id: natgateway.id
          }
        }
      }
      {
        name: subnetNameForISCSi
        properties: {
          addressPrefix: subnetForISCSiAddressPrefix
        }
      }
      {
        name: subnetNameForManagement
        properties: {
          addressPrefix: subnetForManagementAddressPrefix
        }
      }
      {
        name: subnetNameForReplication
        properties: {
          addressPrefix: subnetForReplicationAddressPrefix
        }
      }
    ]
  }
}


output virtualNetworkId string = virtualNetwork.id
output virtualNetworkName string = virtualNetwork.name
