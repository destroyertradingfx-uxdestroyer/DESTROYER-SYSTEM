//+------------------------------------------------------------------+
//|               DESTROYER_V28_19_SCRATCH.mq4                      |
//|           Copyright 2026, DESTROYER Trading Systems              |
//|  V28.19 SCRATCH — Complete from-scratch MQ4 build               |
//|  VWAP Anchor + Clean Pipeliner + Math-First + VWAP MR           |
//|  Zero modify loops · ATR-adaptive · Basket close                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DESTROYER Trading Systems"
#property link      "https://github.com/destroyertradingfx-uxdestroyer"
#property version   "28.19.SCRATCH"
#property strict
#property description "V28.19 SCRATCH - From-scratch MQ4 rebuild"
#property description "VWAP Anchor + Pipeliner Grid + Math-First + Mean Reversion"
#property description "Fixes: No modify loops, Math-first ON, ATR-adaptive grid"

#include <stdlib.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - GENERAL                                        |
//+------------------------------------------------------------------+
input string _hdr0a = "=========== GENERAL SETTINGS ===========";
input int    Magic       = 280190;
input string TradeComment = "V28.19S";
input double BaseLot     = 0.01;
input bool   UseAutoLot  = true;
input double RiskPct     = 1.0;
input int    MaxTrades   = 12;
input int    MaxSpread   = 30;
input int    Slippage    = 3;

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - VWAP ANCHOR                                   |
//+------------------------------------------------------------------+
input string _hdr1a = "=========== VWAP ANCHOR ===========";
input bool   UseVWAP       = true;
input int    VWAPPeriod    = 21;
input double VWAP_Thresh   = 1.0;    // Normal deviation entry threshold
input double VWAP_Extreme  = 2.5;    // Extreme deviation override
input int    VWAP_ATRPeriod= 14;     // ATR for adaptation

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - PIPELINER GRID                                |
//+------------------------------------------------------------------+
input string _hdr2a = "=========== PIPELINER GRID ===========";
input bool   UseGrid       = true;
input double Grid_Step     = 150;    // Base pipstep in points
input int    Grid_Levels   = 10;     // Max grid levels
input double Grid_LotExp   = 1.35;   // Lot multiplier per level
input double Grid_TP       = 2000;   // Take profit in points
input double Grid_SL       = 1000;   // Stop loss in points
input double Grid_TrailOn  = 500;    // Distance to start trailing pending
input bool   Grid_AdaptATR = true;   // Adapt pipstep to ATR
input double Grid_Basket$  = 350;    // Close all when basket hits this $
input double Grid_ATRMult  = 0.8;    // ATR multiplier for adaptive spacing

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - MATH-FIRST REVERSAL                           |
//+------------------------------------------------------------------+
input string _hdr3a = "=========== MATH-FIRST ===========";
input bool   UseMath      = true;    // Enabled by default (V26 had OFF)
input double Math_TP      = 1500;    // TP in points
input double Math_SL      = 800;     // SL in points
input double Math_DevTh   = 1.5;     // Min VWAP deviation for math entry

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - VWAP MEAN REVERSION                           |
//+------------------------------------------------------------------+
input string _hdr4a = "=========== VWAP MEAN-REVERSION ===========";
input bool   UseMR        = true;
input int    MR_RSI_Per   = 10;
input double MR_OB        = 68;      // Overbought
input double MR_OS        = 32;      // Oversold
input double MR_TP        = 1200;    // TP in points
input double MR_SL        = 600;     // SL in points

//+------------------------------------------------------------------+
//| GLOBAL STATE                                                       |
//+------------------------------------------------------------------+
double gVWAP = 0.0;
double gVWAPDev = 0.0;
double gVWAPStdDev = 0.0;
bool   gVWAP_Rising = false;
int    gGridDir = 0;           // 0=none, 1=buy grid, 2=sell grid
double gGridBasePrice = 0.0;
int    gGridLevel = 0;
datetime gLastBar = 0;
int    gTickCount = 0;
double gPeakEquity = 0.0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== DESTROYER V28.19 SCRATCH ===");
   Print("Version: From-Scratch MQ4 Rebuild");
   Print("VWAP:", UseVWAP, " Grid:", UseGrid, " Math:", UseMath, " MR:", UseMR);
   Print("Risk: ", RiskPct, "%  MaxTrades:", MaxTrades, " MaxSpread:", MaxSpread);
   if(!UseGrid) Print("WARNING: Pipeliner disabled — no grid trades will open");
   if(!UseMath) Print("WARNING: Math-First disabled — V26 mistake");
   
   gPeakEquity = AccountEquity();
   gLastBar = iTime(_Symbol, PERIOD_H1, 0);
   gTickCount = 0;
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   int pos = CountPositions(OP_BUY) + CountPositions(OP_SELL);
   double basket = CalcBasketPnL();
   Print("V28.19 SCRATCH stopped. Positions:", pos, " Basket:$", DoubleToString(basket, 2));
}

