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
       bar<=endBar;
       bar++)
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
       bar<=endBar;
       bar++)
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
// SECTION 18 - INSTITUTIONAL ORDER BLOCK ENGINE
//====================================================

//----------------------------------------------------
// Inputs
//----------------------------------------------------

input bool RequireOrderBlock=true;

input double MaximumOrderBlockATR=2.0;

input double MinimumOrderBlockBodyPercent=50.0;

input bool RequireFVGAfterOrderBlock=true;

//----------------------------------------------------
// Order Block
//----------------------------------------------------

struct OrderBlock
{
   bool valid;

   bool confirmed;

   ENUM_DIRECTION direction;

   double high;

   double low;

   double midpoint;

   double size;

   double score;

   datetime creationTime;

   int creationBar;

   int displacementBar;

   bool mitigated;

   bool invalidated;

   int touchCount;
};

OrderBlock
OrderBlockData[ACTIVE_SCAN_TIMEFRAMES];

//----------------------------------------------------
// Reset Order Block
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
// Order Block Size
//----------------------------------------------------

bool ValidOrderBlockSize(
   ENUM_TIMEFRAMES tf,
   double high,
   double low)
{
   double atr=
      GetATR(tf);

   if(atr<=0)
      return false;

   return
      MathAbs(high-low)
      <=
      atr*
      MaximumOrderBlockATR;
}

//----------------------------------------------------
// Strong Body
//----------------------------------------------------

bool StrongOrderBlockBody(
   ENUM_TIMEFRAMES tf,
   int bar)
{
   return
      CandleBodyPercent(
         tf,
         bar)
      >=
      MinimumOrderBlockBodyPercent;
}


//----------------------------------------------------
// Bullish Order Block
//----------------------------------------------------

bool BullishOrderBlock(
   ENUM_TIMEFRAMES tf,
   int bar,
   double &high,
   double &low)
{
   if(iClose(_Symbol,tf,bar)
      >=
      iOpen(_Symbol,tf,bar))
      return false;

   high=
      iHigh(_Symbol,tf,bar);

   low=
      iLow(_Symbol,tf,bar);

   if(!ValidOrderBlockSize(
      tf,
      high,
      low))
      return false;

   if(!StrongOrderBlockBody(
      tf,
      bar))
      return false;

   return true;
}

//----------------------------------------------------
// Bearish Order Block
//----------------------------------------------------

bool BearishOrderBlock(
   ENUM_TIMEFRAMES tf,
   int bar,
   double &high,
   double &low)
{
   if(iClose(_Symbol,tf,bar)
      <=
      iOpen(_Symbol,tf,bar))
      return false;

   high=
      iHigh(_Symbol,tf,bar);

   low=
      iLow(_Symbol,tf,bar);

   if(!ValidOrderBlockSize(
      tf,
      high,
      low))
      return false;

   if(!StrongOrderBlockBody(
      tf,
      bar))
      return false;

   return true;
}

//----------------------------------------------------
// Detect Institutional Order Block
//----------------------------------------------------

bool DetectOrderBlock(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return false;

   ResetOrderBlock(tf);

   //-----------------------------------------
   // Must have confirmed displacement
   //-----------------------------------------

   if(!DisplacementConfirmed(tf))
      return false;

   //-----------------------------------------
   // Must have confirmed FVG
   //-----------------------------------------

   if(RequireFVGAfterOrderBlock)
   {
      if(!FVGData[idx].valid)
         return false;
   }

   double high,low;

   double bestScore=-1.0;

   double bestHigh=0.0;
   double bestLow=0.0;

   int bestBar=-1;

   //-----------------------------------------
   // Search before displacement
   //-----------------------------------------

   for(int bar=2; bar<=8; bar++)
   {
      //--------------------------------------
      // Bullish
      //--------------------------------------

      if(StructureDirection(tf)
         ==
         DIRECTION_BULLISH)
      {
         if(BullishOrderBlock(
            tf,
            bar,
            high,
            low))
         {
            double score=
               CalculateOrderBlockScore(
                  tf,
                  high,
                  low,
                  bar);

            if(score>bestScore)
            {
               bestScore=score;

               bestHigh=high;
               bestLow=low;

               bestBar=bar;
            }
         }
      }

      //--------------------------------------
      // Bearish
      //--------------------------------------

      if(StructureDirection(tf)
         ==
         DIRECTION_BEARISH)
      {
         if(BearishOrderBlock(
            tf,
            bar,
            high,
            low))
         {
            double score=
               CalculateOrderBlockScore(
                  tf,
                  high,
                  low,
                  bar);

            if(score>bestScore)
            {
               bestScore=score;

               bestHigh=high;
               bestLow=low;

               bestBar=bar;
            }
         }
      }
   }

   if(bestBar==-1)
      return false;

   //-----------------------------------------
   // Save Order Block
   //-----------------------------------------

   OrderBlockData[idx].valid=true;

   OrderBlockData[idx].confirmed=true;

   OrderBlockData[idx].direction=
      StructureDirection(tf);

   OrderBlockData[idx].high=
      bestHigh;

   OrderBlockData[idx].low=
      bestLow;

   OrderBlockData[idx].midpoint=
      (bestHigh+bestLow)/2.0;

   OrderBlockData[idx].size=
      MathAbs(bestHigh-bestLow);

   OrderBlockData[idx].creationBar=
      bestBar;

   OrderBlockData[idx].displacementBar=1;

   OrderBlockData[idx].creationTime=
      iTime(_Symbol,tf,bestBar);

   OrderBlockData[idx].score=
      bestScore;

   return true;
}

//----------------------------------------------------
// Order Block Score
//----------------------------------------------------

double CalculateOrderBlockScore(
   ENUM_TIMEFRAMES tf,
   double high,
   double low,
   int bar)
{
   double score=0.0;

   //-----------------------------------------
   // Body Strength
   //-----------------------------------------

   score+=
      CandleBodyPercent(
         tf,
         bar)
      *0.30;

   //-----------------------------------------
   // Close Strength
   //-----------------------------------------

   score+=
      CandleClosePercent(
         tf,
         bar)
      *0.20;

   //-----------------------------------------
   // Freshness
   //-----------------------------------------

   score+=
      MathMax(
         20-(bar*2),
         0);

   //-----------------------------------------
   // Size
   //-----------------------------------------

   double atr=
      GetATR(tf);

   if(atr>0)
   {
      score+=
      MathMin(
         (MathAbs(high-low)/atr)
         *30,
         30);
   }

   return
      MathMin(score,100.0);
}

//----------------------------------------------------
// Update Order Block
//----------------------------------------------------

