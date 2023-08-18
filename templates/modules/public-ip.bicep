param name string

param location string

param sku string


resource publicip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

output id string = publicip.id
output ipAddress string = publicip.properties.ipAddress
