param tags object
param vmNextcloudIdentityPrincipalId string
param subnetNextcloudId string
@minLength(2)
param namePrefix string = 'kv'

@secure()
param sshKeyData string
@secure()
param dbPassword string
@secure()
param adminPassword string
@secure()
param redisPassword string

@secure()
param nextcloudClientId string
@secure()
param nextcloudClientSecret string

var secretContentType = 'text/plain'

resource kvnextcloud 'Microsoft.KeyVault/vaults@2025-05-01' = {
  location: resourceGroup().location
  name: '${namePrefix}-nextcloud-${guid(resourceGroup().id, subscription().id, vmNextcloudIdentityPrincipalId)}'
  properties: {
    enableRbacAuthorization: true
    publicNetworkAccess: 'enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: [
        { id: subnetNextcloudId }
      ]
    }
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
  tags: tags
}

resource vmSSHPrivateKeyNextcloud 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  parent: kvnextcloud
  name: 'nextcloud-ssh-private-key'
  properties: {
    contentType: secretContentType
    value: sshKeyData
  }
}

resource adminPasswordNextcloud 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  parent: kvnextcloud
  name: 'nextcloud-admin-password'
  properties: {
    contentType: secretContentType
    value: adminPassword
  }
}

resource dbPasswordNextcloud 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  parent: kvnextcloud
  name: 'nextcloud-db-password'
  properties: {
    contentType: secretContentType
    value: dbPassword
  }
}

resource redisPasswordNextcloud 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  parent: kvnextcloud
  name: 'nextcloud-redis-password'
  properties: {
    contentType: secretContentType
    value: redisPassword
  }
}

resource adminUsernameNextcloud 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  parent: kvnextcloud
  name: 'nextcloud-admin-username'
  properties: {
    contentType: secretContentType
    value: 'nextcloud'
  }
}

resource dbUsernameNextcloud 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  parent: kvnextcloud
  name: 'nextcloud-db-username'
  properties: {
    contentType: secretContentType
    value: 'nextcloud'
  }
}

resource redisUsernameNextcloud 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  parent: kvnextcloud
  name: 'nextcloud-redis-username'
  properties: {
    contentType: secretContentType
    value: 'nextcloud'
  }
}

resource clientSecretNextcloud 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  parent: kvnextcloud
  name: 'nextcloud-client-secret'
  properties: {
    contentType: secretContentType
    value: nextcloudClientSecret
  }
}

resource clientIdNextcloud 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  parent: kvnextcloud
  name: 'nextcloud-client-id'
  properties: {
    contentType: secretContentType
    value: nextcloudClientId
  }
}

resource kvUserRoleDefinitionId 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource kvUserRoleAssignmentNextcloud 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kvnextcloud
  name: guid('nextcloud-kv-user', kvnextcloud.id, vmNextcloudIdentityPrincipalId)
  properties: {
    description: 'Manages the access of the Nextcloud VM to the Key Vault secrets.'
    principalId: vmNextcloudIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: kvUserRoleDefinitionId.id
  }
}