void UpdateOrderBlock(
   ENUM_TIMEFRAMES tf)
{
   int idx=
      StructureIndex(tf);

   if(idx<0)
      return;

   if(!OrderBlockData[idx].valid)
      return;

   double price=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID);

   //--------------------------------------

   if(price<=OrderBlockData[idx].high &&
      price>=OrderBlockData[idx].low)
   {
      OrderBlockData[idx].mitigated=true;

      OrderBlockData[idx].touchCount++;
   }

   //--------------------------------------

   if(StructureDirection(tf)
      ==
      DIRECTION_BULLISH)
   {
      if(price<
         OrderBlockData[idx].low)
      {
         OrderBlockData[idx].invalidated=true;
      }
   }
   else
   {
      if(price>
         OrderBlockData[idx].high)
      {
         OrderBlockData[idx].invalidated=true;
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
      DetectOrderBlock(
         StructureTF[i]);

      UpdateOrderBlock(
         StructureTF[i]);
   }
}




//====================================================
// SECTION 19 - ORDER BLOCK DATABASE ENGINE
//====================================================

#define MAX_ORDERBLOCKS 100

OrderBlock OrderBlockDatabase[MAX_ORDERBLOCKS];

int TotalOrderBlocks = 0;

//----------------------------------------------------

void ResetOrderBlockDatabase()
{
   TotalOrderBlocks = 0;

   for(int i=0;i<MAX_ORDERBLOCKS;i++)
      ZeroMemory(OrderBlockDatabase[i]);
}

//----------------------------------------------------

void AddOrderBlock(OrderBlock ob)
{
   if(!ob.valid)
      return;

   if(TotalOrderBlocks >= MAX_ORDERBLOCKS)
   {
      for(int i=1;i<MAX_ORDERBLOCKS;i++)
         OrderBlockDatabase[i-1] =
            OrderBlockDatabase[i];

      TotalOrderBlocks =
         MAX_ORDERBLOCKS-1;
   }

   OrderBlockDatabase[TotalOrderBlocks] = ob;

   TotalOrderBlocks++;
}

//----------------------------------------------------

void UpdateOrderBlockTouches()
{
   double bid =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID);

   for(int i=0;i<TotalOrderBlocks;i++)
   {
      if(!OrderBlockDatabase[i].valid)
         continue;

      if(bid >= OrderBlockDatabase[i].low &&
         bid <= OrderBlockDatabase[i].high)
      {
         OrderBlockDatabase[i].touches++;
      }
   }
}

//----------------------------------------------------

void UpdateOrderBlockMitigation()
{
   double bid =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID);

   for(int i=0;i<TotalOrderBlocks;i++)
   {
      if(!OrderBlockDatabase[i].valid)
         continue;

      if(OrderBlockDatabase[i].direction ==
         OB_BULLISH)
      {
         if(bid <
            OrderBlockDatabase[i].low)
         {
            OrderBlockDatabase[i].mitigated = true;
         }
      }

      if(OrderBlockDatabase[i].direction ==
         OB_BEARISH)
      {
         if(bid >
            OrderBlockDatabase[i].high)
         {
            OrderBlockDatabase[i].mitigated = true;
         }
      }
   }
}

//----------------------------------------------------

void RemoveMitigatedOrderBlocks()
{
   for(int i=0;i<TotalOrderBlocks;)
   {
      if(OrderBlockDatabase[i].mitigated)
      {
         for(int j=i+1;j<TotalOrderBlocks;j++)
            OrderBlockDatabase[j-1] =
               OrderBlockDatabase[j];

         TotalOrderBlocks--;

         continue;
      }

      i++;
   }
}

//----------------------------------------------------

int BestBullishOrderBlock()
{
   int index = -1;

   double bestScore = -1;

   for(int i=0;i<TotalOrderBlocks;i++)
   {
      if(!OrderBlockDatabase[i].valid)
         continue;

      if(OrderBlockDatabase[i].direction !=
         OB_BULLISH)
         continue;

      if(OrderBlockDatabase[i].score >
         bestScore)
      {
         bestScore =
            OrderBlockDatabase[i].score;

         index = i;
      }
   }

   return index;
}

//----------------------------------------------------

int BestBearishOrderBlock()
{
   int index = -1;

   double bestScore = -1;

   for(int i=0;i<TotalOrderBlocks;i++)
   {
      if(!OrderBlockDatabase[i].valid)
         continue;

      if(OrderBlockDatabase[i].direction !=
         OB_BEARISH)
         continue;

      if(OrderBlockDatabase[i].score >
         bestScore)
      {
         bestScore =
            OrderBlockDatabase[i].score;

         index = i;
      }
   }

   return index;
}

//----------------------------------------------------

bool SelectBestBullishOrderBlock()
{
   int idx =
      BestBullishOrderBlock();

   if(idx < 0)
      return false;

   CurrentOrderBlock =
      OrderBlockDatabase[idx];

   return true;
}

//----------------------------------------------------

bool SelectBestBearishOrderBlock()
{
   int idx =
      BestBearishOrderBlock();

   if(idx < 0)
      return false;

   CurrentOrderBlock =
      OrderBlockDatabase[idx];

   return true;
}

//----------------------------------------------------

void UpdateOrderBlockDatabase()
{
   UpdateOrderBlock();

   if(CurrentOrderBlock.valid)
      AddOrderBlock(CurrentOrderBlock);

   UpdateOrderBlockTouches();

   UpdateOrderBlockMitigation();

   RemoveMitigatedOrderBlocks();
}


//====================================================
// SECTION 20 - MARKET STRUCTURE ENGINE
//====================================================

enum ENUM_STRUCTURE_EVENT
{
   STRUCTURE_NONE = 0,

   STRUCTURE_BOS,

   STRUCTURE_MSS,

   STRUCTURE_CHOCH
};

struct MarketStructure
{
   bool valid;

   ENUM_STRUCTURE_EVENT event;

   ENUM_TREND direction;

   double breakPrice;

   datetime breakTime;

   double score;

   bool displacementConfirmed;

   bool liquidityConfirmed;
};

MarketStructure CurrentStructure;

input bool EnableStructureFilter = true;

input int MinimumStructureScore = 75;

//----------------------------------------------------

void ResetStructure()
{
   ZeroMemory(CurrentStructure);

   CurrentStructure.event =
      STRUCTURE_NONE;

   CurrentStructure.direction =
      TREND_NONE;
}

//----------------------------------------------------

bool DetectBullishBOS()
{
   SwingPoint latestHigh;

   if(!GetLatestSwingHigh(latestHigh))
      return false;

   double close =
      iClose(_Symbol,
             PERIOD_CURRENT,
             1);

   if(close <= latestHigh.price)
      return false;

   CurrentStructure.valid = true;

   CurrentStructure.event =
      STRUCTURE_BOS;

   CurrentStructure.direction =
      TREND_UP;

   CurrentStructure.breakPrice =
      latestHigh.price;

   CurrentStructure.breakTime =
      TimeCurrent();

   return true;
}

//----------------------------------------------------

