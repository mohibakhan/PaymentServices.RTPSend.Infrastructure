# PaymentServices.RTPSend.Infrastructure

Bicep templates and ADO pipeline for the RTPSend-owned resources: Function App,
App Service Plan, Storage, plus child resources (Cosmos containers,
Service Bus subscription, App Config keys) under the shared platform.

This repo is **infrastructure-only**. Application code lives in the
`PaymentServices.RTPSend` repo.

## Platform conventions

| Resource | DEV | QA | PROD |
|---|---|---|---|
| Region | centralus | centralus | **eastus** |
| Resource group | `rg-pmtsvc-dev` | `rg-pmtsvc-qa` | `rg-pmtsvc-prod` |
| Cosmos account | `cosmos-paymentservices-dev-centralus` | `cosmos-paymentservices-qa-centralus` | `cosmosdb-pmtsvc-prod-eastus` |
| Service Bus namespace | `sb-pmtsvc-dev-centralus` | `sb-pmtsvc-qa-centralus` | `sb-pmtsvc-prod-eastus` |
| Key Vault | `kv-pmtsvc-dev-centralus` | `kv-pmtsvc-qa-centralus` | `kv-pmtsvc-prod-eastus` |
| App Configuration | `appcs-pmtsvc-dev-centralus` | `appcs-pmtsvc-qa-centralus` | `appcs-pmtsvc-rtpsend-prod-eastus` |
| User-assigned MI | `id-pmtsvc-dev-centralus` | `id-pmtsvc-qa-centralus` | `id-pmtsvc-prod-eastus` |
| App Insights (shared) | `appi-paymentservices-dev-centralus` | `appi-paymentservices-qa-centralus` | `appi-paymentservices-prod-eastus` |
| Cosmos database | `tptch` | `tptch` | `tptch` |
| Service connection | `rg-pmsvc-dev-SvcCon-WI` | `rg-pmsvc-qa-SvcCon-WI` | `rg-pmsvc-prod-SvcCon-WI` |

**PROD idiosyncrasies (intentional, do not "fix"):**
- Cosmos uses prefix `cosmosdb-pmtsvc-` instead of `cosmos-paymentservices-`
- App Configuration name includes `rtpsend` for historical reasons (still shared)
- Different region (`eastus`) than DEV/QA (`centralus`)

## What this template creates

**In the RTPSend resource group (e.g. `rg-pmtsvc-dev`):**
- App Service Plan (Premium EP1, elastic scale 1–5 instances), `asp-` prefix
- Function App `fa-pmtsvc-rtpsend-{env}-{region}` attached to the existing
  user-assigned MI `id-pmtsvc-{env}-{region}`
- Storage account `stpmtsvcrtpsend{env}` (Functions runtime)

**In the shared `tptch` Cosmos database:**
- Container `paymentRequests` (PK `/evolveId`, no TTL)
- Container `partnerLedger` (PK `/vAccountNumber`, no TTL)
- Container `apiUserConfig` (PK `/clientId`, no TTL)
- Container `paymentIdempotency` (PK `/paymentReference`, **container TTL enabled**)

**In the shared Service Bus namespace:**
- Subscription `rtpsend-process` on the existing `payment-processing` topic
- CorrelationFilter: `label = "CreatePaymentRequest"` — only inbound work
  messages reach this subscription; outcome envelopes for other services do not

**In the shared App Configuration store:**
- ~11 non-secret `rtpSend:AppSettings:*` keys + 2 telemetry keys

## What this template does NOT manage

- Shared infra accounts (Cosmos / SB / KV / App Config) — referenced as `existing`, never modified
- App Insights instance + Log Analytics workspace — referenced as `existing` (shared platform resources `appi-paymentservices-{env}-{region}`)
- The user-assigned MI itself — referenced as `existing`, lives in the same RG as the Function App
- Key Vault secrets — created and rotated manually by ops
- Role assignments — the platform team already granted `id-pmtsvc-{env}` access to all shared resources (Cosmos / KV / SB / App Config), so this template does not create any RBAC

## Never-delete guarantee

- All deploys use `--mode Incremental` (enforced in `deploy-stage.yml`)
- Shared infrastructure is referenced via `existing` and never modified
- The What-If stage fails the build if it detects any Delete actions