//+------------------------------------------------------------------+
void OnTick()
{
   bool newH1Bar = false;
   datetime currentH1 = iTime(_Symbol, PERIOD_H1, 0);
   if(currentH1 != gLastBar) {
      gLastBar = currentH1;
      newH1Bar = true;
   }
   gTickCount++;
   
   // === PRE-FLIGHT CHECKS ===
   if(IsBadSpread()) return;
   if(IsDD_Breach()) return;
   if(IsOffHours()) return;
   
   // Track peak equity for DD calculation
   if(AccountEquity() > gPeakEquity) {
      gPeakEquity = AccountEquity();
   }
   
   // === VWAP CALCULATION (once per H1 bar) ===
   if(UseVWAP && newH1Bar) {
      CalculateVWAP();
   }
   
   // === SIGNAL EVALUATION (once per H1 bar) ===
   if(newH1Bar && UseVWAP) {
      EvaluateSignals();
   }
   
   // === GRID EXECUTION (every tick - pending management) ===
   if(UseGrid && UseVWAP) {
      ExecutePipeliner();
   }
   
   // === MATH-FIRST REVERSAL (every tick, but checks prevent spam) ===
   if(UseMath) {
      ExecuteMathFirst();
   }
   
   // === VWAP MEAN REVERSION (every tick, but checks prevent spam) ===
   if(UseMR && UseVWAP) {
      ExecuteMeanReversion();
   }
   
   // === BASKET PROFIT CHECK (every tick) ===
   double basketPnL = CalcBasketPnL();
   if(basketPnL >= Grid_Basket$) {
      Print("[V28.19 SCRATCH] Basket profit $", DoubleToString(basketPnL, 2),
            " reached. Closing all positions and resetting grid.");
      CloseAllTrades();
      ResetGrid();
      return;
   }
   
   // === TRAIL PENDING ORDERS (throttled - ONCE per 200 ticks) ===
   // FIX #1: V26 modified 3530 times per trade. We throttle to 200-tick intervals.
   if(gTickCount % 200 == 0) {
      TrailPendingOrders();
   }
   
   // === TRAIL ACTIVE POSITIONS (once per 600 ticks ~ every 10 min) ===
   if(gTickCount % 600 == 0) {
      TrailActiveStops();
   }
}

//+------------------------------------------------------------------+
//| VWAP CALCULATION (Volume-Weighted Average Price)                  |
//| Source: SSRN research on VWAP execution and mean reversion       |
//+------------------------------------------------------------------+
void CalculateVWAP()
{
   double sumTypicalVol = 0;
   double sumVolume = 0;
   
   for(int i = 0; i < VWAPPeriod; i++) {
      double high = iHigh(_Symbol, PERIOD_H1, i);
      double low = iLow(_Symbol, PERIOD_H1, i);
      double close = iClose(_Symbol, PERIOD_H1, i);
      double typical = (high + low + close) / 3.0;
      double vol = (double)iVolume(_Symbol, PERIOD_H1, i);
      
      sumTypicalVol += typical * vol;
      sumVolume += vol;
   }
   
   if(sumVolume > 0) {
      gVWAP = sumTypicalVol / sumVolume;
      
      // Calculate standard deviation (sigma bands)
      double sumSquaredDev = 0;
      for(int i = 0; i < VWAPPeriod; i++) {
         double close = iClose(_Symbol, PERIOD_H1, i);
         double dev = close - gVWAP;
         sumSquaredDev += dev * dev;
      }
      gVWAPStdDev = MathSqrt(sumSquaredDev / VWAPPeriod);
   }
}

