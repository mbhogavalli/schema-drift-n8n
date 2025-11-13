# Quick Start Guide

## 🚀 Repository

**GitHub**: https://github.com/mbhogavalli/schema-drift-n8n

## ⚡ 5-Minute Setup

1. **Import Workflow**
   - Open n8n
   - Import `n8n-schema-drift-demo.json`
   
2. **Run Demo**
   - Click "Chat Trigger" node
   - Click "Execute Node"
   - Watch it run!

3. **View Outputs**
   - Click each node to see its output
   - Check database state at each stage

## 📁 Files Included

- `n8n-schema-drift-demo.json` - Main workflow file
- `README.md` - Complete documentation
- `SETUP.md` - Detailed setup instructions
- `VISUAL_GUIDE.md` - Step-by-step visual guide
- `test-examples.md` - Test cases and examples

## 🎯 What It Demonstrates

✅ Schema validation with v1 contract
✅ Schema drift detection (type errors, additive columns)
✅ Quarantine pattern (never lose data)
✅ Agent-driven compatibility view proposal
✅ Feature flags for gradual migration
✅ Schema evolution (v1 → v2)
✅ Data replay from quarantine

## 💡 Quick Commands

- `"run demo"` - Full demo (default)
- `"ingest batch A"` - Test good data
- `"ingest batch B"` - Test drift detection
- `"propose patch"` - See agent analysis
- `"enable compat"` - Enable feature flag
- `"apply v2"` - Apply v2 schema

## 📊 Expected Outputs

After running the full demo, you should see:

- **Stage 0**: Setup complete (0 records)
- **Stage 1**: Batch A ingested ✅ (1 record in gold_v1)
- **Stage 2**: Batch B quarantined 🛑 (1 record in quarantine)
- **Stage 3**: Agent proposes compat view 🤖
- **Stage 4**: Compat view enabled 🚩
- **Stage 5**: v2 schema applied ✅ (1 record in gold_v2)

## 🆘 Need Help?

- Check `README.md` for detailed documentation
- See `VISUAL_GUIDE.md` for visual walkthrough
- Review `SETUP.md` for troubleshooting

---

**Ready to go! Import the workflow and start exploring! 🎉**

