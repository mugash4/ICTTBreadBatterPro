//+------------------------------------------------------------------+
//|                                               ICTBreadButterPro.mq5
//|
//| Developed By : Augustine Mwathi
//| Strategy     : ICT Bullish & Bearish Bread & Butter
//| Version      : 1.00
//|
//|
//| No Licensing Restrictions
//+------------------------------------------------------------------+

#property strict
#property version   "1.00"
#property description "ICTBreadButterPro"
#property description "Professional ICT Bread & Butter Trading System"
#property description "Developed By Augustine Mwathi"

#include <Trade/Trade.mqh>
CTrade trade;

//====================================================
// SECTION 2 - ENUMERATIONS
//====================================================

// Trading Mode
enum ENUM_TRADING_MODE
{
   MODE_NORMAL = 0,
   MODE_CONTEST
};

// Market Direction
enum ENUM_DIRECTION
{
   DIRECTION_NONE = 0,
   DIRECTION_BULLISH,
   DIRECTION_BEARISH
};

// Market Structure
enum ENUM_STRUCTURE
{
   STRUCTURE_NONE = 0,
   STRUCTURE_BOS,
   STRUCTURE_MSS
};

// Liquidity
enum ENUM_LIQUIDITY
{
   LIQUIDITY_NONE = 0,
   BUY_SIDE,
   SELL_SIDE
};

// Fair Value Gap
enum ENUM_FVG_TYPE
{
   FVG_NONE = 0,
   FVG_BULLISH,
   FVG_BEARISH
};

// Setup State
enum ENUM_SETUP_STATE
{
   WAIT_FOR_LIQUIDITY = 0,
   WAIT_FOR_MSS,
   WAIT_FOR_FVG,
   WAIT_FOR_RETRACE,
   READY_TO_TRADE
};

// News State
enum ENUM_NEWS_STATE
{
   NEWS_CLEAR = 0,
   NEWS_BLOCKED
};

//====================================================
// SECTION 3 - STRUCTURES
//====================================================

struct SwingPoint
{
   datetime time;
   double price;
   bool isHigh;
};

struct FairValueGap
{
   bool valid;

   ENUM_FVG_TYPE type;

   double high;
   double low;

   datetime created;

   bool mitigated;
};

struct LiquiditySweep
{
   bool valid;

   ENUM_LIQUIDITY side;

   double sweepPrice;

   datetime time;
};

struct TradeSignal
{
   bool valid;

   ENUM_DIRECTION direction;

   double entry;

   double stopLoss;

   double takeProfit1;

   double takeProfit2;

   double takeProfit3;

   double riskReward;
};

struct BrokerInformation
{
   string brokerName;

   string symbol;

   int digits;

   double point;

   double tickValue;

   double minLot;

   double maxLot;

   double lotStep;
};

struct Statistics
{
   int trades;

   int wins;

   int losses;

   double winRate;

   double drawdown;

   double profitFactor;
};


//====================================================
// SECTION 4 - INPUT PARAMETERS
//====================================================

//----------------------------------------------------
// Trading Mode
//----------------------------------------------------

input ENUM_TRADING_MODE TradingMode = MODE_NORMAL;

//----------------------------------------------------
// Timeframe Scanner
//----------------------------------------------------

input bool TradeM5  = true;
input bool TradeM15 = true;
input bool TradeH1  = true;

//----------------------------------------------------
// Risk Management
//----------------------------------------------------

input double BaseRiskPercent       = 2.0;
input double ContestRiskPercent    = 5.0;

input bool EnableDynamicRisk       = true;

input double DailyMaxLossPercent   = 20.0;

//----------------------------------------------------
// Setup Quality
//----------------------------------------------------

input int MinimumSetupScore        = 80;

//----------------------------------------------------
// Reward / Risk
//----------------------------------------------------

input double PreferredRR           = 3.0;

//----------------------------------------------------
// Partial Take Profit
//----------------------------------------------------

input bool EnablePartialTP         = true;

input double TP1Percent            = 30.0;
input double TP2Percent            = 50.0;
input double TP3Percent            = 20.0;

//----------------------------------------------------
// Break Even
//----------------------------------------------------

input bool EnableBreakEven         = true;

//----------------------------------------------------
// Trailing Stop
//----------------------------------------------------

input bool EnableTrailingStop      = true;

//----------------------------------------------------
// Spread Filter
//----------------------------------------------------

input bool EnableSpreadFilter = true;

// Auto detect spread limits by instrument
input bool AutoSpreadLimits = true;

// Manual overrides (used only when AutoSpreadLimits=false)
input int MaxForexSpreadPoints      = 50;
input int MaxGoldSpreadPoints       = 60;
input int MaxSilverSpreadPoints     = 70;
input int MaxIndicesSpreadPoints    = 120;
input int MaxCryptoSpreadPoints     = 250;
input int MaxCommoditySpreadPoints  = 100;

//----------------------------------------------------
// News Filter
//----------------------------------------------------

input bool EnableNewsFilter        = true;

input int NewsBlockBeforeMinutes   = 30;

input int NewsBlockAfterMinutes    = 30;

//----------------------------------------------------
// Volatility Filter
//----------------------------------------------------

input bool EnableVolatilityFilter  = true;

//----------------------------------------------------
// Dashboard
//----------------------------------------------------

input bool EnableDashboard         = true;

//----------------------------------------------------
// Debug
//----------------------------------------------------

input bool DebugMode               = false;

//----------------------------------------------------
// Magic Number
//----------------------------------------------------

input long MagicNumber             = 20260710;



//====================================================
// SECTION 5 - GLOBAL VARIABLES
//====================================================

BrokerInformation BrokerInfo;

Statistics Stats;

ENUM_DIRECTION CurrentDirection = DIRECTION_NONE;

ENUM_SETUP_STATE SetupState = WAIT_FOR_LIQUIDITY;

ENUM_NEWS_STATE NewsState = NEWS_CLEAR;

FairValueGap CurrentFVG;

LiquiditySweep CurrentSweep;

TradeSignal CurrentSignal;

//----------------------------------------------------
// Trading
//----------------------------------------------------

double CurrentRiskPercent = 2.0;

datetime LastTradeTime = 0;

datetime LastDailyReset = 0;

double DayStartingBalance = 0.0;

bool DailyLossLimitHit = false;

//----------------------------------------------------
// Indicator Handles
//----------------------------------------------------

int ATRHandle = INVALID_HANDLE;

//----------------------------------------------------
// Dashboard
//----------------------------------------------------

bool DashboardMinimized = false;

//----------------------------------------------------
// EA Information
//----------------------------------------------------

string EAName = "ICTBreadButterPro";

//----------------------------------------------------
// Trade State
//----------------------------------------------------

bool TradeOpenedFromCurrentSetup = false;


//====================================================
// SECTION 6 - BROKER, SYMBOL & INSTRUMENT ENGINE
//====================================================

struct BrokerInformation
{
   string brokerName;

   string symbol;

   int digits;

   double point;

   double tickSize;

   double tickValue;

   double minLot;

   double maxLot;

   double lotStep;

   ENUM_SYMBOL_CLASS symbolClass;

   int normalSpread;

   int maxSpread;

   bool tradable;
};

BrokerInformation BrokerInfo;

//--------------------------------------------------

ENUM_SYMBOL_CLASS DetectSymbolClass()
{
   string s = StringUpper(_Symbol);

   // Precious Metals
   if(StringFind(s,"XAU")>=0)
      return SYMBOL_GOLD;

   if(StringFind(s,"GOLD")>=0)
      return SYMBOL_GOLD;

   if(StringFind(s,"XAG")>=0)
      return SYMBOL_SILVER;

   if(StringFind(s,"SILVER")>=0)
      return SYMBOL_SILVER;

   // Crypto
   if(StringFind(s,"BTC")>=0)
      return SYMBOL_CRYPTO;

   if(StringFind(s,"ETH")>=0)
      return SYMBOL_CRYPTO;

   if(StringFind(s,"SOL")>=0)
      return SYMBOL_CRYPTO;

   if(StringFind(s,"DOGE")>=0)
      return SYMBOL_CRYPTO;

   // Indices
   if(StringFind(s,"US30")>=0)
      return SYMBOL_INDEX;

   if(StringFind(s,"NAS")>=0)
      return SYMBOL_INDEX;

   if(StringFind(s,"SPX")>=0)
      return SYMBOL_INDEX;

   if(StringFind(s,"GER")>=0)
      return SYMBOL_INDEX;

   if(StringFind(s,"UK100")>=0)
      return SYMBOL_INDEX;

   // Commodities
   if(StringFind(s,"WTI")>=0)
      return SYMBOL_COMMODITY;

   if(StringFind(s,"BRENT")>=0)
      return SYMBOL_COMMODITY;

   if(StringFind(s,"OIL")>=0)
      return SYMBOL_COMMODITY;

   // Default
   if(StringLen(s)>=6)
      return SYMBOL_FOREX;

   return SYMBOL_OTHER;
}

//--------------------------------------------------

void LoadSpreadProfile()
{
   switch(BrokerInfo.symbolClass)
   {
      case SYMBOL_FOREX:

         BrokerInfo.normalSpread = 30;
         BrokerInfo.maxSpread    = 50;
         break;

      case SYMBOL_GOLD:

         BrokerInfo.normalSpread = 50;
         BrokerInfo.maxSpread    = 80;
         break;

      case SYMBOL_SILVER:

         BrokerInfo.normalSpread = 45;
         BrokerInfo.maxSpread    = 70;
         break;

      case SYMBOL_INDEX:

         BrokerInfo.normalSpread = 80;
         BrokerInfo.maxSpread    = 150;
         break;

      case SYMBOL_CRYPTO:

         BrokerInfo.normalSpread = 200;
         BrokerInfo.maxSpread    = 500;
         break;

      case SYMBOL_COMMODITY:

         BrokerInfo.normalSpread = 60;
         BrokerInfo.maxSpread    = 120;
         break;

      default:

         BrokerInfo.normalSpread = 50;
         BrokerInfo.maxSpread    = 100;
         break;
   }
}

//--------------------------------------------------

bool SymbolTradable()
{
   long mode;

   SymbolInfoInteger(
      _Symbol,
      SYMBOL_TRADE_MODE,
      mode
   );

   return(mode!=SYMBOL_TRADE_MODE_DISABLED);
}

//--------------------------------------------------

void LoadBrokerInformation()
{
   BrokerInfo.brokerName=
      AccountInfoString(ACCOUNT_COMPANY);

   BrokerInfo.symbol=
      _Symbol;

   BrokerInfo.digits=
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS
      );

   BrokerInfo.point=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_POINT
      );

   BrokerInfo.tickSize=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_TRADE_TICK_SIZE
      );

   BrokerInfo.tickValue=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_TRADE_TICK_VALUE
      );

   BrokerInfo.minLot=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_MIN
      );

   BrokerInfo.maxLot=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_MAX
      );

   BrokerInfo.lotStep=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_STEP
      );

   BrokerInfo.symbolClass=
      DetectSymbolClass();

   BrokerInfo.tradable=
      SymbolTradable();

   LoadSpreadProfile();

   Print("==============================");
   Print(EAName);
   Print("Broker : ",BrokerInfo.brokerName);
   Print("Symbol : ",BrokerInfo.symbol);
   Print("Asset  : ",EnumToString(BrokerInfo.symbolClass));
   Print("Digits : ",BrokerInfo.digits);
   Print("MinLot : ",BrokerInfo.minLot);
   Print("MaxLot : ",BrokerInfo.maxLot);
   Print("==============================");
}

//====================================================
// SECTION 7 - ADAPTIVE EXECUTION ENGINE
//====================================================

#define MAX_SPREAD_HISTORY 1000

struct ExecutionProfile
{
   // Current measurements
   double currentSpread;
   double averageSpread;
   double maximumSpread;
   double minimumSpread;

   double spreadDeviation;

   double executionScore;

   double brokerScore;

   double volatilityScore;

   double sessionScore;

   double slippageScore;

   bool learningComplete;

   int sampleCount;

   double spreadHistory[MAX_SPREAD_HISTORY];
};

ExecutionProfile Execution;

//--------------------------------------------------
// Store latest spread
//--------------------------------------------------

void UpdateSpreadHistory()
{
   double spread =
      (SymbolInfoDouble(_Symbol,SYMBOL_ASK)
      -SymbolInfoDouble(_Symbol,SYMBOL_BID))
      /_Point;

   Execution.currentSpread = spread;

   if(Execution.sampleCount < MAX_SPREAD_HISTORY)
   {
      Execution.spreadHistory[
         Execution.sampleCount
      ] = spread;

      Execution.sampleCount++;
   }
   else
   {
      for(int i=1;i<MAX_SPREAD_HISTORY;i++)
      {
         Execution.spreadHistory[i-1]=
            Execution.spreadHistory[i];
      }

      Execution.spreadHistory[
         MAX_SPREAD_HISTORY-1
      ]=spread;
   }
}
//--------------------------------------------------
// Calculate spread statistics
//--------------------------------------------------

void CalculateSpreadStatistics()
{
   if(Execution.sampleCount==0)
      return;

   double sum=0;

   Execution.maximumSpread=
      Execution.spreadHistory[0];

   Execution.minimumSpread=
      Execution.spreadHistory[0];

   for(int i=0;i<Execution.sampleCount;i++)
   {
      double s=
         Execution.spreadHistory[i];

      sum+=s;

      if(s>Execution.maximumSpread)
         Execution.maximumSpread=s;

      if(s<Execution.minimumSpread)
         Execution.minimumSpread=s;
   }

   Execution.averageSpread=
      sum/
      Execution.sampleCount;

   double variance=0;

   for(int i=0;i<Execution.sampleCount;i++)
   {
      variance+=
      MathPow(
      Execution.spreadHistory[i]
      -Execution.averageSpread,
      2);
   }

   variance/=
      Execution.sampleCount;

   Execution.spreadDeviation=
      MathSqrt(variance);

   if(Execution.sampleCount>=200)
      Execution.learningComplete=true;
}
//--------------------------------------------------
// Dynamic Spread Threshold
//--------------------------------------------------

double DynamicSpreadLimit()
{
   if(!Execution.learningComplete)
      return BrokerInfo.maxSpread;

   return
      Execution.averageSpread
      +(Execution.spreadDeviation*2.0);
}

//--------------------------------------------------
// Spread Safety
//--------------------------------------------------

bool SpreadSafe()
{
   return
      Execution.currentSpread
      <=
      DynamicSpreadLimit();
}

//--------------------------------------------------
// Spread Spike Detection
//--------------------------------------------------

bool SpreadSpikeDetected()
{
   if(!Execution.learningComplete)
      return false;

   return
      Execution.currentSpread
      >
      Execution.averageSpread
      +(Execution.spreadDeviation*3.0);
}

//--------------------------------------------------
// Broker Learning Score
//--------------------------------------------------

double BrokerLearningProgress()
{
   return
      MathMin(
         100.0,
         (
         (double)Execution.sampleCount
         /
         200.0
         )*100.0
      );
}

//--------------------------------------------------
// Execution Health Score
//--------------------------------------------------

void UpdateExecutionScore()
{
   double score=100.0;

   if(SpreadSpikeDetected())
      score-=40;

   if(Execution.currentSpread>
      DynamicSpreadLimit())
      score-=30;

   double atr=GetATR();

   if(atr>0)
   {
      if(atr>GetATR(10)*2.5)
         score-=20;
   }

   Execution.executionScore=
      MathMax(score,0.0);
}



//====================================================
// SECTION 8 - PROFESSIONAL RISK ENGINE
//====================================================

struct RiskProfile
{
   double baseRisk;

   double currentRisk;

   double adaptiveRisk;

   double maximumRisk;

   double minimumRisk;

   double accountBalance;

   double accountEquity;

   double freeMargin;

   double marginLevel;

   double dailyLossPercent;

   double currentDrawdown;

   double riskMultiplier;

   bool dailyLossLock;

   bool adaptiveEnabled;

   bool contestMode;
};

RiskProfile Risk;

//--------------------------------------------------

void InitializeRisk()
{
   Risk.baseRisk      = BaseRiskPercent;
   Risk.currentRisk   = BaseRiskPercent;

   Risk.maximumRisk   = 8.0;
   Risk.minimumRisk   = 0.25;

   Risk.adaptiveRisk  = BaseRiskPercent;

   Risk.dailyLossLock = false;

   Risk.adaptiveEnabled = false;

   Risk.contestMode =
      (TradingMode==MODE_CONTEST);
}

//--------------------------------------------------

void UpdateAccountMetrics()
{
   Risk.accountBalance =
      AccountInfoDouble(
         ACCOUNT_BALANCE);

   Risk.accountEquity =
      AccountInfoDouble(
         ACCOUNT_EQUITY);

   Risk.freeMargin =
      AccountInfoDouble(
         ACCOUNT_MARGIN_FREE);

   Risk.marginLevel =
      AccountInfoDouble(
         ACCOUNT_MARGIN_LEVEL);
}

//--------------------------------------------------

double CurrentDrawdown()
{
   if(Risk.accountBalance<=0)
      return 0;

   return
      MathMax(
         0,
         ((Risk.accountBalance-
         Risk.accountEquity)
         /
         Risk.accountBalance)
         *100.0
      );
}

//--------------------------------------------------

double CurrentDailyLoss()
{
   if(DayStartingBalance<=0)
      return 0;

   return
      MathMax(
         0,
         ((DayStartingBalance-
         Risk.accountEquity)
         /
         DayStartingBalance)
         *100.0
      );
}

//--------------------------------------------------

void UpdateRiskStatistics()
{
   UpdateAccountMetrics();

   Risk.currentDrawdown =
      CurrentDrawdown();

   Risk.dailyLossPercent =
      CurrentDailyLoss();

   if(Risk.dailyLossPercent
      >=DailyMaxLossPercent)
   {
      Risk.dailyLossLock=true;
   }
}

