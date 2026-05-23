// Storage account required by the Azure Functions runtime.
// Same-name re-deployments are idempotent (PUT with same properties = no-op).

@description('Storage account name. Globally unique, 3-24 chars, lowercase + digits only.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Region.')
param location string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true   // required by AzureWebJobsStorage today; can flip to false once MI-based storage is finalized
    publicNetworkAccess: 'Enabled'
    encryption: {
      services: {
        blob: { enabled: true }
        file: { enabled: true }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

output storageAccountName string = storage.name

// AzureWebJobsStorage still expects a connection string. Using listKeys()
// here keeps the deployment self-contained; downstream we can move the
// Functions runtime to MI-based storage when ready.
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
