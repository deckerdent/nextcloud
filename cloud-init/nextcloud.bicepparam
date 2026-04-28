using 'nextcloud.bicep'

param location = 'germanywestcentral' //explicit just for reference

param tags = {
  project: 'nextcloud'
  environment: 'production'
}

//Placeholder params to silence editor warnings.
//These values will be overriden by generated values during deployment.
param adminPassword = ''
param dbPassword = ''
param redisPassword = ''
param sshKeyDataPrivate = ''
param sshKeyDataPublic = ''
param nextcloudClientId = ''
param nextcloudClientSecret = ''
