#!/bin/bash

# Test script for Schema Drift Detection Webhook
# Usage: ./test-webhook.sh [n8n-base-url]
# Example: ./test-webhook.sh http://localhost:5678

N8N_BASE_URL=${1:-"http://localhost:5678"}
WEBHOOK_PATH="schema-drift/ingest"
WEBHOOK_URL="${N8N_BASE_URL}/webhook/${WEBHOOK_PATH}"

echo "🚀 Testing Schema Drift Detection Webhook"
echo "📍 Webhook URL: ${WEBHOOK_URL}"
echo ""

# Test 1: Valid record (should pass)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Valid Record (Should Pass ✅)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -X POST "${WEBHOOK_URL}" \
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
  }' | jq '.'
echo ""
echo ""

# Wait a moment
sleep 1

# Test 2: Schema drift - type error (should quarantine)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Schema Drift - Type Error (Should Quarantine 🛑)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -X POST "${WEBHOOK_URL}" \
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
  }' | jq '.'
echo ""
echo ""

# Wait a moment
sleep 1

# Test 3: Schema drift - additive column (should quarantine)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Schema Drift - Additive Column (Should Quarantine 🛑)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -X POST "${WEBHOOK_URL}" \
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
  }' | jq '.'
echo ""
echo ""

# Wait a moment
sleep 1

# Test 4: Multiple records (batch)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: Batch Processing (Multiple Records)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -X POST "${WEBHOOK_URL}" \
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
        "fare_usd": "1200",
        "carrier_code": "AF",
        "currency": "EUR",
        "taxes_usd": 150.0,
        "booking_source": "website"
      }
    ]
  }' | jq '.'
echo ""
echo ""

echo "✅ All tests completed!"
echo ""
echo "Check the n8n workflow execution logs to see detailed outputs."

