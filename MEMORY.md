# MEMORY.md — Operational State & Rules

## User Profile
- **Ryan** — Algorithmic Trader, DESTROYER Trading Systems
- **Timezone:** SAST (UTC+2)
- **Style:** Direct, analytical, no-fluff
- **Platforms:** MT5 (XM), TradingView, Ubuntu VPS
- **Growth Goal:** $20 → $2,000 in 3 months

## Active Projects
- **DESTROYER System** — Multi-strategy EA, V28.1_RELAXED was proven performer (PF 2.26, $3,741 profit, 6% DD)
- **Warden Strategy** — High PF priority, needs restoration & optimization
- **Reaper Strategy** — Underperforming, needs rebuild or replacement
- **Silicon-X** — Strategy module in development

## System Config
- **Model:** qwen/qwen3.6-plus:free (1M context, 65K max tokens)
- **VPS:** Ubuntu, AWS (ip-172-31-40-81)
- **Channels:** Telegram (primary)

## Standing Operating Rules
- Always use Protocol 1-4 from USER.md for strategy/optimization work
- Backtest validation before any deployment recommendation
- Present 2-3 approaches with trade-offs
- File diffs + progress % on any build task
- Escalate after 16-min stall on any task

## Memory Backup Protocol
- **Every 6 hours:** Auto-backup to Supermemory (cron → `memory-backup-supermemory.sh`)
- **Weekly (Sunday):** Memory audit (`memory-weekly-audit.sh`) — consolidate duplicates, delete stale
- **Monthly:** Full audit — what's working, what's missing, update tools/API keys
- **Supermemory API:** Configured in openclaw.json integrations.supermemory

## Known Issues
- OpenClaw context compaction was causing "context limit exceeded" — fixed with 50K reserve floor
- MT5 HTTP API skill installed (trading-devbox, mt5-httpapi) — needs configuration
- mt5-trading-assistant skipped (VirusTotal flagged suspicious)

## Decisions Log
| Date | Decision | Reason |
|------|----------|--------|
| 2026-04-03 | Set contextWindow to 1M, maxTokens to 65K, reserveFloor to 50K | Model actually supports 1M context, config was stale at 16K |
| 2026-04-03 | Adopted Agents-in-a-Box architecture | Fix context bloat, execution stalling, mixed concerns |
| 2026-04-03 | Named agent "Cortana" | Trading systems identity |

---
*Updated: 2026-04-03*