//--------------------------------------------------

double DrawdownMultiplier()
{
   double dd=
      Risk.currentDrawdown;

   if(dd>=20)
      return 0.25;

   if(dd>=15)
      return 0.50;

   if(dd>=10)
      return 0.75;

   if(dd>=5)
      return 0.90;

   return 1.0;
}

//--------------------------------------------------

void CalculateCurrentRisk()
{
   if(Risk.contestMode)
   {
      Risk.currentRisk=
         ContestRiskPercent;

      return;
   }

   Risk.currentRisk=
      Risk.baseRisk;

   Risk.currentRisk*=
      DrawdownMultiplier();

   if(Risk.adaptiveEnabled)
   {
      Risk.currentRisk=
         Risk.adaptiveRisk;
   }

   Risk.currentRisk=
      MathMax(
         Risk.minimumRisk,
         Risk.currentRisk);

   Risk.currentRisk=
      MathMin(
         Risk.maximumRisk,
         Risk.currentRisk);
}

//--------------------------------------------------

double RiskMoney()
{
   return
      Risk.accountBalance
      *
      Risk.currentRisk
      /100.0;
}

//--------------------------------------------------

double CalculateLotSize(double stopLossPoints)
{
   if(stopLossPoints<=0)
      return BrokerInfo.minLot;

   double tickValue=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_TRADE_TICK_VALUE);

   if(tickValue<=0)
      tickValue=1;

   double lots=
      RiskMoney()
      /
      (stopLossPoints*tickValue);

   lots=
      MathFloor(
         lots/
         BrokerInfo.lotStep)
         *BrokerInfo.lotStep;

   lots=
      MathMax(
         BrokerInfo.minLot,
         lots);

   lots=
      MathMin(
         BrokerInfo.maxLot,
         lots);

   return
      NormalizeDouble(
         lots,
         2);
}

//--------------------------------------------------

bool MarginSafe()
{
   if(Risk.freeMargin<=0)
      return false;

   if(Risk.marginLevel<120)
      return false;

   return true;
}

//--------------------------------------------------

bool DailyLossExceeded()
{
   return
      Risk.dailyLossLock;
}

//--------------------------------------------------

bool RiskTradingAllowed()
{
   if(DailyLossExceeded())
      return false;

   if(!MarginSafe())
      return false;

   return true;
}


//====================================================
// SECTION 9 - SESSION INTELLIGENCE ENGINE 
//====================================================

//----------------------------------------------------
// Reset Session Statistics
//----------------------------------------------------

void ResetSessionStatistics(SessionStatistics &stats)
{
   stats.trades = 0;
   stats.wins = 0;
   stats.losses = 0;

   stats.winRate = 0.0;

   stats.profit = 0.0;

   stats.averageRR = 0.0;

   stats.learningReady = false;
}

//----------------------------------------------------
// Initialize All Sessions
//----------------------------------------------------

void InitializeSessions()
{
   ResetSessionStatistics(AsianStats);

   ResetSessionStatistics(LondonStats);

   ResetSessionStatistics(NewYorkStats);

   ResetSessionStatistics(SydneyStats);

   ResetSessionStatistics(OverlapStats);
}

//----------------------------------------------------
// Return Current Session Statistics
//----------------------------------------------------

SessionStatistics* CurrentSessionStats()
{
   switch(CurrentSession)
   {
      case SESSION_ASIAN:
         return &AsianStats;

      case SESSION_LONDON:
         return &LondonStats;

      case SESSION_NEWYORK:
         return &NewYorkStats;

      case SESSION_SYDNEY:
         return &SydneyStats;

      case SESSION_OVERLAP:
         return &OverlapStats;

      default:
         return NULL;
   }
}

//----------------------------------------------------
// Register Closed Trade
//----------------------------------------------------

void RegisterSessionTrade(
   double profit,
   double rr
)
{
   SessionStatistics *stats =
      CurrentSessionStats();

   if(stats==NULL)
      return;

   stats.trades++;

   stats.profit += profit;

   stats.averageRR =
      (
         (stats.averageRR *
         (stats.trades-1))
         + rr
      )
      /
      stats.trades;

   if(profit>0)
      stats.wins++;
   else
      stats.losses++;

   if(stats.trades>0)
   {
      stats.winRate =
         (
            (double)stats.wins
            /
            stats.trades
         )
         *100.0;
   }

   //------------------------------------------------
   // Machine Learning Activation Criteria
   //------------------------------------------------

   if(
      stats.trades>=60 &&
      stats.winRate>=55.0 &&
      stats.averageRR>=2.0
   )
   {
      stats.learningReady=true;
   }
}

//----------------------------------------------------
// Session Confidence Score
//----------------------------------------------------

double SessionConfidence()
{
   SessionStatistics *stats =
      CurrentSessionStats();

   if(stats==NULL)
      return 50.0;

   double score = 50.0;

   score +=
      (stats->winRate-50.0);

   score +=
      (stats->averageRR*5.0);

   if(stats->profit>0)
      score += 10.0;

   return MathMin(
      100.0,
      MathMax(0.0,score)
   );
}

//----------------------------------------------------
// Session Quality
//----------------------------------------------------

string SessionQuality()
{
   double confidence =
      SessionConfidence();

   if(confidence>=90)
      return "ELITE";

   if(confidence>=80)
      return "VERY GOOD";

   if(confidence>=70)
      return "GOOD";

   if(confidence>=60)
      return "AVERAGE";

   return "POOR";
}

//----------------------------------------------------
// Should We Trade This Session?
//----------------------------------------------------

bool SessionTradingAllowed()
{
   SessionStatistics *stats =
      CurrentSessionStats();

   if(stats==NULL)
      return true;

   //------------------------------------------------
   // Before Learning
   //------------------------------------------------

   if(!stats->learningReady)
      return true;

   //------------------------------------------------
   // After Learning
   //------------------------------------------------

   if(stats->winRate<55.0)
      return false;

   if(stats->averageRR<2.0)
      return false;

   return true;
}

//----------------------------------------------------
// Best Performing Session
//----------------------------------------------------

ENUM_TRADING_SESSION BestSession()
{
   double bestScore=-1;

   ENUM_TRADING_SESSION best=
      SESSION_UNKNOWN;

   SessionStatistics sessions[5]=
   {
      AsianStats,
      LondonStats,
      NewYorkStats,
      SydneyStats,
      OverlapStats
   };

   for(int i=0;i<5;i++)
   {
      double score=
         sessions[i].winRate+
         sessions[i].averageRR*10.0;

      if(score>bestScore)
      {
         bestScore=score;

         best=
            (ENUM_TRADING_SESSION)
            (i+1);
      }
   }

   return best;
}

//----------------------------------------------------
// Update Session Engine
//----------------------------------------------------

void UpdateSessionEngine()
{
   UpdateTradingSession();

   if(!SessionTradingAllowed())
   {
      Print(
         "Session blocked by learning engine."
      );
   }
}


//====================================================
// SECTION 10 - MARKET CLASSIFICATION ENGINE 
//====================================================

enum ENUM_MARKET_STATE
{
   MARKET_UNKNOWN = 0,

   MARKET_TRENDING,

   MARKET_RANGING,

   MARKET_VOLATILE,

   MARKET_COMPRESSION,

   MARKET_EXPANSION
};

//----------------------------------------------------

ENUM_MARKET_STATE CurrentMarketState =
   MARKET_UNKNOWN;

//----------------------------------------------------

struct MarketStatistics
{
   double atr;

   double averageATR;

   double volatilityRatio;

   double adx;

   double trendStrength;

   bool compression;

   bool expansion;

   bool volatility;

   bool trending;

   bool ranging;
};

MarketStatistics MarketStats;

//----------------------------------------------------

void ResetMarketStatistics()
{
   ZeroMemory(MarketStats);
}

//----------------------------------------------------

double AverageATR(int bars=50)
{
   double total=0.0;

   int count=0;

   for(int i=1;i<=bars;i++)
   {
      double value=GetATR(i);

      if(value>0)
      {
         total+=value;
         count++;
      }
   }

   if(count==0)
      return 0;

   return total/count;
}

//----------------------------------------------------

void UpdateVolatility()
{
   MarketStats.atr=
      GetATR();

   MarketStats.averageATR=
      AverageATR();

   if(MarketStats.averageATR<=0)
      return;

   MarketStats.volatilityRatio=
      MarketStats.atr/
      MarketStats.averageATR;
}

//----------------------------------------------------

bool CompressionDetected()
{
   return
      MarketStats.volatilityRatio<0.65;
}

//----------------------------------------------------

bool ExpansionDetected()
{
   return
      MarketStats.volatilityRatio>1.60;
}

//----------------------------------------------------

bool HighVolatilityDetected()
{
   return
      MarketStats.volatilityRatio>2.20;
}

//----------------------------------------------------

bool TrendingMarket()
{
   return
      CurrentTrend!=TREND_NONE
      &&
      CurrentTrendStrength>=60;
}

//----------------------------------------------------

bool RangingMarket()
{
   return
      CurrentTrend==TREND_NONE;
}

//----------------------------------------------------

void DetectMarketState()
{
   UpdateVolatility();

   MarketStats.compression=
      CompressionDetected();

   MarketStats.expansion=
      ExpansionDetected();

   MarketStats.volatility=
      HighVolatilityDetected();

   MarketStats.trending=
      TrendingMarket();

   MarketStats.ranging=
      RangingMarket();

   if(MarketStats.volatility)
   {
      CurrentMarketState=
         MARKET_VOLATILE;

      return;
   }

   if(MarketStats.compression)
   {
      CurrentMarketState=
         MARKET_COMPRESSION;

      return;
   }

   if(MarketStats.expansion)
   {
      CurrentMarketState=
         MARKET_EXPANSION;

      return;
   }

   if(MarketStats.trending)
   {
      CurrentMarketState=
         MARKET_TRENDING;

      return;
   }

   if(MarketStats.ranging)
   {
      CurrentMarketState=
         MARKET_RANGING;

      return;
   }

   CurrentMarketState=
      MARKET_UNKNOWN;
}


//----------------------------------------------------

string MarketStateText()
{
   switch(CurrentMarketState)
   {
      case MARKET_TRENDING:
         return "TRENDING";

      case MARKET_RANGING:
         return "RANGING";

      case MARKET_VOLATILE:
         return "VOLATILE";

      case MARKET_COMPRESSION:
         return "COMPRESSION";

      case MARKET_EXPANSION:
         return "EXPANSION";

      default:
         return "UNKNOWN";
   }
}

//----------------------------------------------------

bool MarketSuitableForBreadButter()
{
   if(CurrentMarketState==
      MARKET_VOLATILE)
      return false;

   if(CurrentMarketState==
      MARKET_COMPRESSION)
      return false;

   return true;
}

//----------------------------------------------------

double MarketConfidence()
{
   double score=50.0;

   switch(CurrentMarketState)
   {
      case MARKET_TRENDING:

         score=95;
         break;

      case MARKET_EXPANSION:

         score=85;
         break;

      case MARKET_RANGING:

         score=60;
         break;

      case MARKET_COMPRESSION:

         score=25;
         break;

      case MARKET_VOLATILE:

         score=15;
         break;

      default:

         score=40;
   }

   return score;
}

//====================================================
// SECTION 11 - MULTI-TIMEFRAME BIAS ENGINE (Part 1)
//====================================================

enum ENUM_MARKET_BIAS
{
   BIAS_NONE = 0,

   BIAS_BULLISH,

   BIAS_BEARISH
};

//----------------------------------------------------

struct TimeframeBias
{
   ENUM_TIMEFRAMES timeframe;

   ENUM_MARKET_BIAS bias;

   double strength;

   bool valid;
};

//----------------------------------------------------

TimeframeBias Bias5M;

TimeframeBias Bias15M;

TimeframeBias Bias1H;

//----------------------------------------------------

ENUM_MARKET_BIAS OverallBias =
   BIAS_NONE;

//----------------------------------------------------

ENUM_MARKET_BIAS DetectBias(
   ENUM_TIMEFRAMES tf
)
{
   double high1 =
      iHigh(_Symbol,tf,5);

   double high2 =
      iHigh(_Symbol,tf,20);

   double low1 =
      iLow(_Symbol,tf,5);

   double low2 =
      iLow(_Symbol,tf,20);

   if(high1>high2 &&
      low1>low2)
   {
      return BIAS_BULLISH;
   }

   if(high1<high2 &&
      low1<low2)
   {
      return BIAS_BEARISH;
   }

   return BIAS_NONE;
}

//----------------------------------------------------

double BiasStrength(
   ENUM_TIMEFRAMES tf
)
{
   double atr =
      iATR(_Symbol,tf,14);

   double move =
      MathAbs(
         iClose(_Symbol,tf,5)
         -
         iClose(_Symbol,tf,20)
      );

   if(atr<=0)
      return 0;

   return
      MathMin(
         (move/atr)*25.0,
         100.0
      );
}

//----------------------------------------------------

void UpdateBiasEngine()
{
   Bias5M.timeframe=
      PERIOD_M5;

   Bias5M.bias=
      DetectBias(PERIOD_M5);

   Bias5M.strength=
      BiasStrength(PERIOD_M5);

   Bias5M.valid=true;

   //------------------------------------------------

   Bias15M.timeframe=
      PERIOD_M15;

   Bias15M.bias=
      DetectBias(PERIOD_M15);

   Bias15M.strength=
      BiasStrength(PERIOD_M15);

   Bias15M.valid=true;

   //------------------------------------------------

   Bias1H.timeframe=
      PERIOD_H1;

   Bias1H.bias=
      DetectBias(PERIOD_H1);

   Bias1H.strength=
      BiasStrength(PERIOD_H1);

   Bias1H.valid=true;
}

//----------------------------------------------------

void CalculateOverallBias()
{
   int bulls=0;

   int bears=0;

   if(Bias5M.bias==
      BIAS_BULLISH)
      bulls++;

   if(Bias15M.bias==
      BIAS_BULLISH)
      bulls++;

   if(Bias1H.bias==
      BIAS_BULLISH)
      bulls++;

   if(Bias5M.bias==
      BIAS_BEARISH)
      bears++;

   if(Bias15M.bias==
      BIAS_BEARISH)
      bears++;

   if(Bias1H.bias==
      BIAS_BEARISH)
      bears++;

   if(bulls>=2)
   {
      OverallBias=
         BIAS_BULLISH;

      return;
   }

   if(bears>=2)
   {
      OverallBias=
         BIAS_BEARISH;

      return;
   }

   OverallBias=
      BIAS_NONE;
}

//----------------------------------------------------

bool BullishBias()
{
   return
      OverallBias==
      BIAS_BULLISH;
}

//----------------------------------------------------

bool BearishBias()
{
   return
      OverallBias==
      BIAS_BEARISH;
}

//----------------------------------------------------

string BiasText()
{
   switch(OverallBias)
   {
      case BIAS_BULLISH:

         return "BULLISH";

      case BIAS_BEARISH:

         return "BEARISH";

      default:

         return "NEUTRAL";
   }
}



//====================================================
// SECTION 12 - PROFESSIONAL ICT SWING ENGINE
//====================================================

//----------------------------------------------------
// Swing Parameters
//----------------------------------------------------

#define MAX_SWINGS 20

//----------------------------------------------------
// Swing Structure
//----------------------------------------------------

struct ICTSwing
{
   bool valid;

   bool isHigh;

   bool major;

   double price;

   int barIndex;

   datetime time;

   double strength;
};

//----------------------------------------------------
// Swing Database
//----------------------------------------------------

struct SwingDatabase
{
   ICTSwing Highs[MAX_SWINGS];

   ICTSwing Lows[MAX_SWINGS];

   int HighCount;

   int LowCount;

   datetime LastUpdate;
};

SwingDatabase SwingData[ACTIVE_SCAN_TIMEFRAMES];

//----------------------------------------------------
// Swing Settings
//----------------------------------------------------

input int SwingLeftBars=3;

input int SwingRightBars=3;

input double MinimumSwingATR=0.50;

input bool DetectMajorSwings=true;

//----------------------------------------------------
// Find Swing Database
//----------------------------------------------------

int SwingIndex(
   ENUM_TIMEFRAMES tf)
{
   return StructureIndex(tf);
}

//----------------------------------------------------
// Reset Swing Database
//----------------------------------------------------

void ResetSwingDatabase(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      SwingIndex(tf);

   if(idx<0)
      return;

   ZeroMemory(
      SwingData[idx]);

   SwingData[idx].HighCount=0;

   SwingData[idx].LowCount=0;

   SwingData[idx].LastUpdate=0;
}

//----------------------------------------------------
// Initialize Swing Engine
//----------------------------------------------------

void InitializeSwingEngine()
{
   for(int i=0;
      i<ACTIVE_SCAN_TIMEFRAMES;
      i++)
   {
      ResetSwingDatabase(
         StructureTF[i]);
   }
}

//----------------------------------------------------
// Is Swing High
//----------------------------------------------------

bool IsSwingHigh(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double candidate=
      iHigh(_Symbol,tf,bar);

   for(int i=1;i<=SwingLeftBars;i++)
   {
      if(iHigh(_Symbol,tf,bar+i)>=candidate)
         return false;
   }

   for(int i=1;i<=SwingRightBars;i++)
   {
      if(iHigh(_Symbol,tf,bar-i)>candidate)
         return false;
   }

   return true;
}

//----------------------------------------------------
// Is Swing Low
//----------------------------------------------------

bool IsSwingLow(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double candidate=
      iLow(_Symbol,tf,bar);

   for(int i=1;i<=SwingLeftBars;i++)
   {
      if(iLow(_Symbol,tf,bar+i)<=candidate)
         return false;
   }

   for(int i=1;i<=SwingRightBars;i++)
   {
      if(iLow(_Symbol,tf,bar-i)<candidate)
         return false;
   }

   return true;
}

