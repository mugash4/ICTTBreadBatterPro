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
// SECTION 9 - SESSION INTELLIGENCE ENGINE (Part 2)
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
// SECTION 10 - MARKET CLASSIFICATION ENGINE (Part 1)
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
// SECTION 12 - ADVANCED SWING DETECTION ENGINE
//====================================================

enum ENUM_SWING_TYPE
{
   SWING_NONE = 0,

   SWING_HIGH,

   SWING_LOW
};

//----------------------------------------------------

struct SwingPoint
{
   datetime time;

   double price;

   int index;

   ENUM_SWING_TYPE type;

   bool strong;

   bool protectedSwing;

   bool liquidityTaken;

   bool valid;
};

//----------------------------------------------------

SwingPoint LatestSwingHigh;

SwingPoint PreviousSwingHigh;

SwingPoint LatestSwingLow;

SwingPoint PreviousSwingLow;
//----------------------------------------------------

bool IsSwingHigh(
   ENUM_TIMEFRAMES tf,
   int shift
)
{
   double candidate =
      iHigh(_Symbol,tf,shift);

   for(int i=1;i<=3;i++)
   {
      if(iHigh(_Symbol,tf,shift+i)>=candidate)
         return false;

      if(iHigh(_Symbol,tf,shift-i)>candidate)
         return false;
   }

   return true;
}

//----------------------------------------------------

bool IsSwingLow(
   ENUM_TIMEFRAMES tf,
   int shift
)
{
   double candidate =
      iLow(_Symbol,tf,shift);

   for(int i=1;i<=3;i++)
   {
      if(iLow(_Symbol,tf,shift+i)<=candidate)
         return false;

      if(iLow(_Symbol,tf,shift-i)<candidate)
         return false;
   }

   return true;
}

//----------------------------------------------------

bool FindLatestSwingHigh(
   ENUM_TIMEFRAMES tf,
   SwingPoint &swing
)
{
   swing.valid=false;

   for(int i=5;i<300;i++)
   {
      if(IsSwingHigh(tf,i))
      {
         swing.valid=true;

         swing.price=
            iHigh(_Symbol,tf,i);

         swing.time=
            iTime(_Symbol,tf,i);

         swing.index=i;

         swing.type=SWING_HIGH;

         return true;
      }
   }

   return false;
}

//----------------------------------------------------

bool FindLatestSwingLow(
   ENUM_TIMEFRAMES tf,
   SwingPoint &swing
)
{
   swing.valid=false;

   for(int i=5;i<300;i++)
   {
      if(IsSwingLow(tf,i))
      {
         swing.valid=true;

         swing.price=
            iLow(_Symbol,tf,i);

         swing.time=
            iTime(_Symbol,tf,i);

         swing.index=i;

         swing.type=SWING_LOW;

         return true;
      }
   }

   return false;
}

//----------------------------------------------------

bool IsStrongSwingHigh(
   SwingPoint swing
)
{
   if(!swing.valid)
      return false;

   double atr =
      GetATR();

   if(atr<=0)
      return false;

   double move =
      swing.price -
      iLow(
         _Symbol,
         PERIOD_CURRENT,
         swing.index
      );

   return move>=atr;
}

//----------------------------------------------------

bool IsStrongSwingLow(
   SwingPoint swing
)
{
   if(!swing.valid)
      return false;

   double atr=
      GetATR();

   if(atr<=0)
      return false;

   double move=
      iHigh(
         _Symbol,
         PERIOD_CURRENT,
         swing.index
      )
      -
      swing.price;

   return move>=atr;
}

//----------------------------------------------------

void UpdateSwingEngine()
{
   FindLatestSwingHigh(
      PERIOD_CURRENT,
      LatestSwingHigh
   );

   FindLatestSwingLow(
      PERIOD_CURRENT,
      LatestSwingLow
   );

   LatestSwingHigh.strong =
      IsStrongSwingHigh(
         LatestSwingHigh
      );

   LatestSwingLow.strong =
      IsStrongSwingLow(
         LatestSwingLow
      );
}

//----------------------------------------------------

bool HigherHigh()
{
   if(!LatestSwingHigh.valid ||
      !PreviousSwingHigh.valid)
      return false;

   return
      LatestSwingHigh.price >
      PreviousSwingHigh.price;
}

//----------------------------------------------------

bool LowerLow()
{
   if(!LatestSwingLow.valid ||
      !PreviousSwingLow.valid)
      return false;

   return
      LatestSwingLow.price <
      PreviousSwingLow.price;
}

//----------------------------------------------------

bool HigherLow()
{
   if(!LatestSwingLow.valid ||
      !PreviousSwingLow.valid)
      return false;

   return
      LatestSwingLow.price >
      PreviousSwingLow.price;
}

//----------------------------------------------------

bool LowerHigh()
{
   if(!LatestSwingHigh.valid ||
      !PreviousSwingHigh.valid)
      return false;

   return
      LatestSwingHigh.price <
      PreviousSwingHigh.price;
}

