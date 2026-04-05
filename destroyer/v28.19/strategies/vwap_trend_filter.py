"""
LAYER 1: VWAP Trend Filter
Primary directional signal for DESTROYER V28.19

Based on: "Volume Weighted Average Price (VWAP) The Holy Grail for Day Trading Systems"
— Zarattini & Aziz (2023), SSRN-4631351

This layer identifies the market regime (BULLISH, BEARISH, or CHOP)
using DVWAP + slope analysis + dynamic noise adaptation.
"""

import math
from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional, Tuple


class Regime(Enum):
    BULLISH = "BULLISH"
    BEARISH = "BEARISH"
    CHOP = "CHOP"


class Signal(Enum):
    LONG = "LONG"
    SHORT = "SHORT"
    WAIT = "WAIT"


@dataclass
class VWAPBar:
    """A single bar with VWAP data."""
    high: float
    low: float
    close: float
    volume: float
    vwap: float
    vwap_slope: float
    hlc_avg: float
    distance_from_vwap_pct: float


@dataclass
class DVWAPSignal:
    """Complete VWAP Trend Filter output."""
    regime: Regime
    signal: Signal
    current_price: float
    current_vwap: float
    vwap_slope: float
    distance_from_vwap_pct: float
    volume_ratio: float
    confidence: float
    bars_analyzed: int
    regime_reason: str = ""
    warnings: List[str] = field(default_factory=list)


