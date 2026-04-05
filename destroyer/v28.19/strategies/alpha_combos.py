"""
LAYER 2: Alpha Combinatorial Scoring
Secondary signal confirmation for DESTROYER V28.19

Based on: Kakushadze & Serur (2018) — "151 Trading Strategies"
Sections: Alpha Combos, Residual Momentum, Low Volatility, Statistical Arbitrage

Combines 10 weak signals (individual Sharpe 0.3–0.8) into a composite
signal (target Sharpe 1.5–2.5) through weighted linear combination.
"""

from dataclasses import dataclass, field
from typing import List, Dict, Optional
import math


# ==================== INDIVIDUAL ALPHA DEFINITIONS ====================

@dataclass
class AlphaDefinition:
    """Definition of a single alpha signal."""
    alpha_id: int
    name: str
    description: str
    timeframe: str
    default_weight: float
    direction: str  # "LONG", "SHORT", or "MEAN_REVERSION"


ALPHA_DEFINITIONS = {
    1: AlphaDefinition(1, "Residual Momentum", "Price momentum after market factor removal", "1H", 0.15, "TREND"),
    2: AlphaDefinition(2, "Low Volatility", "Buy low-vol pullbacks in high-vol trends", "1H", 0.10, "TREND"),
    3: AlphaDefinition(3, "Mean Reversion", "Distance from rolling VWAP z-score", "15m", 0.15, "MEAN_REVERSION"),
    4: AlphaDefinition(4, "Implied Volatility", "IV rank-based regime detection", "4H", 0.10, "TREND"),
    5: AlphaDefinition(5, "Volume Anomaly", "Unusual volume with minimal price move", "5m", 0.15, "TREND"),
    6: AlphaDefinition(6, "MA Cascade", "Price > 20 EMA > 50 EMA > 200 EMA", "1H", 0.10, "TREND"),
    7: AlphaDefinition(7, "RSI Divergence", "Price lower low / RSI higher low", "5m", 0.05, "MEAN_REVERSION"),
    8: AlphaDefinition(8, "Channel Breakout", "Break of N-day Donchian channel", "1H", 0.05, "TREND"),
    9: AlphaDefinition(9, "Support/Resist Bounce", "Touch of S/R with reversal candle", "15m", 0.05, "MEAN_REVERSION"),
    10: AlphaDefinition(10, "KNN Pattern Match", "k-nearest neighbors to historical patterns", "1H", 0.10, "TREND"),
}


@dataclass
class AlphaScore:
    """Score output for a single alpha."""
    alpha_id: int
    name: str
    raw_value: float  # Raw alpha value (-1.0 to 1.0)
    weighted_value: float
    active: bool
    timeframe: str


@dataclass
class CompositeAlphaSignal:
    """Complete alpha combinatorial output."""
    composite_score: float        # -1.0 to 1.0
    signal: str                   # "LONG", "SHORT", "WAIT"
    conviction: str               # "HIGH", "MEDIUM", "LOW"
    long_alphas: List[AlphaScore] # Alphas contributing to long
    short_alphas: List[AlphaScore]# Alphas contributing to short
    neutral_alphas: List[AlphaScore]  # Alphas at zero
    total_active_alphas: int
    alpha_agreement: float        # How many alphas agree (0-1)
    regime_consistency: bool      # Do all timeframes agree?
    warnings: List[str] = field(default_factory=list)