//----------------------------------------------------
// Swing History Storage
//----------------------------------------------------

#define MAX_SWINGS 20

SwingPoint SwingHighs[MAX_SWINGS];

SwingPoint SwingLows[MAX_SWINGS];

int SwingHighCount=0;

int SwingLowCount=0;

//----------------------------------------------------

void ResetSwingHistory()
{
   SwingHighCount=0;

   SwingLowCount=0;

   ArrayInitialize(SwingHighs,0);

   ArrayInitialize(SwingLows,0);
}

//----------------------------------------------------

void AddSwingHigh(SwingPoint swing)
{
   if(!swing.valid)
      return;

   if(SwingHighCount<MAX_SWINGS)
   {
      SwingHighs[SwingHighCount]=swing;

      SwingHighCount++;

      return;
   }

   for(int i=0;i<MAX_SWINGS-1;i++)
      SwingHighs[i]=SwingHighs[i+1];

   SwingHighs[MAX_SWINGS-1]=swing;
}

//----------------------------------------------------

void AddSwingLow(SwingPoint swing)
{
   if(!swing.valid)
      return;

   if(SwingLowCount<MAX_SWINGS)
   {
      SwingLows[SwingLowCount]=swing;

      SwingLowCount++;

      return;
   }

   for(int i=0;i<MAX_SWINGS-1;i++)
      SwingLows[i]=SwingLows[i+1];

   SwingLows[MAX_SWINGS-1]=swing;
}


//----------------------------------------------------

void RefreshSwingHistory()
{
   SwingPoint swing;

   if(FindLatestSwingHigh(PERIOD_CURRENT,swing))
   {
      if(SwingHighCount==0 ||
         SwingHighs[SwingHighCount-1].time!=swing.time)
      {
         AddSwingHigh(swing);
      }
   }

   if(FindLatestSwingLow(PERIOD_CURRENT,swing))
   {
      if(SwingLowCount==0 ||
         SwingLows[SwingLowCount-1].time!=swing.time)
      {
         AddSwingLow(swing);
      }
   }
}

//----------------------------------------------------

SwingPoint GetSwingHigh(int index)
{
   SwingPoint empty;

   ZeroMemory(empty);

   if(index<0 || index>=SwingHighCount)
      return empty;

   return SwingHighs[SwingHighCount-1-index];
}

//----------------------------------------------------

SwingPoint GetSwingLow(int index)
{
   SwingPoint empty;

   ZeroMemory(empty);

   if(index<0 || index>=SwingLowCount)
      return empty;

   return SwingLows[SwingLowCount-1-index];
}

//----------------------------------------------------

void UpdateSwingEngine()
{
   RefreshSwingHistory();

   if(SwingHighCount>=2)
   {
      LatestSwingHigh=
         GetSwingHigh(0);

      PreviousSwingHigh=
         GetSwingHigh(1);
   }

   if(SwingLowCount>=2)
   {
      LatestSwingLow=
         GetSwingLow(0);

      PreviousSwingLow=
         GetSwingLow(1);
   }

   LatestSwingHigh.strong=
      IsStrongSwingHigh(
         LatestSwingHigh
      );

   LatestSwingLow.strong=
      IsStrongSwingLow(
         LatestSwingLow
      );
}


//====================================================
// SECTION 13 - MARKET STRUCTURE ENGINE
//====================================================

enum ENUM_STRUCTURE
{
   STRUCTURE_UNKNOWN = 0,

   STRUCTURE_BULLISH,

   STRUCTURE_BEARISH
};

enum ENUM_STRUCTURE_EVENT
{
   EVENT_NONE = 0,

   EVENT_BOS,

   EVENT_CHOCH,

   EVENT_MSS
};

//----------------------------------------------------

ENUM_STRUCTURE CurrentStructure =
   STRUCTURE_UNKNOWN;

ENUM_STRUCTURE_EVENT LastStructureEvent =
   EVENT_NONE;

//----------------------------------------------------

bool BullishBreakOfStructure()
{
   if(SwingHighCount < 2)
      return false;

   double currentPrice =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID
      );

   return
      currentPrice >
      LatestSwingHigh.price;
}

//----------------------------------------------------

bool BearishBreakOfStructure()
{
   if(SwingLowCount < 2)
      return false;

   double currentPrice =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID
      );

   return
      currentPrice <
      LatestSwingLow.price;
}


//----------------------------------------------------

bool BullishCHOCH()
{
   if(CurrentStructure !=
      STRUCTURE_BEARISH)
      return false;

   return
      BullishBreakOfStructure();
}

//----------------------------------------------------

bool BearishCHOCH()
{
   if(CurrentStructure !=
      STRUCTURE_BULLISH)
      return false;

   return
      BearishBreakOfStructure();
}

//----------------------------------------------------

bool BullishMSS()
{
   if(!HigherHigh())
      return false;

   if(!HigherLow())
      return false;

   return
      BullishBreakOfStructure();
}