bool DetectBearishBOS()
{
   SwingPoint latestLow;

   if(!GetLatestSwingLow(latestLow))
      return false;

   double close =
      iClose(_Symbol,
             PERIOD_CURRENT,
             1);

   if(close >= latestLow.price)
      return false;

   CurrentStructure.valid = true;

   CurrentStructure.event =
      STRUCTURE_BOS;

   CurrentStructure.direction =
      TREND_DOWN;

   CurrentStructure.breakPrice =
      latestLow.price;

   CurrentStructure.breakTime =
      TimeCurrent();

   return true;
}

//----------------------------------------------------

bool DetectBullishMSS()
{
   if(CurrentTrend != TREND_DOWN)
      return false;

   if(!DetectBullishBOS())
      return false;

   CurrentStructure.event =
      STRUCTURE_MSS;

   return true;
}

//----------------------------------------------------

bool DetectBearishMSS()
{
   if(CurrentTrend != TREND_UP)
      return false;

   if(!DetectBearishBOS())
      return false;

   CurrentStructure.event =
      STRUCTURE_MSS;

   return true;
}

//----------------------------------------------------

bool DetectBullishCHoCH()
{
   if(!DetectBullishMSS())
      return false;

   CurrentStructure.event =
      STRUCTURE_CHOCH;

   return true;
}

//----------------------------------------------------

bool DetectBearishCHoCH()
{
   if(!DetectBearishMSS())
      return false;

   CurrentStructure.event =
      STRUCTURE_CHOCH;

   return true;
}

//----------------------------------------------------

double StructureDisplacementScore()
{
   if(CurrentDisplacementScore >= 90)
      return 35;

   if(CurrentDisplacementScore >= 80)
      return 30;

   if(CurrentDisplacementScore >= 70)
      return 25;

   if(CurrentDisplacementScore >= 60)
      return 15;

   return 0;
}

//----------------------------------------------------

double StructureLiquidityScore()
{
   if(IsBullishLiquiditySweep() ||
      IsBearishLiquiditySweep())
      return 30;

   return 0;
}

//----------------------------------------------------

double StructureTrendScore()
{
   if(CurrentTrendStrength >= 80)
      return 35;

   if(CurrentTrendStrength >= 70)
      return 25;

   if(CurrentTrendStrength >= 60)
      return 15;

   return 0;
}

//----------------------------------------------------

double CalculateStructureScore()
{
   double score = 0;

   score += StructureDisplacementScore();

   score += StructureLiquidityScore();

   score += StructureTrendScore();

   return MathMin(score,100.0);
}

//----------------------------------------------------

void UpdateMarketStructure()
{
   ResetStructure();

   DetectBullishCHoCH();

   DetectBearishCHoCH();

   DetectBullishBOS();

   DetectBearishBOS();

   if(CurrentStructure.valid)
   {
      CurrentStructure.score =
         CalculateStructureScore();

      CurrentStructure.displacementConfirmed =
         (CurrentDisplacementScore >= 70);

      CurrentStructure.liquidityConfirmed =
         (IsBullishLiquiditySweep() ||
          IsBearishLiquiditySweep());
   }
}

//----------------------------------------------------

bool ValidStructure()
{
   if(!CurrentStructure.valid)
      return false;

   if(CurrentStructure.score <
      MinimumStructureScore)
      return false;

   return true;
}


//====================================================
// SECTION 21 - MARKET STRUCTURE MATRIX ENGINE
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




//====================================================
// SECTION 22 - LIQUIDITY ENGINE
//====================================================

//----------------------------------------------------
// Liquidity Types
//----------------------------------------------------

enum ENUM_LIQUIDITY_TYPE
{
   LIQ_NONE = 0,

   LIQ_EQUAL_HIGHS,
   LIQ_EQUAL_LOWS,

   LIQ_BUY_SIDE,
   LIQ_SELL_SIDE,

   LIQ_INTERNAL,
   LIQ_EXTERNAL,

   LIQ_SWEEP_BUY,
   LIQ_SWEEP_SELL
};

//----------------------------------------------------
// Liquidity State
//----------------------------------------------------

enum ENUM_LIQUIDITY_STATE
{
   LIQ_STATE_IDLE = 0,
   LIQ_STATE_BUILDING,
   LIQ_STATE_SWEPT,
   LIQ_STATE_CONFIRMED
};

//----------------------------------------------------
// Liquidity Zone
//----------------------------------------------------

struct LiquidityZone
{
   bool valid;

   ENUM_LIQUIDITY_TYPE type;

   ENUM_TIMEFRAMES timeframe;

   double high;

   double low;

   double midpoint;

   datetime created;

   datetime sweptTime;

   bool swept;

   bool internal;

   bool external;

   int touches;

   double strength;

   double score;
};

//----------------------------------------------------
// Liquidity Database
//----------------------------------------------------

#define MAX_LIQUIDITY_ZONES 300

LiquidityZone LiquidityDatabase[MAX_LIQUIDITY_ZONES];

int TotalLiquidityZones = 0;

//----------------------------------------------------
// Current Active Liquidity
//----------------------------------------------------

LiquidityZone CurrentLiquidity;

//----------------------------------------------------
// Inputs
//----------------------------------------------------

input bool EnableLiquidityEngine = true;

input int EqualHighLowTolerancePoints = 10;

input int MinimumLiquidityScore = 75;

input int LiquidityLookbackBars = 200;

input bool RequireLiquiditySweep = true;

input bool EnableInternalLiquidity = true;

input bool EnableExternalLiquidity = true;

//----------------------------------------------------
// Reset Current Liquidity
//----------------------------------------------------

void ResetLiquidity()
{
   ZeroMemory(CurrentLiquidity);

   CurrentLiquidity.valid = false;

   CurrentLiquidity.type = LIQ_NONE;
}

//----------------------------------------------------
// Initialize Database
//----------------------------------------------------

void InitializeLiquidityDatabase()
{
   TotalLiquidityZones = 0;

   for(int i=0;i<MAX_LIQUIDITY_ZONES;i++)
      ZeroMemory(LiquidityDatabase[i]);
}

//----------------------------------------------------
// Add Liquidity Zone
//----------------------------------------------------

void AddLiquidityZone(LiquidityZone zone)
{
   if(!zone.valid)
      return;

   if(TotalLiquidityZones >= MAX_LIQUIDITY_ZONES)
   {
      for(int i=1;i<MAX_LIQUIDITY_ZONES;i++)
         LiquidityDatabase[i-1]=LiquidityDatabase[i];

      TotalLiquidityZones=MAX_LIQUIDITY_ZONES-1;
   }

   LiquidityDatabase[TotalLiquidityZones]=zone;

   TotalLiquidityZones++;
}

//----------------------------------------------------
// Equal High Detection
//----------------------------------------------------