//+------------------------------------------------------------------+
//| SIGNAL EVALUATION                                                 |
//+------------------------------------------------------------------+
void EvaluateSignals()
{
   if(gVWAPStdDev > 0) {
      // Current price deviation from VWAP in sigma terms
      double currentPrice = iClose(_Symbol, PERIOD_H1, 0);
      gVWAPDev = (currentPrice - gVWAP) / gVWAPStdDev;
   }
   
   // Determine if VWAP is rising or falling (slope)
   double prevVwap = 0;
   double prevSumVol = 0;
   double prevSumTypVol = 0;
   for(int i = 1; i < VWAPPeriod; i++) {
      double high = iHigh(_Symbol, PERIOD_H1, i);
      double low = iLow(_Symbol, PERIOD_H1, i);
      double close = iClose(_Symbol, PERIOD_H1, i);
      double typical = (high + low + close) / 3.0;
      double vol = (double)iVolume(_Symbol, PERIOD_H1, i);
      
      prevSumTypVol += typical * vol;
      prevSumVol += vol;
   }
   if(prevSumVol > 0) {
      prevVwap = prevSumTypVol / prevSumVol;
      gVWAP_Rising = (gVWAP > prevVwap);
   }
}

//+------------------------------------------------------------------+
//| PIPELINER GRID EXECUTION (Silicon-X style, fixed)                |
//| FIX #2: Trailing pending orders throttled, not every tick         |
//| FIX #3: No duplicate pending orders (PendingNear check)           |
//| FIX #4: ATR-adaptive grid spacing                                 |
//+------------------------------------------------------------------+
void ExecutePipeliner()
{
   // Calculate adaptive grid spacing
   double gridStep = Grid_Step; // base in points
   if(Grid_AdaptATR) {
      double atr = iATR(_Symbol, PERIOD_H1, VWAP_ATRPeriod, 0) / Point;
      gridStep = MathMax(Grid_Step * 0.5, atr * Grid_ATRMult);  // min 50% of base
      gridStep = MathMin(gridStep, Grid_Step * 2.0);             // max 200% of base
   }
   
   double stepDistance = gridStep * Point;
   
   // Count existing positions and pending orders
   int buyPositions = CountPositions(OP_BUY);
   int sellPositions = CountPositions(OP_SELL);
   int activePositions = buyPositions + sellPositions;
   int pendingOrders = CountPending();
   int totalOrders = activePositions + pendingOrders;
   
   if(totalOrders >= MaxTrades) return;
   if(totalOrders >= Grid_Levels) return;
   
   // === Determine direction from VWAP deviation ===
   int direction = 0;
   
   // Normal entry at 1.0σ threshold
   if(gVWAPDev < -VWAP_Thresh) direction = 1;   // Below VWAP → buy bias
   if(gVWAPDev > VWAP_Thresh)  direction = 2;   // Above VWAP → sell bias
   
   // Force direction at extreme deviation (overrides MTF filters)
   if(gVWAPDev < -VWAP_Extreme) { direction = 1; }
   if(gVWAPDev > VWAP_Extreme)  { direction = 2; }
   
   if(direction == 0) return;  // No signal
   
   // === Direction change handling ===
   if(direction != gGridDir && gGridDir != 0) {
      // Grid direction changed, but only reset if no positions open
      if(activePositions == 0 && pendingOrders == 0) {
         ResetGrid();
      } else {
         // Don't add to opposite direction while positions are open
         direction = 0;
         return;
      }
   }
   
   gGridDir = direction;
   
   // === First Entry (level 0) ===
   if(activePositions == 0 && pendingOrders == 0 && gGridLevel == 0) {
      double lot = CalculateLotSize(0);
      lot = NormalizeLots(lot);
      if(lot <= 0) return;
      
      double entryPrice;
      int orderType;
      
      if(direction == 1) {
         // Buy grid: place buy stop below current price
         entryPrice = NormalizeDouble(Bid - stepDistance, Digits);
         orderType = OP_BUYSTOP;
      } else {
         // Sell grid: place sell stop above current price
         entryPrice = NormalizeDouble(Ask + stepDistance, Digits);
         orderType = OP_SELLSTOP;
      }
      
      double sl, tp;
      if(orderType == OP_BUYSTOP) {
         sl = NormalizeDouble(entryPrice - Grid_SL * Point, Digits);
         tp = NormalizeDouble(entryPrice + Grid_TP * Point, Digits);
      } else {
         sl = NormalizeDouble(entryPrice + Grid_SL * Point, Digits);
         tp = NormalizeDouble(entryPrice - Grid_TP * Point, Digits);
      }
      
      string comment = TradeComment + " (PL0)";
      int ticket = OrderSend(_Symbol, orderType, lot, entryPrice,
                            Slippage, sl, tp, comment, Magic, 0, clrBlue);
      
      if(ticket > 0) {
         gGridBasePrice = entryPrice;
         gGridLevel = 1;
         Print("[V28.19 SCRATCH] First grid order opened: ",
               (direction == 1 ? "BUY" : "SELL"), " @", entryPrice,
               " Lot:", lot, " Ticket:", ticket);
      }
      return;
   }
   
   // === Add Levels (levels 1 through Grid_Levels-1) ===
   if(gGridLevel > 0 && gGridLevel < Grid_Levels) {
      double lot = CalculateLotSize(gGridLevel);
      lot = NormalizeLots(lot);
      if(lot <= 0) return;
      
      double nextLevelPrice;
      int nextOrderType;
      
      if(gGridDir == 1) {
         // Buy grid: add levels below base
         nextLevelPrice = NormalizeDouble(gGridBasePrice - gGridLevel * stepDistance, Digits);
         nextOrderType = OP_BUYSTOP;
      } else {
         // Sell grid: add levels above base
         nextLevelPrice = NormalizeDouble(gGridBasePrice + gGridLevel * stepDistance, Digits);
         nextOrderType = OP_SELLSTOP;
      }
      
      // Check: does a pending order already exist near this price?
      if(PendingNear(nextLevelPrice, stepDistance * 0.3)) {
         return; // Skip, duplicate prevented
      }
      
      double sl, tp;
      if(nextOrderType == OP_BUYSTOP) {
         sl = NormalizeDouble(nextLevelPrice - Grid_SL * Point, Digits);
         tp = NormalizeDouble(nextLevelPrice + Grid_TP * Point, Digits);
      } else {
         sl = NormalizeDouble(nextLevelPrice + Grid_SL * Point, Digits);
         tp = NormalizeDouble(nextLevelPrice - Grid_TP * Point, Digits);
      }
      
      string comment = TradeComment + " (PL" + IntegerToString(gGridLevel) + ")";
      int ticket = OrderSend(_Symbol, nextOrderType, lot, nextLevelPrice,
                            Slippage, sl, tp, comment, Magic, 0, clrBlue);
      
      if(ticket > 0) {
         gGridLevel++;
         Print("[V28.19 SCRATCH] Grid level ", gGridLevel - 1,
               " added at ", nextLevelPrice, " Lot:", lot);
      }
   }
}

