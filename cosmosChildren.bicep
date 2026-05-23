// Cosmos database + 4 RTPSend containers under the EXISTING shared Cosmos account.
// The account itself is never modified by this template.

@description('Existing shared Cosmos DB account.')
param cosmosAccountName string

@description('Database name. Default: payments')
param databaseName string = 'payments'

@description('Database throughput in RU/s. Use shared autoscale at the database level.')
param databaseAutoscaleMaxThroughput int = 4000

// -----------------------------------------------------------------------------
// Reference the existing account — never modified by this template
// -----------------------------------------------------------------------------

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosAccountName
}

// -----------------------------------------------------------------------------
// Database (created if missing, otherwise no-op)
// -----------------------------------------------------------------------------

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
    options: {
      autoscaleSettings: {
        maxThroughput: databaseAutoscaleMaxThroughput
      }
    }
  }
}

// -----------------------------------------------------------------------------
// Container: paymentRequests
// Partition: /evolveId
// -----------------------------------------------------------------------------

resource paymentRequests 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'paymentRequests'
  properties: {
    resource: {
      id: 'paymentRequests'
      partitionKey: {
        paths: [ '/evolveId' ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [ { path: '/*' } ]
        excludedPaths: [ { path: '/"_etag"/?' } ]
      }
      defaultTtl: -1   // TTL feature enabled at container level, no auto-expiry
    }
  }
}

// -----------------------------------------------------------------------------
// Container: partnerLedger
// Partition: /vAccountNumber  (matches existing platform schema)
// -----------------------------------------------------------------------------

resource partnerLedger 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'partnerLedger'
  properties: {
    resource: {
      id: 'partnerLedger'
      partitionKey: {
        paths: [ '/vAccountNumber' ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [ { path: '/*' } ]
        excludedPaths: [ { path: '/"_etag"/?' } ]
      }
    }
  }
}

// -----------------------------------------------------------------------------
// Container: apiUserConfig
// Partition: /clientId
// -----------------------------------------------------------------------------

resource apiUserConfig 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'apiUserConfig'
  properties: {
    resource: {
      id: 'apiUserConfig'
      partitionKey: {
        paths: [ '/clientId' ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [ { path: '/*' } ]
        excludedPaths: [ { path: '/"_etag"/?' } ]
      }
    }
  }
}

// -----------------------------------------------------------------------------
// Container: paymentIdempotency
// Partition: /paymentReference
// TTL enabled at the CONTAINER level — per-doc ttl values then take effect.
// defaultTtl = -1 enables TTL without auto-expiring any doc; the
// PaymentIdempotencyEntry doc carries its own 90-day ttl field.
// -----------------------------------------------------------------------------

resource paymentIdempotency 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'paymentIdempotency'
  properties: {
    resource: {
      id: 'paymentIdempotency'
      partitionKey: {
        paths: [ '/paymentReference' ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [ { path: '/*' } ]
        excludedPaths: [ { path: '/"_etag"/?' } ]
      }
      defaultTtl: -1   // Required for per-doc ttl values to take effect
    }
  }
}

output databaseName string = database.name
output paymentRequestsContainerName string = paymentRequests.name
output partnerLedgerContainerName string = partnerLedger.name
output apiUserConfigContainerName string = apiUserConfig.name
output paymentIdempotencyContainerName string = paymentIdempotency.name