//----------------------------------------------------
// Calculate Swing Strength
//----------------------------------------------------

double CalculateSwingStrength(
   ENUM_TIMEFRAMES tf,
   bool isHigh,
   int bar)
{
   double atr=
      GetATR(tf);

   if(atr<=0)
      return 0;

   double range;

   if(isHigh)
      range=
         iHigh(_Symbol,tf,bar)
         -
         iLow(_Symbol,tf,bar+SwingLeftBars);
   else
      range=
         iHigh(_Symbol,tf,bar+SwingLeftBars)
         -
         iLow(_Symbol,tf,bar);

   return
      range/atr;
}

//----------------------------------------------------
// Insert Swing High
//----------------------------------------------------

void InsertSwingHigh(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   int idx=
      SwingIndex(tf);

   if(idx<0)
      return;

   for(int i=MAX_SWINGS-1;i>0;i--)
      SwingData[idx].Highs[i]=
      SwingData[idx].Highs[i-1];

   SwingData[idx].Highs[0].valid=true;

   SwingData[idx].Highs[0].isHigh=true;

   SwingData[idx].Highs[0].price=
      iHigh(_Symbol,tf,bar);

   SwingData[idx].Highs[0].barIndex=
      bar;

   SwingData[idx].Highs[0].time=
      iTime(_Symbol,tf,bar);

   SwingData[idx].Highs[0].strength=
      CalculateSwingStrength(
         tf,
         true,
         bar);

   SwingData[idx].Highs[0].major=
      (SwingData[idx].Highs[0].strength
      >=MinimumSwingATR);

   if(SwingData[idx].HighCount
      <MAX_SWINGS)
      SwingData[idx].HighCount++;
}

//----------------------------------------------------
// Insert Swing Low
//----------------------------------------------------

void InsertSwingLow(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   int idx=
      SwingIndex(tf);

   if(idx<0)
      return;

   for(int i=MAX_SWINGS-1;i>0;i--)
      SwingData[idx].Lows[i]=
      SwingData[idx].Lows[i-1];

   SwingData[idx].Lows[0].valid=true;

   SwingData[idx].Lows[0].isHigh=false;

   SwingData[idx].Lows[0].price=
      iLow(_Symbol,tf,bar);

   SwingData[idx].Lows[0].barIndex=
      bar;

   SwingData[idx].Lows[0].time=
      iTime(_Symbol,tf,bar);

   SwingData[idx].Lows[0].strength=
      CalculateSwingStrength(
         tf,
         false,
         bar);

   SwingData[idx].Lows[0].major=
      (SwingData[idx].Lows[0].strength
      >=MinimumSwingATR);

   if(SwingData[idx].LowCount
      <MAX_SWINGS)
      SwingData[idx].LowCount++;
}

//----------------------------------------------------
// Scan Swings
//----------------------------------------------------

void ScanSwings(ENUM_TIMEFRAMES tf)
{
   int idx=SwingIndex(tf);

   if(idx<0)
      return;

   int bars=iBars(_Symbol,tf);

   if(bars<(SwingLeftBars+SwingRightBars+10))
      return;

   ResetSwingDatabase(tf);

   for(int bar=bars-SwingRightBars-1;
       bar>=SwingRightBars;
       bar--)
   {
      if(IsSwingHigh(tf,bar))
         InsertSwingHigh(tf,bar);

      if(IsSwingLow(tf,bar))
         InsertSwingLow(tf,bar);
   }

   SwingData[idx].LastUpdate=TimeCurrent();
}

//----------------------------------------------------
// Latest Swing High
//----------------------------------------------------

ICTSwing LatestSwingHigh(
   ENUM_TIMEFRAMES tf)
{
   ICTSwing empty={};

   int idx=SwingIndex(tf);

   if(idx<0)
      return empty;

   return SwingData[idx].Highs[0];
}

//----------------------------------------------------
// Latest Swing Low
//----------------------------------------------------

ICTSwing LatestSwingLow(
   ENUM_TIMEFRAMES tf)
{
   ICTSwing empty={};

   int idx=SwingIndex(tf);

   if(idx<0)
      return empty;

   return SwingData[idx].Lows[0];
}

//----------------------------------------------------
// Previous Swing High
//----------------------------------------------------

ICTSwing PreviousSwingHigh(
   ENUM_TIMEFRAMES tf)
{
   ICTSwing empty={};

   int idx=SwingIndex(tf);

   if(idx<0)
      return empty;

   if(SwingData[idx].HighCount<2)
      return empty;

   return SwingData[idx].Highs[1];
}

//----------------------------------------------------
// Previous Swing Low
//----------------------------------------------------

ICTSwing PreviousSwingLow(
   ENUM_TIMEFRAMES tf)
{
   ICTSwing empty={};

   int idx=SwingIndex(tf);

   if(idx<0)
      return empty;

   if(SwingData[idx].LowCount<2)
      return empty;

   return SwingData[idx].Lows[1];
}

//----------------------------------------------------
// Latest Major Swing High
//----------------------------------------------------

ICTSwing LatestMajorSwingHigh(
   ENUM_TIMEFRAMES tf)
{
   ICTSwing empty={};

   int idx=SwingIndex(tf);

   if(idx<0)
      return empty;

   for(int i=0;i<SwingData[idx].HighCount;i++)
   {
      if(SwingData[idx].Highs[i].valid &&
         SwingData[idx].Highs[i].major)
      {
         return SwingData[idx].Highs[i];
      }
   }

   return empty;
}

//----------------------------------------------------
// Latest Major Swing Low
//----------------------------------------------------

ICTSwing LatestMajorSwingLow(
   ENUM_TIMEFRAMES tf)
{
   ICTSwing empty={};

   int idx=SwingIndex(tf);

   if(idx<0)
      return empty;

   for(int i=0;i<SwingData[idx].LowCount;i++)
   {
      if(SwingData[idx].Lows[i].valid &&
         SwingData[idx].Lows[i].major)
      {
         return SwingData[idx].Lows[i];
      }
   }

   return empty;
}


//----------------------------------------------------
// Swing Engine Update
//----------------------------------------------------

void UpdateSwingEngine()
{
   for(int i=0;
       i<ACTIVE_SCAN_TIMEFRAMES;
       i++)
   {
      ScanSwings(
         StructureTF[i]);
   }
}


      
//====================================================
// SECTION 13 - PROFESSIONAL MARKET STRUCTURE ENGINE
//====================================================

//----------------------------------------------------
// Market Structure State
//----------------------------------------------------

struct StructureAnalysis
{
   bool valid;

   ENUM_TIMEFRAMES timeframe;

   ENUM_DIRECTION direction;

   ENUM_STRUCTURE structure;

   ICTSwing currentHigh;

   ICTSwing previousHigh;

   ICTSwing currentLow;

   ICTSwing previousLow;

   bool higherHigh;

   bool higherLow;

   bool lowerHigh;

   bool lowerLow;

   datetime lastUpdate;
};

StructureAnalysis
StructureAnalysisData[ACTIVE_SCAN_TIMEFRAMES];

//----------------------------------------------------
// Reset Structure Analysis
//----------------------------------------------------

void ResetStructureAnalysis(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   ZeroMemory(
      StructureAnalysisData[idx]);

   StructureAnalysisData[idx].timeframe=tf;
}

//----------------------------------------------------
// Initialize Structure Engine
//----------------------------------------------------

void InitializeStructureEngine()
{
   for(int i=0;
      i<ACTIVE_SCAN_TIMEFRAMES;
      i++)
   {
      ResetStructureAnalysis(
         StructureTF[i]);
   }
}

//----------------------------------------------------
// Analyze Market Structure
//----------------------------------------------------

void AnalyzeMarketStructure(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   ICTSwing high0=
      LatestSwingHigh(tf);

   ICTSwing high1=
      PreviousSwingHigh(tf);

   ICTSwing low0=
      LatestSwingLow(tf);

   ICTSwing low1=
      PreviousSwingLow(tf);

   if(!high0.valid ||
      !high1.valid ||
      !low0.valid ||
      !low1.valid)
      return;

   ResetStructureAnalysis(tf);

   StructureAnalysisData[idx].valid=true;

   StructureAnalysisData[idx].currentHigh=high0;
   StructureAnalysisData[idx].previousHigh=high1;

   StructureAnalysisData[idx].currentLow=low0;
   StructureAnalysisData[idx].previousLow=low1;

   StructureAnalysisData[idx].higherHigh=
      (high0.price>high1.price);

   StructureAnalysisData[idx].higherLow=
      (low0.price>low1.price);

   StructureAnalysisData[idx].lowerHigh=
      (high0.price<high1.price);

   StructureAnalysisData[idx].lowerLow=
      (low0.price<low1.price);

   //--------------------------------------
   // Trend Direction
   //--------------------------------------

   if(
      StructureAnalysisData[idx].higherHigh &&
      StructureAnalysisData[idx].higherLow)
   {
      StructureAnalysisData[idx].direction=
         DIRECTION_BULLISH;

      StructureAnalysisData[idx].structure=
         STRUCTURE_BOS;
   }
   else
   if(
      StructureAnalysisData[idx].lowerHigh &&
      StructureAnalysisData[idx].lowerLow)
   {
      StructureAnalysisData[idx].direction=
         DIRECTION_BEARISH;

      StructureAnalysisData[idx].structure=
         STRUCTURE_BOS;
   }
   else
   {
      StructureAnalysisData[idx].direction=
         DIRECTION_NONE;

      StructureAnalysisData[idx].structure=
         STRUCTURE_NONE;
   }

   StructureAnalysisData[idx].lastUpdate=
      TimeCurrent();
}


//----------------------------------------------------
// Detect Market Structure
//----------------------------------------------------

void DetectMarketStructure(
   ENUM_TIMEFRAMES tf)
{
   AnalyzeMarketStructure(tf);

   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   if(!StructureAnalysisData[idx].valid)
      return;

   bool bos=false;
   bool mss=false;
   bool choch=false;

   ENUM_DIRECTION direction=
      StructureAnalysisData[idx].direction;

   ENUM_STRUCTURE structure=
      StructureAnalysisData[idx].structure;

   //---------------------------------------
   // Bullish Structure
   //---------------------------------------

   if(direction==DIRECTION_BULLISH)
   {
      bos=true;

      if(StructureDirection(tf)==
         DIRECTION_BEARISH)
      {
         mss=true;
         choch=true;
      }
   }

   //---------------------------------------
   // Bearish Structure
   //---------------------------------------

   if(direction==DIRECTION_BEARISH)
   {
      bos=true;

      if(StructureDirection(tf)==
         DIRECTION_BULLISH)
      {
         mss=true;
         choch=true;
      }
   }

   //---------------------------------------
   // Save into Structure Matrix
   //---------------------------------------

   SaveStructureCache(
      tf,
      direction,
      structure,

      StructureAnalysisData[idx]
         .currentHigh.price,

      StructureAnalysisData[idx]
         .currentLow.price,

      StructureAnalysisData[idx]
         .currentHigh.barIndex,

      StructureAnalysisData[idx]
         .currentLow.barIndex,

      bos,
      mss,
      choch,
      false
   );
}

//----------------------------------------------------
// Update Structure Engine
//----------------------------------------------------

void UpdateStructureEngine()
{
   for(int i=0;
      i<ACTIVE_SCAN_TIMEFRAMES;
      i++)
   {
      DetectMarketStructure(
         StructureTF[i]);
   }
}

//----------------------------------------------------
// Structure Status
//----------------------------------------------------

bool BullishMarketStructure(
   ENUM_TIMEFRAMES tf)
{
   return
      StructureDirection(tf)
      ==
      DIRECTION_BULLISH;
}

//----------------------------------------------------

bool BearishMarketStructure(
   ENUM_TIMEFRAMES tf)
{
   return
      StructureDirection(tf)
      ==
      DIRECTION_BEARISH;
}

//----------------------------------------------------

bool MarketStructureReady(
   ENUM_TIMEFRAMES tf)
{
   return
      StructureReady(tf);
}


//====================================================
// SECTION 14 - INSTITUTIONAL BOS / MSS / CHOCH ENGINE
//====================================================

//----------------------------------------------------
// BOS Settings
//----------------------------------------------------

input double MinimumBodyPercent      = 60.0;
input double MinimumBreakATR         = 0.50;

input bool RequireBodyClose          = true;
input bool RequireDisplacement       = true;

//----------------------------------------------------
// Structure Break
//----------------------------------------------------

struct StructureBreak
{
   bool valid;

   bool confirmed;

   bool BOS;

   bool MSS;

   bool CHOCH;

   ENUM_DIRECTION direction;

   ENUM_STRUCTURE structure;

   double brokenLevel;

   double closePrice;

   double candleHigh;

   double candleLow;

   double bodySize;

   double candleRange;

   double bodyPercent;

   double ATRExpansion;

   int breakBar;

   datetime breakTime;
};

StructureBreak
StructureBreakData[ACTIVE_SCAN_TIMEFRAMES];

//----------------------------------------------------
// Reset Structure Break
//----------------------------------------------------

void ResetStructureBreak(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   ZeroMemory(
      StructureBreakData[idx]);
}

//----------------------------------------------------
// Candle Body Percentage
//----------------------------------------------------

double CandleBodyPercent(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double high=
      iHigh(_Symbol,tf,bar);

   double low=
      iLow(_Symbol,tf,bar);

   double open=
      iOpen(_Symbol,tf,bar);

   double close=
      iClose(_Symbol,tf,bar);

   double range=
      high-low;

   if(range<=0)
      return 0;

   double body=
      MathAbs(close-open);

   return
      (body/range)*100.0;
}

//----------------------------------------------------
// ATR Expansion
//----------------------------------------------------

double ATRExpansion(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double atr=
      GetATR(tf);

   if(atr<=0)
      return 0;

   double range=
      iHigh(_Symbol,tf,bar)
      -
      iLow(_Symbol,tf,bar);

   return
      range/atr;
}

//----------------------------------------------------
// Bullish BOS Filters
//----------------------------------------------------

bool BullishBreakFilters(
   ENUM_TIMEFRAMES tf,
   double level)
{
   double close=
      iClose(_Symbol,tf,1);

   if(close<=level)
      return false;

   if(RequireBodyClose)
   {
      if(CandleBodyPercent(tf,1)
         <MinimumBodyPercent)
         return false;
   }

   if(RequireDisplacement)
   {
      if(ATRExpansion(tf,1)
         <MinimumBreakATR)
         return false;
   }

   return true;
}

//----------------------------------------------------
// Bearish BOS Filters
//----------------------------------------------------

bool BearishBreakFilters(
   ENUM_TIMEFRAMES tf,
   double level)
{
   double close=
      iClose(_Symbol,tf,1);

   if(close>=level)
      return false;

   if(RequireBodyClose)
   {
      if(CandleBodyPercent(tf,1)
         <MinimumBodyPercent)
         return false;
   }

   if(RequireDisplacement)
   {
      if(ATRExpansion(tf,1)
         <MinimumBreakATR)
         return false;
   }

   return true;
}

//----------------------------------------------------
// Detect Structure Break
//----------------------------------------------------

void DetectStructureBreak(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return;

   ResetStructureBreak(tf);

   if(!StructureReady(tf))
      return;

   ENUM_DIRECTION previousDirection=
      StructureDirection(tf);

   ICTSwing latestHigh=
      LatestSwingHigh(tf);

   ICTSwing latestLow=
      LatestSwingLow(tf);

   //--------------------------------------------------
   // Bullish Break
   //--------------------------------------------------

   if(BullishBreakFilters(
      tf,
      latestHigh.price))
   {
      StructureBreakData[idx].valid=true;

      StructureBreakData[idx].confirmed=true;

      StructureBreakData[idx].BOS=true;

      StructureBreakData[idx].direction=
         DIRECTION_BULLISH;

      StructureBreakData[idx].structure=
         STRUCTURE_BOS;

      StructureBreakData[idx].brokenLevel=
         latestHigh.price;
   }

   //--------------------------------------------------
   // Bearish Break
   //--------------------------------------------------

   if(BearishBreakFilters(
      tf,
      latestLow.price))
   {
      StructureBreakData[idx].valid=true;

      StructureBreakData[idx].confirmed=true;

      StructureBreakData[idx].BOS=true;

      StructureBreakData[idx].direction=
         DIRECTION_BEARISH;

      StructureBreakData[idx].structure=
         STRUCTURE_BOS;

      StructureBreakData[idx].brokenLevel=
         latestLow.price;
   }

   //--------------------------------------------------
   // MSS
   //--------------------------------------------------

   if(previousDirection==
      DIRECTION_BEARISH &&
      StructureBreakData[idx].direction==
      DIRECTION_BULLISH)
   {
      StructureBreakData[idx].MSS=true;
   }

   if(previousDirection==
      DIRECTION_BULLISH &&
      StructureBreakData[idx].direction==
      DIRECTION_BEARISH)
   {
      StructureBreakData[idx].MSS=true;
   }

   //--------------------------------------------------
   // CHOCH
   //--------------------------------------------------

   if(StructureBreakData[idx].MSS)
      StructureBreakData[idx].CHOCH=true;

   //--------------------------------------------------

   StructureBreakData[idx].breakBar=1;

   StructureBreakData[idx].breakTime=
      iTime(_Symbol,tf,1);

   StructureBreakData[idx].closePrice=
      iClose(_Symbol,tf,1);

   StructureBreakData[idx].candleHigh=
      iHigh(_Symbol,tf,1);

   StructureBreakData[idx].candleLow=
      iLow(_Symbol,tf,1);

   StructureBreakData[idx].bodySize=
      MathAbs(
         iClose(_Symbol,tf,1)-
         iOpen(_Symbol,tf,1));

   StructureBreakData[idx].candleRange=
      iHigh(_Symbol,tf,1)-
      iLow(_Symbol,tf,1);

   StructureBreakData[idx].bodyPercent=
      CandleBodyPercent(tf,1);

   StructureBreakData[idx].ATRExpansion=
      ATRExpansion(tf,1);
}