//----------------------------------------------------

bool BearishMSS()
{
   if(!LowerLow())
      return false;

   if(!LowerHigh())
      return false;

   return
      BearishBreakOfStructure();
}

//----------------------------------------------------

void UpdateMarketStructure()
{
   LastStructureEvent =
      EVENT_NONE;

   if(BullishMSS() &&
      ConfirmedBullishBOS())
   {
      CurrentStructure =
         STRUCTURE_BULLISH;

      LastStructureEvent =
         EVENT_MSS;

      return;
   }

   if(BearishMSS() &&
      ConfirmedBearishBOS())
   {
      CurrentStructure =
         STRUCTURE_BEARISH;

      LastStructureEvent =
         EVENT_MSS;

      return;
   }

   if(BullishCHOCH() &&
      ConfirmedBullishBOS())
   {
      CurrentStructure =
         STRUCTURE_BULLISH;

      LastStructureEvent =
         EVENT_CHOCH;

      return;
   }

   if(BearishCHOCH() &&
      ConfirmedBearishBOS())
   {
      CurrentStructure =
         STRUCTURE_BEARISH;

      LastStructureEvent =
         EVENT_CHOCH;

      return;
   }

   if(ConfirmedBullishBOS())
   {
      CurrentStructure =
         STRUCTURE_BULLISH;

      LastStructureEvent =
         EVENT_BOS;

      return;
   }

   if(ConfirmedBearishBOS())
   {
      CurrentStructure =
         STRUCTURE_BEARISH;

      LastStructureEvent =
         EVENT_BOS;

      return;
   }
}

//----------------------------------------------------

bool BullishStructure()
{
   return
      CurrentStructure ==
      STRUCTURE_BULLISH;
}

//----------------------------------------------------

bool BearishStructure()
{
   return
      CurrentStructure ==
      STRUCTURE_BEARISH;
}

//----------------------------------------------------

bool StructureBullishBias()
{
   return
      BullishBias() &&
      BullishStructure();
}

//----------------------------------------------------

bool StructureBearishBias()
{
   return
      BearishBias() &&
      BearishStructure();
}

//----------------------------------------------------

string StructureText()
{
   switch(CurrentStructure)
   {
      case STRUCTURE_BULLISH:

         return "BULLISH";

      case STRUCTURE_BEARISH:

         return "BEARISH";

      default:

         return "UNKNOWN";
   }
}

//----------------------------------------------------

string StructureEventText()
{
   switch(LastStructureEvent)
   {
      case EVENT_BOS:

         return "BOS";

      case EVENT_CHOCH:

         return "CHoCH";

      case EVENT_MSS:

         return "MSS";

      default:

         return "-";
   }
}



//====================================================
// SECTION 14 - CONFIRMED STRUCTURE BREAK ENGINE
//====================================================

input bool EnableConfirmedBreaks = true;

input double BreakCloseATR = 0.20;

input double MinimumDisplacementATR = 1.20;

input bool RequireMomentumConfirmation = true;

input bool RequireBodyBreak = true;

//----------------------------------------------------

double CandleBodySize(int shift)
{
   return MathAbs(
      iClose(_Symbol,PERIOD_CURRENT,shift) -
      iOpen(_Symbol,PERIOD_CURRENT,shift)
   );
}

//----------------------------------------------------

double CandleRange(int shift)
{
   return
      iHigh(_Symbol,PERIOD_CURRENT,shift) -
      iLow(_Symbol,PERIOD_CURRENT,shift);
}

//----------------------------------------------------

bool StrongBullishDisplacement()
{
   double atr = GetATR();

   if(atr<=0)
      return false;

   if(!IsBullishCandle(1))
      return false;

   return
      CandleBodySize(1) >=
      atr * MinimumDisplacementATR;
}

//----------------------------------------------------

bool StrongBearishDisplacement()
{
   double atr = GetATR();

   if(atr<=0)
      return false;

   if(!IsBearishCandle(1))
      return false;

   return
      CandleBodySize(1) >=
      atr * MinimumDisplacementATR;
}

//----------------------------------------------------

bool BullishBreakConfirmed()
{
   if(!EnableConfirmedBreaks)
      return BullishBreakOfStructure();

   if(SwingHighCount<2)
      return false;

   double atr = GetATR();

   double close =
      iClose(_Symbol,PERIOD_CURRENT,1);

   if(close <
      LatestSwingHigh.price +
      atr*BreakCloseATR)
      return false;

   if(RequireBodyBreak)
   {
      double open =
         iOpen(_Symbol,PERIOD_CURRENT,1);

      if(open >
         LatestSwingHigh.price)
         return false;
   }

   if(RequireMomentumConfirmation)
   {
      if(!StrongBullishDisplacement())
         return false;
   }

   return true;
}

//----------------------------------------------------