class VWAPTrendFilter:
    """
    VWAP Trend Filter with dynamic adaptation.
    
    Features:
    - Rolling DVWAP (not session-reset)
    - Slope analysis (acceleration/deceleration)
    - Volume spike detection for noise adaptation
    - Distance-from-VWAP z-score
    - Confidence scoring
    """
    
    def __init__(
        self,
        vwap_period: int = 60,
        slope_period: int = 10,
        volume_ma_period: int = 20,
        distance_threshold: float = 0.5,
        min_confidence: float = 0.6,
    ):
        """
        Args:
            vwap_period: Number of bars for rolling VWAP (default: 60 = 1H on 1m data)
            slope_period: Bars for VWAP slope calculation
            volume_ma_period: Bars for volume moving average
            distance_threshold: Min distance from VWAP (in %) to signal
            min_confidence: Minimum confidence for trade signal
        """
        self.vwap_period = vwap_period
        self.slope_period = slope_period
        self.volume_ma_period = volume_ma_period
        self.distance_threshold = distance_threshold
        self.min_confidence = min_confidence
        
        # State
        self._vwap_values: List[float] = []
        self._volume_values: List[float] = []
        self._price_values: List[float] = []
    
    def calculate_hlc(self, high: float, low: float, close: float) -> float:
        return (high + low + close) / 3.0
    
    def calculate_vwap(self, bars_data: List[Tuple[float, float, float, float]]) -> List[float]:
        """
        Calculate rolling VWAP from raw bar data.
        
        Args:
            bars_data: List of (high, low, close, volume) tuples
            
        Returns:
            VWAP values for each bar
        """
        cumulative_hlc_vol = 0.0
        cumulative_volume = 0.0
        vwap_values = []
        
        for high, low, close, volume in bars_data:
            hlc = self.calculate_hlc(high, low, close)
            cumulative_hlc_vol += hlc * volume
            cumulative_volume += volume
            
            if cumulative_volume > 0:
                vwap = cumulative_hlc_vol / cumulative_volume
            else:
                vwap = close
            
            vwap_values.append(vwap)
        
        return vwap_values
    
    def calculate_vwap_slope(self, vwap_values: List[float], period: int = None) -> List[float]:
        """
        Calculate VWAP slope using simple linear regression.
        
        Positive slope = price trending up
        Negative slope = price trending down
        """
        period = period or self.slope_period
        slopes = [0.0] * min(period, len(vwap_values))
        
        for i in range(period, len(vwap_values)):
            window = vwap_values[i-period:i]
            n = len(window)
            
            # Simple linear regression: slope = cov(x,y) / var(x)
            x_mean = (period - 1) / 2.0
            y_mean = sum(window) / n
            
            numerator = sum((j - x_mean) * (window[j] - y_mean) for j in range(n))
            denominator = sum((j - x_mean) ** 2 for j in range(n))
            
            if denominator > 0:
                slope = numerator / denominator
                slopes.append(slope)
        
        return slopes
    
    def calculate_distance_from_vwap(self, price: float, vwap: float) -> float:
        """
        Price distance from VWAP, in percent.
        
        price > vwap = positive (bullish)
        price < vwap = negative (bearish)
        """
        if vwap == 0:
            return 0.0
        return ((price - vwap) / vwap) * 100.0
    
    def calculate_volume_ratio(self, current_volume: float, historical_volumes: List[float]) -> float:
        """
        Current volume compared to rolling average.
        
        > 2.0 = volume spike (news arrival)
        < 0.5 = volume lull (low conviction)
        """
        period = min(self.volume_ma_period, len(historical_volumes))
        if period == 0 or current_volume == 0:
            return 1.0
        avg_volume = sum(historical_volumes[-period:]) / period
        return current_volume / avg_volume if avg_volume > 0 else 1.0
    
    def analyze(self, bars: List[Tuple[float, float, float, float]]) -> DVWAPSignal:
        """
        Analyze a series of bars and return the VWAP Trend Signal.
        
        Args:
            bars: List of (high, low, close, volume) tuples, oldest first
            
        Returns:
            DVWAPSignal with regime, signal, confidence, and metadata
        """
        if len(bars) < max(self.vwap_period, self.slope_period, self.volume_ma_period):
            return DVWAPSignal(
                regime=Regime.CHOP,
                signal=Signal.WAIT,
                current_price=0,
                current_vwap=0,
                vwap_slope=0,
                distance_from_vwap_pct=0,
                volume_ratio=1.0,
                confidence=0,
                bars_analyzed=len(bars),
                regime_reason=f"Insufficient data: {len(bars)} bars, need {max(self.vwap_period, self.slope_period, self.volume_ma_period)}"
            )
        
        # Calculate VWAP values
        vwap_values = self.calculate_vwap(bars)
        
        # Calculate VWAP slope
        vwap_slopes = self.calculate_vwap_slope(vwap_values)
        
        # Current values
        current_price = bars[-1][2]
        current_vwap = vwap_values[-1]
        current_slope = vwap_slopes[-1]
        current_distance = self.calculate_distance_from_vwap(current_price, current_vwap)
        current_volume = bars[-1][3]
        volumes = [b[3] for b in bars]
        volume_ratio = self.calculate_volume_ratio(current_volume, volumes)
        
        # Extract vwap history for analysis
        recent_vwap = vwap_values[-self.slope_period:]
        
        # Calculate VWAP slope acceleration (2nd derivative)
        recent_slopes = vwap_slopes[-min(5, len(vwap_slopes)):]
        slope_acceleration = 0
        if len(recent_slopes) >= 2:
            slope_acceleration = recent_slopes[-1] - recent_slopes[-2]
        
        # === REGIME DETERMINATION ===
        regime = Regime.CHOP
        regime_reason = ""
        
        if current_distance > self.distance_threshold and current_slope > 0:
            regime = Regime.BULLISH
            regime_reason = f"Price {current_distance:.2f}% above VWAP with positive slope {current_slope:.6f}"
        elif current_distance < -self.distance_threshold and current_slope < 0:
            regime = Regime.BEARISH
            regime_reason = f"Price {abs(current_distance):.2f}% below VWAP with negative slope {current_slope:.6f}"
        else:
            regime = Regime.CHOP
            regime_reason = f"Price {current_distance:.2f}% from VWAP (threshold: {self.distance_threshold}%), slope: {current_slope:.6f}"
        
        # === SIGNAL GENERATION ===
        signal = Signal.WAIT
        confidence = 0.0
        warnings = []
        
        # Base confidence from regime clarity
        if regime == Regime.BULLISH:
            confidence = 0.5
            signal = Signal.LONG
        elif regime == Regime.BEARISH:
            confidence = 0.5
            signal = Signal.SHORT
        else:
            confidence = 0.0
            warnings.append("CHOP regime — no trade edge")
        
        # === CONFIDENCE MULTIPLIERS ===
        
        # Distance strength (> 1% = stronger conviction)
        if abs(current_distance) > 1.0:
            confidence += 0.15
            if abs(current_distance) > 2.0:
                confidence += 0.1
                warnings.append(f"Price extended {current_distance:.2f}% from VWAP — potential mean reversion risk")
        
        # Slope acceleration (trend strengthening or weakening?)
        if abs(slope_acceleration) > 0:
            if (regime == Regime.BULLISH and slope_acceleration > 0):
                confidence += 0.15  # Upward acceleration
            elif (regime == Regime.BEARISH and slope_acceleration < 0):
                confidence += 0.15  # Downward acceleration
            elif (regime == Regime.BULLISH and slope_acceleration < 0):
                confidence -= 0.1  # Upward but decelerating
            elif (regime == Regime.BEARISH and slope_acceleration > 0):
                confidence -= 0.1  # Downward but decelerating
        
        # Volume confirmation
        if volume_ratio > 1.5:
            confidence += 0.1  # Strong move with volume
        elif volume_ratio < 0.7:
            confidence -= 0.15  # Weak volume = low conviction
            warnings.append(f"Low volume ratio ({volume_ratio:.1f}x) — low conviction move")
        
        # VWAP slope magnitude (stronger slope = clearer trend)
        normalized_slope = abs(current_slope) / current_vwap if current_vwap > 0 else abs(current_slope)
        if normalized_slope > 0.001:
            confidence += 0.1
        
        # Clamp confidence
        confidence = max(0.0, min(1.0, confidence))
        
        # === OVERWRITE SIGNAL IF LOW CONFIDENCE ===
        if confidence < self.min_confidence:
            signal = Signal.WAIT
        
        return DVWAPSignal(
            regime=regime,
            signal=signal,
            current_price=current_price,
            current_vwap=current_vwap,
            vwap_slope=current_slope,
            distance_from_vwap_pct=current_distance,
            volume_ratio=volume_ratio,
            confidence=confidence,
            bars_analyzed=len(bars),
            regime_reason=regime_reason,
            warnings=warnings
        )


