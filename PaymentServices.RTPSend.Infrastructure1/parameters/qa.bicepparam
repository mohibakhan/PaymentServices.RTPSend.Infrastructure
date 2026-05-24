// QA environment parameters for PaymentServices.RTPSend infrastructure.

using '../main.bicep'

param environment = 'qa'
param location = 'centralus'

// -----------------------------------------------------------------------------
// RTPSend-dedicated (created by template)
// -----------------------------------------------------------------------------

param functionAppName = 'fa-pmtsvc-rtpsend-qa-centralus'
param appServicePlanName = 'asp-pmtsvc-rtpsend-qa-centralus'
param storageAccountName = 'stpmtsvcrtpsendqa'

// -----------------------------------------------------------------------------
// Shared platform resources (referenced, never modified)
// -----------------------------------------------------------------------------

param userAssignedIdentityName = 'id-pmtsvc-qa-centralus'
param appInsightsName = 'appi-paymentservices-qa-centralus'

param sharedCosmosResourceGroup = 'rg-pmtsvc-qa'
param sharedCosmosAccountName = 'cosmos-paymentservices-qa-centralus'

param sharedServiceBusResourceGroup = 'rg-pmtsvc-qa'
param sharedServiceBusNamespaceName = 'sb-pmtsvc-qa-centralus'

param sharedAppConfigResourceGroup = 'rg-pmtsvc-qa'
param sharedAppConfigName = 'appcs-pmtsvc-qa-centralus'

// -----------------------------------------------------------------------------
// RTPSend-specific config
// -----------------------------------------------------------------------------

param cosmosDatabaseName = 'payments'
param sharedServiceBusTopicName = 'payment-processing'
param processSubscriptionName = 'rtpsend-process'
param processSubject = 'CreatePaymentRequest'