//----------------------------------------------------
// Update BOS Engine
//----------------------------------------------------

void UpdateStructureBreakEngine()
{
   for(int i=0;
       i<ACTIVE_SCAN_TIMEFRAMES;
       i++)
   {
      DetectStructureBreak(
         StructureTF[i]);
   }
}

//----------------------------------------------------
// Helper Functions
//----------------------------------------------------

bool BOSConfirmed(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return false;

   return StructureBreakData[idx].BOS;
}

//----------------------------------------------------

bool MSSConfirmed(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return false;

   return StructureBreakData[idx].MSS;
}

//----------------------------------------------------

bool CHOCHConfirmed(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return false;

   return StructureBreakData[idx].CHOCH;
}


//====================================================
// SECTION 15 - INSTITUTIONAL DISPLACEMENT ENGINE
//====================================================

//----------------------------------------------------
// Inputs
//----------------------------------------------------

input double MinimumDisplacementATR      = 1.20;

input int    MinimumImpulseCandles       = 2;

input double MinimumBodyPercent          = 70.0;

input double MinimumClosePercent         = 70.0;

//----------------------------------------------------
// Displacement State
//----------------------------------------------------

struct DisplacementState
{
   bool valid;

   bool confirmed;

   ENUM_DIRECTION direction;

   int startBar;

   int endBar;

   int displacementBar;

   int impulseCandles;

   double impulseHigh;

   double impulseLow;

   double impulseRange;

   double displacementHigh;

   double displacementLow;

   double displacementSize;

   double ATRMultiple;

   double bodyPercent;

   double closePercent;

   double score;

   datetime time;
};

DisplacementState
DisplacementData[ACTIVE_SCAN_TIMEFRAMES];

//----------------------------------------------------
// Reset
//----------------------------------------------------

void ResetDisplacement(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   ZeroMemory(
      DisplacementData[idx]);
}


//----------------------------------------------------
// Helpers
//----------------------------------------------------

int DisplacementIndex(
   ENUM_TIMEFRAMES tf)
{
   return
      StructureIndex(tf);
}

//----------------------------------------------------

bool DisplacementConfirmed(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      DisplacementIndex(tf);

   if(idx<0)
      return false;

   return
      DisplacementData[idx].confirmed;
}

//----------------------------------------------------

int DisplacementStartBar(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      DisplacementIndex(tf);

   if(idx<0)
      return -1;

   return
      DisplacementData[idx].startBar;
}

//----------------------------------------------------

int DisplacementEndBar(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      DisplacementIndex(tf);

   if(idx<0)
      return -1;

   return
      DisplacementData[idx].endBar;
}

//----------------------------------------------------

int DisplacementBar(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      DisplacementIndex(tf);

   if(idx<0)
      return -1;

   return
      DisplacementData[idx].displacementBar;
}

//----------------------------------------------------
// Current Stored Displacement Score
//----------------------------------------------------

double StoredDisplacementScore(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      DisplacementIndex(tf);

   if(idx<0)
      return 0.0;

   return
      DisplacementData[idx].score;
}

//----------------------------------------------------
// Candle Close Position
//----------------------------------------------------

double CandleClosePercent(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double high=
      iHigh(_Symbol,tf,bar);

   double low=
      iLow(_Symbol,tf,bar);

   double open=
      iOpen(_Symbol,tf,bar);

   double close=
      iClose(_Symbol,tf,bar);

   double range=
      high-low;

   if(range<=0)
      return 0;

   //--------------------------------------
   // Bullish
   //--------------------------------------

   if(close>=open)
   {
      return
      ((close-low)
      /range)
      *100.0;
   }

   //--------------------------------------
   // Bearish
   //--------------------------------------

   return
   ((high-close)
   /range)
   *100.0;
}

//----------------------------------------------------
// ATR Expansion
//----------------------------------------------------

double ImpulseATR(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double atr=
      GetATR(tf);

   if(atr<=0)
      return 0;

   double range=
      iHigh(_Symbol,tf,bar)
      -
      iLow(_Symbol,tf,bar);

   return
      range/atr;
}

//----------------------------------------------------
// Impulse Body
//----------------------------------------------------

bool StrongImpulseBody(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   return
      CandleBodyPercent(
         tf,
         bar)
      >=
      MinimumBodyPercent;
}

//----------------------------------------------------
// Strong Close
//----------------------------------------------------

bool StrongClose(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   return
      CandleClosePercent(
         tf,
         bar)
      >=
      MinimumClosePercent;
}

//----------------------------------------------------
// Count Institutional Impulse
//----------------------------------------------------

int CountImpulseCandles(
   ENUM_TIMEFRAMES tf,
   int startBar)
{
   int count=0;

   ENUM_DIRECTION direction=
      StructureDirection(tf);

   for(int bar=startBar; bar<=10; bar++)
   {
      bool valid=false;

      //--------------------------------------
      // Bullish Impulse
      //--------------------------------------

      if(direction==DIRECTION_BULLISH)
      {
         valid=
            iClose(_Symbol,tf,bar)
            >
            iOpen(_Symbol,tf,bar);
      }

      //--------------------------------------
      // Bearish Impulse
      //--------------------------------------

      else
      {
         valid=
            iClose(_Symbol,tf,bar)
            <
            iOpen(_Symbol,tf,bar);
      }

      if(!valid)
         break;

      if(!StrongImpulseBody(tf,bar))
         break;

      count++;
   }

   return count;
}

//----------------------------------------------------
// Impulse High
//----------------------------------------------------

double ImpulseHigh(
   ENUM_TIMEFRAMES tf,
   int startBar,
   int endBar)
{
   double highest=
      iHigh(_Symbol,tf,startBar);

   for(int bar=startBar;
       bar>=endBar;
       bar--)
   {
      highest=
         MathMax(
            highest,
            iHigh(_Symbol,tf,bar));
   }

   return highest;
}

//----------------------------------------------------
// Impulse Low
//----------------------------------------------------

double ImpulseLow(
   ENUM_TIMEFRAMES tf,
   int startBar,
   int endBar)
{
   double lowest=
      iLow(_Symbol,tf,startBar);

   for(int bar=startBar;
       bar>=endBar;
       bar--)
   {
      lowest=
         MathMin(
            lowest,
            iLow(_Symbol,tf,bar));
   }

   return lowest;
}

//----------------------------------------------------
// Detect Institutional Impulse
//----------------------------------------------------

bool DetectImpulse(
   ENUM_TIMEFRAMES tf,
   int &startBar,
   int &endBar,
   int &displacementBar)
{
   //--------------------------------------
   // Structure Required
   //--------------------------------------

   if(!BOSConfirmed(tf))
      return false;

   //--------------------------------------
   // Displacement Candle
   //--------------------------------------

   displacementBar=1;

   //--------------------------------------
   // Strong Candle
   //--------------------------------------

   if(!StrongImpulseBody(
      tf,
      displacementBar))
      return false;

   if(!StrongClose(
      tf,
      displacementBar))
      return false;

   if(ImpulseATR(
      tf,
      displacementBar)
      <
      MinimumDisplacementATR)
      return false;

   //--------------------------------------
   // Count Impulse
   //--------------------------------------

   int candles=
      CountImpulseCandles(
         tf,
         displacementBar);

   if(candles<
      MinimumImpulseCandles)
      return false;

  //--------------------------------------
  // Impulse Leg
  //--------------------------------------

  endBar=
     displacementBar;

  startBar=
     displacementBar
     +
     candles
     -
     1;

   return true;
}

//----------------------------------------------------
// Detect Institutional Displacement
//----------------------------------------------------

void DetectDisplacement(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   ResetDisplacement(tf);

   //--------------------------------------
   // Detect Impulse
   //--------------------------------------

   int startBar=-1;

   int endBar=-1;

   int displacementBar=-1;

   if(!DetectImpulse(
      tf,
      startBar,
      endBar,
      displacementBar))
   {
      return;
   }

   //--------------------------------------
   // Calculate Impulse Data
   //--------------------------------------

   double impulseHigh=
      ImpulseHigh(
         tf,
         startBar,
         endBar);

   double impulseLow=
      ImpulseLow(
         tf,
         startBar,
         endBar);

   double displacementHigh=
      iHigh(
         _Symbol,
         tf,
         displacementBar);

   double displacementLow=
      iLow(
         _Symbol,
         tf,
         displacementBar);

   double displacementSize=
      displacementHigh
      -
      displacementLow;

   int impulseCandles=
      CountImpulseCandles(
         tf,
         displacementBar);

   //--------------------------------------
   // Save Displacement
   //--------------------------------------

   DisplacementData[idx].valid=true;

   DisplacementData[idx].confirmed=true;

   DisplacementData[idx].direction=
      StructureDirection(tf);

   DisplacementData[idx].startBar=
      startBar;

   DisplacementData[idx].endBar=
      endBar;

   DisplacementData[idx].displacementBar=
      displacementBar;

   DisplacementData[idx].impulseCandles=
      impulseCandles;

   DisplacementData[idx].impulseHigh=
      impulseHigh;

   DisplacementData[idx].impulseLow=
      impulseLow;

   DisplacementData[idx].impulseRange=
      impulseHigh
      -
      impulseLow;

   DisplacementData[idx].displacementHigh=
      displacementHigh;

   DisplacementData[idx].displacementLow=
      displacementLow;

   DisplacementData[idx].displacementSize=
      displacementSize;

   DisplacementData[idx].ATRMultiple=
      ImpulseATR(
         tf,
         displacementBar);

   DisplacementData[idx].bodyPercent=
      CandleBodyPercent(
         tf,
         displacementBar);

   DisplacementData[idx].closePercent=
      CandleClosePercent(
         tf,
         displacementBar);

   DisplacementData[idx].time=
      iTime(
         _Symbol,
         tf,
         displacementBar);
}

//----------------------------------------------------
// Calculate Institutional Score
//----------------------------------------------------

double CalculateDisplacementScore(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return 0.0;

   if(!DisplacementData[idx].confirmed)
      return 0.0;

   double score=0.0;

   //--------------------------------------
   // ATR Expansion
   //--------------------------------------

   score+=
      MathMin(
         DisplacementData[idx]
         .ATRMultiple
         *20.0,
         40.0);

   //--------------------------------------
   // Body
   //--------------------------------------

   score+=
      DisplacementData[idx]
      .bodyPercent
      *0.30;

   //--------------------------------------
   // Close
   //--------------------------------------

   score+=
      DisplacementData[idx]
      .closePercent
      *0.20;

   //--------------------------------------
   // Impulse
   //--------------------------------------

   score+=
      MathMin(
         DisplacementData[idx]
         .impulseCandles
         *5.0,
         10.0);

   return
      MathMin(
         score,
         100.0);
}

//----------------------------------------------------
// Update Score
//----------------------------------------------------

void UpdateDisplacementScore(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   if(!DisplacementData[idx].confirmed)
      return;

   DisplacementData[idx].score=
      CalculateDisplacementScore(
         tf);
}

//----------------------------------------------------
// Update Displacement Engine
//----------------------------------------------------

void UpdateDisplacementEngine()
{
   for(int i=0;
       i<ACTIVE_SCAN_TIMEFRAMES;
       i++)
   {
      ENUM_TIMEFRAMES tf=
         StructureTF[i];

      DetectDisplacement(tf);

      UpdateDisplacementScore(tf);
   }
}

//----------------------------------------------------
// Current Displacement Score
//----------------------------------------------------

double CurrentDisplacementScore(
   ENUM_TIMEFRAMES tf)
{
   return
      StoredDisplacementScore(tf);
}

//----------------------------------------------------
// Current Impulse Candles
//----------------------------------------------------

int CurrentImpulseCandles(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return 0;

   return
      DisplacementData[idx]
      .impulseCandles;
}

//----------------------------------------------------
// Current Impulse High
//----------------------------------------------------

double CurrentImpulseHigh(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return 0.0;

   return
      DisplacementData[idx]
      .impulseHigh;
}

//----------------------------------------------------
// Current Impulse Low
//----------------------------------------------------

double CurrentImpulseLow(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return 0.0;

   return
      DisplacementData[idx]
      .impulseLow;
}

//----------------------------------------------------
// Current Displacement High
//----------------------------------------------------

double CurrentDisplacementHigh(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return 0.0;

   return
      DisplacementData[idx]
      .displacementHigh;
}

//----------------------------------------------------
// Current Displacement Low
//----------------------------------------------------

double CurrentDisplacementLow(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return 0.0;

   return
      DisplacementData[idx]
      .displacementLow;
}

//----------------------------------------------------
// Current Displacement Bar
//----------------------------------------------------

int CurrentDisplacementBar(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return -1;

   return
      DisplacementData[idx]
      .displacementBar;
}



//====================================================
// SECTION 16 - INSTITUTIONAL FAIR VALUE GAP ENGINE
//====================================================

//----------------------------------------------------
// Institutional Fair Value Gap
//----------------------------------------------------

struct FairValueGap
{
   bool valid;

   bool confirmed;

   ENUM_FVG_TYPE type;

   ENUM_DIRECTION direction;

   double high;

   double low;

   double midpoint;

   double size;

   double filledPercent;

   double score;

   int creationBar;

   int displacementBar;

   datetime creationTime;

   bool mitigated;

   bool invalidated;

   int touchCount;
};

//----------------------------------------------------
// FVG State
//----------------------------------------------------

FairValueGap
FVGData[ACTIVE_SCAN_TIMEFRAMES];

//----------------------------------------------------
// FVG Settings
//----------------------------------------------------

input double MinimumFVGSizeATR = 0.20;

input double MaximumFillPercent = 50.0;

input bool RequireDisplacementFVG = true;

input bool IgnoreTinyFVG = true;

//----------------------------------------------------
// Reset FVG
//----------------------------------------------------

void ResetFVG(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   ZeroMemory(
      FVGData[idx]);
}

//----------------------------------------------------
// FVG Size Filter
//----------------------------------------------------

bool ValidFVGSize(
   ENUM_TIMEFRAMES tf,
   double high,
   double low)
{
   double atr=
      GetATR(tf);

   if(atr<=0)
      return false;

   double gap=
      MathAbs(high-low);

   return
      gap
      >=
      atr*
      MinimumFVGSizeATR;
}

//----------------------------------------------------
// Bullish FVG
//----------------------------------------------------

bool BullishFVG(
   ENUM_TIMEFRAMES tf,
   int bar,
   double &high,
   double &low)
{
   double candle1High=
      iHigh(_Symbol,tf,bar+2);

   double candle3Low=
      iLow(_Symbol,tf,bar);

   if(candle3Low<=candle1High)
      return false;

   high=candle3Low;
   low=candle1High;

   if(IgnoreTinyFVG)
   {
      if(!ValidFVGSize(tf,high,low))
         return false;
   }

   return true;
}

//----------------------------------------------------
// Bearish FVG
//----------------------------------------------------

bool BearishFVG(
   ENUM_TIMEFRAMES tf,
   int bar,
   double &high,
   double &low)
{
   double candle1Low=
      iLow(_Symbol,tf,bar+2);

   double candle3High=
      iHigh(_Symbol,tf,bar);

   if(candle3High>=candle1Low)
      return false;

   high=candle1Low;
   low=candle3High;

   if(IgnoreTinyFVG)
   {
      if(!ValidFVGSize(tf,high,low))
         return false;
   }

   return true;
}

//----------------------------------------------------
// Calculate FVG Score
//----------------------------------------------------

double CalculateFVGScore(
   ENUM_TIMEFRAMES tf,
   double high,
   double low,
   int bar)
{
   double score=0.0;

   //------------------------------------------
   // Size Score (40)
   //------------------------------------------

   double atr=GetATR(tf);

   if(atr>0)
   {
      double ratio=
         MathAbs(high-low)/atr;

      score+=MathMin(ratio*40.0,40.0);
   }

   //------------------------------------------
   // Freshness (20)
   //------------------------------------------

   score+=MathMax(
      20.0-(bar*3.0),
      0.0);

   //------------------------------------------
   // Close Strength (20)
   //------------------------------------------

   score+=
      CandleClosePercent(tf,bar)
      *0.20;

   //------------------------------------------
   // Body Strength (20)
   //------------------------------------------

   score+=
      CandleBodyPercent(tf,bar)
      *0.20;

   return
      MathMin(score,100.0);
}

//----------------------------------------------------
// Detect FVG From Displacement
//----------------------------------------------------