//+------------------------------------------------------------------+
//| MATH-FIRST REVERSAL                                              |
//| FIX #5: This strategy was DISABLED in V26. Enabled here by default.|
//| Generates trades based on VWAP deviation, probability, entropy.  |
//+------------------------------------------------------------------+
void ExecuteMathFirst()
{
   // Only fire when VWAP deviation is significant
   if(MathAbs(gVWAPDev) < Math_DevTh) return;
   
   // Prevent math reversal spam - only one per trade type at a time
   if(HasComment("MATH")) return;
   
   // Don't fire during active grid (let grid handle trading)
   int totalPositions = CountPositions(OP_BUY) + CountPositions(OP_SELL);
   int pendingOrders = CountPending();
   if(totalPositions + pendingOrders > MaxTrades / 2) return;
   
   double lot = CalculateLotSize(0);
   lot = NormalizeLots(lot);
   if(lot <= 0) return;
   
   // Check momentum: is there a strong deviation that's likely to revert?
   // Count recent price changes to detect chop vs trend
   int changeCount = 0;
   for(int i = 1; i < 20; i++) {
      double c1 = iClose(_Symbol, PERIOD_H1, i);
      double c2 = iClose(_Symbol, PERIOD_H1, i + 1);
      double c3 = iClose(_Symbol, PERIOD_H1, i - 1);
      
      bool up1 = (c1 > c2);
      bool up2 = (c3 > c1);
      if(up1 != up2) changeCount++;
   }
   
   // Low change count = trend (don't reverse), high count = chop (good for mean reversion)
   bool isChoppy = (changeCount >= 8);
   if(!isChoppy) return;
   
   int direction = (gVWAPDev < 0) ? 1 : -1;
   string label = (direction == 1) ? "MATH_BUY" : "MATH_SELL";
   double sl, tp;
   
   if(direction == 1) {
      sl = NormalizeDouble(Ask - Math_SL * Point, Digits);
      tp = NormalizeDouble(Ask + Math_TP * Point, Digits);
      OrderSend(_Symbol, OP_BUY, lot, Ask, Slippage, sl, tp,
               TradeComment + " (" + label + ")", Magic, 0, clrGreen);
   } else {
      sl = NormalizeDouble(Bid + Math_SL * Point, Digits);
      tp = NormalizeDouble(Bid - Math_TP * Point, Digits);
      OrderSend(_Symbol, OP_SELL, lot, Bid, Slippage, sl, tp,
               TradeComment + " (" + label + ")", Magic, 0, clrRed);
   }
}

