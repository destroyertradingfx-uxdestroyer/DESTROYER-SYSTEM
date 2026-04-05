# ⚡ DESTROYER TRADING SYSTEM — Full Documentation

**Owner:** Ryan
**Company:** DESTROYER Trading Systems
**Agent:** Cortana (OpenClaw AI Agent)
**VPS:** AWS Ubuntu 24.04 (ip-172-31-40-81)
**Public IP:** 16.170.225.77

---

## 🎯 WHAT THIS AGENT DOES

Cortana is an AI-powered algorithmic trading systems agent. Her job is to:

1. **Monitor TradingView charts** via headless browser automation (agent-browser)
2. **Analyze market conditions** using multi-agent swarm intelligence (MiroFish OASIS)
3. **Generate trade setups** with entry, stop-loss, and take-profit levels
4. **Execute trades** via MT5/MT4 through API bridge (future integration)
5. **Report findings** via Telegram or other messaging surfaces
6. **Maintain continuous backups** of research, analysis, and system configuration

She acts as a full algorithmic trading analyst — reading charts, running simulations, building strategies, and managing the DESTROYER multi-strategy system.

---

## 📦 REPO STRUCTURE

```
DESTROYER-SYSTEM/
├── README.md                    # ← You are here
├── OPENCLAW_SETUP.md            # OpenClaw agent config (models, context, memory)
├── CREDENTIALS.md               # 🔒 All login info & API key locations
├── QUICKSTART.md                # 5-minute system setup
├── ARCHITECTURE.md              # Full system architecture diagram
├── SOUL.md                      # Agent personality & execution constitution
├── IDENTITY.md                  # Agent role definition
├── USER.md                      # Ryan's profile, protocols 1-4
├── MEMORY.md                    # Operational state + decisions log
├── AGENTS.md                    # Workflow procedures
├── TOOLS.md                     # Environment-specific notes
├── HEARTBEAT.md                 # Periodic check tasks
├── TV_AUTOMATION_REFERENCE.md   # TradingView element refs + commands
├── TRADINGVIEW_AUTOMATION.md    # TV browser automation guide
├── MIROFISH_SETUP.md            # MiroFish AI prediction engine setup
├── CHROME_EXTENSION.md          # TradingView Chrome extension
├── WEBHOOK_SERVER.md            # Signal receiver setup
├── BACKUP_PROCEDURES.md         # Memory + system backup procedures
├── memory/                      # Daily memory logs
├── trading/                     # Trading scripts + code
│   ├── chrome-extension/        # Chrome extension for TV data scraping
│   │   ├── manifest.json
│   │   ├── background.js
│   │   ├── popup.html
│   │   ├── popup.js
│   │   ├── injector.js
│   │   └── icons/
│   ├── webhook-server/          # Signal receiver (Python + Node.js)
│   │   ├── server.py
│   │   ├── server.js
│   │   └── https-server.py
│   ├── signal-processor/        # Signal analysis engine
│   │   └── processor.py
│   ├── bookmarklet/             # TV data pusher bookmarklets
│   │   └── tv-data-pusher-v2.js
│   ├── tv-mcp-server/           # MCP server for TV integration
│   │   └── server.py
│   └── MIROFISH-XAUUSD-PROFESSIONAL.pdf  # Full swarm report
└── scripts/                     # Backup & maintenance scripts
    ├── memory-backup-supermemory.sh
    ├── memory-weekly-audit.sh
    └── update-github-backup.sh
```

---

## ⚙️ REQUIRED SKILLS & TOOLS

### Core System
| Tool | Version | Purpose | Install Command |
|------|---------|---------|-----------------|
| **OpenClaw** | 2026.4.2 | AI agent runtime | `npm i -g openclaw` |
| **Node.js** | 22.x | Core runtime | Pre-installed on VPS |
| **Python** | 3.12 | Backend scripts | Pre-installed on Ubuntu |
| **Git** | Latest | Version control | `sudo apt install git` |
| **GitHub CLI** | Latest | Repo management | `sudo apt install gh` |

### Browser Automation
| Tool | Version | Purpose | Install Command |
|------|---------|---------|-----------------|
| **agent-browser** | Latest | Headless Chrome automation | `npm install -g agent-browser` |
| **agent-browser install** | — | Install headless Chrome | `agent-browser install --with-deps` |

### AI & Prediction Engine
| Tool | Source | Purpose | Install Command |
|------|--------|---------|-----------------|
| **MiroFish** | github.com/666ghj/MiroFish | Swarm intelligence prediction | Clone → `npm run setup:all` |
| **uv** | Latest | Python package manager | `pip3 install uv` |
| **Zep Cloud** | app.getzep.com | Memory graph storage | API key in .env |

### CLI Tools
| Tool | Purpose | Install Command |
|------|---------|-----------------|
| **ngrok** | HTTPS tunnel for webhooks | Download from ngrok.com → `./ngrok authtoken <token>` |
| **wkhtmltopdf** | Generate professional PDF reports | `sudo apt install wkhtmltopdf` |
| **curl** | HTTP requests | Pre-installed |
| **ffmpeg** | Audio/video processing | `sudo apt install ffmpeg` |
| **edge-tts** | Voice message generation | `pip3 install edge-tts --break-system-packages` |

