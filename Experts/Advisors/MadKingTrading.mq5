//+------------------------------------------------------------------+
//|                                               MadKingTrading.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <trade/trade.mqh>;

CTrade trade;

MqlRates candle[];
MqlTick tick;
static datetime lastTime = 0;

// stc variables
int stcHandle;
double stcBuffer[];

// variables for calculating ut bot indicator
int buyAtrHandle;
double buyAtrBuffer[];

int sellAtrHandle;
double sellAtrBuffer[];

double buySensitivity = 2.5;
double sellSensitivity = 2;

double buyATR4 = 0.0;
double sellATR4 = 0.0;

// money management
input int streak = 3; // streak size
input int money_risk = 50; // money risk size

int current_streak = 0;
int current_money_risk = money_risk;
ENUM_POSITION_TYPE type;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   sellAtrHandle = iATR(_Symbol, _Period, 1);
   buyAtrHandle = iATR(_Symbol, _Period, 300);
   stcHandle = iCustom(_Symbol, _Period, "STC.ex5");

   CopyRates(_Symbol, _Period, 0, 5, candle);
   ArraySetAsSeries(candle, true);

   SymbolInfoTick(_Symbol, tick);

   CopyBuffer(sellAtrHandle, 0, 0, 5, sellAtrBuffer);
   ArraySetAsSeries(sellAtrBuffer, true);

   CopyBuffer(buyAtrHandle, 0, 0, 5, buyAtrBuffer);
   ArraySetAsSeries(buyAtrBuffer, true);

   CopyBuffer(stcHandle, 0, 0, 5, stcBuffer);
   ArraySetAsSeries(stcBuffer, true);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(stcHandle);
   IndicatorRelease(sellAtrHandle);
   IndicatorRelease(buyAtrHandle);

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   bool newBar = isNewBar();

   if(PositionSelect(_Symbol))
     {
      Comment(PositionGetDouble(POSITION_PROFIT));
      if(PositionGetDouble(POSITION_PROFIT) >= current_money_risk)
        {
         trade.PositionClose(_Symbol, 5);

         if(current_streak == streak)
           {
            current_streak = 0;
            current_money_risk = money_risk;
           }
         else
           {
            current_streak += 1;
            current_money_risk *= 2;
           }
        }
      else
         if(PositionGetDouble(POSITION_PROFIT) <= current_money_risk*-1)
           {
            trade.PositionClose(_Symbol, 5);

            current_money_risk = money_risk;
            current_streak = 0;
           }
     }

   if(newBar)
     {

      if(!PositionSelect(_Symbol))
        {
         CopyRates(_Symbol, _Period, 0, 10, candle);
         ArraySetAsSeries(candle, true);

         SymbolInfoTick(_Symbol, tick);

         CopyBuffer(sellAtrHandle, 0, 0, 5, sellAtrBuffer);
         ArraySetAsSeries(sellAtrBuffer, true);

         CopyBuffer(buyAtrHandle, 0, 0, 5, buyAtrBuffer);
         ArraySetAsSeries(buyAtrBuffer, true);

         CopyBuffer(stcHandle, 0, 0, 5, stcBuffer);
         ArraySetAsSeries(stcBuffer, true);

         // ATR trailing stops by index
         double buyATR3 = calculateAtrTrailingStop(candle[3].close, candle[4].close, buyATR4, buySensitivity * buyAtrBuffer[3]);
         double buyATR2 = calculateAtrTrailingStop(candle[2].close, candle[3].close, buyATR3, buySensitivity * buyAtrBuffer[2]);
         double buyATR1 = calculateAtrTrailingStop(candle[1].close, candle[2].close, buyATR2, buySensitivity * buyAtrBuffer[1]);

         double sellATR3 = calculateAtrTrailingStop(candle[3].close, candle[4].close, sellATR4, sellSensitivity * sellAtrBuffer[3]);
         double sellATR2 = calculateAtrTrailingStop(candle[2].close, candle[3].close, sellATR3, sellSensitivity * sellAtrBuffer[2]);
         double sellATR1 = calculateAtrTrailingStop(candle[1].close, candle[2].close, sellATR2, sellSensitivity * sellAtrBuffer[1]);

         // setting new default ATRs to new ones
         buyATR4 = buyATR3;
         sellATR4 = sellATR3;

         bool buyPrevious = candle[2].close < buyATR2;
         bool buyCurrent = candle[1].close > buyATR1;
         bool buySTC = stcBuffer[1] < 25;

         bool sellPrevious = candle[2].close > sellATR2;
         bool sellCurrent = candle[1].close < sellATR1;
         bool sellSTC = stcBuffer[1] > 75;

         MqlDateTime currentHour;
         TimeToStruct(candle[0].time, currentHour);

         if(currentHour.hour > 3 && currentHour.hour < 22)
           {
            // buy conditions
            if(buyPrevious && buyCurrent && buySTC)
              {
               trade.Sell(calculateOrderSize(current_money_risk, NormalizeDouble(getCurrentHigh() - tick.bid + 0.0002, _Digits)));
               
              }

            // sell conditions
            if(sellPrevious && sellCurrent && sellSTC)
              {
               trade.Buy(calculateOrderSize(current_money_risk, NormalizeDouble(tick.ask - getCurrentLow() - 0.0002, _Digits)));
               //ObjectsDeleteAll(0);
               //ObjectCreate(0,"My Line",OBJ_HLINE,0,0,NormalizeDouble(getCurrentLowHigh(true) - tick.bid, _Digits));
              }
           }

        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar()
  {
   datetime lastBarTime = (datetime) SeriesInfoInteger(Symbol(), Period(), SERIES_LASTBAR_DATE);

   if(lastTime == 0)
     {
      lastTime = lastBarTime;
      return false;
     }

   if(lastTime != lastBarTime)
     {
      lastTime = lastBarTime;
      return true;
     }

   return false;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateOrderSize(int risk, double pips)
  {
   return NormalizeDouble(risk/(pips*100000), 2);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateAtrTrailingStop(double close, double prev_close, double prev_atr, double nloss)
  {
   if(close > prev_atr && prev_close > prev_atr)
     {
      return MathMax(prev_atr, close - nloss);
     }
   else
      if(close < prev_atr && prev_close < prev_atr)
        {
         return MathMin(prev_atr, close + nloss);
        }
      else
         if(close > prev_atr)
           {
            return close - nloss;
           }
         else
           {
            return close + nloss;
           }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getCurrentHigh()
  {
   int highestCandle;
   double high[];

   ArraySetAsSeries(high, true);
   CopyHigh(_Symbol, _Period, 0, 11, high);
   highestCandle = ArrayMaximum(high, 0, 11);

   return high[highestCandle];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getCurrentLow()
  {
   int lowestCandle;
   double low[];

   ArraySetAsSeries(low, true);
   CopyLow(_Symbol, _Period, 0, 11, low);
   lowestCandle = ArrayMinimum(low, 0, 11);

   return low[lowestCandle];
  }
//+------------------------------------------------------------------+
