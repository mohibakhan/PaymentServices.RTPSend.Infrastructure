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
// SQL filter — only deliver messages with Subject = 'CreatePaymentRequest'
//
// The default '$Default' rule (a TrueFilter that matches everything) is
// replaced by this CorrelationFilter. CorrelationFilter on Subject is the
// cheapest filter type — no SQL evaluation, just a string compare on the
// system Subject property.
// -----------------------------------------------------------------------------

resource processFilter 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: processSubscription
  name: '$Default'
  properties: {
    filterType: 'CorrelationFilter'
    correlationFilter: {
      label: processSubject
    }
  }
}

output topicName string = topic.name
output processSubscriptionName string = processSubscription.name