bool DetectEqualHighs()
{
   int tolerance=EqualHighLowTolerancePoints;

   for(int i=5;i<LiquidityLookbackBars;i++)
   {
      double high1=iHigh(_Symbol,PERIOD_CURRENT,i);

      for(int j=i+2;j<LiquidityLookbackBars;j++)
      {
         double high2=iHigh(_Symbol,PERIOD_CURRENT,j);

         if(MathAbs(high1-high2)<=tolerance*_Point)
         {
            ResetLiquidity();

            CurrentLiquidity.valid=true;
            CurrentLiquidity.type=LIQ_EQUAL_HIGHS;
            CurrentLiquidity.timeframe=PERIOD_CURRENT;

            CurrentLiquidity.high=
               MathMax(high1,high2);

            CurrentLiquidity.low=
               MathMin(high1,high2);

            CurrentLiquidity.midpoint=
               (CurrentLiquidity.high+
                CurrentLiquidity.low)/2.0;

            CurrentLiquidity.created=
               TimeCurrent();

            CurrentLiquidity.touches=2;

            AddLiquidityZone(CurrentLiquidity);

            return true;
         }
      }
   }

   return false;
}

//----------------------------------------------------
// Equal Low Detection
//----------------------------------------------------

bool DetectEqualLows()
{
   int tolerance=EqualHighLowTolerancePoints;

   for(int i=5;i<LiquidityLookbackBars;i++)
   {
      double low1=iLow(_Symbol,PERIOD_CURRENT,i);

      for(int j=i+2;j<LiquidityLookbackBars;j++)
      {
         double low2=iLow(_Symbol,PERIOD_CURRENT,j);

         if(MathAbs(low1-low2)<=tolerance*_Point)
         {
            ResetLiquidity();

            CurrentLiquidity.valid=true;
            CurrentLiquidity.type=LIQ_EQUAL_LOWS;
            CurrentLiquidity.timeframe=PERIOD_CURRENT;

            CurrentLiquidity.high=
               MathMax(low1,low2);

            CurrentLiquidity.low=
               MathMin(low1,low2);

            CurrentLiquidity.midpoint=
               (CurrentLiquidity.high+
                CurrentLiquidity.low)/2.0;

            CurrentLiquidity.created=
               TimeCurrent();

            CurrentLiquidity.touches=2;

            AddLiquidityZone(CurrentLiquidity);

            return true;
         }
      }
   }

   return false;
}

//----------------------------------------------------
// Buy Side Liquidity
//----------------------------------------------------

bool DetectBuySideLiquidity()
{
   if(!DetectEqualHighs())
      return false;

   CurrentLiquidity.type=LIQ_BUY_SIDE;

   return true;
}

//----------------------------------------------------
// Sell Side Liquidity
//----------------------------------------------------

bool DetectSellSideLiquidity()
{
   if(!DetectEqualLows())
      return false;

   CurrentLiquidity.type=LIQ_SELL_SIDE;

   return true;
}

//----------------------------------------------------
// Internal Liquidity
//----------------------------------------------------

bool DetectInternalLiquidity()
{
   if(!EnableInternalLiquidity)
      return false;

   double recentHigh=
      iHigh(_Symbol,PERIOD_CURRENT,5);

   double previousHigh=
      iHigh(_Symbol,PERIOD_CURRENT,20);

   if(recentHigh<previousHigh)
   {
      CurrentLiquidity.internal=true;
      return true;
   }

   double recentLow=
      iLow(_Symbol,PERIOD_CURRENT,5);

   double previousLow=
      iLow(_Symbol,PERIOD_CURRENT,20);

   if(recentLow>previousLow)
   {
      CurrentLiquidity.internal=true;
      return true;
   }

   return false;
}

//----------------------------------------------------
// External Liquidity
//----------------------------------------------------

bool DetectExternalLiquidity()
{
   if(!EnableExternalLiquidity)
      return false;

   double highest=
      iHigh(_Symbol,PERIOD_CURRENT,
      iHighest(_Symbol,
               PERIOD_CURRENT,
               MODE_HIGH,
               LiquidityLookbackBars,
               1));

   double lowest=
      iLow(_Symbol,PERIOD_CURRENT,
      iLowest(_Symbol,
              PERIOD_CURRENT,
              MODE_LOW,
              LiquidityLookbackBars,
              1));

   double bid=
      SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(bid>=highest || bid<=lowest)
   {
      CurrentLiquidity.external=true;
      return true;
   }

   return false;
}

//----------------------------------------------------
// Bullish Liquidity Sweep
// (Sell-side liquidity taken)
//----------------------------------------------------

bool DetectBullishLiquiditySweep()
{
   if(!DetectSellSideLiquidity())
      return false;

   double previousLow=iLow(_Symbol,PERIOD_CURRENT,2);
   double currentLow=iLow(_Symbol,PERIOD_CURRENT,1);
   double currentClose=iClose(_Symbol,PERIOD_CURRENT,1);

   if(currentLow>=previousLow)
      return false;

   if(currentClose<=previousLow)
      return false;

   CurrentLiquidity.swept=true;
   CurrentLiquidity.sweptTime=TimeCurrent();
   CurrentLiquidity.type=LIQ_SWEEP_SELL;

   return true;
}

//----------------------------------------------------
// Bearish Liquidity Sweep
// (Buy-side liquidity taken)
//----------------------------------------------------

bool DetectBearishLiquiditySweep()
{
   if(!DetectBuySideLiquidity())
      return false;

   double previousHigh=iHigh(_Symbol,PERIOD_CURRENT,2);
   double currentHigh=iHigh(_Symbol,PERIOD_CURRENT,1);
   double currentClose=iClose(_Symbol,PERIOD_CURRENT,1);

   if(currentHigh<=previousHigh)
      return false;

   if(currentClose>=previousHigh)
      return false;

   CurrentLiquidity.swept=true;
   CurrentLiquidity.sweptTime=TimeCurrent();
   CurrentLiquidity.type=LIQ_SWEEP_BUY;

   return true;
}

//----------------------------------------------------
// Liquidity Freshness Score
//----------------------------------------------------

double LiquidityFreshnessScore(datetime created)
{
   double age=
      (TimeCurrent()-created)/60.0;

   if(age<=30)
      return 30;

   if(age<=120)
      return 25;

   if(age<=360)
      return 20;

   if(age<=720)
      return 15;

   return 10;
}

//----------------------------------------------------
// Touch Score
//----------------------------------------------------

double LiquidityTouchScore(int touches)
{
   if(touches>=5)
      return 30;

   if(touches==4)
      return 25;

   if(touches==3)
      return 20;

   if(touches==2)
      return 15;

   return 5;
}

//----------------------------------------------------
// Sweep Score
//----------------------------------------------------

double LiquiditySweepScore()
{
   if(CurrentLiquidity.swept)
      return 40;

   return 0;
}

//----------------------------------------------------
// Internal / External Score
//----------------------------------------------------

double LiquidityPositionScore()
{
   double score=0;

   if(CurrentLiquidity.internal)
      score+=15;

   if(CurrentLiquidity.external)
      score+=15;

   return score;
}