bool DetectDisplacementFVG(
   ENUM_TIMEFRAMES tf)
{
   int idx = StructureIndex(tf);

   if(idx < 0)
      return false;

   ResetFVG(tf);

   //------------------------------------------
   // Must have confirmed displacement
   //------------------------------------------

   if(!DisplacementConfirmed(tf))
      return false;

   double high, low;

   double bestScore = -1.0;

   double bestHigh = 0.0;
   double bestLow  = 0.0;

   int bestBar = -1;

   ENUM_FVG_TYPE bestType = FVG_NONE;

   //------------------------------------------
   // Search around displacement candle
   //------------------------------------------

   for(int bar = 1; bar <= 5; bar++)
   {
      //--------------------------------------
      // Bullish FVG
      //--------------------------------------

      if(StructureDirection(tf) == DIRECTION_BULLISH)
      {
         if(BullishFVG(tf, bar, high, low))
         {
            double score =
               CalculateFVGScore(
                  tf,
                  high,
                  low,
                  bar);

            if(score > bestScore)
            {
               bestScore = score;

               bestHigh = high;
               bestLow  = low;

               bestBar = bar;

               bestType = FVG_BULLISH;
            }
         }
      }

      //--------------------------------------
      // Bearish FVG
      //--------------------------------------

      if(StructureDirection(tf) == DIRECTION_BEARISH)
      {
         if(BearishFVG(tf, bar, high, low))
         {
            double score =
               CalculateFVGScore(
                  tf,
                  high,
                  low,
                  bar);

            if(score > bestScore)
            {
               bestScore = score;

               bestHigh = high;
               bestLow  = low;

               bestBar = bar;

               bestType = FVG_BEARISH;
            }
         }
      }
   }

   //------------------------------------------
   // No valid FVG found
   //------------------------------------------

   if(bestType == FVG_NONE)
      return false;

   //------------------------------------------
   // Save Best FVG
   //------------------------------------------

   FVGData[idx].valid = true;

   FVGData[idx].confirmed = true;

   FVGData[idx].type = bestType;

   FVGData[idx].direction =
      StructureDirection(tf);

   FVGData[idx].high = bestHigh;

   FVGData[idx].low = bestLow;

   FVGData[idx].midpoint =
      (bestHigh + bestLow) / 2.0;

   FVGData[idx].size =
      MathAbs(bestHigh - bestLow);

   FVGData[idx].creationBar =
      bestBar;

   FVGData[idx].displacementBar = 1;

   FVGData[idx].creationTime =
      iTime(_Symbol, tf, bestBar);

   FVGData[idx].score =
      bestScore;

   return true;
}

//----------------------------------------------------
// FVG Fill Percentage
//----------------------------------------------------

double CurrentFVGFill(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return 100.0;

   if(!FVGData[idx].valid)
      return 100.0;

   double price=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID);

   //---------------------------------------
   // Bullish
   //---------------------------------------

   if(FVGData[idx].direction==
      DIRECTION_BULLISH)
   {
      if(price>=FVGData[idx].high)
         return 0.0;

      if(price<=FVGData[idx].low)
         return 100.0;

      return
         ((FVGData[idx].high-price)
         /
         (FVGData[idx].high-
         FVGData[idx].low))
         *100.0;
   }

   //---------------------------------------
   // Bearish
   //---------------------------------------

   if(price<=FVGData[idx].low)
      return 0.0;

   if(price>=FVGData[idx].high)
      return 100.0;

   return
      ((price-
      FVGData[idx].low)
      /
      (FVGData[idx].high-
      FVGData[idx].low))
      *100.0;
}

//----------------------------------------------------
// Update FVG State
//----------------------------------------------------

void UpdateFVGState(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return;

   if(!FVGData[idx].valid)
      return;

   FVGData[idx].filledPercent=
      CurrentFVGFill(tf);

   //---------------------------------------

   if(FVGData[idx].filledPercent>0)
      FVGData[idx].touchCount++;

   //---------------------------------------

   if(FVGData[idx].filledPercent
      >=100.0)
   {
      FVGData[idx].invalidated=true;
   }

   //---------------------------------------

   if(FVGData[idx].filledPercent
      <=MaximumFillPercent)
   {
      FVGData[idx].mitigated=true;
   }
}

//----------------------------------------------------
// Update FVG Engine
//----------------------------------------------------

void UpdateFVGEngine()
{
   for(int i=0;
       i<ACTIVE_SCAN_TIMEFRAMES;
       i++)
   {
      DetectDisplacementFVG(
         StructureTF[i]);

      UpdateFVGState(
         StructureTF[i]);
   }
}



//====================================================
// SECTION 17 - INSTITUTIONAL PREMIUM / DISCOUNT ENGINE
//====================================================

//----------------------------------------------------
// Inputs
//----------------------------------------------------

input bool RequirePremiumDiscount = true;

input double EquilibriumTolerance = 2.0;

//----------------------------------------------------
// Premium Discount State
//----------------------------------------------------

struct PremiumDiscountState
{
   bool valid;

   bool premium;

   bool discount;

   bool equilibrium;

   ENUM_DIRECTION direction;

   double swingHigh;

   double swingLow;

   double equilibriumPrice;

   double currentPrice;

   double distancePercent;
};

PremiumDiscountState
PremiumDiscountData[ACTIVE_SCAN_TIMEFRAMES];
         
//----------------------------------------------------
// Reset
//----------------------------------------------------

void ResetPremiumDiscount(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   ZeroMemory(
      PremiumDiscountData[idx]);
}

//----------------------------------------------------
// Equilibrium
//----------------------------------------------------

double EquilibriumPrice(
   double high,
   double low)
{
   return
      (high+low)/2.0;
}

//----------------------------------------------------
// Position In Range
//----------------------------------------------------

double RangePercent(
   double high,
   double low,
   double price)
{
   if(high<=low)
      return 50.0;

   return
      ((price-low)/
      (high-low))
      *100.0;
}

//----------------------------------------------------
// Detect Premium Discount
//----------------------------------------------------

void DetectPremiumDiscount(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   ResetPremiumDiscount(tf);

   if(!FVGData[idx].valid)
      return;

   double swingHigh=
      LatestSwingHigh(tf).price;

   double swingLow=
      LatestSwingLow(tf).price;

   double eq=
      EquilibriumPrice(
         swingHigh,
         swingLow);

   double price=
      FVGData[idx].midpoint;

   double percent=
      RangePercent(
         swingHigh,
         swingLow,
         price);

   PremiumDiscountData[idx].valid=true;

   PremiumDiscountData[idx].direction=
      StructureDirection(tf);

   PremiumDiscountData[idx].swingHigh=
      swingHigh;

   PremiumDiscountData[idx].swingLow=
      swingLow;

   PremiumDiscountData[idx].equilibriumPrice=
      eq;

   PremiumDiscountData[idx].currentPrice=
      price;

   PremiumDiscountData[idx].distancePercent=
      percent;

   //------------------------------------------
   // Discount
   //------------------------------------------

   if(percent<50.0-
      EquilibriumTolerance)
   {
      PremiumDiscountData[idx].discount=true;
   }

   //------------------------------------------
   // Premium
   //------------------------------------------

   if(percent>50.0+
      EquilibriumTolerance)
   {
      PremiumDiscountData[idx].premium=true;
   }

   //------------------------------------------
   // Equilibrium
   //------------------------------------------

   if(MathAbs(percent-50.0)
      <=EquilibriumTolerance)
   {
      PremiumDiscountData[idx].equilibrium=true;
   }
}

//----------------------------------------------------
// Premium Discount Validation
//----------------------------------------------------

bool PremiumDiscountValid(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return false;

   if(!PremiumDiscountData[idx].valid)
      return false;

   //------------------------------------------
   // Bullish ICT
   //------------------------------------------

   if(StructureDirection(tf)==
      DIRECTION_BULLISH)
   {
      return
         PremiumDiscountData[idx].discount;
   }

   //------------------------------------------
   // Bearish ICT
   //------------------------------------------

   if(StructureDirection(tf)==
      DIRECTION_BEARISH)
   {
      return
         PremiumDiscountData[idx].premium;
   }

   return false;
}

//----------------------------------------------------
// Premium Discount Score
//----------------------------------------------------

double PremiumDiscountScore(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return 0;

   if(!PremiumDiscountData[idx].valid)
      return 0;

   double score=0.0;

   double percent=
      PremiumDiscountData[idx]
      .distancePercent;

   //------------------------------------------
   // Bullish
   //------------------------------------------

   if(StructureDirection(tf)==
      DIRECTION_BULLISH)
   {
      score=
         100.0
         -
         percent;
   }

   //------------------------------------------
   // Bearish
   //------------------------------------------

   else
   {
      score=
         percent;
   }

   return
      MathMax(
      0.0,
      MathMin(score,100.0));
}

//----------------------------------------------------
// Update Premium Discount Engine
//----------------------------------------------------

void UpdatePremiumDiscountEngine()
{
   for(int i=0;
       i<ACTIVE_SCAN_TIMEFRAMES;
       i++)
   {
      DetectPremiumDiscount(
         StructureTF[i]);
   }
}

//----------------------------------------------------
// Helper Functions
//----------------------------------------------------

bool InPremium(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return false;

   return
      PremiumDiscountData[idx]
      .premium;
}

//----------------------------------------------------

bool InDiscount(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return false;

   return
      PremiumDiscountData[idx]
      .discount;
}

//----------------------------------------------------

bool InEquilibrium(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return false;

   return
      PremiumDiscountData[idx]
      .equilibrium;
}


//====================================================
// SECTION 18 - ICT ORDER BLOCK ENGINE
//====================================================

//----------------------------------------------------
// Inputs
//----------------------------------------------------

input bool RequireOrderBlock=true;

input bool RequireDisplacementForOB=true;

input bool RequireFVGForOB=true;

input double MaximumOrderBlockATR=2.00;

input double MinimumOrderBlockBody=50.0;

//----------------------------------------------------
// Order Block State
//----------------------------------------------------

struct OrderBlockState
{
   bool valid;

   bool confirmed;

   ENUM_DIRECTION direction;

   int candleBar;

   datetime time;

   double high;

   double low;

   double open;

   double close;

   double midpoint;

   double range;

   double bodyPercent;

   double score;

   bool touched;

   bool mitigated;

   bool rejected;

   bool invalidated;

   int touchCount;

   int mitigationCount;

   datetime firstTouchTime;
};

OrderBlockState
OrderBlockData[ACTIVE_SCAN_TIMEFRAMES];

//----------------------------------------------------
// Reset
//----------------------------------------------------

void ResetOrderBlock(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   ZeroMemory(
      OrderBlockData[idx]);
}

//----------------------------------------------------
// Helpers
//----------------------------------------------------

bool OrderBlockConfirmed(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return false;

   return
      OrderBlockData[idx]
      .confirmed;
}

//----------------------------------------------------

double OrderBlockMidpoint(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return 0;

   return
      OrderBlockData[idx]
      .midpoint;
}

//----------------------------------------------------
// Institutional Filters
//----------------------------------------------------

bool ValidOrderBlockBody(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   return
      CandleBodyPercent(
         tf,
         bar)
      >=
      MinimumOrderBlockBody;
}

//----------------------------------------------------

bool ValidOrderBlockSize(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double atr=
      GetATR(tf);

   if(atr<=0)
      return false;

   double range=
      iHigh(_Symbol,tf,bar)
      -
      iLow(_Symbol,tf,bar);

   return
      range
      <=
      atr
      *
      MaximumOrderBlockATR;
}

//----------------------------------------------------
// Find ICT Order Block
//----------------------------------------------------

bool FindICTOrderBlock(
   ENUM_TIMEFRAMES tf,
   int &orderBlockBar)
{
   orderBlockBar=-1;

   if(RequireDisplacementForOB)
   {
      if(!DisplacementConfirmed(tf))
         return false;
   }

   if(RequireFVGForOB)
   {
      int idx=
         StructureIndex(tf);

      if(idx<0)
         return false;

      if(!FVGData[idx].valid)
         return false;
   }

   int startBar=
      DisplacementStartBar(tf);

   if(startBar<0)
      return false;

   ENUM_DIRECTION direction=
      StructureDirection(tf);

   //--------------------------------------
   // Start with the candle immediately
   // preceding the impulse
   //--------------------------------------

   int bar=
      startBar+1;

   while(bar<=20)
   {
      bool opposite=false;

      if(direction==DIRECTION_BULLISH)
      {
         opposite=
            iClose(_Symbol,tf,bar)
            <
            iOpen(_Symbol,tf,bar);
      }
      else
      {
         opposite=
            iClose(_Symbol,tf,bar)
            >
            iOpen(_Symbol,tf,bar);
      }

      if(opposite)
      {
         if(ValidOrderBlockBody(tf,bar) &&
            ValidOrderBlockSize(tf,bar))
         {
            orderBlockBar=bar;
            return true;
         }
      }

      bar++;
   }

   return false;
}

//----------------------------------------------------
// Save ICT Order Block
//----------------------------------------------------

void SaveOrderBlock(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   OrderBlockData[idx].valid=true;

   OrderBlockData[idx].confirmed=true;

   OrderBlockData[idx].direction=
      StructureDirection(tf);

   OrderBlockData[idx].candleBar=
      bar;

   OrderBlockData[idx].time=
      iTime(_Symbol,tf,bar);

   OrderBlockData[idx].high=
      iHigh(_Symbol,tf,bar);

   OrderBlockData[idx].low=
      iLow(_Symbol,tf,bar);

   OrderBlockData[idx].open=
      iOpen(_Symbol,tf,bar);

   OrderBlockData[idx].close=
      iClose(_Symbol,tf,bar);

   OrderBlockData[idx].range=
      OrderBlockData[idx].high
      -
      OrderBlockData[idx].low;

   OrderBlockData[idx].midpoint=
      (
         OrderBlockData[idx].high
         +
         OrderBlockData[idx].low
      )/2.0;

   OrderBlockData[idx].bodyPercent=
      CandleBodyPercent(
         tf,
         bar);
  OrderBlockData[idx].score=0.0;

  OrderBlockData[idx].touched=false;

  OrderBlockData[idx].mitigated=false;

  OrderBlockData[idx].rejected=false;

  OrderBlockData[idx].invalidated=false;

  OrderBlockData[idx].touchCount=0;

  OrderBlockData[idx].mitigationCount=0;

  OrderBlockData[idx].firstTouchTime=0;
}

//----------------------------------------------------
// Detect ICT Order Block
//----------------------------------------------------

void DetectOrderBlock(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   //--------------------------------------
   // Keep existing valid Order Block
   //--------------------------------------

   if(OrderBlockData[idx].confirmed &&
      !OrderBlockData[idx].invalidated)
   {
      return;
   }

   ResetOrderBlock(tf);

   int orderBlockBar=-1;

   if(!FindICTOrderBlock(
      tf,
      orderBlockBar))
   {
      return;
   }

   SaveOrderBlock(
      tf,
      orderBlockBar);
}

//----------------------------------------------------
// Calculate ICT Order Block Score
//----------------------------------------------------

double CalculateOrderBlockScore(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return 0.0;

   if(!OrderBlockData[idx].confirmed)
      return 0.0;

   double score=0.0;

   //--------------------------------------
   // Body Quality
   //--------------------------------------

   score+=
      OrderBlockData[idx]
      .bodyPercent
      *0.35;

   //--------------------------------------
   // Displacement Quality
   //--------------------------------------

   score+=
      CurrentDisplacementScore(tf)
      *0.40;

   //--------------------------------------
   // FVG Confirmation
   //--------------------------------------

   if(FVGData[idx].valid)
      score+=25.0;

   return
      MathMin(score,100.0);
}

//----------------------------------------------------
// Update Order Block Score
//----------------------------------------------------

void UpdateOrderBlockScore(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   if(!OrderBlockData[idx].confirmed)
      return;

   OrderBlockData[idx].score=
      CalculateOrderBlockScore(tf);
}

//----------------------------------------------------
// Detect Order Block Mitigation
//----------------------------------------------------

void DetectOrderBlockMitigation(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   if(!OrderBlockData[idx].confirmed)
      return;

   if(OrderBlockData[idx].invalidated)
      return;

   double high=
      iHigh(_Symbol,tf,1);

   double low=
      iLow(_Symbol,tf,1);

   double midpoint=
      OrderBlockData[idx].midpoint;

   //--------------------------------------
   // Bullish Order Block
   //--------------------------------------

   if(OrderBlockData[idx].direction
      ==
      DIRECTION_BULLISH)
   {
      if(low<=midpoint)
      {
         if(!OrderBlockData[idx].touched)
         {
            OrderBlockData[idx].touched=true;

            OrderBlockData[idx].touchCount=1;

            OrderBlockData[idx].firstTouchTime=
               iTime(_Symbol,tf,1);
         }
         else if(
                iTime(_Symbol,tf,1)
                !=
                OrderBlockData[idx].firstTouchTime)
             {
              OrderBlockData[idx].touchCount++;

              OrderBlockData[idx].firstTouchTime=
              iTime(_Symbol,tf,1);
        }
      }
   }

   //--------------------------------------
   // Bearish Order Block
   //--------------------------------------

   else
   {
      if(high>=midpoint)
      {
         if(!OrderBlockData[idx].touched)
         {
            OrderBlockData[idx].touched=true;

            OrderBlockData[idx].touchCount=1;

            OrderBlockData[idx].firstTouchTime=
               iTime(_Symbol,tf,1);
         }
         else if(iTime(_Symbol,tf,1)
               !=
               OrderBlockData[idx].firstTouchTime)
            {
              OrderBlockData[idx].touchCount++;

              OrderBlockData[idx].firstTouchTime=
              iTime(_Symbol,tf,1);
            }
      }
   }
}

//----------------------------------------------------
// Detect Invalidation
//----------------------------------------------------

void DetectOrderBlockInvalidation(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   if(!OrderBlockData[idx].confirmed)
      return;

   if(OrderBlockData[idx].direction
      ==
      DIRECTION_BULLISH)
   {
      if(iClose(_Symbol,tf,1)
         <
         OrderBlockData[idx].low)
      {
         OrderBlockData[idx]
         .invalidated=true;
      }
   }
   else
   {
      if(iClose(_Symbol,tf,1)
         >
         OrderBlockData[idx].high)
      {
         OrderBlockData[idx]
         .invalidated=true;
      }
   }
}

//----------------------------------------------------
// Update Order Block Engine
//----------------------------------------------------

void UpdateOrderBlockEngine()
{
   for(int i=0;
       i<ACTIVE_SCAN_TIMEFRAMES;
       i++)
   {
      ENUM_TIMEFRAMES tf=
         StructureTF[i];

      DetectOrderBlock(tf);

      UpdateOrderBlockScore(tf);

      DetectOrderBlockMitigation(tf);

      DetectOrderBlockInvalidation(tf);
   }
}

