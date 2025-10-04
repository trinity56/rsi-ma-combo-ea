//+------------------------------------------------------------------+
//|         RSI+MA Combo EA - Final Build (Optimized & Safe)         |
//| Features: RSI+MA entry, ADX & Time filters, Trailing stop,       |
//| Break-even, Daily profit/loss pause, dynamic exit, robust logic. |
//| Improved error handling, magic number, broker constraints.        |
//+------------------------------------------------------------------+
#property strict

//---- Inputs
input double LotSize           = 0.01;
input int    RSI_Period        = 14;
input int    RSI_Buy_Level     = 30;
input int    RSI_Sell_Level    = 70;
input int    MA_Period         = 25;
input int    StopLossPips      = 20;
input int    TakeProfitPips    = 40;

input bool   UseTrailingStop   = true;
input int    TrailingStart     = 5;   // in pips
input int    TrailingStep      = 2;   // in pips

input bool   UseBreakEven      = true;
input int    BreakEvenTrigger  = 8;   // in pips
input int    BreakEvenOffset   = 1;   // in pips

input bool   UseTimeFilter     = true;
input int    TradeStartHour    = 8;
input int    TradeEndHour      = 18;

input bool   UseADXFilter      = true;
input int    ADX_Period        = 14;
input int    ADX_Minimum       = 20;

input bool   UseDailyLimit     = true;   // enable daily pause feature
input double DailyProfitTarget = 10.0;   // USD profit to trigger pause
input double DailyLossLimit    = 10.0;   // USD loss to trigger pause
input int    PauseDurationHours= 4;      // hours to pause when triggered

// Dynamic Exit inputs
input bool   UseDynamicExit    = true;   // Close early on opposite signal
input int    ConfirmBars       = 2;      // Number of consecutive opposite bars to confirm reversal
input double ADXExitThreshold  = 20.0;   // Minimum ADX strength to allow exit

input int    MagicNumber       = 12345;  // <-- Added Magic Number for safe order management

//---- Globals
datetime pausedUntil = 0;
int pauseReason = 0; // 0 = none, 1 = profit, 2 = loss
string labelName = "EA_Status_Label";
datetime lastTradeBarTime = 0; // for entry-once-per-bar