//----------------------------------------------------
// Calculate Overall Liquidity Score
//----------------------------------------------------

double CalculateLiquidityScore()
{
   double score=0;

   score+=LiquidityFreshnessScore(
      CurrentLiquidity.created);

   score+=LiquidityTouchScore(
      CurrentLiquidity.touches);

   score+=LiquiditySweepScore();

   score+=LiquidityPositionScore();

   if(score>100)
      score=100;

   CurrentLiquidity.score=score;

   return score;
}

//----------------------------------------------------
// Valid Liquidity
//----------------------------------------------------

bool ValidLiquidity()
{
   if(!CurrentLiquidity.valid)
      return false;

   if(CurrentLiquidity.score<
      MinimumLiquidityScore)
      return false;

   return true;
}

//----------------------------------------------------
// Update Current Liquidity
//----------------------------------------------------

void UpdateLiquidity()
{
   ResetLiquidity();

   DetectBullishLiquiditySweep();

   DetectBearishLiquiditySweep();

   DetectInternalLiquidity();

   DetectExternalLiquidity();

   if(CurrentLiquidity.valid)
   {
      CurrentLiquidity.score=
         CalculateLiquidityScore();

      AddLiquidityZone(CurrentLiquidity);
   }
}


//----------------------------------------------------
// Is Duplicate Liquidity Zone
//----------------------------------------------------

bool IsDuplicateLiquidityZone(LiquidityZone zone)
{
   for(int i=0;i<TotalLiquidityZones;i++)
   {
      if(!LiquidityDatabase[i].valid)
         continue;

      if(LiquidityDatabase[i].type!=zone.type)
         continue;

      if(MathAbs(
         LiquidityDatabase[i].midpoint-
         zone.midpoint)<=(_Point*5))
      {
         return true;
      }
   }

   return false;
}

//----------------------------------------------------
// Save Liquidity Zone
//----------------------------------------------------

void SaveLiquidityZone(LiquidityZone zone)
{
   if(!zone.valid)
      return;

   if(IsDuplicateLiquidityZone(zone))
      return;

   AddLiquidityZone(zone);
}

//----------------------------------------------------
// Mark Mitigated Liquidity
//----------------------------------------------------

void UpdateLiquidityMitigation()
{
   double bid=
      SymbolInfoDouble(_Symbol,SYMBOL_BID);

   for(int i=0;i<TotalLiquidityZones;i++)
   {
      if(!LiquidityDatabase[i].valid)
         continue;

      if(LiquidityDatabase[i].swept)
         continue;

      if(bid<=LiquidityDatabase[i].high &&
         bid>=LiquidityDatabase[i].low)
      {
         LiquidityDatabase[i].swept=true;
         LiquidityDatabase[i].sweptTime=
            TimeCurrent();
      }
   }
}

//----------------------------------------------------
// Remove Old Liquidity
//----------------------------------------------------

void CleanLiquidityDatabase()
{
   datetime now=TimeCurrent();

   for(int i=0;i<TotalLiquidityZones;i++)
   {
      if(!LiquidityDatabase[i].valid)
         continue;

      if((now-
         LiquidityDatabase[i].created)>
         (7*24*60*60))
      {
         LiquidityDatabase[i].valid=false;
      }
   }
}

//----------------------------------------------------
// Best Liquidity Zone
//----------------------------------------------------

LiquidityZone GetBestLiquidityZone()
{
   LiquidityZone best;

   ZeroMemory(best);

   double bestScore=0;

   for(int i=0;i<TotalLiquidityZones;i++)
   {
      if(!LiquidityDatabase[i].valid)
         continue;

      if(LiquidityDatabase[i].score>
         bestScore)
      {
         bestScore=
            LiquidityDatabase[i].score;

         best=
            LiquidityDatabase[i];
      }
   }

   return best;
}

//----------------------------------------------------
// Highest Liquidity Score
//----------------------------------------------------

double HighestLiquidityScore()
{
   double score=0;

   for(int i=0;i<TotalLiquidityZones;i++)
   {
      if(!LiquidityDatabase[i].valid)
         continue;

      if(LiquidityDatabase[i].score>score)
         score=
            LiquidityDatabase[i].score;
   }

   return score;
}

//----------------------------------------------------
// Has Valid Liquidity
//----------------------------------------------------

bool HasValidLiquidity()
{
   LiquidityZone zone=
      GetBestLiquidityZone();

   if(!zone.valid)
      return false;

   return
      zone.score>=MinimumLiquidityScore;
}

//----------------------------------------------------
// Current Liquidity Direction
//----------------------------------------------------

ENUM_DIRECTION LiquidityDirection()
{
   LiquidityZone zone=
      GetBestLiquidityZone();

   switch(zone.type)
   {
      case LIQ_SWEEP_SELL:
         return DIRECTION_BULLISH;

      case LIQ_SWEEP_BUY:
         return DIRECTION_BEARISH;

      default:
         return DIRECTION_NONE;
   }
}

//----------------------------------------------------
// Master Liquidity Update
//----------------------------------------------------

void UpdateLiquidityEngine()
{
   if(!EnableLiquidityEngine)
      return;

   UpdateLiquidity();

   UpdateLiquidityMitigation();

   CleanLiquidityDatabase();

   CurrentLiquidity=
      GetBestLiquidityZone();
}



//====================================================
// SECTION 23 - PREMIUM / DISCOUNT ENGINE
//====================================================

//----------------------------------------------------
// Premium / Discount State
//----------------------------------------------------

enum ENUM_PD_STATE
{
   PD_UNKNOWN = 0,
   PD_PREMIUM,
   PD_EQUILIBRIUM,
   PD_DISCOUNT
};

//----------------------------------------------------
// Premium Discount Profile
//----------------------------------------------------

struct PremiumDiscountProfile
{
   bool valid;

   ENUM_TIMEFRAMES timeframe;

   ENUM_PD_STATE state;

   double dealingHigh;
   double dealingLow;

   double equilibrium;

   double premiumStart;
   double discountEnd;

   double fib50;
   double fib618;
   double fib705;
   double fib79;

   double oteHigh;
   double oteLow;

   double currentPrice;

   double confidence;

   datetime lastUpdate;
};

PremiumDiscountProfile PDProfile;

//----------------------------------------------------
// Inputs
//----------------------------------------------------

input bool EnablePremiumDiscount = true;

input bool EnableOTEFilter = true;

input double MinimumPDConfidence = 70.0;

//----------------------------------------------------
// Reset
//----------------------------------------------------

void ResetPremiumDiscount()
{
   ZeroMemory(PDProfile);

   PDProfile.valid=false;
   PDProfile.state=PD_UNKNOWN;
}


//----------------------------------------------------
// Highest Swing
//----------------------------------------------------

double GetDealingRangeHigh()
{
   double highest=iHigh(
      _Symbol,
      PERIOD_CURRENT,
      iHighest(
         _Symbol,
         PERIOD_CURRENT,
         MODE_HIGH,
         100,
         1));

   return highest;
}

