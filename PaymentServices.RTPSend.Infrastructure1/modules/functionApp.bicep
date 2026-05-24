// Premium EP1 plan (Windows) + Function App (.NET 10 isolated worker).
//
// Identity: uses the EXISTING user-assigned managed identity provisioned by
// the platform team. That MI already has the role assignments it needs on
// the shared Cosmos / Key Vault / Service Bus / App Configuration resources,
// so this template does NOT create any role assignments.
//
// AZURE_CLIENT_ID app setting is set to the MI's clientId so that
// DefaultAzureCredential in Program.cs picks up the right identity.

@description('Function App name.')
param functionAppName string

@description('App Service Plan name.')
param appServicePlanName string

@description('Region.')
param location string

@description('Storage account name (for AzureWebJobsStorage).')
param storageAccountName string

@description('Storage account connection string.')
@secure()
param storageAccountConnectionString string

@description('Application Insights connection string (from existing AI instance).')
@secure()
param appInsightsConnectionString string

@description('App Configuration endpoint URL (https://<name>.azconfig.io).')
param appConfigEndpoint string

@description('Resource ID of the existing user-assigned managed identity to attach.')
param userAssignedIdentityResourceId string

@description('Client ID (NOT principal ID) of the user-assigned managed identity. Used by DefaultAzureCredential.')
param userAssignedIdentityClientId string

@description('Min instance count for Premium plan elastic scale.')
param minInstanceCount int = 1

@description('Max instance count for Premium plan elastic scale.')
param maxInstanceCount int = 5

// -----------------------------------------------------------------------------
// App Service Plan — Premium v3 EP1
// -----------------------------------------------------------------------------

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
    family: 'EP'
    size: 'EP1'
    capacity: minInstanceCount
  }
  kind: 'elastic'
  properties: {
    reserved: false                      // Windows (Linux would be reserved: true)
    maximumElasticWorkerCount: maxInstanceCount
    elasticScaleEnabled: true
    zoneRedundant: false
  }
}

// -----------------------------------------------------------------------------
// Function App
//
// Identity is user-assigned only (no system-assigned).
// The MI's clientId is exposed to the app via AZURE_CLIENT_ID so that
// DefaultAzureCredential and the Key Vault reference resolver pick it.
// -----------------------------------------------------------------------------

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'                    // Windows (Linux would be 'functionapp,linux')
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
    // Tell App Service to use this user-assigned MI for Key Vault reference resolution
    keyVaultReferenceIdentity: userAssignedIdentityResourceId
    siteConfig: {
      netFrameworkVersion: 'v10.0'       // .NET 10 isolated worker on Windows
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: false                    // Premium plan handles cold start
      functionAppScaleLimit: maxInstanceCount
      minimumElasticInstanceCount: minInstanceCount
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageAccountConnectionString
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'AppConfig:Endpoint'
          value: appConfigEndpoint
        }
        {
          // Required for DefaultAzureCredential to pick the user-assigned MI
          name: 'AZURE_CLIENT_ID'
          value: userAssignedIdentityClientId
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageAccountConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
      ]
    }
  }
}

output functionAppName string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName
