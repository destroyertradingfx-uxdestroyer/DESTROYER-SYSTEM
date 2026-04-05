//+------------------------------------------------------------------+
//|               DESTROYER_V28_19_CERBERUS.mq4                     |
//|           Copyright 2026, DESTROYER Trading Systems              |
//|  V28.19 - VWAP ANCHOR + CLEAN PIPELINER                         |
//|  MQL4 ONLY · Zero modify loops · Fresh start                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DESTROYER Trading Systems"
#property link      "https://github.com/destroyertradingfx-uxdestroyer"
#property version   "28.19"
#property strict
#property description "V28.19 CERBERUS - Fresh MQL4 build"
#property description "VWAP Anchor + Clean Pipeliner Grid"

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input string _hdr0 = "=========== GENERAL ===========";
input int    Magic       = 28019;
input string CommentStr  = "V28.19";
input double BaseLot     = 0.01;
input bool   UseAutoLot  = true;
input double RiskPct     = 1.0;
input int    MaxTrades   = 12;
input int    MaxSpread   = 30;

input string _hdr1 = "=========== VWAP ===========";
input bool   UseVWAP     = true;
input int    VWAPPeriod  = 21;
input double VWAP_Thresh = 1.0;
input double VWAP_Extreme = 2.5;

input string _hdr2 = "=========== PIPELINER GRID ===========";
input bool   UseGrid     = true;
input double Grid_Step   = 150;
input int    Grid_Levels = 10;
input double Grid_LotExp = 1.35;
input double Grid_TP     = 2000;
input double Grid_SL     = 1000;
input double Grid_TrailOn= 500;
input bool   Grid_Adapt  = true;
input double Grid_Basket$= 350;

input string _hdr3 = "=========== MATH-FIRST ===========";
input bool   UseMath     = true;
input double Math_TP    = 1500;
input double Math_SL    = 800;

input string _hdr4 = "=========== VWAP MR ===========";
input bool   UseMR       = true;
input int    MR_RSI      = 10;
input double MR_OB       = 68;
input double MR_OS       = 32;
input double MR_TP       = 1200;
input double MR_SL       = 600;

//+------------------------------------------------------------------+
//| GLOBALS                                                           |
//+------------------------------------------------------------------+
double gVWAP=0, gVWAPDev=0;
int    gGridDir=0;
double gGridBase=0;
int    gGridLvl=0;
datetime gBar=0;
int    gTick=0;
double gPeak=0;