//+------------------------------------------------------------------+
int OnInit() {
   CreateOrUpdateLabel("⚪ Trading active - All systems running.", clrWhite);
   Print("RSI+MA Combo EA vFinal initialized.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(ObjectFind(labelName) >= 0) ObjectDelete(labelName);
}

//+------------------------------------------------------------------+
void OnTick() {
   // update pause status from daily P/L if enabled
   if(UseDailyLimit) {
      double todayPL = GetTodayClosedProfit();
      if(pausedUntil <= TimeCurrent()) {
         if(todayPL >= DailyProfitTarget && DailyProfitTarget > 0) {
            pausedUntil = TimeCurrent() + PauseDurationHours * 3600;
            pauseReason = 1;
            CreateOrUpdateLabel("🟢 Trading paused - Daily Profit Target Hit! ⏰ Resumes at: " + TimeToString(pausedUntil, TIME_MINUTES), clrGreen);
         } else if(todayPL <= -MathAbs(DailyLossLimit) && DailyLossLimit > 0) {
            pausedUntil = TimeCurrent() + PauseDurationHours * 3600;
            pauseReason = 2;
            CreateOrUpdateLabel("🔴 Trading paused - Daily Loss Limit Reached! ⏰ Resumes at: " + TimeToString(pausedUntil, TIME_MINUTES), clrRed);
         }
      } else {
         if(pausedUntil > TimeCurrent()) {
            CreateOrUpdateLabel((pauseReason==1?"🟢 Trading paused - Daily Profit Target Hit!":"🔴 Trading paused - Daily Loss Limit Reached!") + " ⏰ Resumes at: " + TimeToString(pausedUntil,TIME_MINUTES), (pauseReason==1?clrGreen:clrRed));
            ManageTrade();
            return;
         } else {
            pausedUntil = 0;
            pauseReason = 0;
            CreateOrUpdateLabel("⚪ Trading active - All systems running.", clrWhite);
         }
      }
   }

   // Time Filter
   if(UseTimeFilter) {
      int currentHour = Hour();
      if(currentHour < TradeStartHour || currentHour >= TradeEndHour) {
         ManageTrade();
         return;
      }
   }

   // manage open trades first
   if(CountOpenOrders() > 0) {
      ManageTrade();
      return;
   }

   // only trade once per bar
   if(lastTradeBarTime == iTime(NULL, 0, 0)) return;

   // core indicators
   double rsi = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,0);
   double ma  = iMA(NULL,0,MA_Period,0,MODE_SMA,PRICE_CLOSE,0);
   double adx = iADX(NULL,0,ADX_Period,PRICE_CLOSE,MODE_MAIN,0);
   double plusDI = iADX(NULL,0,ADX_Period,PRICE_CLOSE,MODE_PLUSDI,0);
   double minusDI = iADX(NULL,0,ADX_Period,PRICE_CLOSE,MODE_MINUSDI,0);
   double price = Bid;

   // ADX Filter (strength & direction)
   if(UseADXFilter && adx < ADX_Minimum) return;

   // Prevent duplicate entries per bar
   if(IsTradingPaused()) return;

   // Buy condition
   if(rsi <= RSI_Buy_Level && price > ma && plusDI > minusDI) {
      if(!HasOpenOrder(OP_BUY)) {
         if(OpenTrade(OP_BUY)) lastTradeBarTime = iTime(NULL, 0, 0);
      }
   }

   // Sell condition
   if(rsi >= RSI_Sell_Level && price < ma && minusDI > plusDI) {
      if(!HasOpenOrder(OP_SELL)) {
         if(OpenTrade(OP_SELL)) lastTradeBarTime = iTime(NULL, 0, 0);
      }
   }
}

//+------------------------------------------------------------------+
bool IsTradingPaused() {
   if(!UseDailyLimit) return(false);
   if(pausedUntil == 0) return(false);
   return(pausedUntil > TimeCurrent());
}

//+------------------------------------------------------------------+
// Returns true if trade opened successfully
bool OpenTrade(int type) {
   double sl,tp,price;
   double point = MarketInfo(Symbol(), MODE_POINT);
   int digits = MarketInfo(Symbol(), MODE_DIGITS);
   double pip = (digits==3 || digits==5) ? point*10 : point;

   // Broker stop level check
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * pip;
   if(StopLossPips * pip < stopLevel) { Print("SL too close to market. Adjust your StopLossPips."); return(false); }
   if(TakeProfitPips * pip < stopLevel) { Print("TP too close to market. Adjust your TakeProfitPips."); return(false); }

   if(type==OP_BUY) {
      price = Ask;
      sl = price - StopLossPips * pip;
      tp = price + TakeProfitPips * pip;
   } else {
      price = Bid;
      sl = price + StopLossPips * pip;
      tp = price - TakeProfitPips * pip;
   }

   int ticket = OrderSend(Symbol(), type, LotSize, price, 3, sl, tp, "RSI_MA_Trade", MagicNumber, 0, clrBlue);
   if(ticket > 0) {
      Print("Order opened: ", ticket);
      return(true);
   } else {
      int err = GetLastError();
      Print("OrderSend failed: ", err);
      // Optionally add retry logic for common errors
      return(false);
   }
}

