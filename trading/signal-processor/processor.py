#!/usr/bin/env python3
"""
DESTROYER Signal Processor
Reads TradingView data from webhook, analyzes signals, and outputs
structured trade recommendations for MT5 execution.
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../webhook-server/data")
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")
os.makedirs(OUTPUT_DIR, exist_ok=True)


def parse_indicators(signal_data):
    """Extract and categorize indicator values"""
    indicators = signal_data.get("indicators", [])
    parsed = {}
    for ind in indicators:
        name = ind.get("name", "").strip().lower()
        value = ind.get("value", "").strip()
        
        # Categorize by indicator type
        for key in ["rsi", "macd", "ema", "sma", "boll", "atr", "stoch", "cci", "adx", 
                     "fib", "vwap", "ichimoku", "obv", "volume", "support", "resistance"]:
            if key in name:
                parsed.setdefault(key, []).append({
                    "full_name": ind["name"],
                    "value": value,
                    "raw": ind
                })
    
    return parsed


def detect_htf_bias(signal_data):
    """Determine Higher Timeframe bias from indicator cluster analysis"""
    indicators = signal_data.get("indicators", [])
    
    bullish_votes = 0
    bearish_votes = 0
    
    for ind in indicators:
        name = ind.get("name", "").lower()
        value = ind.get("value", "").lower()
        
        # Price above EMA/SMA = bullish
        if any(x in name for x in ["ema", "sma"]):
            # Simplified: check if price is above or below
            if "above" in value or "buy" in value:
                bullish_votes += 1
            elif "below" in value or "sell" in value:
                bearish_votes += 1
        
        # RSI analysis
        if "rsi" in name:
            try:
                rsi = float(value.replace(',', '.'))
                if rsi < 30:
                    bullish_votes += 1  # Oversold
                elif rsi > 70:
                    bearish_votes += 1  # Overbought
                elif rsi > 50:
                    bullish_votes += 0.5  # Momentum
                else:
                    bearish_votes += 0.5
            except (ValueError, AttributeError):
                pass
        
        # MACD
        if "macd" in name:
            if "bullish" in value or "above" in value:
                bullish_votes += 1
            elif "bearish" in value or "below" in value:
                bearish_votes += 1
    
    total = bullish_votes + bearish_votes
    if total == 0:
        return "NEUTRAL", 0.5
    
    bullish_pct = bullish_votes / total
    if bullish_pct > 0.7:
        return "BULLISH", bullish_pct
    elif bullish_pct < 0.3:
        return "BEARISH", bullish_pct
    else:
        return "NEUTRAL", bullish_pct


def extract_support_resistance(signal_data):
    """Extract S/R levels from drawing objects and indicator labels"""
    levels = {"support": [], "resistance": []}
    
    drawings = signal_data.get("drawings", [])
    for d in drawings:
        content = d.get("content", "").lower()
        if any(x in content for x in ["support", "demand", "bottom", "low"]):
            levels["support"].append(content)
        if any(x in content for x in ["resistance", "supply", "top", "high"]):
            levels["resistance"].append(content)
    
    indicators = signal_data.get("indicators", [])
    for ind in indicators:
        name = ind.get("name", "").lower()
        if "support" in name or "pivot low" in name:
            levels["support"].append(ind.get("value", ""))
        if "resistance" in name or "pivot high" in name:
            levels["resistance"].append(ind.get("value", ""))
    
    return levels


def generate_trade_recommendation(signal_data):
    """Generate structured trade recommendation from full signal data"""
    symbol = signal_data.get("symbol", "UNKNOWN")
    price = signal_data.get("price", {})
    timeframe = signal_data.get("timeframe", "Unknown")
    
    parsed_indicators = parse_indicators(signal_data)
    bias, bias_strength = detect_htf_bias(signal_data)
    sr_levels = extract_support_resistance(signal_data)
    
    # Determine recommendation
    recommendation = {
        "symbol": symbol,
        "timeframe": timeframe,
        "current_price": price.get("price", "unknown"),
        "bias": bias,
        "bias_strength": round(bias_strength * 100, 1),
        "support_levels": sr_levels["support"][:5],
        "resistance_levels": sr_levels["resistance"][:5],
        "indicators_summary": {
            k: [v["value"] for v in vals]
            for k, vals in parsed_indicators.items()
        } if parsed_indicators else "No indicators detected",
        "strategy_results": signal_data.get("strategyResults", None),
        "scraped_at": signal_data.get("scraped_at", ""),
        "processed_at": datetime.now(timezone.utc).isoformat(),
        "action": "HOLD",
        "confidence": 0.0,
        "notes": []
    }
    
    # Decision logic
    if bias == "BULLISH" and bias_strength > 0.8:
        recommendation["action"] = "LOOK_FOR_LONG"
        recommendation["confidence"] = round(bias_strength * 0.7, 2)
        if sr_levels["support"]:
            nearest = sr_levels["support"][-1]  # Last/most recent
            recommendation["notes"].append(f"Nearest support: {nearest}")
            recommendation["notes"].append("Consider entry near support with SL below")
    elif bias == "BEARISH" and bias_strength < 0.3:
        recommendation["action"] = "LOOK_FOR_SHORT"
        recommendation["confidence"] = round((1 - bias_strength) * 0.7, 2)
        if sr_levels["resistance"]:
            nearest = sr_levels["resistance"][-1]
            recommendation["notes"].append(f"Nearest resistance: {nearest}")
            recommendation["notes"].append("Consider entry near resistance with SL above")
    
    return recommendation


def main():
    """Process latest signal and output recommendation"""
    latest_path = os.path.join(DATA_DIR, "latest.json")
    
    if not os.path.exists(latest_path):
        print("No signal data found. Start the webhook server first.")
        sys.exit(1)
    
    with open(latest_path) as f:
        signal_data = json.load(f)
    
    rec = generate_trade_recommendation(signal_data)
    
    # Output
    output_file = os.path.join(OUTPUT_DIR, f"rec-{rec['symbol'].replace(':', '_')}-{int(datetime.now().timestamp())}.json")
    with open(output_file, "w") as f:
        json.dump(rec, f, indent=2)
    
    print(json.dumps(rec, indent=2))


if __name__ == "__main__":
    main()
