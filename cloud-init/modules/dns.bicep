param tags object
param dnsZoneName string
param mailExchangeHost string = 'mail'
param publicStaticIp string
param vmNextcloudIdentityPrincipalId string

resource dnsNextcloud 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  etag: uniqueString(resourceGroup().id, dnsZoneName, '1')
  name: dnsZoneName
  location: resourceGroup().location
  properties: {
    zoneType: 'Public'
  }
  tags: tags
}

var aRecordName = 'www'
resource domainEntryWWWNextcloud 'Microsoft.Network/dnsZones/A@2023-07-01-preview' = {
  parent: dnsNextcloud
  name: aRecordName
  etag: uniqueString(resourceGroup().id, dnsZoneName, aRecordName, '1')
  properties: {
    TTL: 3600
    ARecords: [
      {
        ipv4Address: publicStaticIp
      }
    ]
  }
}

resource domainEntryApexNextcloud 'Microsoft.Network/dnsZones/A@2023-07-01-preview' = {
  parent: dnsNextcloud
  name: '@'
  etag: uniqueString(resourceGroup().id, dnsZoneName, 'apex', '1')
  properties: {
    TTL: 3600
    ARecords: [
      {
        ipv4Address: publicStaticIp
      }
    ]
  }
}

resource symbolicname 'Microsoft.Network/dnsZones/MX@2023-07-01-preview' = {
  parent: dnsNextcloud
  name: '@'
  etag: uniqueString(resourceGroup().id, dnsZoneName, 'mail', '1')
  properties: {
    TTL: 3600
    MXRecords: [
      {
        preference: 10
        exchange: '${mailExchangeHost}.${dnsZoneName}'
      }
    ]
  }
}

resource dnsUserRoleDefinitionId 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'befefa01-2a29-4197-83a8-272ff33ce314'
}

resource dnsUserRoleAssignmentNextcloud 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: dnsNextcloud
  name: guid('nextcloud-dns-user', dnsNextcloud.id, vmNextcloudIdentityPrincipalId)
  properties: {
    description: 'Manages the access of the Nextcloud VM to the DNS zone.'
    principalId: vmNextcloudIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: dnsUserRoleDefinitionId.id
  }
}
