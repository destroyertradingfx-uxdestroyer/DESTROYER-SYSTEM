# 🚀 Quick Start — 5 Minutes

## 1. SSH to VPS
```bash
ssh ubuntu@16.170.225.77
```

## 2. Verify OpenClaw
```bash
openclaw gateway status
# If not running:
openclaw gateway start
```

## 3. Start TradingView Browser
```bash
agent-browser --args "--no-sandbox" \
  open "https://www.tradingview.com/chart/?symbol=OANDA:XAUUSD&interval=60"
```

## 4. Take Screenshot
```bash
agent-browser screenshot /tmp/chart.png
```

## 5. Read Indicators
```bash
agent-browser click @e87  # Data window
agent-browser snapshot -i --json
```

## Daily Workflow
1. Check OpenClaw status
2. Start agent-browser
3. Scan charts → screenshots → analysis
4. Report via Telegram

## Quick Commands
```bash
openclaw gateway restart      # Restart agent
openclaw doctor --fix          # Fix config
~/ngrok-bin http 8721          # Start HTTPS tunnel
```

---
*Saved: 2026-04-04*
