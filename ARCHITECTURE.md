# 📊 ARCHITECTURE — DESTROYER SYSTEM

## Full System Diagram

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│ TradingView      │    │  MiroFish     │    │  MT5 (XM)       │
│ (Browser)        │    │  AI Predictor │    │  Execution      │
│ Charts + Indicat.│    │  Predictions   │    │  Trade Engine   │
└──────┬───────────┘    └──────┬───────┘    └──────┬──────────┘
       │                       │                   │
       ▼                       ▼                   │
┌─────────────────┐    ┌──────────────┐            │
│ agent-browser   │    │  Groq API     │            │
│ (Headless       │    │  llama-3.3-70b│            │
│  Chrome --no-s) │    └──────┬───────┘            │
└──────┬──────────┘           │                    │
       │                      ▼                    │
       │              ┌──────────────┐             │
       └─────────────►│  OPENCLAW    │             │
                      │  Cortana      │             │
                      │  Agent        ├─────────────┘
                      │  :18789       │
                      │  Webhook:8721 │
                      └──────┬───────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  Telegram Bot    │
                    │  Notifications   │
                    └─────────────────┘
```

## Infrastructure
- **AWS VPS** — Ubuntu 24.04, ip-172-31-40-81, Public IP: 16.170.225.77
- **Security Group** — launch-wizard-8 (SSH:22, Webhook:8721, Gateway:18789)
- **Model** — qwen/qwen3.6-plus:free via OpenRouter (1M context, 65K output)

## Services
| Port | Service | Status |
|------|---------|--------|
| 18789 | OpenClaw Gateway | ✅ |
| 8721 | TV Webhook Server | ✅ |
| 3000 | MiroFish Frontend | Installed |
| 5001 | MiroFish Backend | Installed |

## Key Files
| Path | Purpose |
|------|---------|
| `~/.openclaw/openclaw.json` | Agent config |
| `~/.openclaw/workspace/` | Agent workspace |
| `~/.agent-browser/tradingview-ryan.json` | TV session |
| `~/MiroFish/.env` | MiroFish keys |

---
*2026-04-04*