class AlphaScorer:
    """
    Alpha Combinatorial Scoring Engine.
    
    Combines 10 weak alpha signals into a composite through:
    1. Individual alpha calculation (-1.0 to 1.0)
    2. Weighted combination
    3. Agreement analysis (do alphas agree on direction?)
    4. Signal generation with conviction level
    """
    
    def __init__(self, long_threshold: float = 0.5, short_threshold: float = -0.5):
        self.long_threshold = long_threshold
        self.short_threshold = short_threshold
    
    def alpha_residual_momentum(
        self,
        prices: List[float],
        market_prices: List[float],
        lookback: int = 20
    ) -> float:
        """
        Alpha #1: Residual Momentum
        
        Momentum after removing market factor (CAPM-style).
        Residual return = asset return - beta * market return.
        
        Positive residual momentum = outperforming on its own, not just riding the market.
        
        Source: Kakushadze & Serur (2018), Section 3.7
        """
        if len(prices) < lookback + 1 or len(market_prices) < lookback + 1:
            return 0.0
        
        # Calculate returns
        asset_returns = [(prices[i] - prices[i-1]) / prices[i-1] for i in range(1, len(prices))]
        market_returns = [(market_prices[i] - market_prices[i-1]) / market_prices[i-1] for i in range(1, len(market_prices))]
        
        # Use only the lookback period
        ar = asset_returns[-lookback:]
        mr = market_returns[-lookback:]
        
        # OLS regression: asset_return = alpha + beta * market_return
        mean_ar = sum(ar) / len(ar)
        mean_mr = sum(mr) / len(mr)
        
        covariance = sum((ar[i] - mean_ar) * (mr[i] - mean_mr) for i in range(len(ar)))
        variance = sum((mr[i] - mean_mr) ** 2 for i in range(len(mr)))
        
        if variance == 0:
            beta = 1.0
        else:
            beta = covariance / variance
        
        # Residual returns
        residuals = [ar[i] - beta * mr[i] for i in range(len(ar))]
        
        # Cumulative residual return (momentum)
        cumulative_residual = sum(residuals)
        
        # Normalize to -1 to 1
        normalized = max(-1.0, min(1.0, cumulative_residual * 10))
        return normalized
    
    def alpha_low_volatility(
        self,
        prices: List[float],
        volatility_window: int = 20,
        trend_window: int = 50
    ) -> float:
        """
        Alpha #2: Low Volatility Anomaly
        
        Buy pullbacks that have low volatility but are within a high-volatility trend.
        Low-vol pullbacks in high-vol trends are the best entries.
        
        Source: Kakushadze & Serur (2018), Section 3.4
        """
        if len(prices) < trend_window + 1:
            return 0.0
        
        # Recent prices
        recent = prices[-volatility_window:]
        trend = prices[-trend_window:]
        
        # Calculate return and volatility
        total_return = (recent[-1] - recent[0]) / recent[0]
        
        # Local volatility (last volatility_window bars)
        local_returns = [(recent[i] - recent[i-1]) / recent[i-1] for i in range(1, len(recent))]
        local_vol = math.sqrt(sum(r**2 for r in local_returns) / len(local_returns))
        
        # Trend direction
        overall_return = (trend[-1] - trend[0]) / trend[0]
        
        # Low volatility in up-trend = bullish
        if overall_return > 0 and local_vol < 0.02:
            return min(1.0, total_return * 5 + 0.5)
        elif overall_return < 0 and local_vol < 0.02:
            return max(-1.0, total_return * 5 - 0.5)
        else:
            return 0.0  # High volatility = uncertain
    
    def alpha_mean_reversion(
        self,
        prices: List[float],
        vwap_values: List[float]
    ) -> float:
        """
        Alpha #3: Mean Reversion (VWAP Distance)
        
        Z-score of price distance from rolling VWAP.
        Price far below VWAP = overshoot = mean reversion to VWAP = bullish
        Price far above VWAP = overshoot = mean reversion to VWAP = bearish
        
        This works WITH the VWAP Trend Filter (Layer 1), not against it.
        When VWAP filter is BULLISH and price pulls BACK to VWAP = buy entry.
        When VWAP filter is BEARISH and price pulls UP to VWAP = sell entry.
        
        Source: Humphery-Jenner (2011), Dynamic VWAP
        """
        if not prices or not vwap_values or len(prices) != len(vwap_values):
            return 0.0
        
        current_price = prices[-1]
        current_vwap = vwap_values[-1]
        
        if current_vwap == 0:
            return 0.0
        
        # Distance in percent
        distance_pct = ((current_price - current_vwap) / current_vwap) * 100.0
        
        # Calculate historical distance std dev for z-score
        deviations = [((prices[i] - vwap_values[i]) / vwap_values[i]) * 100.0 for i in range(len(prices)) if vwap_values[i] != 0]
        
        if len(deviations) < 2:
            return 0.0
        
        mean_dev = sum(deviations) / len(deviations)
        std_dev = math.sqrt(sum((d - mean_dev) ** 2 for d in deviations) / (len(deviations) - 1))
        
        if std_dev == 0:
            return 0.0
        
        z_score = (distance_pct - mean_dev) / std_dev
        
        # Mean reversion signal:
        # Large positive z-score (price far above VWAP) = bearish (will revert down)
        # Large negative z-score (price far below VWAP) = bullish (will revert up)
        normalized = max(-1.0, min(1.0, -z_score / 3.0))  # 3-sigma events
        return normalized
    
    def alpha_ma_cascade(
        self,
        price: float,
        ema_20: float,
        ema_50: float,
        ema_200: float
    ) -> float:
        """
        Alpha #6: MA Cascade
        
        Perfect bullish alignment: Price > EMA20 > EMA50 > EMA200
        Perfect bearish alignment: Price < EMA20 < EMA50 < EMA200
        
        Source: Kakushadze & Serur (2018), Section 3.13 (Three Moving Averages)
        """
        if price == 0 or ema_20 == 0 or ema_50 == 0 or ema_200 == 0:
            return 0.0
        
        # Count bullish alignments
        bullish_count = 0
        if price > ema_20:
            bullish_count += 1
        if ema_20 > ema_50:
            bullish_count += 1
        if ema_50 > ema_200:
            bullish_count += 1
        
        # Count bearish alignments
        bearish_count = 0
        if price < ema_20:
            bearish_count += 1
        if ema_20 < ema_50:
            bearish_count += 1
        if ema_50 < ema_200:
            bearish_count += 1
        
        # Pure bullish = +1.0, pure bearish = -1.0, mixed = proportional
        if bullish_count == 3:
            return 1.0
        elif bearish_count == 3:
            return -1.0
        else:
            # Partial alignment
            return (bullish_count - bearish_count) / 3.0
    
    def compute_composite(
        self,
        alpha_scores: Dict[int, float],
        custom_weights: Dict[int, float] = None
    ) -> CompositeAlphaSignal:
        """
        Compute the composite alpha signal from individual alpha scores.
        
        Args:
            alpha_scores: {alpha_id: raw_value (-1.0 to 1.0)}
            custom_weights: {alpha_id: weight} (optional overrides)
            
        Returns:
            CompositeAlphaSignal with composite score and signal direction
        """
        long_alphas = []
        short_alphas = []
        neutral_alphas = []
        total_weighted = 0.0
        total_weight = 0.0
        
        for alpha_id, raw_value in alpha_scores.items():
            if alpha_id not in ALPHA_DEFINITIONS:
                continue
            
            alpha_def = ALPHA_DEFINITIONS[alpha_id]
            weight = custom_weights.get(alpha_id, alpha_def.default_weight) if custom_weights else alpha_def.default_weight
            
            weighted_value = raw_value * weight
            
            score = AlphaScore(
                alpha_id=alpha_id,
                name=alpha_def.name,
                raw_value=raw_value,
                weighted_value=weighted_value,
                active=abs(raw_value) > 0.1,
                timeframe=alpha_def.timeframe
            )
            
            if raw_value > 0.1:
                long_alphas.append(score)
                total_weighted += abs(weighted_value)
                total_weight += weight
            elif raw_value < -0.1:
                short_alphas.append(score)
                total_weighted += abs(weighted_value)
                total_weight += weight
            else:
                neutral_alphas.append(score)
        
        # Composite score
        if total_weight > 0:
            composite_score = total_weighted / total_weight
        else:
            composite_score = 0.0
        
        # Clamp
        composite_score = max(-1.0, min(1.0, composite_score))
        
        # Signal direction
        if composite_score > self.long_threshold:
            signal = "LONG"
            conviction = "HIGH" if composite_score > 0.7 else "MEDIUM"
        elif composite_score < self.short_threshold:
            signal = "SHORT"
            conviction = "HIGH" if composite_score < -0.7 else "MEDIUM"
        else:
            signal = "WAIT"
            conviction = "LOW"
        
        # Alpha agreement: how many active alphas agree on direction?
        total_active = len(long_alphas) + len(short_alphas)
        if total_active > 0:
            majority_count = max(len(long_alphas), len(short_alphas))
            alpha_agreement = majority_count / total_active
        else:
            alpha_agreement = 0.0
        
        warnings = []
        if alpha_agreement < 0.5 and total_active > 3:
            warnings.append("Low alpha agreement — alphas are conflicted")
        if total_active < 4:
            warnings.append("Few active alphas — insufficient data for reliable signal")
        
        return CompositeAlphaSignal(
            composite_score=composite_score,
            signal=signal,
            conviction=conviction,
            long_alphas=long_alphas,
            short_alphas=short_alphas,
            neutral_alphas=neutral_alphas,
            total_active_alphas=total_active,
            alpha_agreement=alpha_agreement,
            regime_consistency=alpha_agreement >= 0.7,
            warnings=warnings
        )


