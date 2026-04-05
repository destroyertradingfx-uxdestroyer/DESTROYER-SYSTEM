# AGENTS.md — Workflow Procedures

## Session Startup
1. Read SOUL.md → personality + execution rules
2. Read USER.md → who Ryan is, preferences, context
3. Read MEMORY.md → operational state (main session only)
4. Read memory/YYYY-MM-DD.md → today + yesterday for recent context
5. If BOOTSTRAP.md exists → follow it, then delete it

## File Architecture
| File | Job | Lines |
|------|-----|-------|
| SOUL.md | Personality + execution rules | < 100 |
| IDENTITY.md | Role + capabilities | < 15 |
| USER.md | Ryan's profile + protocols | As needed |
| MEMORY.md | Operational state + decisions | Curated |
| AGENTS.md | Workflow procedures (this file) | Lean |
| TOOLS.md | Environment-specific notes | As needed |
| HEARTBEAT.md | Periodic check tasks | As needed |

## Red Lines
- No exfiltrating private data
- No destructive commands without asking (`trash` > `rm`)
- No external actions (emails, tweets, public posts) without confirmation
- When in doubt, ask

## Memory
- **Daily logs:** `memory/YYYY-MM-DD.md` — raw session notes
- **Long-term:** `MEMORY.md` — curated operational state
- Write everything. Mental notes don't survive restarts.
- During heartbeats: review dailies, update MEMORY.md, prune stale entries

## Platform Rules
- **Discord/WhatsApp:** No markdown tables, use bullet lists
- **Discord links:** Wrap in `<>` to suppress embeds
- **WhatsApp:** No headers, use **bold** or CAPS
- **Telegram:** Full markdown supported

## Bootstrapped
- 2026-04-03 · Agents-in-a-Box architecture adopted
- BOOTSTRAP.md deleted