//+------------------------------------------------------------------+
// Count open orders for this EA
int CountOpenOrders() {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
// Returns true if an order of the given type exists
bool HasOpenOrder(int type) {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == type)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
void ManageTrade() {
   double point = MarketInfo(Symbol(), MODE_POINT);
   int digits = MarketInfo(Symbol(), MODE_DIGITS);
   double pip = (digits==3 || digits==5) ? point*10 : point;
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * pip;

   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;

      double profitPips = (OrderType() == OP_BUY) ? (Bid - OrderOpenPrice())/pip : (OrderOpenPrice() - Ask)/pip;
      double newSL;

      // Break-even
      if(UseBreakEven && profitPips >= BreakEvenTrigger) {
         if(OrderType() == OP_BUY && OrderStopLoss() < OrderOpenPrice()) {
            newSL = OrderOpenPrice() + BreakEvenOffset * pip;
            if((OrderOpenPrice() - newSL) >= stopLevel)
               OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrYellow);
         }
         else if(OrderType() == OP_SELL && (OrderStopLoss() > OrderOpenPrice() || OrderStopLoss()==0)) {
            newSL = OrderOpenPrice() - BreakEvenOffset * pip;
            if((newSL - OrderOpenPrice()) >= stopLevel)
               OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrYellow);
         }
      }

      // Trailing stop
      if(UseTrailingStop && profitPips >= TrailingStart) {
         if(OrderType() == OP_BUY) {
            newSL = Bid - TrailingStep * pip;
            if(newSL > OrderStopLoss() && (Bid - newSL) >= stopLevel)
               OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrGreen);
         }
         else if(OrderType() == OP_SELL) {
            newSL = Ask + TrailingStep * pip;
            if((OrderStopLoss() == 0 || newSL < OrderStopLoss()) && (newSL - Ask) >= stopLevel)
               OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrRed);
         }
      }

      // Dynamic Exit with fake-out protection
      if(UseDynamicExit) {
         double adx_now = iADX(NULL,0,ADX_Period,PRICE_CLOSE,MODE_MAIN,0);
         if(adx_now >= ADXExitThreshold) {
            int confirmCount = 0;
            for(int b=0; b<ConfirmBars; b++) {
               double rsi_b = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,b);
               double ma_b  = iMA(NULL,0,MA_Period,0,MODE_SMA,PRICE_CLOSE,b);
               double plusDI_b = iADX(NULL,0,ADX_Period,PRICE_CLOSE,MODE_PLUSDI,b);
               double minusDI_b = iADX(NULL,0,ADX_Period,PRICE_CLOSE,MODE_MINUSDI,b);

               if(OrderType() == OP_BUY) {
                  bool sellSignal = (rsi_b >= RSI_Sell_Level && iClose(NULL,0,b) < ma_b && minusDI_b > plusDI_b);
                  if(sellSignal) confirmCount++;
               }
               else if(OrderType() == OP_SELL) {
                  bool buySignal = (rsi_b <= RSI_Buy_Level && iClose(NULL,0,b) > ma_b && plusDI_b > minusDI_b);
                  if(buySignal) confirmCount++;
               }
            }
            if(confirmCount >= ConfirmBars) {
               bool closed = false;
               if(OrderType() == OP_BUY)
                  closed = OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed);
               else if(OrderType() == OP_SELL)
                  closed = OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrGreen);
               if(closed)
                  Print("Dynamic Exit: Closed ", (OrderType() == OP_BUY ? "BUY" : "SELL"), " #", OrderTicket(), " after ", ConfirmBars, " confirming bars (ADX=", DoubleToString(adx_now,2), ");");
               continue;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
// Calculate today's closed trades profit (in account currency)
double GetTodayClosedProfit() {
   double sum = 0.0;
   int total = OrdersHistoryTotal();
   for(int i = 0; i < total; i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderMagicNumber() != MagicNumber) continue; // Only count this EA's trades
      datetime ct = OrderCloseTime();
      if(ct == 0) continue;
      if(TimeDay(ct) == TimeDay(TimeCurrent()) && TimeMonth(ct) == TimeMonth(TimeCurrent()) && TimeYear(ct) == TimeYear(TimeCurrent()))
         sum += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return(sum);
}

//+------------------------------------------------------------------+
// Create or update on-chart label with color
void CreateOrUpdateLabel(string text, color clr) {
   if(ObjectFind(labelName) < 0) {
      ObjectCreate(labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
   }
   ObjectSetText(labelName, text, 11, "Arial", clr);
}

//+------------------------------------------------------------------+
// End of file
//+------------------------------------------------------------------+