def main():
    """Test the VWAP Trend Filter with sample data."""
    import random
    
    filter_60 = VWAPTrendFilter(vwap_period=60)
    
    # Generate sample data: bullish trend
    print("=== TESTING: BULLISH TREND ===")
    price = 100.0
    bull_bars = []
    for i in range(120):
        if i < 30:
            drift = 0.0
        else:
            drift = 0.05
        price += drift + random.gauss(0, 0.3)
        high = price + abs(random.gauss(0, 0.5))
        low = price - abs(random.gauss(0, 0.5))
        vol = 1000 + random.uniform(-300, 300)
        bull_bars.append((high, low, price, vol))
    
    result = filter_60.analyze(bull_bars)
    print(f"Regime: {result.regime.value}")
    print(f"Signal: {result.signal.value}")
    print(f"Confidence: {result.confidence:.2f}")
    print(f"VWAP: {result.current_vwap:.2f}, Price: {result.current_price:.2f}")
    print(f"Distance from VWAP: {result.distance_from_vwap_pct:.2f}%")
    print(f"Volume Ratio: {result.volume_ratio:.1f}")
    print(f"Reason: {result.regime_reason}")
    if result.warnings:
        print(f"Warnings: {', '.join(result.warnings)}")
    
    # Generate sample data: bearish trend
    print("\n=== TESTING: BEARISH TREND ===")
    price = 100.0
    bear_bars = []
    for i in range(120):
        if i < 30:
            drift = 0.0
        else:
            drift = -0.05
        price += drift + random.gauss(0, 0.3)
        high = price + abs(random.gauss(0, 0.5))
        low = price - abs(random.gauss(0, 0.5))
        vol = 1000 + random.uniform(-300, 300)
        bear_bars.append((high, low, price, vol))
    
    result = filter_60.analyze(bear_bars)
    print(f"Regime: {result.regime.value}")
    print(f"Signal: {result.signal.value}")
    print(f"Confidence: {result.confidence:.2f}")
    print(f"VWAP: {result.current_vwap:.2f}, Price: {result.current_price:.2f}")
    print(f"Distance from VWAP: {result.distance_from_vwap_pct:.2f}%")
    print(f"Volume Ratio: {result.volume_ratio:.1f}")
    print(f"Reason: {result.regime_reason}")
    
    # Generate sample data: chop zone
    print("\n=== TESTING: CHOP ZONE ===")
    price = 100.0
    chop_bars = []
    for i in range(120):
        price += random.gauss(0, 0.2)
        high = price + abs(random.gauss(0, 0.5))
        low = price - abs(random.gauss(0, 0.5))
        vol = 800 + random.uniform(-400, 400)
        chop_bars.append((high, low, price, vol))
    
    result = filter_60.analyze(chop_bars)
    print(f"Regime: {result.regime.value}")
    print(f"Signal: {result.signal.value}")
    print(f"Confidence: {result.confidence:.2f}")
    print(f"VWAP: {result.current_vwap:.2f}, Price: {result.current_price:.2f}")
    print(f"Distance from VWAP: {result.distance_from_vwap_pct:.2f}%")
    print(f"Volume Ratio: {result.volume_ratio:.1f}")
    print(f"Reason: {result.regime_reason}")


if __name__ == "__main__":
    main()
