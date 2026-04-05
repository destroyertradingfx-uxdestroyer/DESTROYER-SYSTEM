# 📊 TRADINGVIEW BROWSER AUTOMATION REFERENCE
Generated: 2026-04-04 20:25 UTC
Tool: agent-browser (Vercel Labs)
Session State: logged-in as moltbotdestroyer@gmail.com

---

## 🔑 AUTH
- Saved state: `/home/ubuntu/.agent-browser/tradingview-ryan.json`
- Load with: `agent-browser state load tradingview-ryan.json`
- No need to re-login as long as session cookies are valid

---

## 📍 ELEMENT REF MAP (Current Chart - XAUUSD 1H)
All refs are dynamic — change after each snapshot. Always re-snap before interacting.

### TOP BAR (Chart Controls)
| Ref ID | Name | Ref ID | Name |
|--------|------|--------|------|
| `@e41` | Symbol (XAUUSD) | `@e42` | Switch data type |
| `@e21` | Compare or Add Symbol | `@e60-64` | Timeframe radios |
| `@e63` | **1h (current, checked=true)** | `@e43` | Chart interval |
| `@e44` | Candles | `@e45` | Indicators, metrics, strategies |
| `@e46` | Indicator templates | `@e23` | Create Alert |
| `@e24` | Bar Replay | `@e25` | Layout setup |
| `@e26` | All changes saved | `@e49` | Manage layouts |
| `@e27` | Quick Search | `@e28` | Settings |
| `@e30` | Take a snapshot | `@e8` | Trade button |
| `@e9` | Share/Community | | |

### TIMEFRAMES (radio buttons)
```
[e60] 5 minutes    [unchecked]
[e61] 15 minutes   [unchecked]
[e62] 30 minutes   [unchecked]  
[e63] 1 hour       [checked ← CURRENT]
[e64] 4 hours      [unchecked]
```

### TOOLBAR (Drawing Tools)
| Ref ID | Name | Use Case |
|--------|-----|----------|
| `@e65` | Cross | Switch to crosshair cursor |
| `@e66` | Cursors | Cursor mode selector |
| `@e67` | Trendline | Draw trend lines |
| `@e68` | Trend tools | Trend-related tools |
| `@e69` | Fib retracement | Fibonacci retracement |
| `@e70` | Gann and Fibonacci tools | Gann/Fib tools |
| `@e71` | XABCD pattern | Harmonic patterns |
| `@e72` | Patterns | Chart patterns |
| `@e73` | Long position | Position tool |
| `@e74` | Forecasting tools | Price forecasting |
| `@e75` | **Brush** | Draw/mark on chart |
| `@e76` | Geometric shapes | Shapes |
| `@e77` | Text | Text annotations |
| `@e78` | Annotation tools | Annotations |
| `@e79` | Icon | Place icons |
| `@e80` | Icons | Icon palette |
| `@e32` | Measure | Distance/price measure |
| `@e33` | Zoom in | Zoom chart |
| `@e103` | Magnet mode | Snap to OHLC |
| `@e104` | Magnets | Magnet settings |
| `@e34` | Keep drawing | Keep tool active |
| `@e35` | Lock drawings | Lock/unlock drawings |
| `@e81` | Hide all drawings | Hide drawings |
| `@e83` | Remove objects | Delete drawings |

### CHART REGION
| Ref ID | Name | Use Case |
|--------|------|----------|
| `@e4` | Chart #1 region | Main chart area |
| `@e111` | Change symbol | Open symbol selector |
| `@e112` | Change interval | Open interval selector |
| `@e109` | Flag symbol | Add flag marker |
| `@e110` | More | More options |
| `@e113` | Market status | Status indicator |
| `@e105` | Show/hide indicators legend | Toggle legend |

### BOTTOM BAR (Price/OHLC)
| Ref ID | Name |
|--------|------|
| `@e36` | Timezone (20:25:55 UTC+2) |
| `@e51` | Timezone settings |

### RIGHT SIDEBAR
| Ref ID | Name |
|--------|------|
| `@e56` | Symbol |
| `@e57` | Last price |
| `@e58` | Chg (change) |
| `@e59` | Chg% (change %) |

### WATCHLIST PANEL
| Ref ID | Name | Data Shown |
|--------|------|-----------|
| `@e95` | Watchlist | Toggle panel |
| `@e52` | Add symbol | Add to watchlist |
| `@e53` | Advanced view | Full info panel |
| `@e54` | Settings | Watchlist settings |
| `@e114` | Indices | Index group |
| `@e120` | Stocks | Stock group |
| `@e124` | Futures | Futures group (Gold, Silver, Oil) |
| `@e128` | Forex | Forex group |
| `@e132` | Crypto | Crypto group |

