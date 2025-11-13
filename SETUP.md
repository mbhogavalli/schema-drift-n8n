# Setup Guide - Schema Drift Demo

## Prerequisites

1. **n8n Installation**
   - Local: Download from [n8n.io](https://n8n.io/download/)
   - Cloud: Sign up at [n8n.cloud](https://n8n.cloud)
   - Docker: `docker run -it --rm --name n8n -p 5678:5678 n8nio/n8n`

2. **Access to n8n**
   - Local: `http://localhost:5678`
   - Cloud: Your n8n.cloud URL

## Step-by-Step Setup

### 1. Import Workflow

1. Open n8n in your browser
2. Click **"Workflows"** in the left sidebar
3. Click **"Import from File"** button (top right)
4. Select `n8n-schema-drift-demo.json`
5. The workflow will appear in your workflow list

### 2. Verify Workflow Structure

You should see these nodes in order:

1. **Chat Trigger** (Manual Trigger)
2. **Parse Chat Command** (Code)
3. **Setup Schemas & v1 Contract** (Code)
4. **Ingest Batch A (Good Data)** (Code)
5. **Ingest Batch B (Drift Data)** (Code)
6. **Agent: Propose Patch** (Code)
7. **Enable Compat View (Feature Flag)** (Code)
8. **Apply v2 Schema & Replay** (Code)
9. **Format Final Output** (Code)

### 3. First Run

1. Click on the **"Chat Trigger"** node
2. Click **"Execute Node"** button (or press `Ctrl/Cmd + Enter`)
3. Watch the workflow execute step by step
4. Click on each node to see its output

### 4. Understanding Outputs

Each node produces output with:
- **Stage name**: Current step in the workflow
- **Timestamp**: When the step executed
- **Database state**: Record counts in each schema
- **Validation results**: Pass/fail with error details
- **Action taken**: What happened (inserted, quarantined, etc.)

## Troubleshooting

### Workflow Won't Execute

- **Check node connections**: Ensure all nodes are connected in sequence
- **Check Code nodes**: Verify JavaScript syntax is correct
- **Clear static data**: Go to workflow settings → Clear static data

### No Output Appearing

- **Check execution log**: Click "Executions" tab to see full logs
- **Check node errors**: Red nodes indicate errors
- **Verify static data**: Some nodes depend on `$workflow.staticData`

### Database State Not Persisting

- **Static data scope**: `$workflow.staticData` persists within a workflow execution
- **Between executions**: Data resets between workflow runs (by design for demo)
- **Production**: Use actual database connections for persistence

## Advanced Usage

### Custom Chat Commands

Modify the "Parse Chat Command" node to add custom commands:

```javascript
if (chatInput.includes('custom command')) {
  command = 'custom_action';
}
```

### Adding More Validation Rules

Edit the `validateV1` function in "Setup Schemas & v1 Contract" node:

```javascript
// Add custom validation
if (record.some_field && record.some_field.length > 100) {
  errors.push('some_field: max length 100');
}
```

### Connecting to Real DuckDB

Replace static data with actual DuckDB connection:

1. Install DuckDB Node.js package: `npm install duckdb`
2. Create a new Code node with DuckDB connection
3. Replace `$workflow.staticData.db` with actual queries

## Next Steps

1. **Run the full demo**: Execute "Chat Trigger" with default input
2. **Experiment**: Try different chat commands
3. **Extend**: Add your own validation rules or schema versions
4. **Share**: Use this demo in presentations or training sessions

## Support

For issues or questions:
- Check the [README.md](./README.md) for detailed documentation
- Review n8n [documentation](https://docs.n8n.io/)
- Open an issue in the repository

