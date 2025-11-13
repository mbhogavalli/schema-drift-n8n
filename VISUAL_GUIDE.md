# Visual Guide - Schema Drift Demo

This guide shows you exactly what to expect at each step of the workflow, with screenshots and output examples.

## 🎬 Running the Demo

### Step 1: Start the Workflow

1. Open n8n and navigate to the "Schema Drift Detection & Evolution Demo" workflow
2. Click on the **"Chat Trigger"** node (first node, left side)
3. You'll see a panel with execution options

**What you see:**
```
┌─────────────────────────────┐
│  Chat Trigger               │
│                             │
│  [Execute Node]             │
│                             │
│  Input: (empty or default)  │
└─────────────────────────────┘
```

### Step 2: Execute the Workflow

Click **"Execute Node"** or press `Ctrl/Cmd + Enter`

The workflow will run automatically through all stages. You'll see:
- Green checkmarks ✅ on successful nodes
- Red X marks ❌ on failed nodes (shouldn't happen in this demo)
- Blue dots 🔵 on nodes currently executing

---

## 📊 Stage-by-Stage Outputs

### Stage 0: Setup Complete

**Node**: `Setup Schemas & v1 Contract`

**Click on the node** to see output:

```json
{
  "stage": "0. Setup Complete",
  "timestamp": "2025-01-27T12:00:00.000Z",
  "schemas_created": [
    "staging.flights_raw",
    "gold.flights_pricing_v1",
    "ops.quarantine"
  ],
  "v1_contract": {
    "flight_id": "string (min 3 chars)",
    "origin": "string (exactly 3 chars)",
    "destination": "string (exactly 3 chars)",
    "depart_ts": "timestamp",
    "cabin": "ECONOMY|PREMIUM|BUSINESS|FIRST",
    "fare_usd": "number >= 0",
    "carrier_code": "string (2-3 chars)",
    "currency": "USD|EUR|GBP",
    "taxes_usd": "number >= 0 (nullable)"
  },
  "db_state": {
    "staging_count": 0,
    "gold_v1_count": 0,
    "quarantine_count": 0
  }
}
```

**Visual Indicator**: ✅ Green checkmark

---

### Stage 1: Batch A Ingested (Success)

**Node**: `Ingest Batch A (Good Data)`

**Output Preview**:

```json
{
  "stage": "1. Batch A Ingested (✅ SUCCESS)",
  "timestamp": "2025-01-27T12:00:01.000Z",
  "correlation_id": "corr-1737984001000-abc123",
  "input_data": {
    "flight_id": "AA1234",
    "origin": "JFK",
    "destination": "SFO",
    "depart_ts": "2025-06-01T16:00:00Z",
    "cabin": "ECONOMY",
    "fare_usd": 329.5,
    "carrier_code": "AA",
    "currency": "USD",
    "taxes_usd": 54.2
  },
  "validation_result": "PASSED",
  "action": "Inserted into gold.flights_pricing_v1",
  "rows_inserted": 1,
  "db_state": {
    "staging_count": 1,
    "gold_v1_count": 1,  // ← Increased!
    "quarantine_count": 0
  }
}
```

**Visual Indicator**: ✅ Green checkmark

**Key Points**:
- ✅ Validation passed
- ✅ Record inserted into `gold.flights_pricing_v1`
- ✅ `gold_v1_count` increased from 0 to 1

---

### Stage 2: Batch B Ingested (Quarantined)

**Node**: `Ingest Batch B (Drift Data)`

**Output Preview**:

```json
{
  "stage": "2. Batch B Ingested (🛑 QUARANTINED - Schema Drift)",
  "timestamp": "2025-01-27T12:00:02.000Z",
  "correlation_id": "corr-1737984002000-xyz789",
  "input_data": {
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
  },
  "validation_result": "FAILED",
  "validation_errors": [
    "fare_usd: must be number >= 0 (got: string)",
    "Additive column: channel"
  ],
  "drift_detected": true,
  "drift_details": {
    "type_error": "fare_usd is string \"three hundred\" instead of number",
    "additive_column": "channel field not in v1 schema"
  },
  "action": "Quarantined for schema drift",
  "db_state": {
    "staging_count": 2,
    "gold_v1_count": 1,  // ← Still 1 (not inserted)
    "quarantine_count": 1  // ← Increased!
  }
}
```

**Visual Indicator**: 🛑 Red warning (but node succeeds - quarantine is expected)

**Key Points**:
- ❌ Validation failed
- 🛑 Record quarantined (not lost!)
- 📊 `quarantine_count` increased from 0 to 1
- 🔍 Drift details show exactly what went wrong

---

### Stage 3: Agent Analysis

**Node**: `Agent: Propose Patch`

**Output Preview**:

```json
{
  "stage": "3. Agent Analysis & Patch Proposal",
  "timestamp": "2025-01-27T12:00:03.000Z",
  "quarantine_analysis": {
    "correlation_id": "corr-1737984002000-xyz789",
    "reason": "fare_usd: must be number >= 0 (got: string); Additive column: channel",
    "sample": {
      "flight_id": "DL567",
      "fare_usd": "three hundred",
      "channel": "mobile"
    }
  },
  "agent_suggestions": [
    {
      "issue": "fare_usd type mismatch",
      "solution": "CAST with tolerance: TRY_CAST(fare_usd AS DOUBLE) AS fare_usd",
      "sql_fragment": "TRY_CAST(fare_usd AS DOUBLE) AS fare_usd"
    },
    {
      "issue": "Additive column: channel",
      "solution": "Add nullable column: CAST(NULL AS VARCHAR) AS channel",
      "sql_fragment": "CAST(NULL AS VARCHAR) AS channel"
    }
  ],
  "proposed_compat_view": "CREATE OR REPLACE VIEW gold.flights_pricing_compat AS\nSELECT\n  flight_id, origin, destination, depart_ts, cabin,\n  /* cast with tolerance */ TRY_CAST(fare_usd AS DOUBLE) AS fare_usd,\n  carrier_code, currency, taxes_usd,\n  /* additive nullable */ CAST(NULL AS VARCHAR) AS channel\nFROM gold.flights_pricing_v1;",
  "pr_file": "PR_flights_pricing_compat.sql",
  "recommendation": "Low-risk compat view ready; enable via feature flag for readers"
}
```

**Visual Indicator**: 🤖 Blue info icon

**Key Points**:
- 🤖 Agent analyzed the quarantine
- 💡 Proposed solutions for each issue
- 📝 Generated SQL for compatibility view
- 🚩 Ready for feature flag activation

---

### Stage 4: Enable Compat View

**Node**: `Enable Compat View (Feature Flag)`

**Output Preview**:

```json
{
  "stage": "4. Feature Flag & Read Flights",
  "timestamp": "2025-01-27T12:00:04.000Z",
  "feature_flag_enabled": true,  // ← Flag flipped!
  "view_used": "gold.flights_pricing_compat",
  "flights": [
    {
      "flight_id": "AA1234",
      "origin": "JFK",
      "destination": "SFO",
      "depart_ts": "2025-06-01T16:00:00Z",
      "cabin": "ECONOMY",
      "fare_usd": 329.5,
      "carrier_code": "AA",
      "currency": "USD",
      "taxes_usd": 54.2,
      "channel": null  // ← New column added via compat view!
    }
  ],
  "flight_count": 1
}
```

**Visual Indicator**: 🚩 Feature flag icon

**Key Points**:
- 🚩 Feature flag enabled (`flights_pricing_read_compat: true`)
- 👁️ Readers now see compat view (includes `channel` column)
- ✅ Existing code continues to work
- 🔄 No breaking changes

---

### Stage 5: Apply v2 Schema

**Node**: `Apply v2 Schema & Replay`

**Output Preview**:

```json
{
  "stage": "5. v2 Schema Applied & Replay Successful",
  "timestamp": "2025-01-27T12:00:05.000Z",
  "v2_schema_changes": {
    "added_column": "channel (nullable VARCHAR)",
    "fare_usd_tolerance": "TRY_CAST with NULL on failure"
  },
  "replayed_record": {
    "flight_id": "DL567",
    "origin": "ATL",
    "destination": "LAX",
    "depart_ts": "2025-06-02T09:30:00Z",
    "cabin": "ECONOMY",
    "fare_usd": null,  // ← Converted from "three hundred" (NULL on failure)
    "carrier_code": "DL",
    "currency": "USD",
    "taxes_usd": 47.1,
    "channel": "mobile",  // ← Now accepted!
    "schema_version": "v2"
  },
  "validation_result": "PASSED (v2)",
  "action": "Inserted into gold.flights_pricing_v2",
  "migration_note": "Downstreams can migrate to v2 when ready",
  "db_state": {
    "staging_count": 2,
    "gold_v1_count": 1,
    "gold_v2_count": 1,  // ← New table!
    "quarantine_count": 1
  }
}
```

**Visual Indicator**: ✅ Green checkmark

**Key Points**:
- ✅ v2 schema created (extends v1)
- 🔄 Quarantined data replayed successfully
- 📊 New table: `gold.flights_pricing_v2`
- 🎯 Data recovered from quarantine!

---

### Final Output

**Node**: `Format Final Output`

**Output Preview**:

```json
{
  "summary": {
    "workflow": "Schema Drift Detection & Evolution Demo",
    "completed_at": "2025-01-27T12:00:06.000Z",
    "stages_completed": 6,
    "final_state": {
      "staging_records": 2,
      "gold_v1_records": 1,
      "gold_v2_records": 1,
      "quarantined_records": 1
    },
    "feature_flags": {
      "flights_pricing_read_compat": true
    }
  },
  "stages": [
    { "stage": "0. Setup Complete", ... },
    { "stage": "1. Batch A Ingested (✅ SUCCESS)", ... },
    { "stage": "2. Batch B Ingested (🛑 QUARANTINED)", ... },
    { "stage": "3. Agent Analysis & Patch Proposal", ... },
    { "stage": "4. Feature Flag & Read Flights", ... },
    { "stage": "5. v2 Schema Applied & Replay Successful", ... }
  ]
}
```

---

## 🎯 Key Visual Indicators

| Indicator | Meaning |
|-----------|---------|
| ✅ Green checkmark | Step completed successfully |
| 🛑 Red warning | Data quarantined (expected behavior) |
| 🤖 Blue info | Agent analysis/processing |
| 🚩 Flag icon | Feature flag operation |
| 📊 Chart icon | Data summary/output |

## 📸 Screenshot Locations

When running the workflow, take screenshots at:

1. **After Stage 0**: Show empty database state
2. **After Stage 1**: Show successful ingestion (gold_v1_count = 1)
3. **After Stage 2**: Show quarantine (quarantine_count = 1)
4. **After Stage 3**: Show agent suggestions
5. **After Stage 4**: Show feature flag enabled
6. **After Stage 5**: Show v2 table populated

## 💡 Tips for Presentations

1. **Run the workflow live** - Show real-time execution
2. **Click through nodes** - Demonstrate output at each stage
3. **Highlight key numbers** - Point out record counts changing
4. **Show the drift** - Emphasize Batch B's validation errors
5. **Demonstrate recovery** - Show how v2 recovers quarantined data

---

**Happy Demonstrating! 🎬**

