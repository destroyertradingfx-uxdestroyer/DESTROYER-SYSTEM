# DESTROYER TRADING SYSTEM — Complete Project History

## 1. SYSTEM OVERVIEW

**Owner:** Ryan (@Its_justryan)
**Agent:** Cortana (OpenClaw AI)
**VPS:** AWS Ubuntu 24.04 (ip-172-31-40-81, Public: 16.170.225.77)
**Goal:** $20 → $2,000 in 3 months via algorithmic trading
**Core System:** DESTROYER multi-strategy EA (MQL4, MT5)

---

## 2. INFRASTRUCTURE

| Component | Status | Details |
|-----------|--------|---------|
| OpenClaw Gateway | ✅ | Port 18789, model qwen/qwen3.6-plus:free |
| TV Webhook Server | ✅ | Port 8721 |
| MiroFish Backend | ✅ | Port 5001, OpenRouter Qwen |
| ngrok Tunnel | ✅ | Tunneling 8721 for HTTPS |
| Chrome Extension | ✅ | Pushed to GitHub |
| Memory Backups | ✅ | Every 6h to Supermemory, weekly audit |

---

## 3. PROBLEMS FACED & FIXES

### 3.1 OpenClaw Context "Context Limit Exceeded"
**Problem:** Agent kept hitting context limit during sessions
**Root Cause:** contextWindow set to stale 16K instead of 1M
**Fix:** Set contextWindow to 1M, maxTokens to 65K, reserveFloor to 50K
**Result:** Context compaction stopped killing sessions
**Date:** 2026-04-03

### 3.2 MiroFish Fake Swarm Analysis
**Problem:** First attempt used 3 sequential Groq API calls with indicator data (SuperTrend, RSI) → called it "swarm analysis" but produced 0 usable agents with no personalities
**Root Cause:** Seed data was indicator thresholds, not trader personas
**Fix:** Rebuilt with 13 named personas (Sarah Chen, Marcus Webb, Aisha Patel, etc.) with distinct strategies and personalities
**Lesson:** "Don't fake MiroFish — real multi-agent simulation requires real agent personas"
**Result:** Full pipeline working — Upload → Ontology → Graph Build → Entity Simulation → Report Agent. XAUUSD analysis completed showing range-bound 4,650-4,690
**Date:** 2026-04-05

### 3.3 Groq Rate Limit on MiroFish
**Problem:** Groq free tier has 100K tokens/day limit — exhausted by full MiroFish pipeline
**Fix:** Switched to OpenRouter Qwen via `qwen/qwen3.6-plus:free` — no hard rate limits, slightly slower but reliable
**Date:** 2026-04-05

### 3.4 MT5 HTTP API Skill (VirusTotal Flagged)
**Problem:** mt5-trading-assistant skill flagged by VirusTotal as suspicious
**Decision:** Skipped for security. Using standard MT5 bridge instead
**Date:** 2026-04-03

### 3.5 agent-browser Headless Chrome Crashing
**Problem:** Headless Chrome keeps crashing when opening new URLs
**Workaround:** Keep one persistent browser session, navigate within it instead of opening new windows
**Root Cause:** `--no-sandbox` flag needed on VPS, memory limits
**Status:** Partially resolved — stable with single-session approach
**Date:** 2026-04-04

### 3.6 ngrok Free-Tier Interstitial Warnings
**Problem:** ngrok free tier adds HTML interstitial page warning → POST requests to webhook server get intercepted
**Impact:** Signal processor receives HTML instead of JSON
**Workaround:** Running direct port 8721 on VPS for internal use, ngrok only for external testing
**Date:** 2026-04-04

### 3.7 DESTROYER V26 — Modify Loop (THE BIGGEST PROBLEM)
**Problem #1 — Warden Trailing Stop Loop:**
- Single order modified **1,178 times** in 2.5 days
- SL ping-pongs: reset to original → move down → reset → repeat every tick
- `ManageWardenTrailingStop()` called on EVERY tick with no throttle
- Warden generated 3,789 in profit but wasted massive CPU on modifications

**Problem #2 — Hubble Trail Loop:**
- Single order modified **3,530 times** per trade
- `ManageSiliconX_HubbleTrail()` ran every tick, trailing pending orders constantly
- 1.5M modifications total for only 441 trades in 6 years

**Fix #1 (Warden):** Add `static datetime lastWardenTrail` throttle → once per new bar
**Fix #2 (Hubble):** Add `static datetime lastTrailModify` → 30-second cooldown
**Status:** Identified and patched in V28.19 SURGICAL version
**Date:** 2026-04-05

### 3.8 DESTROYER V26 — Three Disabled Features (MASSIVE IMPACT)
**Problem:** Three critical toggles were set to `false` by default, silently killing most of the system:

| Input | V26 Default | Impact When False |
|-------|------------|-------------------|
| `InpAlphaExpand` | **false** | ALL V24/V25/V26 features disabled (elastic scoring, math-first, re-entries) |
| `InpElasticScoring` | **false** | V25 continuous scoring layer completely OFF |
| `InpMathFirst` | **false** | MathReversal (400-600 additional trades) COMPLETELY OFF |

