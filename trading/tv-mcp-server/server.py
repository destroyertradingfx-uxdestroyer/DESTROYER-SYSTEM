#!/usr/bin/env python3
"""
DESTROYER MCP Server for TradingView Signals
Exposes TV signal data as MCP tools for OpenClaw agents.
"""

import json
import mcp.server.fastmcp as fastmcp
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../webhook-server/data")

mcp_server = fastmcp.FastMCP("destroyer-tv-signals")


@mcp_server.tool()
def get_latest_signal() -> dict:
    """Get the most recent TradingView signal data pushed from browser"""
    latest_path = os.path.join(DATA_DIR, "latest.json")
    if not os.path.exists(latest_path):
        return {"status": "no_signals", "message": "No data received yet. Run the bookmarklet on your TradingView tab."}
    
    with open(latest_path) as f:
        return json.load(f)


@mcp_server.tool()
def get_recent_signals(count: int = 5) -> list:
    """Get recent TradingView signals (last N signals)"""
    signals = []
    log_path = os.path.join(DATA_DIR, "webhook.log")
    if not os.path.exists(log_path):
        return []
    
    with open(log_path) as f:
        for line in f:
            line = line.strip()
            if line:
                signals.append(json.loads(line))
    
    return signals[-count:]


@mcp_server.tool()
def get_signal_analysis(symbol: str = "", timeframe: str = "") -> dict:
    """Analyze the latest signal and generate a trade recommendation"""
    from importlib.util import spec_from_file_location, module_from_spec
    
    latest_path = os.path.join(DATA_DIR, "latest.json")
    if not os.path.exists(latest_path):
        return {"status": "no_signals", "message": "No data to analyze."}
    
    with open(latest_path) as f:
        signal_data = json.load(f)
    
    if symbol and signal_data.get("symbol", "").upper() != symbol.upper():
        return {"status": "symbol_mismatch", 
                "requested": symbol, 
                "available": signal_data.get("symbol"),
                "message": "Latest signal is for a different symbol."}
    
    # Run analysis logic
    indicators = signal_data.get("indicators", [])
    
    # Bias detection
    bullish = 0
    bearish = 0
    for ind in indicators:
        val = ind.get("value", "").lower()
        if any(x in val for x in ["buy", "long", "above"]):
            bullish += 1
        elif any(x in val for x in ["sell", "short", "below"]):
            bearish += 1
    
    total = bullish + bearish
    bias = "NEUTRAL"
    if total > 0:
        bias_pct = bullish / total
        if bias_pct > 0.7:
            bias = "BULLISH"
        elif bias_pct < 0.3:
            bias = "BEARISH"
    
    return {
        "symbol": signal_data.get("symbol"),
        "timeframe": signal_data.get("timeframe"),
        "price": signal_data.get("price", {}),
        "bias": bias,
        "indicator_count": len(indicators),
        "indicators": indicators,
        "drawings": signal_data.get("drawings", []),
        "strategy_results": signal_data.get("strategyResults"),
        "scraped_at": signal_data.get("scraped_at"),
        "analysis_time": datetime.now(timezone.utc).isoformat()
    }


@mcp_server.tool()
def check_webhook_status() -> dict:
    """Check if the TradingView webhook receiver is running and receiving data"""
    import urllib.request
    
    port = os.environ.get("TV_WEBHOOK_PORT", "8471")
    url = f"http://127.0.0.1:{port}/health"
    
    try:
        with urllib.request.urlopen(url, timeout=3) as resp:
            data = json.loads(resp.read().decode())
            latest_path = os.path.join(DATA_DIR, "latest.json")
            has_data = os.path.exists(latest_path)
            return {
                "webhook_status": "running",
                "health": data,
                "has_data": has_data,
                "data_dir": DATA_DIR
            }
    except Exception as e:
        return {
            "webhook_status": "not_running",
            "error": str(e),
            "data_dir": DATA_DIR,
            "has_data": os.path.exists(os.path.join(DATA_DIR, "latest.json"))
        }


if __name__ == "__main__":
    mcp_server.run(transport="stdio")