bool BearishBreakConfirmed()
{
   if(!EnableConfirmedBreaks)
      return BearishBreakOfStructure();

   if(SwingLowCount<2)
      return false;

   double atr = GetATR();

   double close =
      iClose(_Symbol,PERIOD_CURRENT,1);

   if(close >
      LatestSwingLow.price -
      atr*BreakCloseATR)
      return false;

   if(RequireBodyBreak)
   {
      double open =
         iOpen(_Symbol,PERIOD_CURRENT,1);

      if(open <
         LatestSwingLow.price)
         return false;
   }

   if(RequireMomentumConfirmation)
   {
      if(!StrongBearishDisplacement())
         return false;
   }

   return true;
}

//----------------------------------------------------

bool ConfirmedBullishBOS()
{
   return
      BullishBreakConfirmed();
}

//----------------------------------------------------

bool ConfirmedBearishBOS()
{
   return
      BearishBreakConfirmed();
}


//====================================================
// SECTION 15 - INSTITUTIONAL DISPLACEMENT ENGINE
//====================================================

input bool EnableDisplacementFilter = true;

input int MinimumDisplacementScore = 75;

input bool EnableAdaptiveDisplacement = true;

//----------------------------------------------------

double CurrentDisplacementScore = 0.0;

//----------------------------------------------------

double BodyPercent(int shift)
{
   double range =
      CandleRange(shift);

   if(range<=0)
      return 0;

   return
      (CandleBodySize(shift)/range)*100.0;
}

//----------------------------------------------------

double UpperWick(int shift)
{
   return
      iHigh(_Symbol,PERIOD_CURRENT,shift)-
      MathMax(
         iOpen(_Symbol,PERIOD_CURRENT,shift),
         iClose(_Symbol,PERIOD_CURRENT,shift)
      );
}

//----------------------------------------------------

double LowerWick(int shift)
{
   return
      MathMin(
         iOpen(_Symbol,PERIOD_CURRENT,shift),
         iClose(_Symbol,PERIOD_CURRENT,shift)
      )-
      iLow(_Symbol,PERIOD_CURRENT,shift);
}

//----------------------------------------------------

double BodyStrengthScore()
{
   double percent =
      BodyPercent(1);

   if(percent>=90)
      return 25;

   if(percent>=80)
      return 22;

   if(percent>=70)
      return 18;

   if(percent>=60)
      return 12;

   return 0;
}

//----------------------------------------------------

double ATRExpansionScore()
{
   double atr=
      GetATR();

   if(atr<=0)
      return 0;

   double body=
      CandleBodySize(1);

   double ratio=
      body/atr;

   if(ratio>=2.5)
      return 25;

   if(ratio>=2.0)
      return 20;

   if(ratio>=1.5)
      return 15;

   if(ratio>=1.2)
      return 10;

   return 0;
}

//----------------------------------------------------

double ClosingStrengthScore()
{
   double range=
      CandleRange(1);

   if(range<=0)
      return 0;

   double close=
      iClose(_Symbol,PERIOD_CURRENT,1);

   double high=
      iHigh(_Symbol,PERIOD_CURRENT,1);

   double low=
      iLow(_Symbol,PERIOD_CURRENT,1);

   if(IsBullishCandle(1))
   {
      double position=
         (close-low)/range;

      if(position>=0.90)
         return 20;

      if(position>=0.80)
         return 15;

      if(position>=0.70)
         return 10;
   }

   if(IsBearishCandle(1))
   {
      double position=
         (high-close)/range;

      if(position>=0.90)
         return 20;

      if(position>=0.80)
         return 15;

      if(position>=0.70)
         return 10;
   }

   return 0;
}

//----------------------------------------------------

double WickQualityScore()
{
   double body=
      CandleBodySize(1);

   if(body<=0)
      return 0;

   double upper=
      UpperWick(1);

   double lower=
      LowerWick(1);

   double ratio=
      MathMax(upper,lower)/body;

   if(ratio<=0.10)
      return 15;

   if(ratio<=0.20)
      return 10;

   if(ratio<=0.30)
      return 5;

   return 0;
}


//----------------------------------------------------

double VolumeStrengthScore()
{
   long current=
      iVolume(_Symbol,PERIOD_CURRENT,1);

   double average=0;

   for(int i=2;i<=21;i++)
      average+=iVolume(
         _Symbol,
         PERIOD_CURRENT,
         i);

   average/=20.0;

   if(average<=0)
      return 0;

   double ratio=
      current/average;

   if(ratio>=2.0)
      return 15;

   if(ratio>=1.6)
      return 10;

   if(ratio>=1.3)
      return 5;

   return 0;
}

//----------------------------------------------------

double CalculateDisplacementScore()
{
   double score=0;

   score+=BodyStrengthScore();

   score+=ATRExpansionScore();

   score+=ClosingStrengthScore();

   score+=WickQualityScore();

   score+=VolumeStrengthScore();

   return
      MathMin(score,100.0);
}

//----------------------------------------------------

void UpdateDisplacementEngine()
{
   CurrentDisplacementScore=
      CalculateDisplacementScore();
}

