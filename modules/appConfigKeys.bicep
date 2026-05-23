// Non-secret rtpSend:AppSettings:* keys in the EXISTING shared App Configuration
// store. All actual secrets (TabaPay API key, SQL connstrings, Cosmos connstring,
// Service Bus connstring) live in Key Vault and are referenced by separate
// keys that ops creates manually (so they can rotate independently of infra).
//
// Re-deploying this module overwrites the listed keys to the values below.
// Any key NOT listed here is left untouched.

@description('Existing shared App Configuration store.')
param appConfigName string

@description('Cosmos database name (matches cosmosChildren.bicep).')
param cosmosDatabaseName string

@description('Existing shared Service Bus topic name.')
param sharedTopicName string

@description('Name of RTPSend\'s subscription on the topic.')
param processSubscriptionName string

@description('TabaPay send URL for this environment.')
param tabaPaySendUrl string

@description('Retry timer CRON schedule.')
param retryTimerSchedule string

@description('RTP send transaction code.')
param rtpSendTranCode string

@description('Partner ledger stored proc name.')
param partnerLedgerSpName string

// -----------------------------------------------------------------------------
// Reference the existing App Config store
// -----------------------------------------------------------------------------

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfigName
}

// -----------------------------------------------------------------------------
// Keys to manage (only non-secrets). Secrets are KV references created by ops.
// -----------------------------------------------------------------------------

var keys = [
  { key: 'rtpSend:AppSettings:COSMOS_DATABASE', value: cosmosDatabaseName }
  { key: 'rtpSend:AppSettings:COSMOS_PAYMENT_CONTAINER', value: 'paymentRequests' }
  { key: 'rtpSend:AppSettings:COSMOS_PARTNER_LEDGER_CONTAINER', value: 'partnerLedger' }
  { key: 'rtpSend:AppSettings:COSMOS_API_CONFIG_CONTAINER', value: 'apiUserConfig' }
  { key: 'rtpSend:AppSettings:COSMOS_IDEMPOTENCY_CONTAINER', value: 'paymentIdempotency' }
  { key: 'rtpSend:AppSettings:SERVICE_BUS_TOPIC_NAME', value: sharedTopicName }
  { key: 'rtpSend:AppSettings:SERVICE_BUS_PROCESS_SUBSCRIPTION_NAME', value: processSubscriptionName }
  { key: 'rtpSend:AppSettings:TABAPAY_SEND_URL', value: tabaPaySendUrl }
  { key: 'rtpSend:AppSettings:RETRY_TIMER_SCHEDULE', value: retryTimerSchedule }
  { key: 'rtpSend:AppSettings:RTP_SEND_TRAN_CODE', value: rtpSendTranCode }
  { key: 'rtpSend:AppSettings:PARTNER_LEDGER_SPNAME', value: partnerLedgerSpName }
  { key: 'telemetry:APP_INSIGHTS-CUSTOM_PROP_EVOLVE_TRAIN', value: 'Digital' }
  { key: 'telemetry:APP_INSIGHTS-CUSTOM_PROP_EVOLVE_TEAM', value: 'Services' }
]

@batchSize(1)
resource keyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = [for entry in keys: {
  parent: appConfig
  name: entry.key
  properties: {
    value: entry.value
    contentType: ''
  }
}]

output managedKeys array = [for entry in keys: entry.key]