### LEFT SIDEBAR (Navigation)
| Ref ID | Name | What It Opens |
|--------|------|---------------|
| `@e85` | Watchlist, details and news | Watchlist panel |
| `@e86` | Alerts | Manage alerts |
| `@e87` | Object tree and data window | Indicator values + objects |
| `@e88` | Chats | TradingView chats |
| `@e89` | Screeners | Stock/forex screeners |
| `@e106` | Pine | Pine Script editor |
| `@e90` | Calendars | Economic calendar |
| `@e91` | Community | Social feed |
| `@e92` | Notifications | TV notifications |
| `@e93` | Products | TV products |
| `@e94` | Help Center | Documentation |

### TIME PRESETS (top of chart)
```
[e10] 1 day in 1 minute
[e11] 5 days in 5 minutes
[e12] 1 month in 30 minutes
[e13] 3 months in 1 hour
[e14] 6 months in 2 hours
[e15] Year to day in 1 day
[e16] 1 year in 1 day
[e17] 5 years in 1 week
[e18] All data in 1 month
[e19] Go to (custom date range)
```

### FOOTER DATA
```
[e107] Gold Spot / U.S. Dollar (symbol info link)
[e97]  CFTC Commitments (fundamental data)
[e98]  More seasonals
[e99]  More technicals
[e100] Manage
[e101] Don't allow (cookies)
[e102] Accept all (cookies)
[e108] Our policy (cookies)
```

---

## ⚡ QUICK COMMANDS

### Change Symbol
```bash
agent-browser click @e111  # Change symbol
# Then snapshot to find search box
agent-browser fill @eX "EURUSD"
agent-browser press Enter
```

### Change Timeframe
```bash
# Via radio buttons:
agent-browser click @e61  # 15 min
agent-browser click @e64  # 4 hour

# Via time preset:
agent-browser click @e12  # 1 month / 30m
agent-browser click @e14  # 6 months / 2h
```

### Read Indicator Values
```bash
agent-browser click @e87  # Open data window
agent-browser snapshot -i --json
```

### Take Screenshot
```bash
agent-browser screenshot /tmp/tv-screenshot.png
```

### Open Pine Editor
```bash
agent-browser click @e106  # Pine button
agent-browser wait 2000
agent-browser snapshot -i --json
```

### Open Object Tree
```bash
agent-browser click @e87  # Object tree and data window
```

### Add Indicator
```bash
agent-browser click @e45  # Indicators, metrics, strategies
agent-browser wait 2000
agent-browser snapshot -i --json
# Then click desired indicator
```

### Bar Replay
```bash
agent-browser click @e24  # Bar Replay
```

### Create Alert
```bash
agent-browser click @e23  # Create Alert
```

### Symbol Search
```bash
agent-browser click @e27  # Quick Search
agent-browser fill @eX "BTCUSD"
agent-browser press Enter
```

---

## 📷 SCREENSHOT LOCATIONS
- `/tmp/tv-screenshot-*.png` — temporary screenshots
- `/tmp/aapl-chart.png` — AAPL screenshot
- `/tmp/gold-chart.png` — Gold Futures screenshot
- `/tmp/tv-login.png` — Login page screenshot
- `/tmp/tv-gold-chart.png` — XAUUSD chart with indicators

---

## 🛠️ KNOWN LIMITATIONS
- Cannot draw on canvas elements (actual chart area is a <canvas> tag — pixel-based)
- Cannot click specific price levels on the chart (no DOM refs for price coordinates)
- Cannot drag to draw lines (requires mouse drag on canvas)
- Drawing tools can only be activated, not used interactively

## 💡 WORKAROUNDS
- Use Object Tree (`@e87`) to read indicator values as text
- Navigate to specific symbols via Quick Search (`@e27`)
- Change timeframes via radio buttons (`@e60-64`) or presets (`@e10-18`)
- Read existing drawings from snapshot refs
- Screenshot entire chart for analysis

---

## 🔄 MAINTENANCE
- Refs change every time page updates — always re-snapshot before interacting
- Session state saved — no need to re-login daily
- If browser fails, restart with: `agent-browser --args "--no-sandbox" open "https://www.tradingview.com/chart/?symbol=OANDA:XAUUSD&interval=60"`

---

*This document is the source of truth for all TradingView automation commands. Refs may change — always snapshot first.*
