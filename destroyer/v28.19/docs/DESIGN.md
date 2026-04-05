# DESTROYER V28.19 — Design Specification

**Codename:** DESTROYER-VWAP
**Version:** 28.19
**Date:** 2026-04-05
**Objective:** Outperform Silicon-X on all metrics (higher PF, lower DD, higher trade frequency)

---

## CORE PHILOSOPHY V28.19

V28.19 replaces the old signal-driven paradigm with a **VWAP-anchored, multi-factor, LQR-optimized execution** system. Three key innovations:

1. **VWAP as the directional anchor** (not just an execution benchmark)
2. **Alpha combos** — stacking multiple weak signals into a strong composite
3. **LQR dynamic position sizing** — position adjustments react to real-time conditions, not just static rules

---

## SIGNAL ARCHITECTURE

### Layer 1: VWAP Trend Filter (Primary Signal)
**Source:** Zarattini & Aziz (2023), Humphery-Jenner (2011)

```
if price > VWAP AND VWAP slope > 0  →  BULLISH regime
if price < VWAP AND VWAP slope < 0  →  BEARISH regime
else                                  →  CHOP regime (no trade)
```

**VWAP Calculation (intraday):**
```
VWAP = Σ(HLC × Volume) / Σ(Volume)
where HLC = (High + Low + Close) / 3
```

**Dynamic VWAP (DVWAP):**
Instead of session-reset, use rolling VWAP over N bars (configurable: 60, 120, 240 bars).
This allows VWAP to function across multi-day positions.

**Noise Adaptation:**
When volume spikes (2x rolling average), DVWAP updates faster → adapts to news arrival.
When volume is thin, DVWAP smooths → avoids fake signals.

### Layer 2: Alpha Combos (Secondary Signals)
**Source:** Kakushadze & Serur (2018) — Alpha Combos, Statistical Arbitrage

Each alpha is a weak signal (Sharpe 0.3–0.8). Combined, they create a strong composite.

| Alpha # | Name | Logic | Timeframe | Weight |
|---------|------|-------|-----------|--------|
| 1 | Residual Momentum | Price momentum after market factor removal | 1H | 0.15 |
| 2 | Low Volatility | Buy low-vol pullbacks in high-vol trends | 1H | 0.10 |
| 3 | Mean Reversion | Distance from rolling VWAP z-score | 15m | 0.15 |
| 4 | Implied Volatility | IV rank < 30 = buy, IV rank > 70 = sell | 4H | 0.10 |
| 5 | Volume Anomaly | Unusual volume with minimal price move | 5m | 0.15 |
| 6 | MA Cascade | Price > 20 EMA > 50 EMA > 200 EMA = strong trend | 1H | 0.10 |
| 7 | RSI Divergence | Price makes lower low, RSI makes higher low | 5m | 0.05 |
| 8 | Channel Breakout | Break of N-day Donchian channel | 1H | 0.05 |
| 9 | Support/Resist Bounce | Touch of S/R with reversal candle | 15m | 0.05 |
| 10 | KNN Pattern Match | k-nearest neighbors to historical patterns | 1H | 0.10 |

**Composite Score:**
```
Alpha_Score = Σ (Alpha_i × Weight_i)  [-1.0 to +1.0]

Entry Conditions:
  Alpha_Score > +0.5  →  LONG bias confirmed
  Alpha_Score < -0.5  →  SHORT bias confirmed
  -0.5 ≤ Score ≤ +0.5 →  Wait (no edge)
```

### Layer 3: LQR Position Sizing (Dynamic Control)
**Source:** Shen (2017) — Hybrid IS-VWAP LQR Model

Position sizing is not static. It's a linear-quadratic regulator that optimizes:
- **Market impact:** Don't move the market against yourself
- **Delay cost:** Opportunity cost of waiting
- **Risk aversion:** Current volatility regime
- **Spread cost:** Bid-ask at current time

```
State variables: x_t = [remaining_shares, current_slippage]
Control variable: u_t = optimal_trade_size_this_bar

Cost function:
  J = Σ (delay_cost + impact_cost + spread_cost + risk_penalty)

u*_t = K_t × x_t + f_t  (closed-form LQR solution)
```

