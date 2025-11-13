# Test Examples - Schema Drift Demo

This document provides example inputs and expected outputs for testing the workflow.

## Example 1: Full Demo Run

**Input**: (default - empty or "run demo")

**Expected Flow**:
1. Setup schemas ✅
2. Ingest Batch A ✅
3. Ingest Batch B 🛑 (quarantined)
4. Agent proposes patch 🤖
5. Enable compat view 🚩
6. Apply v2 schema ✅

**Final State**:
- staging: 2 records
- gold_v1: 1 record
- gold_v2: 1 record
- quarantine: 1 record

---

## Example 2: Batch A Only

**Input**: `"ingest batch A"`

**Expected Output**:
```json
{
  "stage": "1. Batch A Ingested (✅ SUCCESS)",
  "validation_result": "PASSED",
  "rows_inserted": 1
}
```

---

## Example 3: Batch B Only

**Input**: `"ingest batch B"`

**Expected Output**:
```json
{
  "stage": "2. Batch B Ingested (🛑 QUARANTINED - Schema Drift)",
  "validation_result": "FAILED",
  "drift_detected": true
}
```

---

## Example 4: Agent Analysis

**Input**: `"propose patch"`

**Prerequisites**: Must have quarantine entries (run Batch B first)

**Expected Output**:
```json
{
  "stage": "3. Agent Analysis & Patch Proposal",
  "agent_suggestions": [
    {
      "issue": "fare_usd type mismatch",
      "solution": "CAST with tolerance..."
    }
  ],
  "proposed_compat_view": "CREATE OR REPLACE VIEW..."
}
```

---

## Example 5: Enable Compat View

**Input**: `"enable compat"`

**Expected Output**:
```json
{
  "stage": "4. Feature Flag & Read Flights",
  "feature_flag_enabled": true,
  "view_used": "gold.flights_pricing_compat"
}
```

---

## Example 6: Apply v2 Schema

**Input**: `"apply v2"`

**Prerequisites**: Must have raw data in staging (run Batch B first)

**Expected Output**:
```json
{
  "stage": "5. v2 Schema Applied & Replay Successful",
  "validation_result": "PASSED (v2)",
  "v2_schema_changes": {
    "added_column": "channel (nullable VARCHAR)"
  }
}
```

---

## Test Data Samples

### Valid Record (Batch A)
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

### Invalid Record (Batch B - Type Error)
```json
{
  "flight_id": "DL567",
  "origin": "ATL",
  "destination": "LAX",
  "depart_ts": "2025-06-02T09:30:00Z",
  "cabin": "ECONOMY",
  "fare_usd": "three hundred",  // ❌ String instead of number
  "carrier_code": "DL",
  "currency": "USD",
  "taxes_usd": 47.1
}
```

### Invalid Record (Batch B - Additive Column)
```json
{
  "flight_id": "DL567",
  "origin": "ATL",
  "destination": "LAX",
  "depart_ts": "2025-06-02T09:30:00Z",
  "cabin": "ECONOMY",
  "fare_usd": 450.0,
  "carrier_code": "DL",
  "currency": "USD",
  "taxes_usd": 47.1,
  "channel": "mobile"  // ❌ Not in v1 schema
}
```

---

## Validation Rules Reference

### v1 Contract Rules

| Field | Rule | Example Valid | Example Invalid |
|-------|------|---------------|------------------|
| `flight_id` | string, min 3 chars | `"AA1234"` | `"AA"` (too short) |
| `origin` | string, exactly 3 chars | `"JFK"` | `"JFKX"` (too long) |
| `destination` | string, exactly 3 chars | `"SFO"` | `"SF"` (too short) |
| `depart_ts` | valid timestamp | `"2025-06-01T16:00:00Z"` | `"invalid"` |
| `cabin` | enum: ECONOMY, PREMIUM, BUSINESS, FIRST | `"ECONOMY"` | `"COACH"` |
| `fare_usd` | number >= 0 | `329.5` | `"three hundred"` |
| `carrier_code` | string, 2-3 chars | `"AA"` | `"A"` (too short) |
| `currency` | enum: USD, EUR, GBP | `"USD"` | `"CAD"` |
| `taxes_usd` | number >= 0 or null | `54.2` or `null` | `-10` (negative) |

### v2 Contract Rules (extends v1)

| Field | Rule | Notes |
|-------|------|-------|
| `fare_usd` | number >= 0 or null | Tolerates string input, converts to null on failure |
| `channel` | string or null | New nullable column |

---

## Troubleshooting Test Cases

### Issue: "No quarantine items"

**Cause**: Ran "propose patch" before running Batch B

**Solution**: Run Batch B first, then propose patch

### Issue: "No raw data found"

**Cause**: Ran "apply v2" without any ingestion

**Solution**: Run Batch B first to create staging data

### Issue: Database state resets

**Cause**: n8n static data resets between workflow executions

**Solution**: This is expected behavior for the demo. In production, use persistent storage.

---

## Performance Benchmarks

Expected execution times (approximate):

- Setup: < 100ms
- Batch A ingestion: < 50ms
- Batch B ingestion: < 50ms
- Agent analysis: < 100ms
- Enable compat: < 50ms
- Apply v2: < 100ms

**Total workflow**: < 500ms

---

## Success Criteria

✅ Workflow completes without errors
✅ Batch A inserted into gold_v1
✅ Batch B quarantined (not lost)
✅ Agent proposes valid SQL
✅ Feature flag enables compat view
✅ v2 schema recovers quarantined data

---

**Happy Testing! 🧪**