if __name__ == "__main__":
    scorer = AlphaScorer()
    
    # Test with simulated alpha inputs
    test_alphas = {
        1: 0.6,   # Residual momentum: moderately bullish
        2: 0.8,   # Low vol pullback in trend: bullish
        3: -0.3,  # Mean reversion: slightly bearish (price extended)
        4: 0.5,   # IV rank: bullish regime
        5: 0.7,   # Volume anomaly: bullish
        6: 1.0,   # MA cascade: perfect alignment
        7: 0.2,   # RSI divergence: neutral
        8: 0.0,   # Channel breakout: no signal
        9: 0.4,   # S/R bounce: moderately bullish
        10: 0.6,  # KNN pattern: bullish
    }
    
    result = scorer.compute_composite(test_alphas)
    
    print(f"Composite Score: {result.composite_score:.2f}")
    print(f"Signal: {result.signal}")
    print(f"Conviction: {result.conviction}")
    print(f"Alpha Agreement: {result.alpha_agreement:.2f}")
    print(f"Active Alphas: {result.total_active_alphas}")
    print()
    print("Long Alphas:")
    for a in result.long_alphas:
        print(f"  {a.name}: {a.raw_value:.2f} (weighted: {a.weighted_value:.3f})")
    print("Short Alphas:")
    for a in result.short_alphas:
        print(f"  {a.name}: {a.raw_value:.2f} (weighted: {a.weighted_value:.3f})")
    if result.warnings:
        print("Warnings:")
        for w in result.warnings:
            print(f"  ⚠ {w}")
