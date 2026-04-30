// for more details see: https://learn.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses?pivots=deployment-language-bicep#property-values
param ipNamePrefix string = 'public-ip'
param vnetNamePrefix string = 'vnet'
param nsgNamePrefix string = 'nsg'
param nicNamePrefix string = 'nic'
param tags object

// static ip 
resource publicIPNextcloud 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  location: resourceGroup().location
  name: '${ipNamePrefix}-nextcloud'
  sku: {
    name: 'Standard'
  }
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

//NSG
resource nsgNextcloud 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  location: resourceGroup().location
  name: '${nsgNamePrefix}-nextcloud'
  tags: tags
  properties: {
    flushConnection: false
    securityRules: [
      {
        name: 'Allow-HTTPS-Internet'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-SSH-Internet'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 200
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '22' //TODO: port 22 for ssh should not be mixed with sourceAddress/port * 
        }
      }
      {
        name: 'Allow-HTTPS-Outbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 101
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '443'
            '80'
          ]
        }
      }
      {
        name: 'Allow-SMTP-Inbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 300
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '25'
            '587'
            '465'
          ]
        }
      }
      {
        name: 'Allow-SMTP-Outbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 301
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '25'
            '587'
            '465'
          ]
        }
      }
      {
        name: 'Allow-IMAP-Inbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 302
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '993'
          ]
        }
      }
    ]
  }
}

//vnet
resource virtualNetworkNextcloud 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  location: resourceGroup().location
  name: '${vnetNamePrefix}-nextcloud'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16' //we don't need so many ips, we could go for /28 even, but lets be generous for now
      ]
    }
    subnets: [
      {
        name: '${vnetNamePrefix}-subnet-nextcloud'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsgNextcloud.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
    ]
  }
}

//NIC
resource nicNextcloudVM 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  location: resourceGroup().location
  name: '${nicNamePrefix}-nextcloud'
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: '${nicNamePrefix}-ipconfig-nextcloud'
        properties: {
          publicIPAddress: {
            id: publicIPNextcloud.id
          }
          subnet: {
            id: virtualNetworkNextcloud.properties.subnets[0].id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgNextcloud.id
    }
  }
}

output nicNextcloudVMId string = nicNextcloudVM.id
output subnetNextcloudId string = virtualNetworkNextcloud.properties.subnets[0].id
output publicStaticIpNextcloudAddress string = publicIPNextcloud.properties.ipAddress
