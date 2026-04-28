param nicNextcloudVMId string
param namePrefix string = 'vm'
param adminUsername string = '${namePrefix}-admin-nextcloud'
param sshKeyData string
param tags object

resource diskNextcloud 'Microsoft.Compute/disks@2025-01-02' = {
  location: resourceGroup().location
  name: '${namePrefix}-disk-nextcloud'
  tags: tags
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 128
    tier: 'E10'
  }
  sku: {
    name: 'StandardSSD_LRS'
  }
}

resource vmnextcloud 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  location: resourceGroup().location
  name: '${namePrefix}-nextcloud'
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2als_v2'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicNextcloudVMId
          properties: {
            primary: true
          }
        }
      ]
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      dataDisks: [
        {
          managedDisk: {
            id: diskNextcloud.id
          }
          createOption: 'Attach'
          lun: 0
        }
      ]
    }
    osProfile: {
      computerName: '${namePrefix}-nextcloud'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshKeyData
            }
          ]
        }
      }
    }
  }
}

output vmNextcloudIndentityPrincipalId string = vmnextcloud.identity.principalId