//----------------------------------------------------
// Lowest Swing
//----------------------------------------------------

double GetDealingRangeLow()
{
   double lowest=iLow(
      _Symbol,
      PERIOD_CURRENT,
      iLowest(
         _Symbol,
         PERIOD_CURRENT,
         MODE_LOW,
         100,
         1));

   return lowest;
}


//----------------------------------------------------
// Structure Based Dealing Range
//----------------------------------------------------

bool BuildStructureDealingRange()
{
   PDProfile.valid=false;

   // Require confirmed structure
   if(CurrentDirection==DIRECTION_NONE)
      return false;

   double highest=-DBL_MAX;
   double lowest= DBL_MAX;

   bool found=false;

   //------------------------------------------------
   // Search recent confirmed swings
   //------------------------------------------------

   int bars=MathMin(Bars(_Symbol,PERIOD_CURRENT),
                    LiquidityLookbackBars);

   for(int i=2;i<bars;i++)
   {
      double high=iHigh(_Symbol,PERIOD_CURRENT,i);
      double low =iLow(_Symbol,PERIOD_CURRENT,i);

      if(high>highest)
         highest=high;

      if(low<lowest)
         lowest=low;

      found=true;
   }

   if(!found)
      return false;

   if(highest<=lowest)
      return false;

   PDProfile.dealingHigh=highest;
   PDProfile.dealingLow =lowest;

   double range=
      highest-lowest;

   PDProfile.equilibrium=
      lowest+(range*0.50);

   //------------------------------------------------
   // Bullish Fib Levels
   //------------------------------------------------

   PDProfile.fib50=
      lowest+(range*0.50);

   PDProfile.fib618=
      lowest+(range*0.618);

   PDProfile.fib705=
      lowest+(range*0.705);

   PDProfile.fib79=
      lowest+(range*0.79);

   //------------------------------------------------
   // OTE Zone
   //------------------------------------------------

   PDProfile.oteLow=
      PDProfile.fib618;

   PDProfile.oteHigh=
      PDProfile.fib79;

   PDProfile.discountEnd=
      PDProfile.fib50;

   PDProfile.premiumStart=
      PDProfile.fib50;

   PDProfile.currentPrice=
      SymbolInfoDouble(_Symbol,SYMBOL_BID);

   PDProfile.timeframe=
      PERIOD_CURRENT;

   PDProfile.lastUpdate=
      TimeCurrent();

   PDProfile.valid=true;

   return true;
}



//----------------------------------------------------
// Determine Premium / Discount
//----------------------------------------------------

void CalculatePremiumDiscountState()
{
   if(PDProfile.currentPrice>
      PDProfile.equilibrium)
   {
      PDProfile.state=
         PD_PREMIUM;
   }
   else
   if(PDProfile.currentPrice<
      PDProfile.equilibrium)
   {
      PDProfile.state=
         PD_DISCOUNT;
   }
   else
   {
      PDProfile.state=
         PD_EQUILIBRIUM;
   }

   PDProfile.valid=true;

   PDProfile.lastUpdate=
      TimeCurrent();
}

//----------------------------------------------------
// Is Premium
//----------------------------------------------------

bool IsPremium()
{
   return
      PDProfile.state==
      PD_PREMIUM;
}

//----------------------------------------------------
// Is Discount
//----------------------------------------------------

bool IsDiscount()
{
   return
      PDProfile.state==
      PD_DISCOUNT;
}

//----------------------------------------------------
// Is Equilibrium
//----------------------------------------------------

bool IsEquilibrium()
{
   return
      PDProfile.state==
      PD_EQUILIBRIUM;
}

//----------------------------------------------------
// Bullish OTE
//----------------------------------------------------

bool InBullishOTE()
{
   if(!PDProfile.valid)
      return false;

   double price=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID);

   return(
      price>=PDProfile.oteLow &&
      price<=PDProfile.oteHigh
   );
}

//----------------------------------------------------
// Bearish OTE
//----------------------------------------------------

bool InBearishOTE()
{
   if(!PDProfile.valid)
      return false;

   double price=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID);

   double upper=
      PDProfile.dealingHigh-
      (PDProfile.dealingHigh-
      PDProfile.dealingLow)*0.618;

   double lower=
      PDProfile.dealingHigh-
      (PDProfile.dealingHigh-
      PDProfile.dealingLow)*0.79;

   return(
      price<=upper &&
      price>=lower
   );
}

//----------------------------------------------------
// Liquidity Confidence
//----------------------------------------------------

double LiquidityConfidence()
{
   if(!HasValidLiquidity())
      return 0;

   return HighestLiquidityScore();
}

//----------------------------------------------------
// Structure Confidence
//----------------------------------------------------

double StructureConfidence()
{
   return StructureAgreementScore();
}

//----------------------------------------------------
// OTE Confidence
//----------------------------------------------------

double OTEConfidence()
{
   double score=0;

   if(InBullishOTE())
      score=100;

   if(InBearishOTE())
      score=100;

   return score;
}

//----------------------------------------------------
// Premium Discount Confidence
//----------------------------------------------------

void CalculatePDConfidence()
{
   double score=0;

   score+=LiquidityConfidence()*0.35;

   score+=StructureConfidence()*0.40;

   score+=OTEConfidence()*0.25;

   PDProfile.confidence=
      MathMin(score,100.0);
}

//----------------------------------------------------
// Premium Discount Valid
//----------------------------------------------------

bool PremiumDiscountValid()
{
   if(!PDProfile.valid)
      return false;

   if(PDProfile.confidence<
      MinimumPDConfidence)
      return false;

   return true;
}

//----------------------------------------------------
// Update Premium Discount Engine
//----------------------------------------------------

void UpdatePremiumDiscountEngine()
{
   if(!EnablePremiumDiscount)
      return;

   ResetPremiumDiscount();

   if(!BuildStructureDealingRange())
      return;

   CalculatePremiumDiscountState();

   CalculatePDConfidence();
}

//----------------------------------------------------
// Bullish Premium Discount Filter
//----------------------------------------------------

bool BullishPDFilter()
{
   if(!PremiumDiscountValid())
      return false;

   if(!IsDiscount())
      return false;

   if(EnableOTEFilter &&
      !InBullishOTE())
      return false;

   return true;
}

//----------------------------------------------------
// Bearish Premium Discount Filter
//----------------------------------------------------

bool BearishPDFilter()
{
   if(!PremiumDiscountValid())
      return false;

   if(!IsPremium())
      return false;

   if(EnableOTEFilter &&
      !InBearishOTE())
      return false;

   return true;
}

//----------------------------------------------------
// Premium Discount Direction
//----------------------------------------------------