//+------------------------------------------------------------------+
//| VWAP MEAN REVERSION                                               |
//| Combines VWAP deviation with RSI for confluence entries           |
//+------------------------------------------------------------------+
void ExecuteMeanReversion()
{
   double rsi = iRSI(_Symbol, PERIOD_H1, MR_RSI_Per, PRICE_CLOSE, 0);
   if(rsi < 0) return; // Invalid RSI
   
   // Only fire when VWAP deviation + RSI agree on oversold/overbought
   if(gVWAPDev < -VWAP_Thresh && rsi < MR_OS) {
      if(!HasComment("MR")) {
         double lot = CalculateLotSize(0);
         lot = NormalizeLots(lot);
         if(lot > 0) {
            double sl = NormalizeDouble(Ask - MR_SL * Point, Digits);
            double tp = NormalizeDouble(Ask + MR_TP * Point, Digits);
            OrderSend(_Symbol, OP_BUY, lot, Ask, Slippage, sl, tp,
                     TradeComment + " (MR_BUY)", Magic, 0, clrGreen);
         }
      }
   }
   
   if(gVWAPDev > VWAP_Thresh && rsi > MR_OB) {
      if(!HasComment("MR")) {
         double lot = CalculateLotSize(0);
         lot = NormalizeLots(lot);
         if(lot > 0) {
            double sl = NormalizeDouble(Bid + MR_SL * Point, Digits);
            double tp = NormalizeDouble(Bid - MR_TP * Point, Digits);
            OrderSend(_Symbol, OP_SELL, lot, Bid, Slippage, sl, tp,
                     TradeComment + " (MR_SELL)", Magic, 0, clrRed);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| BASKET PROFIT CHECK                                               |
//+------------------------------------------------------------------+
// (handled in OnTick before execution)

//+------------------------------------------------------------------+
//| TRAIL PENDING ORDERS (THROTTLED - No Modify Loops)               |
//| Called every 200 ticks. V26 called this every tick = 3530 mods.  |
//+------------------------------------------------------------------+
void TrailPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() != Magic) continue;
      int type = OrderType();
      if(type <= OP_SELL) continue;  // Skip market positions
      
      double newPrice = 0;
      if(type == OP_BUYSTOP) {
         newPrice = NormalizeDouble(Bid - Grid_TrailOn * Point, Digits);
         if(newPrice <= 0 || newPrice >= OrderOpenPrice()) continue;
      } else if(type == OP_SELLSTOP) {
         newPrice = NormalizeDouble(Ask + Grid_TrailOn * Point, Digits);
         if(newPrice <= 0 || newPrice <= OrderOpenPrice()) continue;
      } else {
         continue;
      }
      
      // Calculate new SL/TP based on new pending price
      double sl, tp;
      if(type == OP_BUYSTOP) {
         sl = NormalizeDouble(newPrice - Grid_SL * Point, Digits);
         tp = NormalizeDouble(newPrice + Grid_TP * Point, Digits);
      } else {
         sl = NormalizeDouble(newPrice + Grid_SL * Point, Digits);
         tp = NormalizeDouble(newPrice - Grid_TP * Point, Digits);
      }
      
      int ticket = OrderModify(OrderTicket(), newPrice, sl, tp, 0, clrNONE);
      if(ticket) {
         // Only log occasionally to avoid log spam
         // Print("[V28.19] Pending trailed to ", newPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| TRAIL ACTIVE STOPS                                                |
//| Move stop loss to breakeven or trail with price                  |
//+------------------------------------------------------------------+
void TrailActiveStops()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderType() > OP_SELL) continue;  // Skip pending orders
      
      double trailDist = Grid_SL * 0.5 * Point;  // Trail at 50% of original SL
      double newTrail;
      
      if(OrderType() == OP_BUY) {
         newTrail = NormalizeDouble(Bid - trailDist, Digits);
         // Only move SL up (never down)
         if(OrderStopLoss() == 0 || newTrail > OrderStopLoss()) {
            OrderModify(OrderTicket(), OrderOpenPrice(),
                       newTrail, OrderTakeProfit(), 0, clrGreen);
         }
      } else if(OrderType() == OP_SELL) {
         newTrail = NormalizeDouble(Ask + trailDist, Digits);
         // Only move SL down (never up)
         if(OrderStopLoss() == 0 || newTrail < OrderStopLoss()) {
            OrderModify(OrderTicket(), OrderOpenPrice(),
                       newTrail, OrderTakeProfit(), 0, clrRed);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| BASKET CLOSE - Close all trades at profit target                 |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
   // Close market orders first
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderType() == OP_BUY) {
         OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrGreen);
      } else if(OrderType() == OP_SELL) {
         OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);
      }
   }
   
   // Delete pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderType() > OP_SELL) {
         OrderDelete(OrderTicket(), clrGray);
      }
   }
}

