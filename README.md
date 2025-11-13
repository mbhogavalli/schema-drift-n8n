# Schema Drift Detection & Evolution Demo - n8n Workflow

A visual, step-by-step demonstration of schema drift detection and evolution using n8n workflows. This demo showcases how to handle schema changes gracefully with compatibility views, feature flags, and gradual migration.

## 🎯 Overview

This workflow demonstrates a complete schema evolution pattern:

1. **Setup**: Create DuckDB schemas (staging, gold, ops) and define v1 contract
2. **Ingest Good Data**: Batch A passes validation → inserted into gold
3. **Detect Drift**: Batch B fails validation → quarantined (type error + additive column)
4. **Agent Analysis**: AI agent analyzes quarantine and proposes compatibility view
5. **Feature Flag**: Enable compat view for readers without breaking existing code
6. **Schema Evolution**: Apply v2 schema and replay quarantined data

## 📋 Prerequisites

- n8n installed and running (local or cloud)
- Basic understanding of data pipelines and schema evolution

## 🚀 Quick Start

### 1. Import Workflow

1. Open your n8n instance
2. Click **"Workflows"** → **"Import from File"**
3. Select `n8n-schema-drift-demo.json`
4. The workflow will be imported with all nodes configured
5. **Activate the workflow** (toggle switch in top right)

### 2. Get Webhook URL

1. Click on the **"Webhook: Ingest Flight Data"** node
2. Copy the **Webhook URL** (e.g., `http://localhost:5678/webhook/schema-drift/ingest`)
3. This URL accepts POST requests with flight data

### 3. Send Test Data

#### Option A: Using cURL

```bash
curl -X POST http://localhost:5678/webhook/schema-drift/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "flight_id": "AA1234",
    "origin": "JFK",
    "destination": "SFO",
    "depart_ts": "2025-06-01T16:00:00Z",
    "cabin": "ECONOMY",
    "fare_usd": 329.5,
    "carrier_code": "AA",
    "currency": "USD",
    "taxes_usd": 54.2
  }'
```

#### Option B: Using Test Script

```bash
./test-webhook.sh http://localhost:5678
```

#### Option C: Using Postman/Insomnia

1. Create a POST request to the webhook URL
2. Set Content-Type: `application/json`
3. Send flight record(s) in the body

### 4. View Outputs

After sending data:
1. Check the **webhook response** (JSON with validation results)
2. Click on workflow nodes to see:
   - **Validation results** (passed/quarantined)
   - **Database state** (record counts)
   - **Drift detection details**
   - **Agent analysis** (if drift detected)

## 📊 Workflow Stages

### Stage 1: Webhook Trigger & Initialize

**Node**: `Webhook: Ingest Flight Data` → `Initialize & Parse Incoming Data`

- Receives POST requests with flight data
- Accepts single record or array of records
- Initializes database schemas on first run:
  - `staging.flights_raw` - Raw payload storage
  - `gold.flights_pricing_v1` - Validated v1 data
  - `ops.quarantine` - Failed records with reasons

**v1 Contract**:
```javascript
{
  flight_id: 'string (min 3 chars)',
  origin: 'string (exactly 3 chars)',
  destination: 'string (exactly 3 chars)',
  depart_ts: 'timestamp',
  cabin: 'ECONOMY|PREMIUM|BUSINESS|FIRST',
  fare_usd: 'number >= 0',
  carrier_code: 'string (2-3 chars)',
  currency: 'USD|EUR|GBP',
  taxes_usd: 'number >= 0 (nullable)'
}
```

**Expected Output**:
```json
{
  "records": [...],
  "record_count": 1,
  "db_initialized": true,
  "db_state": {
    "staging_count": 0,
    "gold_v1_count": 0,
    "quarantine_count": 0
  }
}
```

---

### Stage 2: Validate & Detect Schema Drift

**Node**: `Validate & Detect Schema Drift`

**Process**:
- Validates each record against v1 contract
- Detects type errors (e.g., string instead of number)
- Detects additive columns (fields not in v1 schema)
- Inserts valid records into `gold.flights_pricing_v1`
- Quarantines records with drift or validation errors

**Example: Valid Record** (passes validation):
```json
{
  "flight_id": "AA1234",
  "origin": "JFK",
  "destination": "SFO",
  "depart_ts": "2025-06-01T16:00:00Z",
  "cabin": "ECONOMY",
  "fare_usd": 329.5,
  "carrier_code": "AA",
  "currency": "USD",
  "taxes_usd": 54.2
}
```