## Layout

```
.
├── azure-pipelines.yml           ← ADO points here
├── main.bicep                    ← orchestrator
├── modules/
│   ├── storage.bicep
│   ├── functionApp.bicep         ← asp- prefix, user-assigned MI attached
│   ├── cosmosChildren.bicep
│   ├── serviceBusChildren.bicep
│   └── appConfigKeys.bicep
├── parameters/                   ← one .bicepparam per env
└── pipelines/
    ├── infra-pipeline.yml
    └── templates/
        ├── validate-stage.yml
        ├── whatif-stage.yml
        └── deploy-stage.yml
```

## Running the pipeline

The pipeline is **manual-only**. There are no automatic triggers.

1. **Pipelines** → `PaymentServices.RTPSend.Infrastructure` → **Run pipeline**
2. Set parameters:
   - **Environment**: `dev`, `qa`, or `prod`
   - **Action**: `whatIf` (preview) or `deploy`
3. Run

For `deploy` against `qa` or `prod`, the pipeline pauses for approval at the
deploy stage (gated by the ADO Environment).

## One-time ADO setup

### 1. Service connections — already exist

`rg-pmsvc-dev-SvcCon-WI`, `rg-pmsvc-qa-SvcCon-WI`, and `rg-pmsvc-prod-SvcCon-WI`
already exist in the project. Each SP needs **Contributor** on the matching
`rg-pmtsvc-{env}` resource group.

Because the platform team already granted RBAC on shared resources to
`id-pmtsvc-{env}`, the deployment SP does NOT need User Access Administrator
— Contributor is enough.

### 2. Create ADO Environments

**Pipelines → Environments → New environment**

- `rtpsend-infra-dev` — no approvals
- `rtpsend-infra-qa` — add approvers
- `rtpsend-infra-prod` — add approvers (stricter)

### 3. Register the pipeline

**Pipelines → New pipeline → Azure Repos Git → this repo →
Existing Azure Pipelines YAML file → `/azure-pipelines.yml`**

## Running locally (template dev)

```powershell
az login
az account set --subscription "<dev-subscription-id>"

az deployment group validate `
  --resource-group rg-pmtsvc-dev `
  --template-file main.bicep `
  --parameters parameters/dev.bicepparam

az deployment group what-if `
  --resource-group rg-pmtsvc-dev `
  --template-file main.bicep `
  --parameters parameters/dev.bicepparam

az deployment group create `
  --resource-group rg-pmtsvc-dev `
  --template-file main.bicep `
  --parameters parameters/dev.bicepparam `
  --mode Incremental
```

## After the first deploy

Ops needs to populate Key Vault secrets in `kv-pmtsvc-{env}-{region}`. Then
either link them via App Configuration Key Vault references OR add them as
flat Function App settings (the latter is required for the
`SERVICE_BUS_CONNSTRING` used by the trigger binding — isolated worker can't
resolve App Config for binding connection strings).

| Function App setting | Key Vault secret name |
|---|---|
| `SERVICE_BUS_CONNSTRING` | `RTPSEND-SERVICE-BUS-CONNSTRING` (flat, KV reference) |
| `rtpSend:AppSettings:SERVICE_BUS_CONNSTRING` | same KV secret, via App Config KV reference |
| `rtpSend:AppSettings:COSMOS_CONNSTRING` | `RTPSEND-COSMOS-CONNSTRING` (via App Config) |
| `rtpSend:AppSettings:TABAPAY_SEND_APIKEY` | `RTPSEND-TABAPAY-APIKEY` |
| `rtpSend:AppSettings:TABAPAY_SEND_CLIENT_ID` | `RTPSEND-TABAPAY-CLIENT-ID` |
| `rtpSend:AppSettings:TABAPAY_SEND_MERCHANT_ID` | `RTPSEND-TABAPAY-MERCHANT-ID` |
| `rtpSend:AppSettings:PARTNER_LEDGER_SQL_CONNSTRING` | `RTPSEND-PARTNER-LEDGER-SQL-CONNSTRING` |

The Function App's `AZURE_CLIENT_ID` is set automatically by the template to
the user-assigned MI's client ID, so KV reference resolution and
`DefaultAzureCredential` in Program.cs both work with the same identity.
