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

### 2. Run the Demo

#### Option A: Chat Trigger (Recommended)

1. Click the **"Chat Trigger"** node
2. Click **"Execute Node"** (or press `Ctrl/Cmd + Enter`)
3. The workflow will run end-to-end automatically

#### Option B: Step-by-Step Execution

You can also trigger individual steps by modifying the chat input:

- `"run demo"` - Run full demo (default)
- `"ingest batch A"` - Run only Batch A ingestion
- `"ingest batch B"` - Run only Batch B ingestion
- `"propose patch"` - Run agent analysis
- `"enable compat"` - Enable compatibility view
- `"apply v2"` - Apply v2 schema

### 3. View Outputs

After each node execution, click on the node to see:
- **Output data** with stage information
- **Database state** (record counts)
- **Validation results**
- **Error details** (if any)

## 📊 Workflow Stages

### Stage 0: Setup Schemas & v1 Contract

**Node**: `Setup Schemas & v1 Contract`

Creates three schemas:
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
  "stage": "0. Setup Complete",
  "schemas_created": ["staging.flights_raw", "gold.flights_pricing_v1", "ops.quarantine"],
  "db_state": {
    "staging_count": 0,
    "gold_v1_count": 0,
    "quarantine_count": 0
  }
}
```

---

### Stage 1: Ingest Batch A (Good Data)

**Node**: `Ingest Batch A (Good Data)`

**Input Data**:
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
  "stage": "1. Batch A Ingested (✅ SUCCESS)",
  "validation_result": "PASSED",
  "action": "Inserted into gold.flights_pricing_v1",
  "rows_inserted": 1,
  "db_state": {
    "staging_count": 1,
    "gold_v1_count": 1,
    "quarantine_count": 0
  }
}
```

---

### Stage 2: Ingest Batch B (Drift Data)

**Node**: `Ingest Batch B (Drift Data)`

**Input Data** (with drift):
```json
{
  "flight_id": "DL567",
  "origin": "ATL",
  "destination": "LAX",
  "depart_ts": "2025-06-02T09:30:00Z",
  "cabin": "ECONOMY",
  "fare_usd": "three hundred",  // ❌ TYPE ERROR: string instead of number
  "carrier_code": "DL",
  "currency": "USD",
  "taxes_usd": 47.1,
  "channel": "mobile"  // ❌ ADDITIVE COLUMN: not in v1 schema
}
```

**Expected Output**:
```json
{
  "stage": "2. Batch B Ingested (🛑 QUARANTINED - Schema Drift)",
  "validation_result": "FAILED",
  "drift_detected": true,
  "drift_details": {
    "type_error": "fare_usd is string \"three hundred\" instead of number",
    "additive_column": "channel field not in v1 schema"
  },
  "action": "Quarantined for schema drift",
  "db_state": {
    "staging_count": 2,
    "gold_v1_count": 1,
    "quarantine_count": 1
  }
}
```

---

### Stage 3: Agent Analysis & Patch Proposal

**Node**: `Agent: Propose Patch`

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

### Stage 4: Enable Compat View (Feature Flag)

**Node**: `Enable Compat View (Feature Flag)`

Enables the compatibility view via feature flag, allowing readers to access the new schema without code changes.

**Expected Output**:
```json
{
  "stage": "4. Feature Flag & Read Flights",
  "feature_flag_enabled": true,
  "view_used": "gold.flights_pricing_compat",
  "flights": [
    {
      "flight_id": "AA1234",
      "origin": "JFK",
      "destination": "SFO",
      "fare_usd": 329.5,
      "channel": null  // ← Added via compat view
    }
  ],
  "flight_count": 1
}
```

---

### Stage 5: Apply v2 Schema & Replay

**Node**: `Apply v2 Schema & Replay`

Creates v2 schema (extends v1 with nullable `channel`) and replays quarantined data.

**v2 Schema Changes**:
- Adds `channel` column (nullable VARCHAR)
- Makes `fare_usd` tolerant (TRY_CAST with NULL on failure)

**Expected Output**:
```json
{
  "stage": "5. v2 Schema Applied & Replay Successful",
  "v2_schema_changes": {
    "added_column": "channel (nullable VARCHAR)",
    "fare_usd_tolerance": "TRY_CAST with NULL on failure"
  },
  "replayed_record": {
    "flight_id": "DL567",
    "origin": "ATL",
    "destination": "LAX",
    "fare_usd": null,  // ← Converted from "three hundred"
    "channel": "mobile",  // ← Now accepted
    "schema_version": "v2"
  },
  "validation_result": "PASSED (v2)",
  "action": "Inserted into gold.flights_pricing_v2",
  "migration_note": "Downstreams can migrate to v2 when ready"
}
```

---

## 🎨 Visual Flow

```
┌─────────────────┐
│  Chat Trigger   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  Parse Chat Command     │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  Setup Schemas & v1 Contract│
└────────┬────────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Ingest Batch A (Good)   │ ✅ → gold.flights_pricing_v1
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Ingest Batch B (Drift)  │ 🛑 → ops.quarantine
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Agent: Propose Patch    │ 📝 → compat view SQL
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Enable Compat (FF)      │ 🚩 → feature flag ON
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Apply v2 Schema & Replay│ ✅ → gold.flights_pricing_v2
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Format Final Output     │ 📊 → summary
└──────────────────────────┘
```

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

## 🧪 Testing Individual Steps

### Test Batch A Only
1. Click "Chat Trigger"
2. In the input, type: `"ingest batch A"`
3. Execute the workflow
4. Check output at "Ingest Batch A" node

### Test Batch B Only
1. Click "Chat Trigger"
2. In the input, type: `"ingest batch B"`
3. Execute the workflow
4. Check output at "Ingest Batch B" node

### Test Agent Analysis
1. First run Batch B to create quarantine entry
2. Click "Chat Trigger"
3. Type: `"propose patch"`
4. Execute and check "Agent: Propose Patch" output

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