ENUM_DIRECTION PremiumDiscountDirection()
{
   if(BullishPDFilter())
      return DIRECTION_BULLISH;

   if(BearishPDFilter())
      return DIRECTION_BEARISH;

   return DIRECTION_NONE;
}




//====================================================
// SECTION 24 - ICT BREAD & BUTTER ENGINE
//====================================================

//----------------------------------------------------
// Bread & Butter State
//----------------------------------------------------

enum ENUM_BNB_STATE
{
   BNB_WAIT_LIQUIDITY = 0,

   BNB_WAIT_SWEEP,

   BNB_WAIT_STRUCTURE,

   BNB_WAIT_DISPLACEMENT,

   BNB_WAIT_FVG,

   BNB_WAIT_PREMIUM_DISCOUNT,

   BNB_WAIT_RETRACEMENT,

   BNB_READY,

   BNB_EXECUTED,

   BNB_INVALID
};

//----------------------------------------------------
// Bread & Butter Setup
//----------------------------------------------------

struct BreadButterSetup
{
   bool valid;

   ENUM_DIRECTION direction;

   ENUM_BNB_STATE state;

   ENUM_TIMEFRAMES timeframe;

   double confidence;

   double entry;

   double stopLoss;

   double takeProfit;

   double riskReward;

   datetime created;

   datetime confirmed;

   bool liquidityConfirmed;

   bool sweepConfirmed;

   bool structureConfirmed;

   bool displacementConfirmed;

   bool fvgConfirmed;

   bool pdConfirmed;

   bool retracementConfirmed;

   bool executed;
};

BreadButterSetup BreadButter;

//----------------------------------------------------
// Inputs
//----------------------------------------------------

input bool EnableBreadButterEngine = true;

input double MinimumBreadButterConfidence = 85.0;

input int SetupTimeoutBars = 15;

//----------------------------------------------------
// Reset Setup
//----------------------------------------------------

void ResetBreadButter()
{
   ZeroMemory(BreadButter);

   BreadButter.valid=false;

   BreadButter.state=
      BNB_WAIT_LIQUIDITY;
}

//----------------------------------------------------
// Step 1
//----------------------------------------------------

bool BreadButterLiquidity()
{
   if(!HasValidLiquidity())
      return false;

   BreadButter.liquidityConfirmed=true;

   BreadButter.direction=
      LiquidityDirection();

   BreadButter.state=
      BNB_WAIT_SWEEP;

   return true;
}

//----------------------------------------------------
// Step 2
//----------------------------------------------------

bool BreadButterSweep()
{
   if(BreadButter.state!=BNB_WAIT_SWEEP)
      return false;

   if(CurrentLiquidity.swept==false)
      return false;

   BreadButter.sweepConfirmed=true;

   BreadButter.state=
      BNB_WAIT_STRUCTURE;

   return true;
}

//----------------------------------------------------
// Step 3
//----------------------------------------------------

bool BreadButterStructure()
{
   if(BreadButter.state!=
      BNB_WAIT_STRUCTURE)
      return false;

   if(!StructureReady())
      return false;

   if(BreadButter.direction!=
      StructureState.direction)
      return false;

   BreadButter.structureConfirmed=true;

   BreadButter.state=
      BNB_WAIT_DISPLACEMENT;

   return true;
}

//----------------------------------------------------
// Step 4
//----------------------------------------------------

bool BreadButterDisplacement()
{
   if(BreadButter.state!=BNB_WAIT_DISPLACEMENT)
      return false;

   // Existing Displacement Engine
   if(!ValidDisplacement())
      return false;

   // Direction must agree
   if(DisplacementDirection()!=
      BreadButter.direction)
      return false;

   BreadButter.displacementConfirmed=true;

   BreadButter.state=
      BNB_WAIT_FVG;

   return true;
}

//----------------------------------------------------
// Step 5
//----------------------------------------------------

bool BreadButterFVG()
{
   if(BreadButter.state!=BNB_WAIT_FVG)
      return false;

   if(!CurrentFVG.valid)
      return false;

   //------------------------------------------------
   // Bullish Setup
   //------------------------------------------------

   if(BreadButter.direction==
      DIRECTION_BULLISH)
   {
      if(CurrentFVG.type!=
         FVG_BULLISH)
         return false;
   }

   //------------------------------------------------
   // Bearish Setup
   //------------------------------------------------

   if(BreadButter.direction==
      DIRECTION_BEARISH)
   {
      if(CurrentFVG.type!=
         FVG_BEARISH)
         return false;
   }

   BreadButter.fvgConfirmed=true;

   BreadButter.state=
      BNB_WAIT_PREMIUM_DISCOUNT;

   return true;
}

//----------------------------------------------------
// Step 6
//----------------------------------------------------

bool BreadButterPremiumDiscount()
{
   if(BreadButter.state!=
      BNB_WAIT_PREMIUM_DISCOUNT)
      return false;

   //------------------------------------------------
   // Bullish
   //------------------------------------------------

   if(BreadButter.direction==
      DIRECTION_BULLISH)
   {
      if(!BullishPDFilter())
         return false;
   }

   //------------------------------------------------
   // Bearish
   //------------------------------------------------

   if(BreadButter.direction==
      DIRECTION_BEARISH)
   {
      if(!BearishPDFilter())
         return false;
   }

   BreadButter.pdConfirmed=true;

   BreadButter.state=
      BNB_WAIT_RETRACEMENT;

   return true;
}

//----------------------------------------------------
// Step 7
//----------------------------------------------------

bool BreadButterRetracement()
{
   if(BreadButter.state!=
      BNB_WAIT_RETRACEMENT)
      return false;

   double bid=
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID);

   //------------------------------------------------
   // Bullish
   //------------------------------------------------

   if(BreadButter.direction==
      DIRECTION_BULLISH)
   {
      if(bid>
         CurrentFVG.high)
         return false;
   }

   //------------------------------------------------
   // Bearish
   //------------------------------------------------

   if(BreadButter.direction==
      DIRECTION_BEARISH)
   {
      if(bid<
         CurrentFVG.low)
         return false;
   }

   BreadButter.retracementConfirmed=true;

   BreadButter.state=
      BNB_READY;

   BreadButter.confirmed=
      TimeCurrent();

   return true;
}

//----------------------------------------------------
// Bread & Butter Confidence
//----------------------------------------------------

void CalculateBreadButterConfidence()
{
   double score=0;

   if(BreadButter.liquidityConfirmed)
      score+=15;

   if(BreadButter.sweepConfirmed)
      score+=15;

   if(BreadButter.structureConfirmed)
      score+=20;

   if(BreadButter.displacementConfirmed)
      score+=15;

   if(BreadButter.fvgConfirmed)
      score+=15;

   if(BreadButter.pdConfirmed)
      score+=10;

   if(BreadButter.retracementConfirmed)
      score+=10;

   BreadButter.confidence=
      MathMin(score,100.0);

   BreadButter.valid=
      (BreadButter.confidence>=
      MinimumBreadButterConfidence);
}