//+------------------------------------------------------------------+
int OnInit(){
   Print("V28.19 CERBERUS starting");
   Print("VWAP:",UseVWAP," Grid:",UseGrid," Math:",UseMath," MR:",UseMR);
   gPeak=AccountEquity();
   gBar=iTime(_Symbol,PERIOD_H1,0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int r){
   Print("V28.19 stopped. Pos:",N(OP_BUY)+N(OP_SELL)," $",DoubleToString(Basket(),2));
}

//+------------------------------------------------------------------+
void OnTick(){
   bool nb=(iTime(_Symbol,PERIOD_H1,0)!=gBar);
   if(nb) gBar=iTime(_Symbol,PERIOD_H1,0);
   gTick++;
   
   if(MarketInfo(_Symbol,MODE_SPREAD)>MaxSpread) return;
   if(AccountEquity()<gPeak*(1-12.0/100)) return;
   if(AccountEquity()>gPeak) gPeak=AccountEquity();
   
   if(nb){
      if(UseVWAP) CalcVWAP();
   }
   
   if(UseGrid&&UseVWAP)  RunGrid();
   if(UseMath)           RunMath();
   if(UseMR&&UseVWAP)    RunMR();
   if(nb)                BasketClose();
   if(gTick%200==0)      TrailPend();
   if(nb)                TrailStop();
}

//+------------------------------------------------------------------+
//| CORE FUNCTIONS                                                    |
//+------------------------------------------------------------------+
void CalcVWAP(){
   double ch=0,cv=0;
   for(int i=0;i<VWAPPeriod;i++){
      double t=(iHigh(_Symbol,1,i)+iLow(_Symbol,1,i)+iClose(_Symbol,1,i))/3.0;
      double v=iVolume(_Symbol,1,i);
      ch+=t*v; cv+=v;
   }
   if(cv==0) return;
   double old=gVWAP; gVWAP=ch/cv;
   
   double sq=0;
   for(int i=0;i<VWAPPeriod;i++){
      double d=iClose(_Symbol,1,i)-gVWAP;
      sq+=d*d;
   }
   double sd=MathSqrt(sq/VWAPPeriod);
   if(sd>0) gVWAPDev=(iClose(_Symbol,1,0)-gVWAP)/sd;
}

void RunGrid(){
   double step=Grid_Step;
   if(Grid_Adapt){
      double a=iATR(_Symbol,PERIOD_H1,14,0)/Point;
      step=MathMax(Grid_Step*0.5,a*0.8);
      step=MathMin(step,Grid_Step*3.0);
   }
   double sp=step*Point;
   
   int buys=N(OP_BUY),sells=N(OP_SELL);
   int tot=buys+sells+PendingCount();
   if(tot>=MaxTrades) return;
   
   bool buySig=(gVWAPDev<-VWAP_Thresh);
   bool sellSig=(gVWAPDev> VWAP_Thresh);
   
   // Force direction on extreme deviation
   if(gVWAPDev<-VWAP_Extreme)  {buySig=true;  sellSig=false;}
   if(gVWAPDev> VWAP_Extreme)  {sellSig=true; buySig=false;}
   
   if(tot==0&&gGridLvl==0){
      if(buySig){
         double lot=Lot(0);
         double p=Ask-sp;
         if(OpenPend(OP_BUYSTOP,lot,p,1)){gGridDir=1;gGridBase=p;gGridLvl=1;}
      }
      if(sellSig){
         double lot=Lot(1);
         double p=Bid+sp;
         if(OpenPend(OP_SELLSTOP,lot,p,1)){gGridDir=2;gGridBase=p;gGridLvl=1;}
      }
      return;
   }
   
   int lvl=gGridLvl;
   if(lvl<Grid_Levels){
      if(gGridDir==1&&buys>0){
         double lvl2=gGridBase-sp*lvl;
         if(!PendingNear(lvl2,sp*0.3)){
            double lot=BaseLot*MathPow(Grid_LotExp,lvl);
            if(OpenPend(OP_BUYSTOP,lot,lvl2,1)) gGridLvl++;
         }
      }
      if(gGridDir==2&&sells>0){
         double lvl2=gGridBase+sp*lvl;
         if(!PendingNear(lvl2,sp*0.3)){
            double lot=BaseLot*MathPow(Grid_LotExp,lvl);
            if(OpenPend(OP_SELLSTOP,lot,lvl2,1)) gGridLvl++;
         }
      }
   }
}

void RunMath(){
   if(MathAbs(gVWAPDev)<VWAP_Thresh) return;
   int sig=(gVWAPDev<0)?1:-1;
   if(HasComment("MATH")) return;
   double lot=Lot(0);
   if(sig==1) Trade(OP_BUY,lot,Ask-Math_SL*Point,Ask+Math_TP*Point,"MATH");
   else       Trade(OP_SELL,lot,Bid+Math_SL*Point,Bid-Math_TP*Point,"MATH");
}

void RunMR(){
   double rsi=iRSI(_Symbol,PERIOD_H1,MR_RSI,PRICE_CLOSE,0);
   if(gVWAPDev<-VWAP_Thresh && rsi<MR_OS){
      if(!HasComment("MR")) Trade(OP_BUY,Lot(0),Ask-MR_SL*Point,Ask+MR_TP*Point,"MR");
   }
   if(gVWAPDev>VWAP_Thresh && rsi>MR_OB){
      if(!HasComment("MR")) Trade(OP_SELL,Lot(0),Bid+MR_SL*Point,Bid-MR_TP*Point,"MR");
   }
}

void BasketClose(){
   double b=Basket();
   if(b>=Grid_Basket$){
      Print("V28.19 Basket $",b," - close all");
      CloseAll(); gGridDir=0; gGridLvl=0;
   }
}

void TrailPend(){
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS)) continue;
      if(OrderMagicNumber()!=Magic) continue;
      int t=OrderType();
      if(t<=1) continue;
      double np=0;
      if(t==OP_BUYSTOP)  np=Bid-Grid_TrailOn*Point;
      if(t==OP_SELLSTOP) np=Ask+Grid_TrailOn*Point;
      if(np<=0) continue;
      bool mv=false;
      if(t==OP_BUYSTOP && np<OrderOpenPrice()) mv=true;
      if(t==OP_SELLSTOP && np>OrderOpenPrice()) mv=true;
      if(!mv) continue;
      
      double sl,tp;
      if(t==OP_BUYSTOP){sl=nd(np-Grid_SL*Point);tp=nd(np+Grid_TP*Point);}
      else{sl=nd(np+Grid_SL*Point);tp=nd(np-Grid_TP*Point);}
      
      OrderModify(OrderTicket(),nd(np),sl,tp,0,clrNONE);
   }
}