### OpenClaw Skills (from ClawHub)
| Skill | Purpose | Install Command |
|-------|---------|-----------------|
| agent-browser-clawdbot | Browser automation skill | `clawhub install agent-browser-clawdbot` |
| healthcheck | Security hardening | `clawhub install healthcheck` |
| mcporter | MCP server access | `clawhub install mcporter` |
| clawhub | Skill marketplace CLI | `npm i -g clawhub` |

### API Keys Required
| Service | Purpose | Where to Get |
|---------|---------|-------------|
| TradingView | Chart access & data | tradingview.com (account needed) |
| OpenRouter | LLM access (Qwen 3.6+) | openrouter.ai/keys |
| Groq | LLM access (Llama 70B) | console.groq.com/keys |
| Zep Cloud | Memory graph | app.getzep.com |
| Supermemory | Memory backup API | supermemory.ai |
| ngrok | HTTPS tunnel | dashboard.ngrok.com |

---

## 🚀 QUICK START

### 1. Clone & Setup
```bash
git clone https://github.com/destroyertradingfx-uxdestroyer/DESTROYER-SYSTEM.git
cd DESTROYER-SYSTEM
```

### 2. Install Core Dependencies
```bash
# OpenClaw setup (see OPENCLAW_SETUP.md)
npm i -g openclaw

# Browser automation
npm install -g agent-browser
agent-browser install --with-deps

# MiroFish (optional - for swarm predictions)
git clone https://github.com/destroyertradingfx-uxdestroyer/MiroFish.git
cd MiroFish && npm run setup:all && cd ..
```

### 3. Configure API Keys
Edit `CREDENTIALS.md` and add your keys to:
- `~/.openclaw/openclaw.json` (OpenClaw config)
- `~/MiroFish/.env` (MiroFish config)
- `~/.config/ngrok/ngrok.yml` (ngrok config)

### 4. Start Services
```bash
# OpenClaw agent
openclaw gateway start

# TV Webhook Server
python3 trading/webhook-server/server.py &

# MiroFish (optional)
cd ~/MiroFish && npm run dev &
```

### 5. Verify Everything
```bash
openclaw gateway status
curl http://127.0.0.1:8721/health
curl http://127.0.0.1:5001/health
```

---

## 🏗️ ARCHITECTURE

```
TradingView (Browser)  →  agent-browser  →  OpenClaw (Cortana)  →  MT5 Execution
                              ↓
                      MiroFish AI Predictor (OASIS Swarm)
                              ↓
                       Zep Cloud Memory Graph
                              ↓
                    Telegram Bot → User Reports
```

**Flow:**
1. agent-browser opens TradingView, reads charts, indicators, price data
2. Data is sent to MiroFish for swarm intelligence analysis
3. MiroFish simulates 13+ agent personas (traders, fund managers, analysts)
4. Report Agent synthesizes predictions into actionable trade setups
5. Cortana delivers analysis to Ryan via Telegram
6. Future: Trade setups routed to MT5 for execution

---

## 💾 BACKUP SYSTEM

| Task | Frequency | Mechanism |
|------|-----------|-----------|
| **GitHub Backup** | Every 2 hours | `update-github-backup.sh` via cron |
| **Memory to Supermemory** | Every 6 hours | `memory-backup-supermemory.sh` via cron |
| **Memory Audit** | Weekly (Sunday) | `memory-weekly-audit.sh` via cron |
| **Monthly Audit** | Monthly | Manual review + tool check |

Crontab entries:
```cron
0 */2 * * * update-github-backup.sh
0 */6 * * * memory-backup-supermemory.sh
0 0 * * 0 memory-weekly-audit.sh
```

---

## 📊 CURRENT STATUS

| Component | Status | Port |
|-----------|--------|------|
| OpenClaw Gateway | ✅ Running | 18789 |
| TV Webhook Server | ✅ Running | 8721 |
| MiroFish Backend | ✅ Running | 5001 |
| Chrome Extension | ✅ Pushed to GitHub | — |
| ngrok Tunnel | ✅ Active | Dynamic |

---

## 📝 PROTOCOLS

### Protocol 1 — Strategy Optimization
1. Identify underperforming strategy (low PF, high DD, inconsistency)
2. Break down internal logic (entry, exit, filters)
3. Compare against high-performers (e.g., Warden)
4. Generate 2-3 improved variants
5. Backtest each rigorously
6. Deploy best performer

### Protocol 2 — Execution Precision
1. Establish HTF bias (Monthly / H4)
2. Drop to LTF (15m → 5m)
3. Identify liquidity zones / entry triggers
4. Execute sniper entry with predefined SL/TP
5. Enforce fixed profit rule ($20 close target)

### Protocol 3 — Risk Management
1. Max risk per trade (~$5)
2. Fixed TP ($10-$20 range, or strict $20 live)
3. Monitor DD thresholds
4. Block trades if risk exposure exceeds limits
5. Adjust allocation per strategy based on PF

### Protocol 4 — System Evolution
1. Audit full system (6-year backtest baseline)
2. Identify bottlenecks (VAR blocking, low trade count)
3. Reallocate capital to strongest strategies
4. Remove/rebuild weak components
5. Re-test full integration
6. Deploy upgraded version

---

**Last Updated:** 2026-04-05
**Version:** 1.0
**Maintainer:** Cortana (AI Agent) via OpenClaw
