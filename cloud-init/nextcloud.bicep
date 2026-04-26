targetScope = 'subscription'

param location string = 'germanywestcentral'

param sshKeyDataPublic string

@secure()
param sshKeyDataPrivate string
@secure()
param dbPassword string
@secure()
param adminPassword string
@secure()
param redisPassword string

param tags object

@minLength(2)
param resourceGroupNamePrefix string = 'rg'

//Resource Group
resource rgnextcloud 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  location: location
  name: '${resourceGroupNamePrefix}-nextcloud'
  tags: tags
}

module network './modules/network.bicep' = {
  name: 'networkNextcloud'
  scope: rgnextcloud
  params: {
    tags: tags
  }
}

module vm './modules/vm.bicep' = {
  name: 'vmNextcloud'
  scope: rgnextcloud
  params: {
    sshKeyData: sshKeyDataPublic
    nicNextcloudVMId: network.outputs.nicNextcloudVMId
    tags: tags
  }
}

module kv './modules/kv.bicep' = {
  name: 'kvNextcloud'
  scope: rgnextcloud
  params: {
    subnetNextcloudId: network.outputs.subnetNextcloudId
    vmNextcloudIdentityPrincipalId: vm.outputs.vmNextcloudIdentityPrincipalId
    sshKeyData: sshKeyDataPrivate
    dbPassword: dbPassword
    adminPassword: adminPassword
    redisPassword: redisPassword
    tags: tags
  }
}
