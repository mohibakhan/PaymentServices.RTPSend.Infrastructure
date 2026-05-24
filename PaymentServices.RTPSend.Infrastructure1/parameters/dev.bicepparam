// DEV environment parameters for PaymentServices.RTPSend infrastructure.

using '../main.bicep'

param environment = 'dev'
param location = 'centralus'

// -----------------------------------------------------------------------------
// RTPSend-dedicated (created by template)
// -----------------------------------------------------------------------------

param functionAppName = 'fa-pmtsvc-rtpsend-dev-centralus'
param appServicePlanName = 'asp-pmtsvc-rtpsend-dev-centralus'
param storageAccountName = 'stpmtsvcrtpsenddev'

// -----------------------------------------------------------------------------
// Shared platform resources (referenced, never modified)
// -----------------------------------------------------------------------------

// User-assigned managed identity — lives in the function app's RG
param userAssignedIdentityName = 'id-pmtsvc-dev-centralus'

// Application Insights — shared platform instance
param appInsightsName = 'appi-paymentservices-dev-centralus'

// Cosmos
param sharedCosmosResourceGroup = 'rg-pmtsvc-dev'
param sharedCosmosAccountName = 'cosmos-paymentservices-dev-centralus'

// Service Bus
param sharedServiceBusResourceGroup = 'rg-pmtsvc-dev'
param sharedServiceBusNamespaceName = 'sb-pmtsvc-dev-centralus'

// App Configuration
param sharedAppConfigResourceGroup = 'rg-pmtsvc-dev'
param sharedAppConfigName = 'appcs-pmtsvc-dev-centralus'

// -----------------------------------------------------------------------------
// RTPSend-specific config
// -----------------------------------------------------------------------------

param cosmosDatabaseName = 'payments'
param sharedServiceBusTopicName = 'payment-processing'
param processSubscriptionName = 'rtpsend-process'
param processSubject = 'CreatePaymentRequest'