//----------------------------------------------------

bool InstitutionalBullishDisplacement()
{
   if(!IsBullishCandle(1))
      return false;

   return
      CurrentDisplacementScore>=
      MinimumDisplacementScore;
}

//----------------------------------------------------

bool InstitutionalBearishDisplacement()
{
   if(!IsBearishCandle(1))
      return false;

   return
      CurrentDisplacementScore>=
      MinimumDisplacementScore;
}


//====================================================
// SECTION 16 - INSTITUTIONAL FAIR VALUE GAP ENGINE
//====================================================

enum ENUM_FVG_DIRECTION
{
   FVG_NONE = 0,

   FVG_BULLISH,

   FVG_BEARISH
};

struct FairValueGap
{
   bool valid;

   ENUM_FVG_DIRECTION direction;

   double upperPrice;

   double lowerPrice;

   double midpoint;

   double size;

   datetime created;

   bool mitigated;

   int touches;

   double score;
};

FairValueGap CurrentFVG;

//----------------------------------------------------

input bool EnableFVGFilter = true;

input int MinimumFVGScore = 70;

//----------------------------------------------------

void ResetFVG()
{
   ZeroMemory(CurrentFVG);

   CurrentFVG.direction = FVG_NONE;
}

//----------------------------------------------------

bool DetectBullishFVG()
{
   ResetFVG();

   double high1 =
      iHigh(_Symbol,PERIOD_CURRENT,3);

   double low3 =
      iLow(_Symbol,PERIOD_CURRENT,1);

   if(low3<=high1)
      return false;

   CurrentFVG.valid=true;

   CurrentFVG.direction=
      FVG_BULLISH;

   CurrentFVG.upperPrice=
      low3;

   CurrentFVG.lowerPrice=
      high1;

   CurrentFVG.midpoint=
      (low3+high1)/2.0;

   CurrentFVG.size=
      low3-high1;

   CurrentFVG.created=
      iTime(_Symbol,PERIOD_CURRENT,1);

   return true;
}

//----------------------------------------------------

bool DetectBearishFVG()
{
   ResetFVG();

   double low1 =
      iLow(_Symbol,PERIOD_CURRENT,3);

   double high3 =
      iHigh(_Symbol,PERIOD_CURRENT,1);

   if(high3>=low1)
      return false;

   CurrentFVG.valid=true;

   CurrentFVG.direction=
      FVG_BEARISH;

   CurrentFVG.upperPrice=
      low1;

   CurrentFVG.lowerPrice=
      high3;

   CurrentFVG.midpoint=
      (low1+high3)/2.0;

   CurrentFVG.size=
      low1-high3;

   CurrentFVG.created=
      iTime(_Symbol,PERIOD_CURRENT,1);

   return true;
}

//----------------------------------------------------

double FVGSizeScore()
{
   double atr=
      GetATR();

   if(atr<=0)
      return 0;

   double ratio=
      CurrentFVG.size/atr;

   if(ratio>=1.50)
      return 30;

   if(ratio>=1.20)
      return 25;

   if(ratio>=1.00)
      return 20;

   if(ratio>=0.70)
      return 15;

   return 5;
}

//----------------------------------------------------

double FVGDisplacementScore()
{
   if(CurrentDisplacementScore>=90)
      return 25;

   if(CurrentDisplacementScore>=80)
      return 20;

   if(CurrentDisplacementScore>=70)
      return 15;

   return 0;
}

//----------------------------------------------------

double FVGFreshnessScore()
{
   int bars=
      iBarShift(
         _Symbol,
         PERIOD_CURRENT,
         CurrentFVG.created
      );

   if(bars<=3)
      return 20;

   if(bars<=8)
      return 15;

   if(bars<=15)
      return 10;

   return 5;
}

//----------------------------------------------------

double FVGMitigationScore()
{
   if(CurrentFVG.touches==0)
      return 15;

   if(CurrentFVG.touches==1)
      return 10;

   if(CurrentFVG.touches==2)
      return 5;

   return 0;
}

//----------------------------------------------------

double CalculateFVGScore()
{
   double score=0;

   score+=FVGSizeScore();

   score+=FVGDisplacementScore();

   score+=FVGFreshnessScore();

   score+=FVGMitigationScore();

   return MathMin(score,100.0);
}

//----------------------------------------------------

void UpdateFVG()
{
   ResetFVG();

   if(DetectBullishFVG() ||
      DetectBearishFVG())
   {
      CurrentFVG.score=
         CalculateFVGScore();
   }
}

//----------------------------------------------------

bool ValidBullishFVG()
{
   return
      CurrentFVG.valid &&
      CurrentFVG.direction==
      FVG_BULLISH &&
      CurrentFVG.score>=
      MinimumFVGScore;
}

//----------------------------------------------------

bool ValidBearishFVG()
{
   return
      CurrentFVG.valid &&
      CurrentFVG.direction==
      FVG_BEARISH &&
      CurrentFVG.score>=
      MinimumFVGScore;
}



