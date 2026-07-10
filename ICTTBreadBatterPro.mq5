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