//----------------------------------------------------
// Helper Functions
//----------------------------------------------------

double CurrentOrderBlockScore(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return 0.0;

   return
      OrderBlockData[idx]
      .score;
}

//----------------------------------------------------

bool OrderBlockMitigated(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return false;

   return
      OrderBlockData[idx]
      .mitigated;
}

//----------------------------------------------------

bool OrderBlockInvalidated(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return false;

   return
      OrderBlockData[idx]
      .invalidated;
}



//====================================================
// SECTION 19 - ICT LIQUIDITY & PATTERN ENGINE
//====================================================

#define MAX_LIQUIDITY_RECORDS      500
#define MAX_ACTIVE_PATTERNS        100

//----------------------------------------------------
// Liquidity Types
//----------------------------------------------------

enum ENUM_LIQUIDITY_TYPE
{
   LIQUIDITY_NONE=0,

   LIQUIDITY_OLD_HIGH,

   LIQUIDITY_OLD_LOW,

   LIQUIDITY_EQUAL_HIGH,

   LIQUIDITY_EQUAL_LOW,

   LIQUIDITY_SWING_HIGH,

   LIQUIDITY_SWING_LOW
};

//----------------------------------------------------
// Pattern Stage
//----------------------------------------------------

enum ENUM_PATTERN_STAGE
{
   PATTERN_NONE=0,

   PATTERN_WAITING_SWEEP,

   PATTERN_WAITING_MSS,

   PATTERN_WAITING_DISPLACEMENT,

   PATTERN_WAITING_FVG,

   PATTERN_WAITING_ORDERBLOCK,

   PATTERN_WAITING_RETRACEMENT,

   PATTERN_COMPLETE,

   PATTERN_INVALID
};

//----------------------------------------------------
// Liquidity Record
//----------------------------------------------------

struct LiquidityRecord
{
   bool valid;

   bool active;

   bool swept;

   ENUM_LIQUIDITY_TYPE type;

   ENUM_TIMEFRAMES timeframe;

   ENUM_DIRECTION direction;

   double price;

   datetime creationTime;

   datetime sweepTime;

   int sourceBar;

   double wickRejection;

   double closeStrength;
};

//----------------------------------------------------
// Active ICT Pattern
//----------------------------------------------------

struct ICTPattern
{
   bool active;

   int liquidityIndex;

   ENUM_PATTERN_STAGE stage;

   ENUM_TIMEFRAMES sourceTF;

   ENUM_DIRECTION direction;

   datetime startTime;

   datetime lastUpdate;

   double entry;

   double stopLoss;

   double takeProfit;

   double mssPrice;

   datetime mssTime;

   double displacementHigh;

   double displacementLow;

   datetime displacementTime;

   double fvgHigh;

   double fvgLow;

   datetime fvgTime;

   double orderBlockHigh;

   double orderBlockLow;

   datetime orderBlockTime;

   double retracementPrice;

   datetime retracementTime;
};

//----------------------------------------------------
// Databases
//----------------------------------------------------

LiquidityRecord
LiquidityDatabase
[MAX_LIQUIDITY_RECORDS];

ICTPattern
PatternDatabase
[MAX_ACTIVE_PATTERNS];


//----------------------------------------------------
// Initialize Databases
//----------------------------------------------------

void InitializeSection19()
{
   ZeroMemory(
      LiquidityDatabase);

   ZeroMemory(
      PatternDatabase);
}

//----------------------------------------------------
// Find Free Liquidity Slot
//----------------------------------------------------

int FindFreeLiquiditySlot()
{
   for(int i=0;i<MAX_LIQUIDITY_RECORDS;i++)
   {
      if(!LiquidityDatabase[i].valid)
         return i;
   }

   return -1;
}

//----------------------------------------------------
// Find Liquidity By Price
//----------------------------------------------------

int FindLiquidityRecord(
   ENUM_TIMEFRAMES tf,
   ENUM_LIQUIDITY_TYPE type,
   double price)
{
   for(int i=0;i<MAX_LIQUIDITY_RECORDS;i++)
   {
      if(!LiquidityDatabase[i].valid)
         continue;

      if(LiquidityDatabase[i].timeframe!=tf)
         continue;

      if(LiquidityDatabase[i].type!=type)
         continue;

      if(MathAbs(
         LiquidityDatabase[i].price-price)<=(_Point*2))
      {
         return i;
      }
   }

   return -1;
}

//----------------------------------------------------
// Liquidity Exists
//----------------------------------------------------

bool LiquidityExists(
   ENUM_TIMEFRAMES tf,
   ENUM_LIQUIDITY_TYPE type,
   double price)
{
   return
      (FindLiquidityRecord(
         tf,
         type,
         price)>=0);
}

//----------------------------------------------------
// Add Liquidity
//----------------------------------------------------

bool AddLiquidity(
   ENUM_TIMEFRAMES tf,
   ENUM_LIQUIDITY_TYPE type,
   ENUM_DIRECTION direction,
   double price,
   datetime creationTime,
   int sourceBar)
{
   if(LiquidityExists(
      tf,
      type,
      price))
      return false;

   int slot=
      FindFreeLiquiditySlot();

   if(slot<0)
      return false;

   LiquidityDatabase[slot].valid=true;

   LiquidityDatabase[slot].active=true;

   LiquidityDatabase[slot].swept=false;

   LiquidityDatabase[slot].timeframe=tf;

   LiquidityDatabase[slot].type=type;

   LiquidityDatabase[slot].direction=direction;

   LiquidityDatabase[slot].price=price;

   LiquidityDatabase[slot].creationTime=
      creationTime;

   LiquidityDatabase[slot].sourceBar=
      sourceBar;

   LiquidityDatabase[slot].sweepTime=0;

   LiquidityDatabase[slot].wickRejection=0;

   LiquidityDatabase[slot].closeStrength=0;

   return true;
}

//----------------------------------------------------
// Remove Liquidity
//----------------------------------------------------

void RemoveLiquidity(int index)
{
   if(index<0)
      return;

   if(index>=MAX_LIQUIDITY_RECORDS)
      return;

   ZeroMemory(
      LiquidityDatabase[index]);
}

//----------------------------------------------------
// Active Liquidity Count
//----------------------------------------------------

int ActiveLiquidityCount()
{
   int total=0;

   for(int i=0;i<MAX_LIQUIDITY_RECORDS;i++)
   {
      if(!LiquidityDatabase[i].valid)
         continue;

      if(!LiquidityDatabase[i].active)
         continue;

      total++;
   }

   return total;
}

//----------------------------------------------------
// Remove Mitigated Liquidity
//----------------------------------------------------

void RemoveMitigatedLiquidity()
{
   for(int i=0;i<MAX_LIQUIDITY_RECORDS;i++)
   {
      if(!LiquidityDatabase[i].valid)
         continue;

      if(!LiquidityDatabase[i].active)
         continue;

      if(IsLiquidityMitigated(
         LiquidityDatabase[i]))
      {
         RemoveLiquidity(i);
      }
   }
}

//----------------------------------------------------
// Scan Timeframe For Liquidity
//----------------------------------------------------

void ScanTimeframeLiquidity(
   ENUM_TIMEFRAMES tf)
{
   int bars=iBars(_Symbol,tf);

   if(bars<20)
      return;

   for(int bar=5;bar<bars-5;bar++)
   {
      DetectOldHigh(tf,bar);

      DetectOldLow(tf,bar);

      DetectEqualHigh(tf,bar);

      DetectEqualLow(tf,bar);

      DetectSwingHigh(tf,bar);

      DetectSwingLow(tf,bar);
   }
}


//----------------------------------------------------
// Scan All Timeframes
//----------------------------------------------------

void ScanAllLiquidity()
{
   for(int i=0;
       i<ACTIVE_SCAN_TIMEFRAMES;
       i++)
   {
      ScanTimeframeLiquidity(
         StructureTF[i]);
   }
}


//----------------------------------------------------
// Update Liquidity Engine
//----------------------------------------------------

void UpdateLiquidityEngine()
{
   //---------------------------------
   // Remove mitigated liquidity
   //---------------------------------

   RemoveMitigatedLiquidity();

   //---------------------------------
   // Scan for new liquidity
   //---------------------------------

   ScanAllLiquidity();
}

//----------------------------------------------------
// Detect All Liquidity
//----------------------------------------------------

void DetectLiquidity()
{
   UpdateLiquidityEngine();
}

//----------------------------------------------------
// Detect Old High Liquidity
//----------------------------------------------------

void DetectOldHigh(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double high=iHigh(_Symbol,tf,bar);

   //----------------------------------
   // Must be a confirmed swing high
   //----------------------------------

   if(high<=iHigh(_Symbol,tf,bar+1))
      return;

   if(high<=iHigh(_Symbol,tf,bar-1))
      return;

   //----------------------------------
   // Ignore duplicate liquidity
   //----------------------------------

   if(LiquidityExists(
      tf,
      LIQUIDITY_OLD_HIGH,
      high))
      return;

   //----------------------------------
   // Store liquidity
   //----------------------------------

   AddLiquidity(
      tf,
      LIQUIDITY_OLD_HIGH,
      DIRECTION_BEARISH,
      high,
      iTime(_Symbol,tf,bar),
      bar);
}

//----------------------------------------------------
// Detect Old Low Liquidity
//----------------------------------------------------

void DetectOldLow(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double low=iLow(_Symbol,tf,bar);

   //----------------------------------
   // Must be confirmed swing low
   //----------------------------------

   if(low>=iLow(_Symbol,tf,bar+1))
      return;

   if(low>=iLow(_Symbol,tf,bar-1))
      return;

   //----------------------------------
   // Ignore duplicate liquidity
   //----------------------------------

   if(LiquidityExists(
      tf,
      LIQUIDITY_OLD_LOW,
      low))
      return;

   //----------------------------------
   // Store liquidity
   //----------------------------------

   AddLiquidity(
      tf,
      LIQUIDITY_OLD_LOW,
      DIRECTION_BULLISH,
      low,
      iTime(_Symbol,tf,bar),
      bar);
}


//----------------------------------------------------
// Detect Equal High Liquidity
//----------------------------------------------------

void DetectEqualHigh(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double currentHigh=iHigh(_Symbol,tf,bar);

   double tolerance=GetLiquidityTolerance(tf);

   for(int i=bar+5;
       i<iBars(_Symbol,tf)-5;
       i++)
   {
      double previousHigh=
         iHigh(_Symbol,tf,i);

      if(MathAbs(
            currentHigh-
            previousHigh)
            <=tolerance)
      {
         if(!LiquidityExists(
            tf,
            LIQUIDITY_EQUAL_HIGH,
            currentHigh))
         {
            AddLiquidity(
               tf,
               LIQUIDITY_EQUAL_HIGH,
               DIRECTION_BEARISH,
               currentHigh,
               iTime(_Symbol,tf,bar),
               bar);
         }

         return;
      }
   }
}

//----------------------------------------------------
// Detect Equal Low Liquidity
//----------------------------------------------------

void DetectEqualLow(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double currentLow=iLow(_Symbol,tf,bar);

   double tolerance=
      GetLiquidityTolerance(tf);

   for(int i=bar+5;
       i<iBars(_Symbol,tf)-5;
       i++)
   {
      double previousLow=
         iLow(_Symbol,tf,i);

      if(MathAbs(
            currentLow-
            previousLow)
            <=tolerance)
      {
         if(!LiquidityExists(
            tf,
            LIQUIDITY_EQUAL_LOW,
            currentLow))
         {
            AddLiquidity(
               tf,
               LIQUIDITY_EQUAL_LOW,
               DIRECTION_BULLISH,
               currentLow,
               iTime(_Symbol,tf,bar),
               bar);
         }

         return;
      }
   }
}

//----------------------------------------------------
// Detect Swing High Liquidity
//----------------------------------------------------

void DetectSwingHigh(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double high=iHigh(_Symbol,tf,bar);

   //----------------------------------
   // Confirm swing high
   //----------------------------------

   if(high<=iHigh(_Symbol,tf,bar+1))
      return;

   if(high<=iHigh(_Symbol,tf,bar+2))
      return;

   if(high<=iHigh(_Symbol,tf,bar-1))
      return;

   if(high<=iHigh(_Symbol,tf,bar-2))
      return;

   //----------------------------------
   // Already stored?
   //----------------------------------

   if(LiquidityExists(
      tf,
      LIQUIDITY_SWING_HIGH,
      high))
      return;

   //----------------------------------
   // Store
   //----------------------------------

   AddLiquidity(
      tf,
      LIQUIDITY_SWING_HIGH,
      DIRECTION_BEARISH,
      high,
      iTime(_Symbol,tf,bar),
      bar);
}

//----------------------------------------------------
// Detect Swing Low Liquidity
//----------------------------------------------------

void DetectSwingLow(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   double low=iLow(_Symbol,tf,bar);

   //----------------------------------
   // Confirm swing low
   //----------------------------------

   if(low>=iLow(_Symbol,tf,bar+1))
      return;

   if(low>=iLow(_Symbol,tf,bar+2))
      return;

   if(low>=iLow(_Symbol,tf,bar-1))
      return;

   if(low>=iLow(_Symbol,tf,bar-2))
      return;

   //----------------------------------
   // Already stored?
   //----------------------------------

   if(LiquidityExists(
      tf,
      LIQUIDITY_SWING_LOW,
      low))
      return;

   //----------------------------------
   // Store
   //----------------------------------

   AddLiquidity(
      tf,
      LIQUIDITY_SWING_LOW,
      DIRECTION_BULLISH,
      low,
      iTime(_Symbol,tf,bar),
      bar);
}

//----------------------------------------------------
// Mark Liquidity Swept
//----------------------------------------------------

void MarkLiquiditySwept(
   int index,
   double wickStrength,
   double closeStrength)
{
   LiquidityDatabase[index].swept=true;

   LiquidityDatabase[index].sweepTime=
      TimeCurrent();

   LiquidityDatabase[index].wickRejection=
      wickStrength;

   LiquidityDatabase[index].closeStrength=
      closeStrength;
}

//----------------------------------------------------
// Sweep Detected?
//----------------------------------------------------

bool LiquiditySweepDetected(
   int index)
{
   if(index<0)
      return false;

   if(index>=MAX_LIQUIDITY_RECORDS)
      return false;

   if(!LiquidityDatabase[index].valid)
      return false;

   if(LiquidityDatabase[index].swept)
      return false;

   ENUM_TIMEFRAMES tf=
      LiquidityDatabase[index].timeframe;

   double liquidity=
      LiquidityDatabase[index].price;

   double high=iHigh(_Symbol,tf,1);

   double low=iLow(_Symbol,tf,1);

   switch(LiquidityDatabase[index].type)
   {
      case LIQUIDITY_OLD_HIGH:
      case LIQUIDITY_EQUAL_HIGH:
      case LIQUIDITY_SWING_HIGH:

         return(high>liquidity);

      case LIQUIDITY_OLD_LOW:
      case LIQUIDITY_EQUAL_LOW:
      case LIQUIDITY_SWING_LOW:

         return(low<liquidity);
   }

   return false;
}

//----------------------------------------------------
// Scan Database For Sweeps
//----------------------------------------------------

void DetectLiquiditySweeps()
{
   for(int i=0;
       i<MAX_LIQUIDITY_RECORDS;
       i++)
   {
      if(!LiquidityDatabase[i].valid)
         continue;

      if(LiquidityDatabase[i].swept)
         continue;

      if(LiquiditySweepDetected(i))
      {
         ValidateLiquiditySweep(i);
      }
   }
}


//----------------------------------------------------
// Validate Initial Sweep
//----------------------------------------------------

void ValidateLiquiditySweep(int index)
{
   if(index<0)
      return;

   if(index>=MAX_LIQUIDITY_RECORDS)
      return;

   ENUM_TIMEFRAMES tf=
      LiquidityDatabase[index].timeframe;

   //----------------------------------------
   // Calculate rejection wick
   //----------------------------------------

   double high=iHigh(_Symbol,tf,1);

   double low=iLow(_Symbol,tf,1);

   double open=iOpen(_Symbol,tf,1);

   double close=iClose(_Symbol,tf,1);

   double candleRange=high-low;

   if(candleRange<=0)
      return;

   double upperWick=
      high-MathMax(open,close);

   double lowerWick=
      MathMin(open,close)-low;

   double wickStrength=0.0;

   if(LiquidityDatabase[index].direction==
      DIRECTION_BEARISH)
   {
      wickStrength=
         upperWick/candleRange;
   }
   else
   {
      wickStrength=
         lowerWick/candleRange;
   }

   //----------------------------------------
   // Candle close quality
   //----------------------------------------

   double closeStrength=
      MathAbs(close-open)/
      candleRange;

   //----------------------------------------
   // Minimum quality
   //----------------------------------------

   if(wickStrength<0.30)
      return;

   if(closeStrength<0.40)
      return;

   //----------------------------------------
   // Initial sweep confirmed
   //----------------------------------------

   MarkLiquiditySwept(
      index,
      wickStrength,
      closeStrength);

   //----------------------------------------
   // Start ICT Pattern
   //----------------------------------------

   StartICTPattern(index);
}

//----------------------------------------------------
// Start ICT Pattern
//----------------------------------------------------