//----------------------------------------------------
// Setup Creation Bar
//----------------------------------------------------

int BreadButterStartBar = -1;

//----------------------------------------------------
// Start Tracking Setup
//----------------------------------------------------

void StartBreadButterSetup()
{
   BreadButterStartBar =
      iBars(_Symbol,PERIOD_CURRENT);
}

//----------------------------------------------------
// Setup Age
//----------------------------------------------------

int BreadButterAge()
{
   if(BreadButterStartBar<0)
      return 0;

   return
      BreadButterStartBar-
      iBars(_Symbol,PERIOD_CURRENT);
}

//----------------------------------------------------
// Setup Expired
//----------------------------------------------------

bool BreadButterExpired()
{
   int age=
      MathAbs(
         BreadButterAge());

   return
      age>=SetupTimeoutBars;
}

//----------------------------------------------------
// Reset Entire Setup
//----------------------------------------------------

void InvalidateBreadButter()
{
   ResetBreadButter();

   BreadButterStartBar=-1;
}

//----------------------------------------------------
// Opposite Structure
//----------------------------------------------------

bool OppositeStructureDetected()
{
   if(!StructureReady())
      return false;

   if(BreadButter.direction==
      DIRECTION_BULLISH &&
      StructureState.direction==
      DIRECTION_BEARISH)
      return true;

   if(BreadButter.direction==
      DIRECTION_BEARISH &&
      StructureState.direction==
      DIRECTION_BULLISH)
      return true;

   return false;
}

//----------------------------------------------------
// Opposite Liquidity Sweep
//----------------------------------------------------

bool OppositeLiquiditySweep()
{
   if(!CurrentLiquidity.valid)
      return false;

   if(BreadButter.direction==
      DIRECTION_BULLISH &&
      CurrentLiquidity.type==
      LIQ_SWEEP_BUY)
      return true;

   if(BreadButter.direction==
      DIRECTION_BEARISH &&
      CurrentLiquidity.type==
      LIQ_SWEEP_SELL)
      return true;

   return false;
}

//----------------------------------------------------
// Prevent Reusing Same FVG
//----------------------------------------------------

datetime LastUsedFVGTime=0;

bool FreshFVG()
{
   if(!CurrentFVG.valid)
      return false;

   if(CurrentFVG.created==
      LastUsedFVGTime)
      return false;

   return true;
}

void LockCurrentFVG()
{
   LastUsedFVGTime=
      CurrentFVG.created;
}

//----------------------------------------------------
// Validate Existing Setup
//----------------------------------------------------

void ValidateBreadButterSetup()
{
   if(BreadButter.state==
      BNB_WAIT_LIQUIDITY)
      return;

   //----------------------------------

   if(BreadButterExpired())
   {
      InvalidateBreadButter();
      return;
   }

   //----------------------------------

   if(OppositeStructureDetected())
   {
      InvalidateBreadButter();
      return;
   }

   //----------------------------------

   if(OppositeLiquiditySweep())
   {
      InvalidateBreadButter();
      return;
   }

   //----------------------------------

   if(!FreshFVG())
   {
      InvalidateBreadButter();
      return;
   }
}

//----------------------------------------------------
// Bread & Butter Engine
//----------------------------------------------------

void UpdateBreadButterEngine()
{
   if(!EnableBreadButterEngine)
      return;

   ValidateBreadButterSetup();

   switch(BreadButter.state)
   {
      case BNB_WAIT_LIQUIDITY:

         if(BreadButterLiquidity())
            StartBreadButterSetup();

         break;

      case BNB_WAIT_SWEEP:

         BreadButterSweep();
         break;

      case BNB_WAIT_STRUCTURE:

         BreadButterStructure();
         break;

      case BNB_WAIT_DISPLACEMENT:

         BreadButterDisplacement();
         break;

      case BNB_WAIT_FVG:

         BreadButterFVG();
         break;

      case BNB_WAIT_PREMIUM_DISCOUNT:

         BreadButterPremiumDiscount();
         break;

      case BNB_WAIT_RETRACEMENT:

         BreadButterRetracement();
         break;

      default:
         break;
   }

   CalculateBreadButterConfidence();
}

//----------------------------------------------------
// Timeframe Index
//----------------------------------------------------

enum ENUM_BNB_TIMEFRAME
{
   BNB_M5 = 0,
   BNB_M15,
   BNB_H1,
   BNB_TOTAL
};

//----------------------------------------------------
// One Setup Per Timeframe
//----------------------------------------------------

BreadButterSetup BreadButterTF[BNB_TOTAL];

int BreadButterStartBarTF[BNB_TOTAL];

//----------------------------------------------------
// Timeframe Mapping
//----------------------------------------------------

ENUM_TIMEFRAMES BreadButterTimeframes[BNB_TOTAL]=
{
   PERIOD_M5,
   PERIOD_M15,
   PERIOD_H1
};

//----------------------------------------------------
// Timeframe Name
//----------------------------------------------------

string BreadButterTFName(int index)
{
   switch(index)
   {
      case BNB_M5:
         return "M5";

      case BNB_M15:
         return "M15";

      case BNB_H1:
         return "H1";
   }

   return "";
}

//----------------------------------------------------
// Reset Timeframe Setup
//----------------------------------------------------

void ResetBreadButterTF(int tf)
{
   ZeroMemory(BreadButterTF[tf]);

   BreadButterTF[tf].state=
      BNB_WAIT_LIQUIDITY;

   BreadButterTF[tf].timeframe=
      BreadButterTimeframes[tf];

   BreadButterStartBarTF[tf]=-1;
}

//----------------------------------------------------
// Initialize Bread Butter
//----------------------------------------------------

void InitializeBreadButterEngine()
{
   for(int tf=0;tf<BNB_TOTAL;tf++)
      ResetBreadButterTF(tf);
}

//----------------------------------------------------
// Highest Confidence Setup
//----------------------------------------------------

int BestBreadButterSetup()
{
   double best=0;

   int index=-1;

   for(int tf=0;tf<BNB_TOTAL;tf++)
   {
      if(!BreadButterTF[tf].valid)
         continue;

      if(BreadButterTF[tf].state!=
         BNB_READY)
         continue;

      if(BreadButterTF[tf].confidence>
         best)
      {
         best=
            BreadButterTF[tf].confidence;

         index=tf;
      }
   }

   return index;
}


//----------------------------------------------------
// Execution Priority
//----------------------------------------------------

int ExecutionPriority()
{
   int best=
      BestBreadButterSetup();

   if(best>=0)
      return best;

   return -1;
}

//----------------------------------------------------
// Update Every Timeframe
//----------------------------------------------------

void UpdateBreadButterScanner()
{
   if(TradeM5)
   {
      // M5 scanner
   }

   if(TradeM15)
   {
      // M15 scanner
   }

   if(TradeH1)
   {
      // H1 scanner
   }
}






