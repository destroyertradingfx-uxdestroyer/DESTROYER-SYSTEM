//+------------------------------------------------------------------+
//|               DESTROYER_V28_19_CERBERUS_FULL.mq4                |
//|           Copyright 2026, DESTROYER Trading Systems              |
//|  V28.19 - VWAP ANCHOR + SILICON-X PIPELINER + V26 ARCHITECTURE  |
//|  KEY FIX: Zero modify loops, clean pipelining, VWAP alpha       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DESTROYER Trading Systems"
#property link      "https://github.com/destroyertradingfx-uxdestroyer"
#property version   "28.19"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input string InpHdr_Gen     = "====== DESTROYER V28.19 ======";
input int    InpMagic       = 7772819;
input string InpComment     = "DST_V28.19";
input double InpBaseLot     = 0.01;
input bool   InpAutoLot     = true;
input double InpRiskPct     = 1.5;
input int    InpMaxTrades   = 12;
input int    InpMaxSpread   = 30;
input int    InpSlippage    = 3;

input string InpHdr_VWAP    = "====== VWAP ANCHOR ======";
input bool   InpVWAP_On     = true;
input int    InpVWAP_Per    = 20;

input string InpHdr_Grid    = "====== PIPELINER (Silicon-X++) ======";
input bool   InpGrid_On     = true;
input double InpGrid_Dist   = 150;
input int    InpGrid_MaxLvl = 10;
input double InpGrid_Exp    = 1.35;
input double InpGrid_TP     = 2000;
input double InpGrid_SL     = 1000;
input double InpGrid_TrailOn= 500;
input bool   InpGrid_Ada    = true;
input double InpGrid_ATRMul = 0.8;
input double InpGrid_Basket$= 350;

input string InpHdr_Math    = "====== MATH-FIRST ======";
input bool   InpMath_On     = true;
input double InpMath_TP     = 1500;
input double InpMath_SL     = 800;

input string InpHdr_MR      = "====== VWAP MEAN-REVERSION ======";
input bool   InpMR_On       = true;
input int    InpMR_RSI      = 10;
input double InpMR_OB       = 68;
input double InpMR_OS       = 32;
input double InpMR_TP       = 1200;
input double InpMR_SL       = 600;

input string InpHdr_Titan   = "====== MTF MOMENTUM ======";
input bool   InpTitan_On    = true;
input int    InpTitan_D1    = 50;
input int    InpTitan_H4    = 34;

//+------------------------------------------------------------------+
double gVWAP=0, gVWAP_Dev=0, gVWAP_Slope=0;
int    gMath_Sig=0;
double gRSI=0;
bool   gD1B=false, gH4B=false;
int    gPipDir=0;
double gPipBase=0;
int    gPipLvl=0;
datetime gLastBar=0;
int    gTickCnt=0;
double gPeakEq=0;