bool StartICTPattern(int liquidityIndex)
{
   int slot=FindFreePatternSlot();

   if(slot<0)
      return false;

   PatternDatabase[slot].active=true;

   PatternDatabase[slot].liquidityIndex=
      liquidityIndex;

   PatternDatabase[slot].stage=
      PATTERN_WAITING_MSS;

   PatternDatabase[slot].direction=
      LiquidityDatabase[liquidityIndex].direction;

   PatternDatabase[slot].sourceTF=
      LiquidityDatabase[liquidityIndex].timeframe;

   PatternDatabase[slot].startTime=
      TimeCurrent();

   PatternDatabase[slot].lastUpdate=
      TimeCurrent();

   PatternDatabase[slot].entry=0.0;

   PatternDatabase[slot].stopLoss=0.0;

   PatternDatabase[slot].takeProfit=0.0;

   PatternDatabase[slot].mssPrice=0.0;
   
   PatternDatabase[slot].mssTime=0;

   PatternDatabase[slot].displacementHigh=0.0;
   
   PatternDatabase[slot].displacementLow=0.0;
  
   PatternDatabase[slot].displacementTime=0;

   PatternDatabase[slot].fvgHigh=0.0;
   
   PatternDatabase[slot].fvgLow=0.0;
 
   PatternDatabase[slot].fvgTime=0;

   PatternDatabase[slot].orderBlockHigh=0.0;
 
   PatternDatabase[slot].orderBlockLow=0.0;

   PatternDatabase[slot].orderBlockTime=0;

   PatternDatabase[slot].retracementPrice=0.0;

   PatternDatabase[slot].retracementTime=0;

   return true;
}

//----------------------------------------------------
// Remove Pattern
//----------------------------------------------------

void RemovePattern(int index)
{
   if(index<0)
      return;

   if(index>=MAX_ACTIVE_PATTERNS)
      return;

   ZeroMemory(
      PatternDatabase[index]);
}

//----------------------------------------------------
// Update Pattern Timestamp
//----------------------------------------------------

void UpdatePatternTime(int index)
{
   if(index<0)
      return;

   if(index>=MAX_ACTIVE_PATTERNS)
      return;

   PatternDatabase[index].lastUpdate=
      TimeCurrent();
}

//----------------------------------------------------
// Update Active ICT Patterns
//----------------------------------------------------

void UpdateICTPatterns()
{
   for(int i=0;
       i<MAX_ACTIVE_PATTERNS;
       i++)
   {
      if(!PatternDatabase[i].active)
         continue;

      switch(PatternDatabase[i].stage)
      {
         case PATTERN_WAITING_MSS:

            MonitorPatternMSS(i);

            break;

         case PATTERN_WAITING_DISPLACEMENT:

            MonitorPatternDisplacement(i);

            break;

         case PATTERN_WAITING_FVG:

            MonitorPatternFVG(i);

            break;

         case PATTERN_WAITING_ORDERBLOCK:

            MonitorPatternOrderBlock(i);

            break;

         case PATTERN_WAITING_RETRACEMENT:

            MonitorPatternRetracement(i);

            break;

         case PATTERN_COMPLETE:

            CompleteICTPattern(i);

            break;

         case PATTERN_INVALID:

            RemovePattern(i);

            break;
      }
   }
}

//----------------------------------------------------
// MSS Found On Any Lower Timeframe
//----------------------------------------------------

bool PatternHasMSS(
   int patternIndex,
   ENUM_TIMEFRAMES &confirmedTF)
{
   ENUM_TIMEFRAMES sourceTF=
      PatternDatabase[patternIndex].sourceTF;

   int totalTF=
      GetLowerTimeframeCount(sourceTF);

   for(int i=0;i<totalTF;i++)
   {
      ENUM_TIMEFRAMES tf=
         GetLowerTimeframe(
            sourceTF,
            i);

      if(DetectMSS(
            tf,
            PatternDatabase[patternIndex].direction))
      {
         confirmedTF=tf;
         return true;
      }
   }

   return false;
}


//----------------------------------------------------
// Monitor MSS Stage
//----------------------------------------------------

void MonitorPatternMSS(
   int patternIndex)
{
   ENUM_TIMEFRAMES confirmedTF;

   if(!PatternHasMSS(
         patternIndex,
         confirmedTF))
   {
      return;
   }

   //----------------------------------
   // MSS confirmed
   //----------------------------------
   PatternDatabase[patternIndex].sourceTF=
      confirmedTF;

   PatternDatabase[patternIndex].mssPrice=
      GetMSSPrice(confirmedTF);

   PatternDatabase[patternIndex].mssTime=
      TimeCurrent();

   PatternDatabase[patternIndex].stage=
      PATTERN_WAITING_DISPLACEMENT;

   UpdatePatternTime(
      patternIndex);
}

//----------------------------------------------------
// Count Active Patterns
//----------------------------------------------------

int ActivePatternCount()
{
   int total=0;

   for(int i=0;
       i<MAX_ACTIVE_PATTERNS;
       i++)
   {
      if(PatternDatabase[i].active)
         total++;
   }

   return total;
}

//----------------------------------------------------
// Displacement Found On Any Lower Timeframe
//----------------------------------------------------

bool PatternHasDisplacement(
   int patternIndex)
{
   return DetectDisplacement(
      PatternDatabase[patternIndex].sourceTF,
      PatternDatabase[patternIndex].direction);
}

//----------------------------------------------------
// Monitor Displacement
//----------------------------------------------------

void MonitorPatternDisplacement(
   int patternIndex)
{
   if(!PatternHasDisplacement(patternIndex))
      return;

   //----------------------------------
   // Displacement confirmed
   //----------------------------------

   PatternDatabase[patternIndex].displacementHigh=
      GetDisplacementHigh(
         PatternDatabase[patternIndex].sourceTF);

   PatternDatabase[patternIndex].displacementLow=
      GetDisplacementLow(
         PatternDatabase[patternIndex].sourceTF);

  PatternDatabase[patternIndex].displacementTime=
      TimeCurrent();

  PatternDatabase[patternIndex].stage=
      PATTERN_WAITING_FVG;

   UpdatePatternTime(
      patternIndex);
}


//----------------------------------------------------
// FVG Found
//----------------------------------------------------

bool PatternHasFVG(
   int patternIndex)
{
   return DetectFVG(
      PatternDatabase[patternIndex].sourceTF,
      PatternDatabase[patternIndex].direction);
}

//----------------------------------------------------
// Monitor FVG
//----------------------------------------------------

void MonitorPatternFVG(
   int patternIndex)
{
   if(!PatternHasFVG(patternIndex))
      return;

   //----------------------------------
   // FVG confirmed
   //----------------------------------

   PatternDatabase[patternIndex].fvgHigh=
      GetFVGHigh(
         PatternDatabase[patternIndex].sourceTF);
 
  PatternDatabase[patternIndex].fvgLow=
      GetFVGLow(
         PatternDatabase[patternIndex].sourceTF);

  PatternDatabase[patternIndex].fvgTime=
      TimeCurrent();

  PatternDatabase[patternIndex].stage=
      PATTERN_WAITING_ORDERBLOCK;

   UpdatePatternTime(
      patternIndex);
}

//----------------------------------------------------
// Order Block Found
//----------------------------------------------------

bool PatternHasOrderBlock(
   int patternIndex)
{
   return DetectOrderBlock(
      PatternDatabase[patternIndex].sourceTF,
      PatternDatabase[patternIndex].direction);
}


//----------------------------------------------------
// Monitor Order Block
//----------------------------------------------------

void MonitorPatternOrderBlock(
   int patternIndex)
{
   if(!PatternHasOrderBlock(patternIndex))
      return;

   //----------------------------------
   // Store confirmed Order Block
   //----------------------------------

   PatternDatabase[patternIndex].orderBlockHigh=
      GetOrderBlockHigh(
         PatternDatabase[patternIndex].sourceTF);

   PatternDatabase[patternIndex].orderBlockLow=
      GetOrderBlockLow(
         PatternDatabase[patternIndex].sourceTF);

   PatternDatabase[patternIndex].orderBlockTime=
      TimeCurrent();

   //----------------------------------
   // Next stage
   //----------------------------------

   PatternDatabase[patternIndex].stage=
      PATTERN_WAITING_RETRACEMENT;

   UpdatePatternTime(
      patternIndex);
}

//----------------------------------------------------
// Retracement Found
//----------------------------------------------------

bool PatternHasRetracement(
   int patternIndex)
{
   return DetectRetracement(
      PatternDatabase[patternIndex].sourceTF,
      PatternDatabase[patternIndex].direction,
      PatternDatabase[patternIndex].fvgHigh,
      PatternDatabase[patternIndex].fvgLow,
      PatternDatabase[patternIndex].orderBlockHigh,
      PatternDatabase[patternIndex].orderBlockLow);
}

//----------------------------------------------------
// Monitor Retracement
//----------------------------------------------------

void MonitorPatternRetracement(
   int patternIndex)
{
   if(!PatternHasRetracement(patternIndex))
      return;

   //----------------------------------
   // Store entry
   //----------------------------------

   PatternDatabase[patternIndex].retracementPrice=
      GetRetracementPrice(
         PatternDatabase[patternIndex].sourceTF);

   PatternDatabase[patternIndex].retracementTime=
      TimeCurrent();

   //----------------------------------
   // Pattern complete
   //----------------------------------

   PatternDatabase[patternIndex].stage=
      PATTERN_COMPLETE;

   UpdatePatternTime(
      patternIndex);
}

//----------------------------------------------------
// Pattern Score
//----------------------------------------------------

double CalculatePatternScore(
   int patternIndex)
{
   double score=0.0;

   //----------------------------------
   // Higher timeframe gets priority
   //----------------------------------

   switch(PatternDatabase[patternIndex].sourceTF)
   {
      case PERIOD_H4: score+=40; break;
      case PERIOD_H1: score+=35; break;
      case PERIOD_M30: score+=30; break;
      case PERIOD_M15: score+=25; break;
      case PERIOD_M5: score+=20; break;
      case PERIOD_M1: score+=15; break;
   }

   //----------------------------------
   // Complete pattern bonus
   //----------------------------------

   if(PatternDatabase[patternIndex].stage==
      PATTERN_COMPLETE)
      score+=50;

   //----------------------------------
   // Fresh setup bonus
   //----------------------------------

   score+=MathMax(
      0,
      10-
      (TimeCurrent()-
      PatternDatabase[patternIndex].lastUpdate)/60);

   return score;
}


//----------------------------------------------------
// Best Completed Pattern
//----------------------------------------------------

int FindBestCompletedPattern()
{
   int best=-1;

   double bestScore=-1;

   for(int i=0;
       i<MAX_ACTIVE_PATTERNS;
       i++)
   {
      if(!PatternDatabase[i].active)
         continue;

      if(PatternDatabase[i].stage!=
         PATTERN_COMPLETE)
         continue;

      double score=
         CalculatePatternScore(i);

      if(score>bestScore)
      {
         bestScore=score;

         best=i;
      }
   }

   return best;
}


//----------------------------------------------------
// Send Pattern To Decision Engine
//----------------------------------------------------

void ProcessCompletedPatterns()
{
   int pattern=
      FindBestCompletedPattern();

   if(pattern<0)
      return;

   SendPatternToDecisionEngine(pattern);

   RemovePattern(pattern);
}


//====================================================
// SECTION 20 - MARKET STRUCTURE MATRIX ENGINE
//====================================================

//----------------------------------------------------
// Active Scan Timeframes
//----------------------------------------------------

#define ACTIVE_SCAN_TIMEFRAMES 3

ENUM_TIMEFRAMES StructureTF[ACTIVE_SCAN_TIMEFRAMES]=
{
   PERIOD_M5,
   PERIOD_M15,
   PERIOD_H1
};

//----------------------------------------------------
// Market Structure State
//----------------------------------------------------

struct MarketStructureState
{
   //------------------------------------------
   // General
   //------------------------------------------

   bool valid;

   ENUM_TIMEFRAMES timeframe;

   ENUM_DIRECTION direction;

   ENUM_STRUCTURE structure;

   //------------------------------------------
   // Swing Structure
   //------------------------------------------

   double swingHigh;

   double swingLow;

   int swingHighIndex;

   int swingLowIndex;

   datetime swingHighTime;

   datetime swingLowTime;

   //------------------------------------------
   // Impulse Leg
   //------------------------------------------

   double impulseHigh;

   double impulseLow;

   double impulseRange;

   datetime impulseStart;

   datetime impulseEnd;

   //------------------------------------------
   // Structure Events
   //------------------------------------------

   bool BOS;

   bool MSS;

   bool CHOCH;

   bool Displacement;

   //------------------------------------------
   // Trend
   //------------------------------------------

   bool bullish;

   bool bearish;

   //------------------------------------------
   // Market Statistics
   //------------------------------------------

   double ATR;

   double confidence;

   //------------------------------------------
   // Internal State
   //------------------------------------------

   bool newStructure;

   datetime lastUpdate;
};

//----------------------------------------------------
// Structure Cache
//----------------------------------------------------

MarketStructureState
StructureState[ACTIVE_SCAN_TIMEFRAMES];
   
//----------------------------------------------------
// Find Structure Index
//----------------------------------------------------

int StructureIndex(
   ENUM_TIMEFRAMES tf)
{
   for(int i=0;
       i<ACTIVE_SCAN_TIMEFRAMES;
       i++)
   {
      if(StructureTF[i]==tf)
         return i;
   }

   return -1;
}

//----------------------------------------------------
// Reset Structure Cache
//----------------------------------------------------

void ResetStructureCache(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   ZeroMemory(
      StructureState[idx]);

   StructureState[idx].timeframe=tf;

   StructureState[idx].valid=false;

   StructureState[idx].confidence=0;

   StructureState[idx].newStructure=false;
}

//----------------------------------------------------
// Initialize Cache
//----------------------------------------------------

void InitializeStructureCache()
{
   for(int i=0;
       i<ACTIVE_SCAN_TIMEFRAMES;
       i++)
   {
      ResetStructureCache(
         StructureTF[i]);
   }
}

//----------------------------------------------------
// Save Market Structure
//----------------------------------------------------

void SaveStructureCache(
   ENUM_TIMEFRAMES tf,
   ENUM_DIRECTION direction,
   ENUM_STRUCTURE structure,
   double swingHigh,
   double swingLow,
   int swingHighIndex,
   int swingLowIndex,
   bool bos,
   bool mss,
   bool choch,
   bool displacement)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   //------------------------------------------
   // Basic Information
   //------------------------------------------

   StructureState[idx].valid=true;

   StructureState[idx].timeframe=tf;

   StructureState[idx].direction=
      direction;

   StructureState[idx].structure=
      structure;

   //------------------------------------------
   // Swing Information
   //------------------------------------------

   StructureState[idx].swingHigh=
      swingHigh;

   StructureState[idx].swingLow=
      swingLow;

   StructureState[idx].swingHighIndex=
      swingHighIndex;

   StructureState[idx].swingLowIndex=
      swingLowIndex;

   StructureState[idx].swingHighTime=
      iTime(
         _Symbol,
         tf,
         swingHighIndex);

   StructureState[idx].swingLowTime=
      iTime(
         _Symbol,
         tf,
         swingLowIndex);

   //------------------------------------------
   // Impulse
   //------------------------------------------

   StructureState[idx].impulseHigh=
      MathMax(
         swingHigh,
         swingLow);

   StructureState[idx].impulseLow=
      MathMin(
         swingHigh,
         swingLow);

   StructureState[idx].impulseRange=
      MathAbs(
         swingHigh-
         swingLow);

   StructureState[idx].impulseStart=
      StructureState[idx].swingLowTime;

   StructureState[idx].impulseEnd=
      StructureState[idx].swingHighTime;

   //------------------------------------------
   // Structure Events
   //------------------------------------------

   StructureState[idx].BOS=
      bos;

   StructureState[idx].MSS=
      mss;

   StructureState[idx].CHOCH=
      choch;

   StructureState[idx].Displacement=
      displacement;

   //------------------------------------------
   // Trend
   //------------------------------------------

   StructureState[idx].bullish=
      (direction==
      DIRECTION_BULLISH);

   StructureState[idx].bearish=
      (direction==
      DIRECTION_BEARISH);

   //------------------------------------------
   // ATR
   //------------------------------------------

   StructureState[idx].ATR=
      GetATR(tf);

   //------------------------------------------
   // Confidence
   //------------------------------------------

   double score=0;

   if(bos)
      score+=25;

   if(mss)
      score+=25;

   if(choch)
      score+=20;

   if(displacement)
      score+=20;

   if(StructureState[idx].ATR>0)
      score+=10;

   StructureState[idx].confidence=
      MathMin(score,100.0);

   //------------------------------------------

   StructureState[idx].newStructure=
      true;

   StructureState[idx].lastUpdate=
      TimeCurrent();
}

//----------------------------------------------------
// Update Existing Structure
//----------------------------------------------------

void UpdateStructureConfidence(
   ENUM_TIMEFRAMES tf,
   double confidence)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   StructureState[idx].confidence=
      MathMax(
         0.0,
         MathMin(
            confidence,
            100.0));
}

//----------------------------------------------------
// Mark Structure Consumed
//----------------------------------------------------

void ClearNewStructureFlag(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   StructureState[idx].newStructure=
      false;
}

//----------------------------------------------------
// Check New Structure
//----------------------------------------------------

bool HasNewStructure(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return false;

   return
      StructureState[idx].newStructure;
}

//----------------------------------------------------
// Structure Ready
//----------------------------------------------------

bool StructureReady(ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return false;

   return StructureState[idx].valid;
}

//----------------------------------------------------
// Structure Direction
//----------------------------------------------------

ENUM_DIRECTION StructureDirection(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return DIRECTION_NONE;

   return StructureState[idx].direction;
}

//----------------------------------------------------
// Current Structure
//----------------------------------------------------

ENUM_STRUCTURE CurrentStructure(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return STRUCTURE_NONE;

   return StructureState[idx].structure;
}

//----------------------------------------------------
// Current Swing High
//----------------------------------------------------

double CurrentSwingHigh(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return 0;

   return StructureState[idx].swingHigh;
}

//----------------------------------------------------
// Current Swing Low
//----------------------------------------------------

double CurrentSwingLow(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return 0;

   return StructureState[idx].swingLow;
}