**Discovery:** V26 had code for all these features but they were opt-out by default
**Fix:** Changed all three to `true` in V28.19 SURGICAL
**Expected Impact:** 468 trades → 1,800+ trades with math reversal enabled
**Date:** 2026-04-05

### 3.9 Silicon-X $1.44M vs V26 $5,463 — The Analysis
**V26 Performance (6 years, EURUSD, $10K):**
- 468 trades, PF 2.35, Max DD 11.91%, Net: $5,463

**Silicon-X Standalone (same period, XAUUSD, $10K):**
- 1,480 trades, PF 11.72, Max DD 4.88%, Net: $1,442,407

**Why Silicon-X wins 837×:**
1. Grid pipelining with 1.6 lot exponent (massive lot compounding)
2. Trailing pending orders that actually execute (V26's pipelining was disabled)
3. Basket close at $400 → clean profit capture
4. Hubble mean reversion catching real extremes (LengthA=242, DeviationA=5.2)
5. No VAR blocking killing valid setups

**V26 Strategy Breakdown (who carries what):**
| Strategy | Trades | Net $ | PF | % of Profit |
|----------|--------|-------|-----|-------------|
| **Warden** | 20 | **$3,789** | 3.13 | 69% |
| Silicon-X | 192 | $1,595 | 2.70 | 29% |
| Reaper | 247 | $41 | 1.04 | 1% |
| Titan | 5 | $21 | 2.59 | <1% |
| MeanReversion | 9 | $15 | 1.11 | <1% |

**Key Finding:** Warden carries 69% of ALL profit with only 20 trades. Reaper loses money despite 247 trades (PF 1.04).

### 3.10 V28.19 Two-Versions Approach
**SCRATCH version (747 lines, 28KB):** Complete from-scratch MQ4 rewrite with VWAP anchor + pipeliner grid + math-first + mean reversion. Clean, no legacy.

**SURGICAL version (12,240 lines, 504KB):** V26 base with only 5 targeted changes:
1. Hubble Trail → 30s throttle (was 3,530 mods/trade)
2. Warden Trail → per-bar throttle (was every tick)
3. InpAlphaExpand → true (was false)
4. InpElasticScoring → true (was false)
5. InpMathFirst → true (was false)

Both pushed to separate GitHub links for backtesting.

### 3.11 Version String MQL5 Market Incompatibility
**Problem:** `#property version   "28.19.SURGICAL"` rejected by MQL5 Market compiler — must be `xxx.yyy` format
**Fix:** Changed to `#property version   "28.190"`
**Lesson:** MQL5 version strings strictly require exactly two numeric segments

---

## 4. CLAUDE CODE ARCHITECTURE RESEARCH (April 2026 Leak)

*Ryan said "not yet, remind me" — saved for future implementation*

- **5-level system prompt priority:** Override → Coordinator → Agent → Custom → Default
- **KAIROS daemon mode:** 210 file references for autonomous background agent
- **87 hidden feature flags:** PROACTIVE, COORDINATOR_MODE, CONTEXT_COLLAPSE, etc.
- **Static/dynamic prompt boundary:** 90% token cache savings
- **4-level tool permission model:** Granular access control
- **Subagent hierarchy:** cheap model (scan) → expensive model (analysis) → most expensive (decision)
- **Cost optimization:** output reservation 8K default, subagents use cheapest model
- **Undercover mode:** Strategy protection in public repos

---

## 5. MEMORY BACKUP SYSTEM

| Task | Frequency | Mechanism |
|------|-----------|-----------|
| GitHub Backup | Every 2 hours | `update-github-backup.sh` via cron |
| Memory to Supermemory | Every 6 hours | `memory-backup-supermemory.sh` via cron |
| Memory Audit | Weekly (Sunday) | `memory-weekly-audit.sh` via cron |
| Monthly Audit | Monthly | Manual review + tool check |

---

## 6. LESSONS LEARNED

1. **Don't fake multi-agent systems** — real swarm intelligence requires real personas with distinct strategies
2. **Always check toggle defaults** — V26 had features built but disabled by default, killing 80% of potential
3. **Throttle on-tick operations** — any function modifying orders must have per-bar or time-based throttle
4. **Read the trade log, not just the summary** — the 1,178 modifications per trade only showed in the detailed log
5. **MQL5 version strings are strict** — `xxx.yyy` format only, no additional segments
6. **Modify loops are silent killers** — they don't crash, they just waste CPU and VPS resources
7. **Warden carries the whole system** — optimize it first, fix Reaper second
8. **Silicon-X pipelining was in V26 all along** — just disabled by three false toggles
9. **Don't rewrite from scratch when 5 lines fix it** — surgical patches beat full rewrites for proven codebases

---

*Last Updated: 2026-04-05 15:00 UTC*
*Status: DESTROYER EA files removed from repo — keeping infra and documentation only*