int OnInit(){
   Print("=== DESTROYER V28.19 ===");
   Print("V:",InpVWAP_On,"G:",InpGrid_On,"M:",InpMath_On,"R:",InpMR_On,"T:",InpTitan_On);
   gPeakEq=AccountEquity();
   gLastBar=iTime(_Symbol,PERIOD_H1,0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int r){
   Print("V28.19 stopped. Trades:",Cnt(OP_BUY)+Cnt(OP_SELL)," Basket:$",DoubleToString(Basket$(),2));
}

void OnTick(){
   bool nb=(iTime(_Symbol,PERIOD_H1,0)!=gLastBar);
   if(nb)gLastBar=iTime(_Symbol,PERIOD_H1,0);
   gTickCnt++;
   
   if(MarketInfo(_Symbol,MODE_SPREAD)>InpMaxSpread)return;
   double dd=(gPeakEq-AccountEquity())/gPeakEq*100;
   if(dd>12.0)return;
   if(AccountEquity()>gPeakEq)gPeakEq=AccountEquity();
   
   if(nb){
      CalcVWAP();
      if(InpMath_On)CalcMath();
      if(InpMR_On)gRSI=iRSI(NULL,PERIOD_H1,InpMR_RSI,PRICE_CLOSE,0);
      Titan_Calc();
   }
   
   if(InpGrid_On&&InpVWAP_On)RunGrid();
   if(InpMath_On)RunMath();
   if(InpMR_On&&InpVWAP_On)RunMR();
   if(InpTitan_On&&nb)RunTitan();
   
   if(nb)TrailPendings();
   if(nb)BasketClose();
   if(gTickCnt%5000==0)TrailStops();
}

void CalcVWAP(){
   double ch=0,cv=0;
   for(int i=0;i<InpVWAP_Per;i++){
      double h=iHigh(_Symbol,1,i),l=iLow(_Symbol,1,i),c=iClose(_Symbol,1,i);
      double v=iVolume(_Symbol,1,i);
      ch+=((h+l+c)/3.0)*v; cv+=v;
   }
   if(cv>0){
      double old=gVWAP; gVWAP=ch/cv;
      gVWAP_Slope=gVWAP-old;
      double sq=0;
      for(int i=0;i<InpVWAP_Per;i++){
         double c=iClose(_Symbol,1,i); sq+=(c-gVWAP)*(c-gVWAP);
      }
      double std=(InpVWAP_Per>0)?MathSqrt(sq/InpVWAP_Per):0;
      if(std>0)gVWAP_Dev=(Close[0]-gVWAP)/std;
   }
}

void CalcMath(){
   gMath_Sig=0;
   if(gVWAP_Dev<-1.5)gMath_Sig=1;
   else if(gVWAP_Dev>1.5)gMath_Sig=-1;
}

void Titan_Calc(){
   double c=Close[0];
   gD1B=(c>iMA(NULL,PERIOD_D1,InpTitan_D1,0,MODE_EMA,PRICE_CLOSE,0));
   gH4B=(c>iMA(NULL,PERIOD_H4,InpTitan_H4,0,MODE_EMA,PRICE_CLOSE,0));
}

void RunGrid(){
   double dist=InpGrid_Dist;
   if(InpGrid_Ada){
      double atr=iATR(NULL,PERIOD_H1,14,0)/Point;
      dist=MathMax(InpGrid_Dist*0.5,atr*InpGrid_ATRMul);
      dist=MathMin(dist,InpGrid_Dist*3.0);
   }
   
   int buys=Cnt(OP_BUY),sells=Cnt(OP_SELL),tot=buys+sells;
   bool doB=(gVWAP_Dev<-1.0);
   bool doS=(gVWAP_Dev> 1.0);
   
   if(tot==0&&(doB||doS)){
      if(doB&&!HasPend(OP_BUYSTOP)){
         double lot=CLot(0);
         double p=Ask-dist*Point;
         OGrid(OP_BUYSTOP,lot,p); gPipDir=1; gPipBase=p; gPipLvl=1;
      }
      if(doS&&!HasPend(OP_SELLSTOP)){
         double lot=CLot(1);
         double p=Bid+dist*Point;
         OGrid(OP_SELLSTOP,lot,p); gPipDir=2; gPipBase=p; gPipLvl=1;
      }
      return;
   }
   
   if(gPipDir==1&&tot<InpGrid_MaxLvl&&buys>0){
      double lvl=gPipBase-(gPipLvl)*dist*Point;
      if(!PNear(lvl,dist*Point*0.3)&&!HasPend(OP_BUYSTOP)){
         double lot=InpBaseLot*MathPow(InpGrid_Exp,gPipLvl);
         OGrid(OP_BUYSTOP,lot,lvl); gPipLvl++;
      }
   }
   if(gPipDir==2&&tot<InpGrid_MaxLvl&&sells>0){
      double lvl=gPipBase+(gPipLvl)*dist*Point;
      if(!PNear(lvl,dist*Point*0.3)&&!HasPend(OP_SELLSTOP)){
         double lot=InpBaseLot*MathPow(InpGrid_Exp,gPipLvl);
         OGrid(OP_SELLSTOP,lot,lvl); gPipLvl++;
      }
   }
}

void RunMath(){
   if(gMath_Sig==0)return;
   if(CntTxt("MATH")>0)return;
   double lot=CLot(gMath_Sig==1?0:1);
   if(gMath_Sig==1)Trade(0,lot,Close[0]-InpMath_SL*Point,Close[0]+InpMath_TP*Point,"MATH_B");
   if(gMath_Sig==-1)Trade(1,lot,Close[0]+InpMath_SL*Point,Close[0]-InpMath_TP*Point,"MATH_S");
}

void RunMR(){
   if(!InpVWAP_On)return;
   if(gVWAP_Dev<-1.0&&gRSI<InpMR_OS){
      if(CntTxt("MR_B")==0)Trade(0,CLot(0),Low[1]-20*Point,Close[0]+InpMR_TP*Point,"MR_B");
   }
   if(gVWAP_Dev>1.0&&gRSI>InpMR_OB){
      if(CntTxt("MR_S")==0)Trade(1,CLot(1),High[1]+20*Point,Close[0]-InpMR_TP*Point,"MR_S");
   }
}

void RunTitan(){
   if(!gD1B||!gH4B)return;
   if(CntTxt("TITAN")>0)return;
   if(gVWAP_On&&MathAbs(gVWAP_Dev)<0.5)return;
   Trade(0,CLot(0),Low[1]-30*Point,Close[0]+2000*Point,"TITAN_B");
}

void TrailPendings(){
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS))continue;
      if(OrderMagicNumber()!=InpMagic||OrderType()<=1)continue;
      double np=0;
      if(OrderType()==OP_BUYSTOP)  np=Bid-InpGrid_TrailOn*Point;
      if(OrderType()==OP_SELLSTOP) np=Ask+InpGrid_TrailOn*Point;
      bool m=false;
      if(OrderType()==OP_BUYSTOP&&np>0&&np<OrderOpenPrice())m=true;
      if(OrderType()==OP_SELLSTOP&&np>0&&np>OrderOpenPrice())m=true;
      if(!m)continue;
      double sl,tp;
      if(OrderType()==OP_BUYSTOP){sl=nd(np-InpGrid_SL*Point);tp=nd(np+InpGrid_TP*Point);}
      else{sl=nd(np+InpGrid_SL*Point);tp=nd(np-InpGrid_TP*Point);}
      OrderModify(OrderTicket(),nd(np),sl,tp,0,clrNONE);
   }
}

