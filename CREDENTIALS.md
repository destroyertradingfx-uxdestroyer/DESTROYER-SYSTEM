# 🔒 CREDENTIALS — DESTROYER SYSTEM

**⚠️ KEEP PRIVATE — Do not share publicly**

---

## TradingView
| Field | Value |
|-------|-------|
| **Email** | moltbotdestroyer@gmail.com |
| **Password** | Your password (see below) |
| **URL** | https://www.tradingview.com/ |
| **Plan** | Free tier (no webhook alerts) |
| **Session State** | `~/.agent-browser/tradingview-ryan.json` |

## OpenClaw
| Field | Value |
|-------|-------|
| **Gateway Port** | 18789 |
| **Config File** | `~/.openclaw/openclaw.json` |
| **Model** | qwen/qwen3.6-plus:free (1M context, 65K max tokens) |

## MT5 Trading
| Field | Value |
|-------|-------|
| **Broker** | XM |
| **Platform** | MT5 |
| **VPS** | Ubuntu AWS (ip-172-31-40-81) |

## API Keys (Setup Required)
| Service | Where to Get | Setup File |
|---------|-------------|------------|
| Groq (LLM) | https://console.groq.com/keys | `~/MiroFish/.env` |
| Zep Cloud (Memory) | https://app.getzep.com/ | `~/MiroFish/.env` |
| Supermemory | https://supermemory.ai/ | `~/.openclaw/openclaw.json` |
| OpenRouter | https://openrouter.ai/keys | `~/.openclaw/openclaw.json` |
| Telegram Bot | @BotFather | `~/.openclaw/openclaw.json` |
| ngrok | https://dashboard.ngrok.com/signup | `~/.config/ngrok/ngrok.yml` |

## Webhook Server
| Field | Value |
|-------|-------|
| **Port** | 8721 |
| **Auth Token** | `destroyer-sig-2026` |

## GitHub
| Field | Value |
|-------|-------|
| **Username** | destroyertradingfx-uxdestroyer |
| **Auth** | gh CLI (repo, read:org, workflow scopes) |

---

## SESSION STATE FILES (on VPS)
| File | Purpose |
|------|---------|
| `~/.agent-browser/tradingview-ryan.json` | TradingView login cookies |
| `~/.config/ngrok/ngrok.yml` | ngrok auth token |
| `~/.openclaw/openclaw.json` | OpenClaw full config |
| `~/.config/gh/hosts.yml` | GitHub CLI auth |
| `~/MiroFish/.env` | MiroFish API keys (Groq + Zep) |

---

*API keys are stored locally on the VPS. Do not commit them to git.*
*Last Updated: 2026-04-04*
