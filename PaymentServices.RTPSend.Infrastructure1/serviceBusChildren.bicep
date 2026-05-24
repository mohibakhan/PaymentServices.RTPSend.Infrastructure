// Adds RTPSend's subscription to the EXISTING shared <c>payment-processing</c>
// topic. The namespace and topic themselves are never modified by this
// template — they're provisioned by PaymentServices.Infrastructure.
//
// The subscription filters on message Subject = 'CreatePaymentRequest' so
// outcome envelopes (which use Subject = 'CreatePayment - Success' /
// 'CreatePayment - Failure') and messages destined for other services
// (AccountResolutionPending, KycPending, etc.) are never delivered to
// ProcessPayment.

@description('Existing shared Service Bus namespace.')
param namespaceName string

@description('Existing shared topic name (e.g. payment-processing).')
param topicName string

@description('Name of the RTPSend subscription on the topic.')
param processSubscriptionName string

@description('Subject value the subscription filters on. Must match what CreatePayment publishes.')
param processSubject string = 'CreatePaymentRequest'

@description('Max delivery count before a message is dead-lettered.')
param processMaxDeliveryCount int = 10

@description('Lock duration on the subscription. ISO 8601 duration.')
param processLockDuration string = 'PT5M'

@description('Default message TTL on the subscription. ISO 8601 duration.')
param processDefaultTtl string = 'P14D'

// -----------------------------------------------------------------------------
// Reference the existing namespace and topic — never modified
// -----------------------------------------------------------------------------

resource namespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: namespaceName
}

resource topic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' existing = {
  parent: namespace
  name: topicName
}

// -----------------------------------------------------------------------------
// Subscription — rtpsend-process
//
// ProcessPayment triggers off this subscription.
// RetryFailedPayments drains its dead-letter sub-queue.
// -----------------------------------------------------------------------------

resource processSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: topic
  name: processSubscriptionName
  properties: {
    lockDuration: processLockDuration
    maxDeliveryCount: processMaxDeliveryCount
    defaultMessageTimeToLive: processDefaultTtl
    deadLetteringOnMessageExpiration: true
    deadLetteringOnFilterEvaluationExceptions: true
    enableBatchedOperations: true
    requiresSession: false
  }
}

// -----------------------------------------------------------------------------
// Subscription filter — Subject = 'CreatePaymentRequest'
//
// IMPORTANT — Service Bus auto-default rule:
// When ARM creates a subscription, Service Bus internally auto-creates a
// $Default rule with a TrueFilter (SqlFilter 1=1) that matches everything.
// If we declare our filter under that same name, ARM treats it as an
// "already exists" no-op — our CorrelationFilter is NOT applied, and the
// subscription is left with the wide-open auto-rule. Result: ProcessPayment
// would receive every message on the topic, including outcome envelopes
// it published itself.
//
// Workaround: declare our filter under a DIFFERENT name. The auto-created
// $Default rule still exists alongside ours, but since rules are OR'ed,
// the wide-open $Default would still match everything — so it must be
// MANUALLY DELETED ONCE per environment via the Azure CLI or portal:
//
//   az servicebus topic subscription rule delete \
//     --resource-group rg-pmtsvc-<env> \
//     --namespace-name sb-pmtsvc-<env>-<region> \
//     --topic-name payment-processing \
//     --subscription-name rtpsend-process \
//     --name '$Default'
//
// After the one-time delete, the subscription has exactly one rule:
//   rtpsend-process-filter (CorrelationFilter on Label='CreatePaymentRequest')
//
// Subsequent infra deploys leave it alone — bicep doesn't touch $Default
// and idempotently updates rtpsend-process-filter if its definition changes.
// -----------------------------------------------------------------------------

resource processFilter 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: processSubscription
  name: 'rtpsend-process-filter'
  properties: {
    filterType: 'CorrelationFilter'
    correlationFilter: {
      label: processSubject
    }
  }
}

output topicName string = topic.name
output processSubscriptionName string = processSubscription.name