//====================================================
// SECTION 17 - FAIR VALUE GAP DATABASE ENGINE
//====================================================

#define MAX_FVGS 50

FairValueGap FVGDatabase[MAX_FVGS];

int TotalFVGs = 0;

//----------------------------------------------------

void ResetFVGDatabase()
{
   TotalFVGs = 0;

   for(int i=0; i<MAX_FVGS; i++)
      ZeroMemory(FVGDatabase[i]);
}

//----------------------------------------------------

void AddFVG(FairValueGap fvg)
{
   if(!fvg.valid)
      return;

   if(TotalFVGs >= MAX_FVGS)
   {
      for(int i=1; i<MAX_FVGS; i++)
         FVGDatabase[i-1] = FVGDatabase[i];

      TotalFVGs = MAX_FVGS - 1;
   }

   FVGDatabase[TotalFVGs] = fvg;

   TotalFVGs++;
}


//----------------------------------------------------

void UpdateFVGTouches()
{
   double bid =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID);

   for(int i=0;i<TotalFVGs;i++)
   {
      if(!FVGDatabase[i].valid)
         continue;

      if(bid >= FVGDatabase[i].lowerPrice &&
         bid <= FVGDatabase[i].upperPrice)
      {
         FVGDatabase[i].touches++;
      }
   }
}

//----------------------------------------------------

void UpdateMitigationStatus()
{
   double bid =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID);

   for(int i=0;i<TotalFVGs;i++)
   {
      if(!FVGDatabase[i].valid)
         continue;

      if(FVGDatabase[i].direction ==
         FVG_BULLISH)
      {
         if(bid <
            FVGDatabase[i].lowerPrice)
         {
            FVGDatabase[i].mitigated = true;
         }
      }

      if(FVGDatabase[i].direction ==
         FVG_BEARISH)
      {
         if(bid >
            FVGDatabase[i].upperPrice)
         {
            FVGDatabase[i].mitigated = true;
         }
      }
   }
}

//----------------------------------------------------

void RemoveMitigatedFVGs()
{
   for(int i=0;i<TotalFVGs;)
   {
      if(FVGDatabase[i].mitigated)
      {
         for(int j=i+1;j<TotalFVGs;j++)
            FVGDatabase[j-1] =
               FVGDatabase[j];

         TotalFVGs--;

         continue;
      }

      i++;
   }
}

//----------------------------------------------------

int BestBullishFVG()
{
   int index = -1;

   double best = -1;

   for(int i=0;i<TotalFVGs;i++)
   {
      if(!FVGDatabase[i].valid)
         continue;

      if(FVGDatabase[i].direction !=
         FVG_BULLISH)
         continue;

      if(FVGDatabase[i].score > best)
      {
         best =
            FVGDatabase[i].score;

         index = i;
      }
   }

   return index;
}

//----------------------------------------------------

int BestBearishFVG()
{
   int index = -1;

   double best = -1;

   for(int i=0;i<TotalFVGs;i++)
   {
      if(!FVGDatabase[i].valid)
         continue;

      if(FVGDatabase[i].direction !=
         FVG_BEARISH)
         continue;

      if(FVGDatabase[i].score > best)
      {
         best =
            FVGDatabase[i].score;

         index = i;
      }
   }

   return index;
}

//----------------------------------------------------

bool SelectBestBullishFVG()
{
   int idx =
      BestBullishFVG();

   if(idx < 0)
      return false;

   CurrentFVG =
      FVGDatabase[idx];

   return true;
}

//----------------------------------------------------

bool SelectBestBearishFVG()
{
   int idx =
      BestBearishFVG();

   if(idx < 0)
      return false;

   CurrentFVG =
      FVGDatabase[idx];

   return true;
}

//----------------------------------------------------

void UpdateFVGDatabase()
{
   UpdateFVG();

   if(CurrentFVG.valid)
      AddFVG(CurrentFVG);

   UpdateFVGTouches();

   UpdateMitigationStatus();

   RemoveMitigatedFVGs();
}




//====================================================
// SECTION 18 - INSTITUTIONAL ORDER BLOCK ENGINE
//====================================================

enum ENUM_OB_DIRECTION
{
   OB_NONE = 0,

   OB_BULLISH,

   OB_BEARISH
};

struct OrderBlock
{
   bool valid;

   ENUM_OB_DIRECTION direction;

   double high;

   double low;

   double midpoint;

   datetime created;

   bool mitigated;

   int touches;

   double displacementScore;

   double fvgScore;

   double score;
};

OrderBlock CurrentOrderBlock;

input bool EnableOrderBlockFilter = true;

input int MinimumOrderBlockScore = 75;


//----------------------------------------------------

void ResetOrderBlock()
{
   ZeroMemory(CurrentOrderBlock);

   CurrentOrderBlock.direction =
      OB_NONE;
}

//----------------------------------------------------