void TrailStop(){
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS)) continue;
      if(OrderMagicNumber()!=Magic) continue;
      if(OrderType()>1) continue;
      double trail;
      if(OrderType()==OP_BUY) trail=nd(Bid-Grid_SL*0.5*Point);
      else trail=nd(Ask+Grid_SL*0.5*Point);
      if(OrderStopLoss()==0 || trail>OrderStopLoss())
         OrderModify(OrderTicket(),OrderOpenPrice(),trail,OrderTakeProfit(),0,clrNONE);
   }
}

//+------------------------------------------------------------------+
//| HELPERS                                                           |
//+------------------------------------------------------------------+
int N(int t){int c=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==Magic&&OrderType()==t)c++;return c;}

int PendingCount(){int c=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==Magic&&OrderType()>1)c++;return c;}

bool HasComment(string s){
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==Magic&&
         OrderType()<2&&StringFind(OrderComment(),s)>=0) return true;
   return false;
}

bool PendingNear(double p,double margin){
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==Magic&&OrderType()>1&&
         MathAbs(OrderOpenPrice()-p)<margin) return true;
   return false;
}

double Basket(){double p=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==Magic&&OrderType()<2)
         p+=OrderProfit()+OrderSwap()+OrderCommission();return p;}

void CloseAll(){
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==Magic){
         if(OrderType()==OP_BUY) OrderClose(OrderTicket(),OrderLots(),Bid,3,clrGreen);
         if(OrderType()==OP_SELL) OrderClose(OrderTicket(),OrderLots(),Ask,3,clrRed);
      }
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==Magic&&OrderType()>1)
         OrderDelete(OrderTicket(),clrGray);
}

double Lot(int t){
   double lot=BaseLot;
   if(UseAutoLot){
      double atr=iATR(_Symbol,PERIOD_H1,14,0);
      double risk$=AccountBalance()*RiskPct/100.0;
      double tv=MarketInfo(_Symbol,MODE_TICKVALUE);
      lot=risk$/(Grid_SL*tv+0.0001);
   }
   double mn=MarketInfo(_Symbol,MODE_MINLOT);
   double mx=MarketInfo(_Symbol,MODE_MAXLOT);
   double st=MarketInfo(_Symbol,MODE_LOTSTEP)+0.0001;
   lot=MathMax(mn,MathMin(mx,lot));
   lot=MathFloor(lot/st)*st;
   return lot;
}

bool Trade(int t,double lot,double sl,double tp,string c){
   if(lot<=0) return false;
   double pr=(t==OP_BUY)?Ask:Bid;
   string cm=CommentStr+" ("+c+")";
   return(OrderSend(_Symbol,t,lot,pr,3,sl,tp,cm,Magic,0,(t==0)?clrGreen:clrRed)>0);
}

bool OpenPend(int t,double lot,double pr,int lv){
   if(lot<=0) return false;
   double sl,tp;
   if(t==OP_BUYSTOP){sl=nd(pr-Grid_SL*Point);tp=nd(pr+Grid_TP*Point);}
   else{sl=nd(pr+Grid_SL*Point);tp=nd(pr-Grid_TP*Point);}
   string cm=CommentStr+" (PL"+IntegerToString(lv)+")";
   int ticket=OrderSend(_Symbol,t,lot,nd(pr),3,sl,tp,cm,Magic,0,clrBlue);
   return(ticket>0);
}

double nd(double v){return(NormalizeDouble(v,Digits));}
