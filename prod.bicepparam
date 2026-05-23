// PROD environment parameters for PaymentServices.RTPSend infrastructure.
//
// NOTE: PROD is in eastus, not centralus like DEV/QA.
// PROD also has some naming idiosyncrasies left over from earlier provisioning:
//   - Cosmos:          cosmosdb-pmtsvc-prod-eastus   (NOT cosmos-paymentservices-prod-eastus)
//   - App Config:      appcs-pmtsvc-rtpsend-prod-eastus  (includes "rtpsend" for legacy reasons)

using '../main.bicep'

param environment = 'prod'
param location = 'eastus'

// -----------------------------------------------------------------------------
// RTPSend-dedicated (created by template)
// -----------------------------------------------------------------------------

param functionAppName = 'fa-pmtsvc-rtpsend-prod-eastus'
param appServicePlanName = 'asp-pmtsvc-rtpsend-prod-eastus'
param storageAccountName = 'stpmtsvcrtpsendprod'

// -----------------------------------------------------------------------------
// Shared platform resources (referenced, never modified)
// -----------------------------------------------------------------------------

param userAssignedIdentityName = 'id-pmtsvc-prod-eastus'
param appInsightsName = 'appi-paymentservices-prod-eastus'

param sharedCosmosResourceGroup = 'rg-pmtsvc-prod'
param sharedCosmosAccountName = 'cosmosdb-pmtsvc-prod-eastus'   // intentional — name differs from dev/qa

param sharedServiceBusResourceGroup = 'rg-pmtsvc-prod'
param sharedServiceBusNamespaceName = 'sb-pmtsvc-prod-eastus'

param sharedAppConfigResourceGroup = 'rg-pmtsvc-prod'
param sharedAppConfigName = 'appcs-pmtsvc-rtpsend-prod-eastus'  // intentional — name differs from dev/qa

// -----------------------------------------------------------------------------
// RTPSend-specific config
// -----------------------------------------------------------------------------

param cosmosDatabaseName = 'tptch'
param sharedServiceBusTopicName = 'payment-processing'
param processSubscriptionName = 'rtpsend-process'
param processSubject = 'CreatePaymentRequest'

// IMPORTANT: production TabaPay URL — not the test one
param tabaPaySendUrl = 'https://api.tabapay.net/v1/Transactions/Card'
param retryTimerSchedule = '0 */5 * * * *'
param rtpSendTranCode = '21'
param partnerLedgerSpName = '[prod].[vAccountFboLookup]'