bool DetectBullishOrderBlock()
{
   ResetOrderBlock();

   for(int i=2;i<=8;i++)
   {
      if(IsBearishCandle(i))
      {
         if(iClose(_Symbol,PERIOD_CURRENT,i-1)>
            iHigh(_Symbol,PERIOD_CURRENT,i))
         {
            CurrentOrderBlock.valid=true;

            CurrentOrderBlock.direction=
               OB_BULLISH;

            CurrentOrderBlock.high=
               iHigh(_Symbol,PERIOD_CURRENT,i);

            CurrentOrderBlock.low=
               iLow(_Symbol,PERIOD_CURRENT,i);

            CurrentOrderBlock.midpoint=
               (CurrentOrderBlock.high+
               CurrentOrderBlock.low)/2.0;

            CurrentOrderBlock.created=
               iTime(_Symbol,PERIOD_CURRENT,i);

            return true;
         }
      }
   }

   return false;
}

//----------------------------------------------------

bool DetectBearishOrderBlock()
{
   ResetOrderBlock();

   for(int i=2;i<=8;i++)
   {
      if(IsBullishCandle(i))
      {
         if(iClose(_Symbol,PERIOD_CURRENT,i-1)<
            iLow(_Symbol,PERIOD_CURRENT,i))
         {
            CurrentOrderBlock.valid=true;

            CurrentOrderBlock.direction=
               OB_BEARISH;

            CurrentOrderBlock.high=
               iHigh(_Symbol,PERIOD_CURRENT,i);

            CurrentOrderBlock.low=
               iLow(_Symbol,PERIOD_CURRENT,i);

            CurrentOrderBlock.midpoint=
               (CurrentOrderBlock.high+
               CurrentOrderBlock.low)/2.0;

            CurrentOrderBlock.created=
               iTime(_Symbol,PERIOD_CURRENT,i);

            return true;
         }
      }
   }

   return false;
}

//----------------------------------------------------

double OrderBlockFreshnessScore()
{
   int bars=
      iBarShift(
         _Symbol,
         PERIOD_CURRENT,
         CurrentOrderBlock.created);

   if(bars<=5)
      return 25;

   if(bars<=10)
      return 20;

   if(bars<=20)
      return 15;

   return 5;
}

//----------------------------------------------------

double OrderBlockTouchScore()
{
   if(CurrentOrderBlock.touches==0)
      return 20;

   if(CurrentOrderBlock.touches==1)
      return 15;

   if(CurrentOrderBlock.touches==2)
      return 10;

   return 0;
}


//----------------------------------------------------

double OrderBlockConfluenceScore()
{
   double score=0;

   score+=CurrentDisplacementScore*0.25;

   if(CurrentFVG.valid)
      score+=20;

   if(IsBullishLiquiditySweep()||
      IsBearishLiquiditySweep())
      score+=15;

   return MathMin(score,40.0);
}


//----------------------------------------------------

double CalculateOrderBlockScore()
{
   double score=0;

   score+=OrderBlockFreshnessScore();

   score+=OrderBlockTouchScore();

   score+=OrderBlockConfluenceScore();

   return MathMin(score,100.0);
}


//----------------------------------------------------

void UpdateOrderBlock()
{
   ResetOrderBlock();

   if(DetectBullishOrderBlock() ||
      DetectBearishOrderBlock())
   {
      CurrentOrderBlock.displacementScore=
         CurrentDisplacementScore;

      CurrentOrderBlock.fvgScore=
         CurrentFVG.score;

      CurrentOrderBlock.score=
         CalculateOrderBlockScore();
   }
}

//----------------------------------------------------

bool ValidBullishOrderBlock()
{
   return
      CurrentOrderBlock.valid &&
      CurrentOrderBlock.direction==
      OB_BULLISH &&
      CurrentOrderBlock.score>=
      MinimumOrderBlockScore;
}

//----------------------------------------------------