**Expected Output**:
```json
{
  "stage": "Schema Validation & Drift Detection",
  "records_processed": 1,
  "results": [{
    "validation_result": "PASSED",
    "action": "Inserted into gold.flights_pricing_v1"
  }],
  "summary": {
    "passed": 1,
    "quarantined": 0,
    "drift_detected": 0
  }
}
```

**Example: Drift Record** (quarantined):
```json
{
  "flight_id": "DL567",
  "origin": "ATL",
  "destination": "LAX",
  "depart_ts": "2025-06-02T09:30:00Z",
  "cabin": "ECONOMY",
  "fare_usd": "three hundred",  // ❌ TYPE ERROR
  "carrier_code": "DL",
  "currency": "USD",
  "taxes_usd": 47.1,
  "channel": "mobile"  // ❌ ADDITIVE COLUMN
}
```

**Expected Output**:
```json
{
  "stage": "Schema Validation & Drift Detection",
  "results": [{
    "validation_result": "FAILED",
    "drift_detected": true,
    "drift_details": {
      "typeErrors": ["fare_usd: expected number, got string"],
      "additiveColumns": ["channel"]
    },
    "action": "Quarantined"
  }],
  "summary": {
    "passed": 0,
    "quarantined": 1,
    "drift_detected": 1
  }
}
```

---

### Stage 3: Agent Analysis & Patch Proposal

**Node**: `Agent: Analyze Drift & Propose Patch`

**Triggered**: Only when drift is detected

Analyzes quarantined records and proposes a compatibility view.

**Expected Output**:
```json
{
  "stage": "3. Agent Analysis & Patch Proposal",
  "quarantine_analysis": {
    "correlation_id": "corr-...",
    "reason": "fare_usd: must be number >= 0 (got: string); Additive column: channel",
    "sample": { /* quarantined record */ }
  },
  "agent_suggestions": [
    {
      "issue": "fare_usd type mismatch",
      "solution": "CAST with tolerance: TRY_CAST(fare_usd AS DOUBLE) AS fare_usd"
    },
    {
      "issue": "Additive column: channel",
      "solution": "Add nullable column: CAST(NULL AS VARCHAR) AS channel"
    }
  ],
  "proposed_compat_view": "CREATE OR REPLACE VIEW gold.flights_pricing_compat AS ...",
  "pr_file": "PR_flights_pricing_compat.sql"
}
```

**Proposed SQL**:
```sql
CREATE OR REPLACE VIEW gold.flights_pricing_compat AS
SELECT
  flight_id, origin, destination, depart_ts, cabin,
  /* cast with tolerance */ TRY_CAST(fare_usd AS DOUBLE) AS fare_usd,
  carrier_code, currency, taxes_usd,
  /* additive nullable */ CAST(NULL AS VARCHAR) AS channel
FROM gold.flights_pricing_v1;
```

---

### Stage 4: Webhook Response

**Node**: `Respond to Webhook`

Returns JSON response with validation results and agent analysis.

**Expected Response**:
```json
{
  "success": true,
  "timestamp": "2025-01-27T12:00:00.000Z",
  "records_processed": 1,
  "summary": {
    "passed": 1,
    "quarantined": 0,
    "drift_detected": 0
  },
  "validation_results": [...],
  "agent_analysis": false,
  "db_state": {
    "staging_count": 1,
    "gold_v1_count": 1,
    "quarantine_count": 0
  },
  "message": "All records processed successfully."
}
```

**When Drift Detected**:
```json
{
  "success": true,
  "summary": {
    "passed": 0,
    "quarantined": 1,
    "drift_detected": 1
  },
  "agent_analysis": true,
  "agent_suggestions": [
    {
      "issue": "fare_usd type mismatch",
      "solution": "CAST with tolerance: TRY_CAST(fare_usd AS DOUBLE) AS fare_usd"
    },
    {
      "issue": "Additive column: channel",
      "solution": "Add nullable column: CAST(NULL AS VARCHAR) AS channel"
    }
  ],
  "message": "Some records quarantined due to schema drift. Check agent_analysis for recommendations."
}
```

---

## 🎨 Visual Flow

```
┌─────────────────────────────┐
│  Webhook: Ingest Flight Data│ ← POST /webhook/schema-drift/ingest
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ Initialize & Parse Incoming │ → Initialize DB schemas
│          Data                │ → Parse flight record(s)
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ Validate & Detect Schema     │ → Validate against v1 contract
│          Drift               │ → Detect type errors & additive columns
└────────┬────────────────────┘
         │
         ├─✅ Valid → gold.flights_pricing_v1
         └─🛑 Drift → ops.quarantine
         │
         ▼
┌─────────────────────────────┐
│ Agent: Analyze Drift &      │ → Analyze quarantine (if drift detected)
│      Propose Patch           │ → Generate compat view SQL
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│   Respond to Webhook         │ → Return JSON response
└─────────────────────────────┘
```