//----------------------------------------------------
// Current Impulse High
//----------------------------------------------------

double CurrentImpulseHigh(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return 0;

   return StructureState[idx].impulseHigh;
}

//----------------------------------------------------
// Current Impulse Low
//----------------------------------------------------

double CurrentImpulseLow(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return 0;

   return StructureState[idx].impulseLow;
}

//----------------------------------------------------
// Current ATR
//----------------------------------------------------

double StructureATR(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return 0;

   return StructureState[idx].ATR;
}

//----------------------------------------------------
// Structure Confidence
//----------------------------------------------------

double StructureConfidence(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return 0;

   return StructureState[idx].confidence;
}

//----------------------------------------------------
// Bullish Structure
//----------------------------------------------------

bool BullishStructure(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return false;

   return StructureState[idx].bullish;
}

//----------------------------------------------------
// Bearish Structure
//----------------------------------------------------

bool BearishStructure(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return false;

   return StructureState[idx].bearish;
}

//----------------------------------------------------
// BOS
//----------------------------------------------------

bool StructureBOS(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return false;

   return StructureState[idx].BOS;
}

//----------------------------------------------------
// MSS
//----------------------------------------------------

bool StructureMSS(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return false;

   return StructureState[idx].MSS;
}

//----------------------------------------------------
// CHOCH
//----------------------------------------------------

bool StructureCHOCH(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return false;

   return StructureState[idx].CHOCH;
}

//----------------------------------------------------
// Displacement
//----------------------------------------------------

bool StructureDisplacement(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return false;

   return StructureState[idx].Displacement;
}

//----------------------------------------------------
// Last Update
//----------------------------------------------------

datetime StructureLastUpdate(
   ENUM_TIMEFRAMES tf)
{
   int idx=StructureIndex(tf);

   if(idx<0)
      return 0;

   return StructureState[idx].lastUpdate;
}



//+------------------------------------------------------------------+
//| SECTION 21 : TRADE EXECUTION & TRADE MANAGEMENT ENGINE           |
//+------------------------------------------------------------------+

//----------------------------------------------------------
// Trade Execution Status
//----------------------------------------------------------
enum ENUM_EXECUTION_STATUS
{
   EXECUTION_IDLE = 0,
   EXECUTION_PENDING,
   EXECUTION_SENT,
   EXECUTION_FILLED,
   EXECUTION_FAILED,
   EXECUTION_CANCELLED
};

//----------------------------------------------------------
// Trade Management Status
//----------------------------------------------------------
enum ENUM_TRADE_STAGE
{
   TRADE_WAITING = 0,
   TRADE_ACTIVE,
   TRADE_BREAK_EVEN,
   TRADE_PARTIAL_1,
   TRADE_PARTIAL_2,
   TRADE_TRAILING,
   TRADE_CLOSED
};

//----------------------------------------------------------
// Complete Trade Request
//----------------------------------------------------------
struct TradeRequestData
{
   bool                 valid;

   ENUM_ORDER_TYPE      orderType;

   ENUM_TIMEFRAMES      timeframe;

   double               entryPrice;

   double               stopLoss;

   double               takeProfit;

   double               lotSize;

   double               riskPercent;

   double               rr;

   ulong                patternID;

   ulong                liquidityID;

   datetime             signalTime;

   string               symbol;
};

//----------------------------------------------------------
// Active Trade Information
//----------------------------------------------------------
struct ActiveTradeData
{
   bool                 active;

   ulong                ticket;

   ulong                patternID;

   ulong                liquidityID;

   ENUM_TRADE_STAGE     stage;

   ENUM_ORDER_TYPE      orderType;

   double               entry;

   double               stopLoss;

   double               takeProfit;

   double               initialRisk;

   double               currentRR;

   double               lots;

   datetime             openTime;

   bool                 breakEvenDone;

   bool                 partial1Done;

   bool                 partial2Done;

   bool                 trailingActive;
};

//----------------------------------------------------------
// Global Variables
//----------------------------------------------------------
TradeRequestData PendingTrade;

ActiveTradeData CurrentTrade;

ENUM_EXECUTION_STATUS ExecutionStatus = EXECUTION_IDLE;


//----------------------------------------------------------
// Reset Pending Trade
//----------------------------------------------------------
void ResetPendingTrade()
{
   ZeroMemory(PendingTrade);

   PendingTrade.valid = false;
}

//----------------------------------------------------------
// Receive Approved Trade
//----------------------------------------------------------
bool ReceiveTradeRequest(const TradeRequestData &request)
{
   ResetPendingTrade();

   PendingTrade = request;

   if(!PendingTrade.valid)
      return false;

   ExecutionStatus = EXECUTION_PENDING;

   return true;
}

//----------------------------------------------------------
// Broker Trading Allowed
//----------------------------------------------------------
bool IsBrokerTradingAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;

   if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)==0)
      return false;

   return true;
}

//----------------------------------------------------------
// Symbol Tradable
//----------------------------------------------------------
bool IsSymbolTradable(const string symbol)
{
   if(!SymbolSelect(symbol,true))
      return false;

   if(!SymbolInfoInteger(symbol,SYMBOL_SELECT))
      return false;

   if(SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE)==SYMBOL_TRADE_MODE_DISABLED)
      return false;

   return true;
}

//----------------------------------------------------------
// Market Open
//----------------------------------------------------------
bool IsMarketOpen(const string symbol)
{
   double bid=0;
   double ask=0;

   if(!SymbolInfoDouble(symbol,SYMBOL_BID,bid))
      return false;

   if(!SymbolInfoDouble(symbol,SYMBOL_ASK,ask))
      return false;

   if(bid<=0 || ask<=0)
      return false;

   return true;
}

//----------------------------------------------------------
// Margin Check
//----------------------------------------------------------
bool HasEnoughMargin()
{
   double marginRequired=0.0;

   ENUM_ORDER_TYPE type=PendingTrade.orderType;

   double price=(type==ORDER_TYPE_BUY)?
                 SymbolInfoDouble(PendingTrade.symbol,SYMBOL_ASK):
                 SymbolInfoDouble(PendingTrade.symbol,SYMBOL_BID);

   if(!OrderCalcMargin(type,
                       PendingTrade.symbol,
                       PendingTrade.lotSize,
                       price,
                       marginRequired))
      return false;

   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE)<marginRequired)
      return false;

   return true;
}

//----------------------------------------------------------
// Validate Trade Before Execution
//----------------------------------------------------------
bool ValidateExecution()
{
   if(!PendingTrade.valid)
      return false;

   if(!IsBrokerTradingAllowed())
      return false;

   if(!IsSymbolTradable(PendingTrade.symbol))
      return false;

   if(!IsMarketOpen(PendingTrade.symbol))
      return false;

   if(!HasEnoughMargin())
      return false;

   return true;
}

//----------------------------------------------------------
// Execute Approved Trade
//----------------------------------------------------------
bool ExecuteTrade()
{
   if(!ValidateExecution())
   {
      ExecutionStatus = EXECUTION_FAILED;
      return false;
   }

   MqlTradeRequest request;
   MqlTradeResult  result;

   ZeroMemory(request);
   ZeroMemory(result);

   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = PendingTrade.symbol;
   request.volume       = PendingTrade.lotSize;
   request.type         = PendingTrade.orderType;
   request.sl           = NormalizeDouble(PendingTrade.stopLoss,_Digits);
   request.tp           = NormalizeDouble(PendingTrade.takeProfit,_Digits);
   request.deviation    = MaxSlippagePoints;
   request.magic        = MagicNumber;
   request.type_filling = ORDER_FILLING_FOK;
   request.comment      = EAName;

   if(PendingTrade.orderType==ORDER_TYPE_BUY)
      request.price=SymbolInfoDouble(PendingTrade.symbol,SYMBOL_ASK);
   else
      request.price=SymbolInfoDouble(PendingTrade.symbol,SYMBOL_BID);

   if(!OrderSend(request,result))
   {
      ExecutionStatus = EXECUTION_FAILED;
      Print("OrderSend Failed : ",GetLastError());
      return false;
   }

   if(result.retcode!=TRADE_RETCODE_DONE &&
      result.retcode!=TRADE_RETCODE_DONE_PARTIAL)
   {
      ExecutionStatus = EXECUTION_FAILED;

      Print("Trade Rejected : ",result.retcode);

      return false;
   }

   ExecutionStatus=EXECUTION_FILLED;

   CurrentTrade.active=true;
   CurrentTrade.ticket=result.order;
   CurrentTrade.patternID=PendingTrade.patternID;
   CurrentTrade.liquidityID=PendingTrade.liquidityID;
   CurrentTrade.orderType=PendingTrade.orderType;
   CurrentTrade.entry=result.price;
   CurrentTrade.stopLoss=PendingTrade.stopLoss;
   CurrentTrade.takeProfit=PendingTrade.takeProfit;
   CurrentTrade.lots=PendingTrade.lotSize;
   CurrentTrade.stage=TRADE_ACTIVE;
   CurrentTrade.openTime=TimeCurrent();

   CurrentTrade.breakEvenDone=false;
   CurrentTrade.partial1Done=false;
   CurrentTrade.partial2Done=false;
   CurrentTrade.trailingActive=false;

   return true;
}

//----------------------------------------------------------
// Trade Management Controller
//----------------------------------------------------------
void ManageActiveTrade()
{
   if(!CurrentTrade.active)
      return;

   if(!PositionSelectByTicket(CurrentTrade.ticket))
   {
      CurrentTrade.active=false;
      CurrentTrade.stage=TRADE_CLOSED;
      return;
   }

   ManageBreakEven();

   ManagePartialTakeProfit();

   ManageTrailingStop();

   ManageDynamicTakeProfit();

   ManageEmergencyExit();

   UpdateTradeStatistics();
}

//----------------------------------------------------------
// Break Even Manager
//----------------------------------------------------------
void ManageBreakEven()
{
   if(CurrentTrade.breakEvenDone)
      return;

   if(!EnableBreakEven)
      return;

   double entry=CurrentTrade.entry;

   double sl=CurrentTrade.stopLoss;

   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   double risk=MathAbs(entry-sl);

   if(CurrentTrade.orderType==ORDER_TYPE_BUY)
   {
      if(bid>=entry+risk)
      {
         ModifyPositionSL(CurrentTrade.ticket,
                          entry,
                          CurrentTrade.takeProfit);

         CurrentTrade.breakEvenDone=true;

         CurrentTrade.stage=TRADE_BREAK_EVEN;
      }
   }
   else
   {
      if(ask<=entry-risk)
      {
         ModifyPositionSL(CurrentTrade.ticket,
                          entry,
                          CurrentTrade.takeProfit);

         CurrentTrade.breakEvenDone=true;

         CurrentTrade.stage=TRADE_BREAK_EVEN;
      }
   }
}

//----------------------------------------------------------
// Partial Take Profit Manager
//----------------------------------------------------------
void ManagePartialTakeProfit()
{
   if(!EnablePartialTakeProfit)
      return;

   if(!PositionSelectByTicket(CurrentTrade.ticket))
      return;

   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   double entry=CurrentTrade.entry;
   double stop =CurrentTrade.stopLoss;

   double risk=MathAbs(entry-stop);

   double rr=0.0;

   if(CurrentTrade.orderType==ORDER_TYPE_BUY)
      rr=(bid-entry)/risk;
   else
      rr=(entry-ask)/risk;

   //--------------------------------------------------
   // TP1
   //--------------------------------------------------
   if(!CurrentTrade.partial1Done)
   {
      if(rr>=1.0)
      {
         ClosePartialPosition(CurrentTrade.ticket,
                              TP1_ClosePercent);

         CurrentTrade.partial1Done=true;

         CurrentTrade.stage=TRADE_PARTIAL_1;

         return;
      }
   }

   //--------------------------------------------------
   // TP2
   //--------------------------------------------------
   if(!CurrentTrade.partial2Done)
   {
      if(rr>=2.0)
      {
         ClosePartialPosition(CurrentTrade.ticket,
                              TP2_ClosePercent);

         CurrentTrade.partial2Done=true;

         CurrentTrade.stage=TRADE_PARTIAL_2;

         return;
      }
   }
}


//----------------------------------------------------------
// Professional ICT Trailing Stop
//----------------------------------------------------------
void ManageTrailingStop()
{
   if(!EnableTrailingStop)
      return;

   if(!PositionSelectByTicket(CurrentTrade.ticket))
      return;

   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);

   double newSL = currentSL;

   //--------------------------------------------------
   // BUY Positions
   //--------------------------------------------------
   if(CurrentTrade.orderType==ORDER_TYPE_BUY)
   {
      double swingLow = GetLatestProtectedSwingLow();

      if(swingLow<=0)
         return;

      double atr = GetATRValue();

      newSL = swingLow - (atr * ATRStopMultiplier);

      if(newSL > currentSL)
      {
         ModifyPositionSL(CurrentTrade.ticket,
                          NormalizeDouble(newSL,_Digits),
                          currentTP);

         CurrentTrade.trailingActive=true;
         CurrentTrade.stage=TRADE_TRAILING;
      }
   }

   //--------------------------------------------------
   // SELL Positions
   //--------------------------------------------------
   else
   {
      double swingHigh = GetLatestProtectedSwingHigh();

      if(swingHigh<=0)
         return;

      double atr = GetATRValue();

      newSL = swingHigh + (atr * ATRStopMultiplier);

      if(currentSL==0 || newSL < currentSL)
      {
         ModifyPositionSL(CurrentTrade.ticket,
                          NormalizeDouble(newSL,_Digits),
                          currentTP);

         CurrentTrade.trailingActive=true;
         CurrentTrade.stage=TRADE_TRAILING;
      }
   }
}


//----------------------------------------------------------
// Dynamic Exit Manager
//----------------------------------------------------------
void ManageDynamicTakeProfit()
{
   if(!PositionSelectByTicket(CurrentTrade.ticket))
      return;

   //--------------------------------------------------
   // Trade already protected?
   //--------------------------------------------------
   if(!CurrentTrade.breakEvenDone)
      return;

   //--------------------------------------------------
   // Strong opposite ICT pattern
   //--------------------------------------------------
   if(OppositePatternConfirmed(CurrentTrade.orderType))
   {
      CloseEntirePosition(CurrentTrade.ticket);

      CurrentTrade.stage = TRADE_CLOSED;

      return;
   }

   //--------------------------------------------------
   // Market structure failure
   //--------------------------------------------------
   if(PositionStructureInvalid(CurrentTrade.orderType))
   {
      CloseEntirePosition(CurrentTrade.ticket);

      CurrentTrade.stage = TRADE_CLOSED;

      return;
   }

   //--------------------------------------------------
   // Momentum completely exhausted
   //--------------------------------------------------
   if(MomentumExhausted(CurrentTrade.orderType))
   {
      CloseEntirePosition(CurrentTrade.ticket);

      CurrentTrade.stage = TRADE_CLOSED;

      return;
   }
}

//----------------------------------------------------------
// Emergency Protection
//----------------------------------------------------------
void ManageEmergencyExit()
{
   if(!PositionSelectByTicket(CurrentTrade.ticket))
      return;

   //--------------------------------------------------
   // Spread explosion
   //--------------------------------------------------
   if(CurrentSpreadPoints() > MaxSpreadPoints * 2)
      return;

   //--------------------------------------------------
   // Trading disabled
   //--------------------------------------------------
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return;

   //--------------------------------------------------
   // Account protection
   //--------------------------------------------------
   if(GetDailyLossPercent() >= DailyMaxLossPercent)
   {
      CloseEntirePosition(CurrentTrade.ticket);

      CurrentTrade.stage = TRADE_CLOSED;

      return;
   }

   //--------------------------------------------------
   // Margin protection
   //--------------------------------------------------
   if(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < 120.0)
   {
      CloseEntirePosition(CurrentTrade.ticket);

      CurrentTrade.stage = TRADE_CLOSED;

      return;
   }
}


//----------------------------------------------------------
// Update Trade Statistics
//----------------------------------------------------------
void UpdateTradeStatistics()
{
   if(PositionSelectByTicket(CurrentTrade.ticket))
      return;

   CurrentTrade.active = false;

   CurrentTrade.stage = TRADE_CLOSED;

   ExecutionStatus = EXECUTION_IDLE;

   ResetPendingTrade();
}

//----------------------------------------------------------
// Find Active Trade By Pattern
//----------------------------------------------------------
bool FindTradeByPattern(const ulong patternID)
{
   if(!CurrentTrade.active)
      return false;

   if(CurrentTrade.patternID != patternID)
      return false;

   if(!PositionSelectByTicket(CurrentTrade.ticket))
      return false;

   return true;
}

//----------------------------------------------------------
// Is Pattern Still Active
//----------------------------------------------------------
bool PatternOwnsTrade(const ulong patternID)
{
   return FindTradeByPattern(patternID);
}

//----------------------------------------------------------
// Release Pattern Ownership
//----------------------------------------------------------
void ReleaseTradeOwnership()
{
   CurrentTrade.patternID   = 0;
   CurrentTrade.liquidityID = 0;
}

//----------------------------------------------------------
// Trade Lifecycle
//----------------------------------------------------------
void ProcessTradeEngine()
{
   //--------------------------------------------------
   // Execute New Trade
   //--------------------------------------------------
   if(ExecutionStatus == EXECUTION_PENDING)
   {
      ExecuteTrade();
   }

   //--------------------------------------------------
   // Manage Existing Trade
   //--------------------------------------------------
   if(CurrentTrade.active)
   {
      ManageActiveTrade();
   }

   //--------------------------------------------------
   // Cleanup
   //--------------------------------------------------
   if(!CurrentTrade.active &&
      ExecutionStatus != EXECUTION_IDLE)
   {
      UpdateTradeStatistics();

      ReleaseTradeOwnership();
   }
}