In practice for DESTROYER:
- High conviction (Alpha > 0.7) → scale in aggressively (larger K)
- Low conviction (Alpha 0.5-0.7) → scale in passively (smaller K)
- High volatility regime → widen SL, reduce size
- Low volatility → tighten SL, maintain size

---

## MULTI-TIMEFRAME CONFIRMATION

```
MONTHLY  →  Regime filter (trending/ranging) ── disabled if ranging
WEEKLY   →  Macro bias direction              ── sets primary bias
DAILY    →  VWAP trend direction              ── confirms bias
4H       →  Entry zone identification         ── sets target zones
1H       →  Alpha combo scoring               ── generates composite
15m      →  Precision entry timing            ── triggers entry
5m       →  Execution (LQR sizing)            ── controls fill
1m       →  Micro-adjustment                  ── fine-tunes entries
```

**Confirmation Matrix:**
All timeframes must align (or at least 5 of 7) for a trade to fire.
- If HTF (D/W/M) says LONG and LTF says SHORT → WAIT
- If all say LONG → HIGH conviction trade
- If HTF says LONG, LTF says LONG, but 15m says SHORT → WAIT for 15m alignment

---

## RISK MANAGEMENT

### Per-Trade
- Max risk: $5 (fixed from V28.1)
- Min RRR: 1:2 (hard rule, no exceptions)
- TP structure: 3 levels (30% @ TP1, 40% @ TP2, 30% @ TP3)
- Trailing stop: activate after TP1 hit

### Portfolio
- Max concurrent positions: 3
- Max correlation exposure: 2 (no more than 2 correlated pairs)
- Daily max loss: $15 (3 trades at $5 each)
- Weekly max loss: $40 (reset if hit)

### Regime Detection
- **Trending:** Price > 200 EMA + ADX > 25 → normal position sizing
- **Ranging:** Price within 200 EMA ± X + ADX < 20 → reduce size by 50%
- **Volatile:** ATR > 2x rolling average → widen SL by 1.5x, reduce size by 30%

---

## EXECUTION ENGINE

### Entry Types
| Type | Condition | LQR Behavior |
|------|-----------|-------------|
| **Market Entry** | Alpha breakout, urgent | Aggressive (full K value) |
| **Limit Entry** | Pullback to DVWAP | Passive (0.5× K value) |
| **Scale-In Entry** | Partial confirmation | Staggered (0.3× K per tranche) |

### Exit Types
| Type | Condition | Action |
|------|-----------|--------|
| **TP Hit** | Price reaches target level | Close at market, trail remaining |
| **SL Hit** | Price breaches stop | Close immediately |
| **Alpha Decay** | Composite score drops below threshold | Partial close (50%) |
| **Regime Change** | VWAP flip + HTF reversal | Close all positions |
| **Time Stop** | Trade open > N hours with no progress | Close at market |

---

## EXPECTED PERFORMANCE TARGETS

| Metric | V28.1 (Proven) | Silicon-X | V28.19 (Target) |
|--------|---------------|-----------|-----------------|
| **PF** | 2.26 | ~2.0 | **2.8+** |
| **Win Rate** | 65% | ~60% | **70%+** |
| **Max DD** | 6% | ~8% | **< 5%** |
| **Trade Frequency** | ~15/month | ~20/month | **25+/month** |
| **Avg RRR** | 1:2.5 | 1:1.8 | **1:3+** |
| **Sharpe** | 1.8 | ~1.5 | **2.5+** |

---

## IMPLEMENTATION PLAN

### Phase 1: Core Structure (DONE)
- ✅ VWAP trend filter
- ✅ Alpha combinatorial scoring
- ✅ Multi-timeframe confirmation matrix
- ✅ Regime detection system

### Phase 2: LQR Execution Engine (NEXT)
- Position size calculation
- Dynamic SL/TP adjustment
- Entry type selection logic

### Phase 3: Backtest Framework
- Historical simulation engine
- Walk-forward optimization
- Parameter sensitivity analysis

### Phase 4: MT5 Integration
- Signal-to-order translation
- Position management
- Risk monitoring

---

*Built from SSRN research: Kakushadze (151 Strategies), Faber (Tactical Asset Allocation), Zarattini/Aziz (VWAP Trading), Shen (LQR IS-VWAP), Humphery-Jenner (Dynamic VWAP)*
*Last updated: 2026-04-05*