void TrailStops(){
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS))continue;
      if(OrderMagicNumber()!=InpMagic||OrderType()>1)continue;
      double tr=(OrderType()==OP_BUY)?nd(Bid-InpGrid_SL*0.5*Point):nd(Ask+InpGrid_SL*0.5*Point);
      if(OrderStopLoss()==0||tr>OrderStopLoss())
         OrderModify(OrderTicket(),OrderOpenPrice(),tr,OrderTakeProfit(),0,clrNONE);
   }
}

void BasketClose(){
   double p=Basket$();
   if(p>=InpGrid_Basket$){
      Print("V28.19 Basket $",p," close all");
      CloseAll(); gPipDir=0; gPipLvl=0;
   }
}

//+------------------------------------------------------------------+
//| HELPERS                                                           |
//+------------------------------------------------------------------+
int Cnt(int t){int c=0;for(int i=OrdersTotal()-1;i>=0;i--)
   if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagic&&OrderType()==t)c++;return c;}
int CntTxt(string t){int c=0;for(int i=OrdersTotal()-1;i>=0;i--)
   if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagic&&
      StringFind(OrderComment(),t)>=0&&OrderType()<2)c++;return c;}
bool HasPend(int t){for(int i=OrdersTotal()-1;i>=0;i--)
   if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagic&&OrderType()==t)return true;return false;}
bool PNear(double p,double thr){for(int i=OrdersTotal()-1;i>=0;i--)
   if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagic&&OrderType()>1&&MathAbs(OrderOpenPrice()-p)<thr)return true;return false;}
double Basket$(){double p=0;for(int i=OrdersTotal()-1;i>=0;i--)
   if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagic&&OrderType()<2)
      p+=OrderProfit()+OrderSwap()+OrderCommission();return p;}

void CloseAll(){
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagic){
         if(OrderType()==OP_BUY)OrderClose(OrderTicket(),OrderLots(),Bid,InpSlippage,clrGreen);
         if(OrderType()==OP_SELL)OrderClose(OrderTicket(),OrderLots(),Ask,InpSlippage,clrRed);
      }
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagic&&OrderType()>1)
         OrderDelete(OrderTicket(),clrGray);
}

double CLot(int t){
   double lot=InpBaseLot;
   if(InpAutoLot){
      double atr=iATR(NULL,PERIOD_H1,14,0);
      double risk$=AccountBalance()*InpRiskPct/100.0;
      double pipV=MarketInfo(_Symbol,MODE_TICKVALUE);
      lot=risk$/(InpGrid_SL*pipV+0.0001);
   }
   double mn=MarketInfo(_Symbol,MODE_MINLOT),mx=MarketInfo(_Symbol,MODE_MAXLOT),st=MarketInfo(_Symbol,MODE_LOTSTEP);
   lot=MathMax(mn,MathMin(mx,lot));lot=MathFloor(lot/st)*st;
   return lot;
}

bool Trade(int t,double lot,double sl,double tp,string c){
   if(lot<=0)return false;
   double op=(t==0)?Ask:Bid;
   return(OrderSend(_Symbol,t,lot,op,InpSlippage,sl,tp,InpComment+"("+c+")",InpMagic,0,(t==0)?clrGreen:clrRed)>0);
}

bool OGrid(int t,double lot,double price){
   if(lot<=0||(Cnt(OP_BUY)+Cnt(OP_SELL)+CntPend())>=InpMaxTrades)return false;
   double sl=(t==OP_BUYSTOP)?nd(price-InpGrid_SL*Point):nd(price+InpGrid_SL*Point);
   double tp=(t==OP_BUYSTOP)?nd(price+InpGrid_TP*Point):nd(price-InpGrid_TP*Point);
   return(OrderSend(_Symbol,t,lot,nd(price),InpSlippage,sl,tp,InpComment+"(PL"+IntegerToString(Cnt(OP_BUY)+Cnt(OP_SELL))+")",InpMagic,0,clrBlue)>0);
}

int CntPend(){int c=0;for(int i=OrdersTotal()-1;i>=0;i--)
   if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagic&&OrderType()>1)c++;return c;}
double nd(double v){return(NormalizeDouble(v,Digits));}
//+------------------------------------------------------------------+