bool ValidBearishOrderBlock()
{
   return
      CurrentOrderBlock.valid &&
      CurrentOrderBlock.direction==
      OB_BEARISH &&
      CurrentOrderBlock.score>=
      MinimumOrderBlockScore;
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
// SECTION 21 - STRUCTURE MATRIX ENGINE
//====================================================

enum ENUM_STRUCTURE_STATE
{
   STRUCTURE_UNKNOWN = 0,
   STRUCTURE_BULLISH,
   STRUCTURE_BEARISH,
   STRUCTURE_TRANSITION
};

struct StructureMatrix
{
   ENUM_TIMEFRAMES timeframe;

   ENUM_STRUCTURE_STATE state;

   bool HigherHigh;
   bool HigherLow;

   bool LowerHigh;
   bool LowerLow;

   bool BullishBOS;
   bool BearishBOS;

   bool BullishCHOCH;
   bool BearishCHOCH;

   bool Premium;
   bool Discount;

   bool InternalLiquidityTaken;
   bool ExternalLiquidityTaken;

   bool FVGPresent;

   double TrendStrength;

   double Confidence;

   datetime LastUpdate;
};

//----------------------------------------------------
// Global Structure Matrices
//----------------------------------------------------

StructureMatrix MatrixM5;
StructureMatrix MatrixM15;
StructureMatrix MatrixH1;

//----------------------------------------------------

void InitializeMatrix(
   StructureMatrix &matrix,
   ENUM_TIMEFRAMES tf
)
{
   matrix.timeframe=tf;

   matrix.state=STRUCTURE_UNKNOWN;

   matrix.HigherHigh=false;
   matrix.HigherLow=false;

   matrix.LowerHigh=false;
   matrix.LowerLow=false;

   matrix.BullishBOS=false;
   matrix.BearishBOS=false;

   matrix.BullishCHOCH=false;
   matrix.BearishCHOCH=false;

   matrix.Premium=false;
   matrix.Discount=false;

   matrix.InternalLiquidityTaken=false;
   matrix.ExternalLiquidityTaken=false;

   matrix.FVGPresent=false;

   matrix.TrendStrength=0;

   matrix.Confidence=0;

   matrix.LastUpdate=0;
}

//----------------------------------------------------

void InitializeStructureMatrices()
{
   InitializeMatrix(
      MatrixM5,
      PERIOD_M5
   );

   InitializeMatrix(
      MatrixM15,
      PERIOD_M15
   );

   InitializeMatrix(
      MatrixH1,
      PERIOD_H1
   );
}

//----------------------------------------------------

bool MatrixHigherHigh(
   ENUM_TIMEFRAMES tf
)
{
   double h1=iHigh(_Symbol,tf,5);
   double h2=iHigh(_Symbol,tf,20);

   return h1>h2;
}

//----------------------------------------------------

bool MatrixHigherLow(
   ENUM_TIMEFRAMES tf
)
{
   double l1=iLow(_Symbol,tf,5);
   double l2=iLow(_Symbol,tf,20);

   return l1>l2;
}

//----------------------------------------------------

bool MatrixLowerHigh(
   ENUM_TIMEFRAMES tf
)
{
   double h1=iHigh(_Symbol,tf,5);
   double h2=iHigh(_Symbol,tf,20);

   return h1<h2;
}

//----------------------------------------------------

bool MatrixLowerLow(
   ENUM_TIMEFRAMES tf
)
{
   double l1=iLow(_Symbol,tf,5);
   double l2=iLow(_Symbol,tf,20);

   return l1<l2;
}

//----------------------------------------------------

ENUM_STRUCTURE_STATE GetStructureState(
   ENUM_TIMEFRAMES tf
)
{
   bool HH=MatrixHigherHigh(tf);
   bool HL=MatrixHigherLow(tf);

   bool LH=MatrixLowerHigh(tf);
   bool LL=MatrixLowerLow(tf);

   if(HH && HL)
      return STRUCTURE_BULLISH;

   if(LH && LL)
      return STRUCTURE_BEARISH;

   return STRUCTURE_TRANSITION;
}

//----------------------------------------------------

void UpdateMatrix(
   StructureMatrix &matrix
)
{
   matrix.state=
      GetStructureState(
         matrix.timeframe
      );

   matrix.HigherHigh=
      MatrixHigherHigh(
         matrix.timeframe
      );

   matrix.HigherLow=
      MatrixHigherLow(
         matrix.timeframe
      );

   matrix.LowerHigh=
      MatrixLowerHigh(
         matrix.timeframe
      );

   matrix.LowerLow=
      MatrixLowerLow(
         matrix.timeframe
      );

   matrix.LastUpdate=
      TimeCurrent();
}

//----------------------------------------------------

void UpdateStructureMatrix()
{
   UpdateMatrix(MatrixM5);

   UpdateMatrix(MatrixM15);

   UpdateMatrix(MatrixH1);
}

//----------------------------------------------------

ENUM_STRUCTURE_STATE OverallStructure()
{
   int bulls=0;
   int bears=0;

   if(MatrixM5.state==STRUCTURE_BULLISH)
      bulls++;

   if(MatrixM15.state==STRUCTURE_BULLISH)
      bulls++;

   if(MatrixH1.state==STRUCTURE_BULLISH)
      bulls++;

   if(MatrixM5.state==STRUCTURE_BEARISH)
      bears++;

   if(MatrixM15.state==STRUCTURE_BEARISH)
      bears++;

   if(MatrixH1.state==STRUCTURE_BEARISH)
      bears++;

   if(bulls>=2)
      return STRUCTURE_BULLISH;

   if(bears>=2)
      return STRUCTURE_BEARISH;

   return STRUCTURE_TRANSITION;
}

//----------------------------------------------------

double StructureAgreementScore()
{
   int agreement=0;

   ENUM_STRUCTURE_STATE overall=
      OverallStructure();

   if(MatrixM5.state==overall)
      agreement++;

   if(MatrixM15.state==overall)
      agreement++;

   if(MatrixH1.state==overall)
      agreement++;

   return agreement*33.33;
}











