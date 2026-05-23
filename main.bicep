// =============================================================================
// PaymentServices.RTPSend — main infrastructure template
//
// Deployment scope: existing resource group (e.g. rg-pmtsvc-dev).
//
// SHARED platform resources referenced via `existing` (NEVER modified):
//   - Cosmos DB account
//   - Service Bus namespace + payment-processing topic
//   - Key Vault
//   - App Configuration store
//   - User-assigned managed identity (already has RBAC on the above)
//   - Application Insights + Log Analytics workspace
//
// What this template CREATES (idempotent — re-running is safe):
//   - App Service Plan (EP1)
//   - Function App with user-assigned MI attached
//   - Storage account for the Functions runtime
//   - Cosmos database + 4 containers under the shared Cosmos account
//   - rtpsend-process subscription on the shared payment-processing topic
//   - App Configuration keys for rtpSend:AppSettings:*
//
// NOT managed here:
//   - Role assignments — the platform team granted the user-assigned MI
//     access to all shared resources separately
//   - Key Vault secrets — ops creates these manually
//
// All deploys MUST be `--mode Incremental` (default for resource-group scope).
// =============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Parameters — environment + region
// -----------------------------------------------------------------------------

@description('Environment short name: dev, qa, prod')
@allowed([ 'dev', 'qa', 'prod' ])
param environment string

@description('Azure region for resources created by this template.')
param location string = resourceGroup().location

// -----------------------------------------------------------------------------
// Parameters — RTPSend-dedicated (CREATED by this template)
// -----------------------------------------------------------------------------

@description('Function App name.')
param functionAppName string

@description('App Service Plan name (asp- prefix).')
param appServicePlanName string

@description('Storage account name. Globally unique, 3-24 chars, lowercase + digits only.')
@minLength(3)
@maxLength(24)
param storageAccountName string

// -----------------------------------------------------------------------------
// Parameters — shared infra (REFERENCED via `existing`)
// -----------------------------------------------------------------------------

@description('Existing user-assigned managed identity name (e.g. id-pmtsvc-dev-centralus).')
param userAssignedIdentityName string

@description('Resource group of the user-assigned managed identity. Same as the function app RG in this platform.')
param userAssignedIdentityResourceGroup string = resourceGroup().name

@description('Existing Application Insights instance name (e.g. appi-paymentservices-dev-centralus).')
param appInsightsName string

@description('Resource group of the existing Application Insights instance.')
param appInsightsResourceGroup string = resourceGroup().name

// Shared Cosmos
@description('Resource group containing the shared Cosmos DB account.')
param sharedCosmosResourceGroup string

@description('Name of the existing shared Cosmos DB account.')
param sharedCosmosAccountName string

// Shared Service Bus
@description('Resource group containing the shared Service Bus namespace.')
param sharedServiceBusResourceGroup string

@description('Name of the existing shared Service Bus namespace.')
param sharedServiceBusNamespaceName string

// Shared App Configuration
@description('Resource group containing the shared App Configuration store.')
param sharedAppConfigResourceGroup string

@description('Name of the existing shared App Configuration store.')
param sharedAppConfigName string

// -----------------------------------------------------------------------------
// Parameters — RTPSend-specific config
// -----------------------------------------------------------------------------

@description('Cosmos database for RTPSend (shared platform DB).')
param cosmosDatabaseName string = 'tptch'

@description('Shared Service Bus topic name (platform convention).')
param sharedServiceBusTopicName string = 'payment-processing'

@description('Name of RTPSend\'s subscription on the topic.')
param processSubscriptionName string = 'rtpsend-process'

@description('Message Subject the subscription filter matches on.')
param processSubject string = 'CreatePaymentRequest'

@description('TabaPay send URL for this environment.')
param tabaPaySendUrl string

@description('CRON schedule for the RetryFailedPayments timer.')
param retryTimerSchedule string = '0 */5 * * * *'

@description('RTP send transaction code.')
param rtpSendTranCode string

@description('Partner ledger SQL stored procedure name.')
param partnerLedgerSpName string

// -----------------------------------------------------------------------------
// Existing — referenced, never modified
// -----------------------------------------------------------------------------

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
  scope: resourceGroup(userAssignedIdentityResourceGroup)
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: resourceGroup(appInsightsResourceGroup)
}

// -----------------------------------------------------------------------------
// Module — storage (for Functions runtime)
// -----------------------------------------------------------------------------

module storage 'modules/storage.bicep' = {
  name: 'storage-${environment}'
  params: {
    storageAccountName: storageAccountName
    location: location
  }
}

// -----------------------------------------------------------------------------
// Module — Function App + plan
// -----------------------------------------------------------------------------

module functionApp 'modules/functionApp.bicep' = {
  name: 'functionApp-${environment}'
  params: {
    functionAppName: functionAppName
    appServicePlanName: appServicePlanName
    location: location
    storageAccountName: storage.outputs.storageAccountName
    storageAccountConnectionString: storage.outputs.connectionString
    appInsightsConnectionString: appInsights.properties.ConnectionString
    appConfigEndpoint: 'https://${sharedAppConfigName}.azconfig.io'
    userAssignedIdentityResourceId: userAssignedIdentity.id
    userAssignedIdentityClientId: userAssignedIdentity.properties.clientId
  }
}

// -----------------------------------------------------------------------------
// Module — Cosmos children (database + 4 containers under existing account)
// -----------------------------------------------------------------------------

module cosmosChildren 'modules/cosmosChildren.bicep' = {
  name: 'cosmosChildren-${environment}'
  scope: resourceGroup(sharedCosmosResourceGroup)
  params: {
    cosmosAccountName: sharedCosmosAccountName
    databaseName: cosmosDatabaseName
  }
}

// -----------------------------------------------------------------------------
// Module — Service Bus subscription on existing topic
// -----------------------------------------------------------------------------

module serviceBusChildren 'modules/serviceBusChildren.bicep' = {
  name: 'sbChildren-${environment}'
  scope: resourceGroup(sharedServiceBusResourceGroup)
  params: {
    namespaceName: sharedServiceBusNamespaceName
    topicName: sharedServiceBusTopicName
    processSubscriptionName: processSubscriptionName
    processSubject: processSubject
  }
}

// -----------------------------------------------------------------------------
// Module — App Configuration keys
// -----------------------------------------------------------------------------

module appConfigKeys 'modules/appConfigKeys.bicep' = {
  name: 'appConfigKeys-${environment}'
  scope: resourceGroup(sharedAppConfigResourceGroup)
  params: {
    appConfigName: sharedAppConfigName
    cosmosDatabaseName: cosmosDatabaseName
    sharedTopicName: sharedServiceBusTopicName
    processSubscriptionName: processSubscriptionName
    tabaPaySendUrl: tabaPaySendUrl
    retryTimerSchedule: retryTimerSchedule
    rtpSendTranCode: rtpSendTranCode
    partnerLedgerSpName: partnerLedgerSpName
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------

output functionAppName string = functionApp.outputs.functionAppName
output functionAppHostName string = functionApp.outputs.defaultHostName
output userAssignedIdentityClientId string = userAssignedIdentity.properties.clientId