**Streaming Data Flow**:
- Each POST request processes one or more flight records
- Records are validated in real-time
- Drift is detected immediately
- Agent analysis runs automatically when drift is detected
- Response includes validation results and recommendations

## 🔍 Key Concepts Demonstrated

### 1. Schema Validation
- **v1 Contract**: Strict validation using Pandera-like rules
- **Type Safety**: Enforces data types (number vs string)
- **Enum Validation**: Cabin and currency must match allowed values

### 2. Quarantine Pattern
- Failed records are **never lost**
- Stored in `ops.quarantine` with:
  - Correlation ID for traceability
  - Reason for failure
  - Sample payload for analysis

### 3. Compatibility Views
- **Backward Compatible**: Existing code continues to work
- **Forward Compatible**: New columns added as nullable
- **Gradual Migration**: Downstreams migrate at their own pace

### 4. Feature Flags
- **Zero-Downtime**: Enable new behavior without deployment
- **Safe Rollback**: Can disable if issues arise
- **A/B Testing**: Test new schema with subset of traffic

### 5. Schema Evolution
- **v1 → v2**: Additive changes only (nullable columns)
- **Type Tolerance**: TRY_CAST handles type mismatches
- **Replay Capability**: Re-process quarantined data after schema update

## 🧪 Testing Examples

### Test Valid Record

```bash
curl -X POST http://localhost:5678/webhook/schema-drift/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "flight_id": "AA1234",
    "origin": "JFK",
    "destination": "SFO",
    "depart_ts": "2025-06-01T16:00:00Z",
    "cabin": "ECONOMY",
    "fare_usd": 329.5,
    "carrier_code": "AA",
    "currency": "USD",
    "taxes_usd": 54.2
  }'
```

### Test Schema Drift (Type Error)

```bash
curl -X POST http://localhost:5678/webhook/schema-drift/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "flight_id": "DL567",
    "origin": "ATL",
    "destination": "LAX",
    "depart_ts": "2025-06-02T09:30:00Z",
    "cabin": "ECONOMY",
    "fare_usd": "three hundred",
    "carrier_code": "DL",
    "currency": "USD",
    "taxes_usd": 47.1
  }'
```

### Test Schema Drift (Additive Column)

```bash
curl -X POST http://localhost:5678/webhook/schema-drift/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "flight_id": "UA789",
    "origin": "ORD",
    "destination": "DEN",
    "depart_ts": "2025-06-03T14:00:00Z",
    "cabin": "BUSINESS",
    "fare_usd": 850.0,
    "carrier_code": "UA",
    "currency": "USD",
    "taxes_usd": 120.5,
    "channel": "mobile"
  }'
```

### Test Batch Processing

```bash
curl -X POST http://localhost:5678/webhook/schema-drift/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "records": [
      {
        "flight_id": "BA456",
        "origin": "LHR",
        "destination": "JFK",
        "depart_ts": "2025-06-04T10:00:00Z",
        "cabin": "FIRST",
        "fare_usd": 2500.0,
        "carrier_code": "BA",
        "currency": "GBP",
        "taxes_usd": 300.0
      },
      {
        "flight_id": "AF789",
        "origin": "CDG",
        "destination": "SFO",
        "depart_ts": "2025-06-05T08:00:00Z",
        "cabin": "PREMIUM",
        "fare_usd": 1200.0,
        "carrier_code": "AF",
        "currency": "EUR",
        "taxes_usd": 150.0
      }
    ]
  }'
```

### Run All Tests

Use the provided test script:

```bash
./test-webhook.sh http://localhost:5678
```

## 📝 Notes

- **In-Memory Database**: This demo uses n8n's `$workflow.staticData` to simulate DuckDB. In production, use actual DuckDB connections.
- **Pandera Simulation**: Validation logic is simplified for n8n. Production should use actual Pandera schemas.
- **Feature Flags**: Stored in workflow static data. Production should use a feature flag service (LaunchDarkly, etc.).

## 🔗 Related Resources

- [DuckDB Documentation](https://duckdb.org/docs/)
- [Pandera Documentation](https://pandera.readthedocs.io/)
- [n8n Documentation](https://docs.n8n.io/)

## 📄 License

MIT License - feel free to use this demo for learning and presentations.

## 🤝 Contributing

Contributions welcome! Please open an issue or PR for improvements.

---

**Happy Schema Evolving! 🚀**