//+------------------------------------------------------------------+
//| HELPER: Has comment string in any open position                   |
//+------------------------------------------------------------------+
bool HasComment(string searchTerm)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderType() > OP_SELL) continue;  // Only check market positions
      if(StringFind(OrderComment(), searchTerm) >= 0) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| HELPER: Check if pending order exists near price                 |
//| FIX: Prevents duplicate orders at same level                     |
//+------------------------------------------------------------------+
bool PendingNear(double price, double margin)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderType() <= OP_SELL) continue;  // Only check pending orders
      if(MathAbs(OrderOpenPrice() - price) < margin) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| HELPER: Count positions by type                                   |
//+------------------------------------------------------------------+
int CountPositions(int type)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderType() == type) count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| HELPER: Count pending orders                                      |
//+------------------------------------------------------------------+
int CountPending()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderType() > OP_SELL) count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| HELPER: Calculate basket P&L                                      |
//+------------------------------------------------------------------+
double CalcBasketPnL()
{
   double total = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderType() <= OP_SELL) {
         total += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }
   return total;
}

//+------------------------------------------------------------------+
//| HELPER: Reset grid state                                          |
//+------------------------------------------------------------------+
void ResetGrid()
{
   gGridDir = 0;
   gGridBasePrice = 0;
   gGridLevel = 0;
}

//+------------------------------------------------------------------+
//| HELPER: Calculate lot size with auto-sizing                       |
//+------------------------------------------------------------------+
double CalculateLotSize(int level)
{
   double lot = BaseLot;
   
   if(UseAutoLot) {
      double atr = iATR(_Symbol, PERIOD_H1, VWAP_ATRPeriod, 0);
      double riskMoney = AccountBalance() * RiskPct / 100.0;
      double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
      if(tickValue > 0) {
         lot = riskMoney / (Grid_SL * tickValue + 0.0001);
      }
   }
   
   // Apply lot exponent for grid levels
   if(level > 0) {
      lot *= MathPow(Grid_LotExp, level);
   }
   
   // Elastic risk dampening in drawdown
   if(gPeakEquity > 0) {
      double ddPct = (gPeakEquity - AccountEquity()) / gPeakEquity * 100.0;
      if(ddPct > 6.0) {
         lot *= MathMax(0.3, 1.0 - (ddPct / 12.0));
      }
   }
   
   lot = NormalizeLots(lot);
   return lot;
}

//+------------------------------------------------------------------+
//| HELPER: Normalize lots to broker constraints                     |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot = MarketInfo(_Symbol, MODE_MINLOT);
   double maxLot = MarketInfo(_Symbol, MODE_MAXLOT);
   double lotStep = MarketInfo(_Symbol, MODE_LOTSTEP);
   
   if(lotStep > 0) lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = NormalizeDouble(lots, 2);
   
   return lots;
}

//+------------------------------------------------------------------+
//| HELPER: Bad spread check                                          |
//+------------------------------------------------------------------+
bool IsBadSpread()
{
   double spread = MarketInfo(_Symbol, MODE_SPREAD);
   return(spread > MaxSpread);
}

//+------------------------------------------------------------------+
//| HELPER: Maximum drawdown breach check                             |
//+------------------------------------------------------------------+
bool IsDD_Breach()
{
   if(gPeakEquity <= 0) return false;
   double ddPct = (gPeakEquity - AccountEquity()) / gPeakEquity * 100.0;
   return(ddPct > 12.0);
}

//+------------------------------------------------------------------+
//| HELPER: Trading hours filter (avoid low-liquidity hours)          |
//+------------------------------------------------------------------+
bool IsOffHours()
{
   int hour = Hour();
   // Trade only during active market hours (roughly 8:00-20:00 server time)
   if(hour < 8 || hour >= 20) return true;
   return false;
}
//+------------------------------------------------------------------+
