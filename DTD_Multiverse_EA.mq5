//+------------------------------------------------------------------+
//|                                           DTD_Multiverse_EA.mq5 |
//|          ลิขสิทธิ์ 2026, Good Trade Gold Suite & อาจารย์เดช DTD |
//|               ระบบฝึกเทรดวิเคราะห์โครงสร้างตลาดและค็อกพิทมือถือ |
//+------------------------------------------------------------------+
#property copyright   "ลิขสิทธิ์ 2026, Good Trade Gold Suite & อาจารย์เดช DTD"
#property link        "https://github.com/eaeybaent51-creator/Good"
#property version     "1.07"
#property description "DTD Multiverse V1.06 - True 1R:3R Setup Distances, Background Trendlines & Clean Cockpit"
#property description "วิเคราะห์โครงสร้างตลาด Multiverse 3-Timeframe (HTF -> MTF -> LTF M1)"
#property description "ผสานคลื่น A-B-C-D, Fibonacci OTE, POI Zone, LQ Sweep และเรดาร์ CF M1 เสมอ"
#property description "ระบบบริหารหน้าตัก MM 1:3R คำนวณ Lot อัตโนมัติ (ไม่ยิงออเดอร์ในลูปคำสั่ง 100%)"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== [ 1. โครงสร้างตลาด MULTIVERSE 3-TIMEFRAME ] ==="
input ENUM_TIMEFRAMES InpHTF                 = PERIOD_H1;        // 🌐 ไทม์เฟรมใหญ่ HTF (เจตนาตลาดและทิศทางหลัก)
input ENUM_TIMEFRAMES InpMTF                 = PERIOD_M15;       // 🏛️ ไทม์เฟรมกลาง MTF (โซนคุณภาพ POI & LQ Sweep)
input ENUM_TIMEFRAMES InpLTF                 = PERIOD_M1;        // 🎯 ไทม์เฟรมเล็ก LTF (จุดคอนเฟิร์ม CF M1 เสมอ)
input int             InpSwingLookback       = 15;               // 🔍 จำนวนแท่งตรวจจับจุดสวิง High / Low
input bool            InpShowThaiStructText  = true;             // 🏷️ แสดงป้ายโครงสร้างภาษาไทย ("ขึ้น" / "ลง")
input color           InpColorBullBreak      = C'0,255,136';     // 🟢 สีโครงสร้าง "ขึ้น" (Bullish BOS/CHoCH)
input color           InpColorBearBreak      = C'255,80,90';     // 🔴 สีโครงสร้าง "ลง" (Bearish BOS/CHoCH)

input group "=== [ 2. โซนคุณภาพ POI & ดักจับ LIQUIDITY SWEEP ] ==="
input bool            InpDrawPOI_Zones       = true;             // 🏛️ แสดงกล่องโซนคุณภาพ POI BUY & POI SELL
input color           InpColorPOI_Buy        = C'15,65,40';      // 🟩 สีโซน POI BUY (Demand / Bullish OB)
input color           InpColorPOI_Sell       = C'75,20,30';      // 🟥 สีโซน POI SELL (Supply / Bearish OB)
input bool            InpDetectLQSweep       = true;             // 💧 เปิดเรดาร์ตรวจจับ Liquidity Sweep (จุดกวาด SL)
input color           InpColorLQSweep        = C'0,225,255';     // 💠 สีสัญลักษณ์จุดกวาดสภาพคล่อง (Cyan LQ)

input group "=== [ 3. ระบบคลื่น A-B-C-D & FIBONACCI GOLDEN OTE ] ==="
input bool            InpUseABCD_Wave        = true;             // 🌊 เปิดการวิเคราะห์คลื่น A ➔ B ➔ C ➔ D
input bool            InpDrawFiboLevels      = true;             // 📐 แสดงเส้น Fibonacci Retracement & Extension
input color           InpColorFiboOTE        = C'255,215,0';     // 🟡 สีโซนทองคำ OTE (61.8% - 78.6%)
input color           InpColorFiboTarget     = C'50,225,130';    // 🏆 สีเป้าหมายคลื่น D (127.2% / 161.8%)

input group "=== [ 4. เรดาร์คอนเฟิร์ม CF M1 เสมอ (อาจารย์เดช DTD) ] ==="
input bool            InpUseDTD_CF_M1        = true;             // 🎯 เปิดเรดาร์คอนเฟิร์ม CF M1 (เกาะปลายไส้สั้นสุด + แท่งกลืนกิน)
input bool            InpDrawM1Visuals       = true;             // 📐 แสดงเส้นระดับไส้สั้นสุดและกล่อง 1R:3R บนชาร์ต
input int             InpDTD_SL_BufferPts    = 35;               // 🛡️ ระยะเผื่อสเปรดใต้/เหนือจุดสวิงคอนเฟิร์ม (จุด)
input double          InpTargetRR            = 3.0;              // 🏆 เป้าความคุ้มค่า RR ขั้นต่ำ (แนะนำ 3.0 เท่า = 3R)
input bool            InpRequireM15_Alignment= true;              // 🎯 กฎเหล็ก: M1 และ M15 ต้องไปในทิศทางเดียวกัน 100% (ห้ามสวนเทรนด์ M15)

input group "=== [ 5. บริหารเงินทุน MM 1:3R & คำนวณ LOT อัตโนมัติ ] ==="
input double          InpRiskMoney           = 20.0;             // 💵 จำนวนเงินความเสี่ยงต่อไม้ ($ หรือ USC)
input double          InpDefaultLot          = 0.01;             // 📦 ขนาด Lot เริ่มต้น
input ulong           InpMagicNumber         = 888111;           // 🔢 หมายเลข Magic Number ค็อกพิท
input int             InpSlippagePts         = 30;               // ⚡ สลิปเพจสูงสุดที่ยอมรับได้ (จุด)

input group "=== [ 6. หน้าต่างควบคุมและบันทึกสถิติ (COCKPIT HUD) ] ==="
input bool            InpShowCockpitHUD      = true;             // 🖥️ เปิดแผงแดชบอร์ดฝึกเทรดบนกราฟ
input int             InpHUD_X               = 20;               // ตำแหน่ง X ของแดชบอร์ด
input int             InpHUD_Y               = 30;               // ตำแหน่ง Y ของแดชบอร์ด
input int             InpHUD_Width           = 405;              // ความกว้างของแดชบอร์ด
input bool            InpDumpTradeJournal    = true;             // 📓 ส่งออกประวัติการเทรดเป็น CSV ซิงค์สมุดบันทึก

//+------------------------------------------------------------------+
//| STRUCTS & ENUMS                                                  |
//+------------------------------------------------------------------+
#define DTD_PREFIX "DTD_M_"

struct SMultiverseSwing
{
   datetime time;
   double   price;
   bool     isHigh;
   int      bar;
   string   thaiLabel; // "ขึ้น" หรือ "ลง"
};

struct SPOI_Zone
{
   datetime time;
   double   high;
   double   low;
   bool     isBuy;     // true = POI BUY, false = POI SELL
   bool     isActive;
   string   tfName;
};

struct SABCD_State
{
   datetime timeA, timeB, timeC;
   double   priceA, priceB, priceC;
   double   fibo50, fibo618, fibo786;
   double   targetD_1272, targetD_1618;
   int      waveDir;   // +1 = ขาขึ้น (Bullish A-B-C-D), -1 = ขาลง (Bearish A-B-C-D)
   bool     isFormed;
};

struct SDTD_M1_Engine
{
   int      setupSide;          // +1 = แผน BUY, -1 = แผน SELL
   bool     hasM1Shift;         // โครงสร้าง M1 เปลี่ยนทางสำเร็จ ("ขึ้น" / "ลง")
   double   m1SwingHighPrice;   // ราคา Swing High M1 ป้าย "ขึ้น"
   datetime m1SwingHighTime;    // เวลา Swing High M1
   double   m1SwingLowPrice;    // ราคา Swing Low M1 ป้าย "ลง"
   datetime m1SwingLowTime;     // เวลา Swing Low M1
   bool     isRetestConfirmed;  // การรีเทสต์เข้าใกล้ระดับโครงสร้าง M1
   double   shortestWickPrice;  // ระดับราคาของปลายไส้ที่สั้นที่สุด
   datetime shortestWickTime;   // เวลาของแท่งปลายไส้สั้นสุด
   bool     isEngulfConfirmed;  // แท่ง M1 ปิดเนื้อเทียนกลืนกินสำเร็จ
   double   confirmEntryPrice;  // ราคาเข้าอ้างอิง
   double   confirmSLPrice;     // ราคาจุดยอมแพ้ (1R)
   double   confirmTP1RPrice;   // ราคาเป้าหมาย 1R (1:1)
   double   confirmTP2RPrice;   // ราคาเป้าหมาย 2R (1:2)
   double   confirmTP3RPrice;   // ราคาเป้าหมาย 3R (1:3) [เป้าหลัก]
   double   slPoints;           // ระยะ SL เป็นจุด
   double   tp1RPoints;         // ระยะ TP 1R เป็นจุด
   double   tp2RPoints;         // ระยะ TP 2R เป็นจุด
   double   tp3RPoints;         // ระยะ TP 3R เป็นจุด
   double   recommendedLot;     // ขนาด Lot ตามสูตร (ความเสี่ยง ÷ ระยะ SL)
   string   statusText;         // ข้อความสถานะ CF M1 ภาษาไทย
   string   mmPlanText;         // ข้อความแผน MM 1R/2R/3R
   color    statusColor;        // สีสถานะ

   // Dual-Directional Tracking (สแกนทั้ง BUY และ SELL ขนานกันแบบเรียลไทม์)
   bool     buyEngulfConfirmed;
   double   buyShortestWickPrice;
   datetime buyShortestWickTime;
   double   buyConfirmEntryPrice;
   double   buyConfirmSLPrice;
   double   buyConfirmTP1RPrice;
   double   buyConfirmTP2RPrice;
   double   buyConfirmTP3RPrice;
   double   buySlPoints;
   double   buyRecommendedLot;

   bool     sellEngulfConfirmed;
   double   sellShortestWickPrice;
   datetime sellShortestWickTime;
   double   sellConfirmEntryPrice;
   double   sellConfirmSLPrice;
   double   sellConfirmTP1RPrice;
   double   sellConfirmTP2RPrice;
   double   sellConfirmTP3RPrice;
   double   sellSlPoints;
   double   sellRecommendedLot;

   // Setup Freeze & Latch State (ระบบล็อกและตรึงกรอบแผนเทรดนิ่งสนิท)
   bool     isLatched;
   int      latchedSide;
   datetime latchedTime;
   double   latchedEntryPrice;
   double   latchedSLPrice;
   double   latchedTP1Price;
   double   latchedTP2Price;
   double   latchedTP3Price;
   double   latchedSLPoints;
   double   latchedLot;
   double   latchedShortestWick;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade            m_trade;
CSymbolInfo       m_symbol;
CPositionInfo     m_position;

SMultiverseSwing  g_HTF_Swings[50];
int               g_HTF_SwingCount = 0;
SPOI_Zone         g_POI_Zones[30];
int               g_POI_Count = 0;
SABCD_State       g_ABCD;
SDTD_M1_Engine    g_DTD_M1;

double            g_CurrentLot = 0.01;
int               g_HTF_Trend  = 0;     // +1 = ขึ้น, -1 = ลง, 0 = ไซด์เวย์
bool              g_Card1_Expanded = true;
bool              g_Card2_Expanded = true;
bool              g_Card3_Expanded = true;

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
bool IsCentAccount();
string FormatMoneyOrPoints(double points);
void ScanHTF_Structure();
void ScanMTF_POI_Zones();
void ScanABCD_Fibonacci();
void ScanDTD_CF_M1_Always();
void DrawMultiverseVisuals();
void RenderDashboard();
void ExecuteManualTrade(ENUM_ORDER_TYPE orderType);
void ExecuteBreakEven();
void ExecutePartialClose(double pct = 0.80);
void ExecuteCloseAll();
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize = 8, bool isBold = false);
void CreateButton(string name, int x, int y, int w, int h, string text, color bgClr, color txtClr, int fontSize = 8);
void CreateRect(string name, int x, int y, int w, int h, color bgClr, color borderClr);
void RenderWrappedLabel(string prefix, int x, int &curY, string text, color clr, int fontSize = 8, bool isBold = false, int maxChars = 56, int lineSpacing = 16);
void DumpAccountTradeHistory();

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION HANDLER                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!m_symbol.Name(_Symbol))
   {
      Print("[DTD_Multiverse_EA] ผิดพลาดในการเปิดสัญลักษณ์: ", _Symbol);
      return INIT_FAILED;
   }
   m_symbol.Refresh();

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippagePts);

   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_IOC) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else if((filling & SYMBOL_FILLING_FOK) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(minLot <= 0.0) minLot = 0.01;
   if(maxLot <= 0.0) maxLot = 100.0;

   g_CurrentLot = InpDefaultLot;
   if(g_CurrentLot < minLot) g_CurrentLot = minLot;
   if(g_CurrentLot > maxLot) g_CurrentLot = maxLot;

   string gvLot = "DTD_LOT_" + _Symbol;
   if(GlobalVariableCheck(gvLot))
   {
      double savedLot = GlobalVariableGet(gvLot);
      if(savedLot >= minLot && savedLot <= maxLot)
         g_CurrentLot = NormalizeDouble(savedLot, 2);
   }

   ObjectsDeleteAll(0, DTD_PREFIX);
   Print(">>> [DTD_Multiverse_EA] เริ่มต้นระบบวิเคราะห์โครงสร้างตลาดและค็อกพิทฝึกเทรด อาจารย์เดช DTD: ", _Symbol);

   EventSetTimer(1);

   ScanHTF_Structure();
   ScanMTF_POI_Zones();
   ScanABCD_Fibonacci();
   ScanDTD_CF_M1_Always();
   DrawMultiverseVisuals();
   if(InpShowCockpitHUD)
      RenderDashboard();

   if(InpDumpTradeJournal)
      DumpAccountTradeHistory();

   ChartRedraw();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION HANDLER                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, DTD_PREFIX);
   ChartRedraw();
}

void OnTimer()
{
   static ENUM_TIMEFRAMES s_TimerLastTF = PERIOD_CURRENT;
   static int s_tickCount = 0;
   s_tickCount++;
   bool tfChanged = (s_TimerLastTF != _Period);
   bool needsInit = (g_DTD_M1.recommendedLot <= 0.0 || g_DTD_M1.shortestWickPrice <= 0.0);
   if(tfChanged || needsInit || (s_tickCount % 3 == 0))
   {
      if(tfChanged) ObjectsDeleteAll(0, DTD_PREFIX + "M1_");
      s_TimerLastTF = _Period;
      ScanHTF_Structure();
      ScanMTF_POI_Zones();
      ScanABCD_Fibonacci();
      ScanDTD_CF_M1_Always();
      DrawMultiverseVisuals();
      if(InpShowCockpitHUD)
         RenderDashboard();
      if(tfChanged || needsInit) ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| EXPERT TICK HANDLER                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Auto-Reset เมื่อสลับ Timeframe เคลียร์วัตถุ M1 เดิม
   static ENUM_TIMEFRAMES s_LastPeriod = PERIOD_CURRENT;
   if(s_LastPeriod != _Period)
   {
      ObjectsDeleteAll(0, DTD_PREFIX + "M1_");
      s_LastPeriod = _Period;
   }
   // 1. วิเคราะห์โครงสร้างภาพใหญ่ HTF (เจตนาตลาด)
   ScanHTF_Structure();

   // 2. สแกนหาโซนคุณภาพ MTF POI & จุดกวาด Liquidity Sweep
   ScanMTF_POI_Zones();

   // 3. วิเคราะห์คลื่น A-B-C-D และระดับทองคำ Fibonacci OTE
   ScanABCD_Fibonacci();

   // 4. เรดาร์คอนเฟิร์ม LTF M1 เสมอ (เกาะปลายไส้สั้นสุด + แท่งกลืนกิน)
   ScanDTD_CF_M1_Always();

   // 5. วาดกราฟฟิกและแดชบอร์ดฝึกเทรด
   static ulong lastTickMs = 0;
   ulong curTickMs = GetTickCount64();
   if(curTickMs - lastTickMs >= 500)
   {
      lastTickMs = curTickMs;
      DrawMultiverseVisuals();
      if(InpShowCockpitHUD)
         RenderDashboard();
   }
}

//+------------------------------------------------------------------+
//| CHART EVENT HANDLER (INTERACTIVE BUTTONS)                        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == DTD_PREFIX + "BTN_BUY")
      {
         ExecuteManualTrade(ORDER_TYPE_BUY);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == DTD_PREFIX + "BTN_SELL")
      {
         ExecuteManualTrade(ORDER_TYPE_SELL);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == DTD_PREFIX + "BTN_BE")
      {
         ExecuteBreakEven();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == DTD_PREFIX + "BTN_PARTIAL")
      {
         ExecutePartialClose(0.80);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowCockpitHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == DTD_PREFIX + "BTN_CLOSE")
      {
         ExecuteCloseAll();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowCockpitHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == DTD_PREFIX + "BTN_DTD_LOT")
      {
         if(g_DTD_M1.recommendedLot > 0.0)
         {
            g_CurrentLot = g_DTD_M1.recommendedLot;
            GlobalVariableSet("DTD_LOT_" + _Symbol, g_CurrentLot);
            ObjectSetString(0, DTD_PREFIX + "LOT_VAL", OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
            Print(">>> [DTD_Multiverse] 🎯 ปรับใช้ขนาด Lot ตามสูตร MM อ.เดช (1:3R): ", g_CurrentLot);
            if(InpShowCockpitHUD) RenderDashboard();
            ChartRedraw();
         }
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == DTD_PREFIX + "LOT_MINUS")
      {
         double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         if(step <= 0.0) step = 0.01;
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(minLot <= 0.0) minLot = 0.01;

         g_CurrentLot -= step;
         if(g_CurrentLot < minLot) g_CurrentLot = minLot;
         g_CurrentLot = NormalizeDouble(g_CurrentLot, 2);
         GlobalVariableSet("DTD_LOT_" + _Symbol, g_CurrentLot);
         ObjectSetString(0, DTD_PREFIX + "LOT_VAL", OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowCockpitHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == DTD_PREFIX + "LOT_PLUS")
      {
         double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         if(step <= 0.0) step = 0.01;
         double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
         if(maxLot <= 0.0) maxLot = 100.0;

         g_CurrentLot += step;
         if(g_CurrentLot > maxLot) g_CurrentLot = maxLot;
         g_CurrentLot = NormalizeDouble(g_CurrentLot, 2);
         GlobalVariableSet("DTD_LOT_" + _Symbol, g_CurrentLot);
         ObjectSetString(0, DTD_PREFIX + "LOT_VAL", OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowCockpitHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == DTD_PREFIX + "BTN_MIN_C1")
      {
         g_Card1_Expanded = !g_Card1_Expanded;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowCockpitHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == DTD_PREFIX + "BTN_MIN_C2")
      {
         g_Card2_Expanded = !g_Card2_Expanded;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowCockpitHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == DTD_PREFIX + "BTN_MIN_C3")
      {
         g_Card3_Expanded = !g_Card3_Expanded;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowCockpitHUD) RenderDashboard();
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| 0B. IS CENT ACCOUNT & DYNAMIC FORMATTING                         |
//+------------------------------------------------------------------+
bool IsCentAccount()
{
   string curr = AccountInfoString(ACCOUNT_CURRENCY);
   StringToUpper(curr);
   string sym = _Symbol;
   StringToUpper(sym);
   
   if(StringFind(curr, "USC") >= 0 || StringFind(curr, "CENT") >= 0 || StringFind(curr, "EUX") >= 0 || 
      StringFind(curr, "GBC") >= 0 || StringFind(curr, "EURC") >= 0 || StringFind(curr, "GBPC") >= 0 ||
      StringFind(curr, "UST") >= 0 || StringFind(curr, "PROCENT") >= 0 || StringFind(curr, "CUSD") >= 0 ||
      StringFind(sym, "C") == (StringLen(sym) - 1))
      return true;
   return false;
}

string FormatMoneyOrPoints(double points)
{
   string sym = _Symbol;
   StringToUpper(sym);
   if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 || StringFind(sym, "CRYPTO") >= 0)
   {
      double cash = points * _Point;
      return StringFormat("$%.2f", cash);
   }
   return StringFormat("%.0f จุด", points);
}

//+------------------------------------------------------------------+
//| M15 MULTI-TIMEFRAME DIRECTION DETECTOR                           |
//| คำนวณทิศทางแนวโน้ม M15 (EMA 14 + แท่งเทียน M15 + โมเมนตัม)       |
//| คืนค่า: +1 = ขาขึ้น (BULL), -1 = ขาลง (BEAR)                     |
//+------------------------------------------------------------------+
int GetM15_TrendDirection()
{
   MqlRates ratesM15[];
   ArraySetAsSeries(ratesM15, true);
   int copied = CopyRates(_Symbol, PERIOD_M15, 0, 30, ratesM15);
   if(copied < 15) return 0;

   // 1. คำนวณ EMA 14 บน M15 แบบ Native เพื่อความแม่นยำและเสถียร 100%
   double ema14 = 0.0;
   double k = 2.0 / (14.0 + 1.0);
   double smaSum = 0.0;
   int startBar = copied - 1;
   for(int i = startBar; i > startBar - 14; i--)
      smaSum += ratesM15[i].close;
   ema14 = smaSum / 14.0;
   for(int i = startBar - 14; i >= 0; i--)
      ema14 = (ratesM15[i].close * k) + (ema14 * (1.0 - k));

   double curPrice = ratesM15[0].close;
   double close1   = ratesM15[1].close;
   double open1    = ratesM15[1].open;

   // 2. วิเคราะห์ทิศทาง M15:
   bool priceAboveEMA = (curPrice >= ema14);
   bool priceBelowEMA = (curPrice <= ema14);
   bool bar1Bull      = (close1 >= open1);
   bool higherHigh    = (ratesM15[0].high >= ratesM15[1].high);
   bool lowerLow      = (ratesM15[0].low <= ratesM15[1].low);

   if(priceAboveEMA && (bar1Bull || higherHigh))
      return 1;  // M15 ขาขึ้น (BULL)
   else if(priceBelowEMA && (!bar1Bull || lowerLow))
      return -1; // M15 ขาลง (BEAR)
   else
      return (curPrice >= ema14) ? 1 : -1;
}

//+------------------------------------------------------------------+
//| 1. SCAN HTF STRUCTURE (เจตนาตลาดและโครงสร้างหลัก)                |
//+------------------------------------------------------------------+
void ScanHTF_Structure()
{
   MqlRates ratesHTF[];
   ArraySetAsSeries(ratesHTF, true);
   int copied = CopyRates(_Symbol, InpHTF, 0, 100, ratesHTF);
   if(copied < 30) return;

   g_HTF_SwingCount = 0;
   int lookback = InpSwingLookback;

   for(int i = lookback; i < copied - lookback && g_HTF_SwingCount < 40; i++)
   {
      bool isH = true;
      bool isL = true;
      for(int k = 1; k <= lookback; k++)
      {
         if(ratesHTF[i].high <= ratesHTF[i - k].high || ratesHTF[i].high <= ratesHTF[i + k].high) isH = false;
         if(ratesHTF[i].low  >= ratesHTF[i - k].low  || ratesHTF[i].low  >= ratesHTF[i + k].low)  isL = false;
      }

      if(isH)
      {
         g_HTF_Swings[g_HTF_SwingCount].time      = ratesHTF[i].time;
         g_HTF_Swings[g_HTF_SwingCount].price     = ratesHTF[i].high;
         g_HTF_Swings[g_HTF_SwingCount].isHigh    = true;
         g_HTF_Swings[g_HTF_SwingCount].bar       = i;
         g_HTF_Swings[g_HTF_SwingCount].thaiLabel = "ขึ้น";
         g_HTF_SwingCount++;
      }
      else if(isL)
      {
         g_HTF_Swings[g_HTF_SwingCount].time      = ratesHTF[i].time;
         g_HTF_Swings[g_HTF_SwingCount].price     = ratesHTF[i].low;
         g_HTF_Swings[g_HTF_SwingCount].isHigh    = false;
         g_HTF_Swings[g_HTF_SwingCount].bar       = i;
         g_HTF_Swings[g_HTF_SwingCount].thaiLabel = "ลง";
         g_HTF_SwingCount++;
      }
   }

   // วิเคราะห์เจตนาตลาด (Market Intent): สวิงล่าสุด
   if(g_HTF_SwingCount >= 2)
   {
      if(g_HTF_Swings[0].isHigh && g_HTF_Swings[1].isHigh)
      {
         if(g_HTF_Swings[0].price > g_HTF_Swings[1].price) g_HTF_Trend = 1;
         else g_HTF_Trend = -1;
      }
      else if(!g_HTF_Swings[0].isHigh && !g_HTF_Swings[1].isHigh)
      {
         if(g_HTF_Swings[0].price > g_HTF_Swings[1].price) g_HTF_Trend = 1;
         else g_HTF_Trend = -1;
      }
      else
      {
         g_HTF_Trend = (ratesHTF[0].close >= ratesHTF[15].close) ? 1 : -1;
      }
   }
   else
   {
      g_HTF_Trend = 1;
   }
}

//+------------------------------------------------------------------+
//| 2. SCAN MTF POI ZONES & LIQUIDITY SWEEP                          |
//+------------------------------------------------------------------+
void ScanMTF_POI_Zones()
{
   MqlRates ratesMTF[];
   ArraySetAsSeries(ratesMTF, true);
   int copied = CopyRates(_Symbol, InpMTF, 0, 100, ratesMTF);
   if(copied < 35) return;

   g_POI_Count = 0;

   // สแกนแท่งเทียนที่ทำให้เกิด Breakout และทิ้ง FVG/Imbalance
   for(int i = 3; i < 45 && g_POI_Count < 20; i++)
   {
      // 1. POI BUY: แท่งเขียวทรงพลังเบรกขึ้น และทิ้ง FVG (Low ของแท่ง i-1 สูงกว่า High ของแท่ง i+1)
      if(ratesMTF[i - 1].low > ratesMTF[i + 1].high + (50 * _Point))
      {
         g_POI_Zones[g_POI_Count].time     = ratesMTF[i].time;
         g_POI_Zones[g_POI_Count].high     = ratesMTF[i].high;
         g_POI_Zones[g_POI_Count].low      = ratesMTF[i].low;
         g_POI_Zones[g_POI_Count].isBuy    = true;
         g_POI_Zones[g_POI_Count].isActive = (ratesMTF[0].close > ratesMTF[i].low);
         g_POI_Zones[g_POI_Count].tfName   = EnumToString(InpMTF);
         g_POI_Count++;
      }
      // 2. POI SELL: แท่งแดงทรงพลังทุบลง และทิ้ง FVG (High ของแท่ง i-1 ต่ำกว่า Low ของแท่ง i+1)
      else if(ratesMTF[i + 1].low > ratesMTF[i - 1].high + (50 * _Point))
      {
         g_POI_Zones[g_POI_Count].time     = ratesMTF[i].time;
         g_POI_Zones[g_POI_Count].high     = ratesMTF[i].high;
         g_POI_Zones[g_POI_Count].low      = ratesMTF[i].low;
         g_POI_Zones[g_POI_Count].isBuy    = false;
         g_POI_Zones[g_POI_Count].isActive = (ratesMTF[0].close < ratesMTF[i].high);
         g_POI_Zones[g_POI_Count].tfName   = EnumToString(InpMTF);
         g_POI_Count++;
      }
   }
}

//+------------------------------------------------------------------+
//| 3. SCAN ABCD WAVE & FIBONACCI GOLDEN OTE                         |
//+------------------------------------------------------------------+
void ScanABCD_Fibonacci()
{
   if(!InpUseABCD_Wave) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 0, 100, rates);
   if(copied < 35) return;

   // หาสวิง A (จุดเริ่มต้นรอบ), สวิง B (จุดทะลุเบรกโครงสร้าง), และสวิง C (จุดย่อพักตัว)
   int lookback = 8;
   int swingBars[10];
   double swingPrices[10];
   bool swingIsHigh[10];
   int count = 0;

   for(int i = lookback; i < copied - lookback && count < 6; i++)
   {
      bool isH = true;
      bool isL = true;
      for(int k = 1; k <= lookback; k++)
      {
         if(rates[i].high <= rates[i - k].high || rates[i].high <= rates[i + k].high) isH = false;
         if(rates[i].low  >= rates[i - k].low  || rates[i].low  >= rates[i + k].low)  isL = false;
      }

      if(isH)
      {
         swingBars[count]   = i;
         swingPrices[count] = rates[i].high;
         swingIsHigh[count] = true;
         count++;
      }
      else if(isL)
      {
         swingBars[count]   = i;
         swingPrices[count] = rates[i].low;
         swingIsHigh[count] = false;
         count++;
      }
   }

   if(count >= 3)
   {
      // ตรวจสอบโครงสร้างขาขึ้น Bullish ABCD (A ต่ำสุด -> B ยอดเบรก -> C ย่อยกตัว)
      if(!swingIsHigh[2] && swingIsHigh[1] && !swingIsHigh[0])
      {
         g_ABCD.waveDir = 1;
         g_ABCD.priceA  = swingPrices[2];
         g_ABCD.timeA   = rates[swingBars[2]].time;
         g_ABCD.priceB  = swingPrices[1];
         g_ABCD.timeB   = rates[swingBars[1]].time;
         g_ABCD.priceC  = swingPrices[0];
         g_ABCD.timeC   = rates[swingBars[0]].time;

         double rangeAB = g_ABCD.priceB - g_ABCD.priceA;
         if(rangeAB > 0)
         {
            g_ABCD.fibo50       = g_ABCD.priceB - (rangeAB * 0.50);
            g_ABCD.fibo618      = g_ABCD.priceB - (rangeAB * 0.618);
            g_ABCD.fibo786      = g_ABCD.priceB - (rangeAB * 0.786);
            g_ABCD.targetD_1272 = g_ABCD.priceC + (rangeAB * 1.272);
            g_ABCD.targetD_1618 = g_ABCD.priceC + (rangeAB * 1.618);
            g_ABCD.isFormed     = true;
         }
      }
      // ตรวจสอบโครงสร้างขาลง Bearish ABCD (A สูงสุด -> B ก้นเบรก -> C เด้งเตี้ยลง)
      else if(swingIsHigh[2] && !swingIsHigh[1] && swingIsHigh[0])
      {
         g_ABCD.waveDir = -1;
         g_ABCD.priceA  = swingPrices[2];
         g_ABCD.timeA   = rates[swingBars[2]].time;
         g_ABCD.priceB  = swingPrices[1];
         g_ABCD.timeB   = rates[swingBars[1]].time;
         g_ABCD.priceC  = swingPrices[0];
         g_ABCD.timeC   = rates[swingBars[0]].time;

         double rangeAB = g_ABCD.priceA - g_ABCD.priceB;
         if(rangeAB > 0)
         {
            g_ABCD.fibo50       = g_ABCD.priceB + (rangeAB * 0.50);
            g_ABCD.fibo618      = g_ABCD.priceB + (rangeAB * 0.618);
            g_ABCD.fibo786      = g_ABCD.priceB + (rangeAB * 0.786);
            g_ABCD.targetD_1272 = g_ABCD.priceC - (rangeAB * 1.272);
            g_ABCD.targetD_1618 = g_ABCD.priceC - (rangeAB * 1.618);
            g_ABCD.isFormed     = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 4. SCAN DTD CF M1 ALWAYS (เกาะปลายไส้ที่สั้นที่สุด)             |
//+------------------------------------------------------------------+
void ScanDTD_CF_M1_Always()
{
   if(!InpUseDTD_CF_M1)
   {
      g_DTD_M1.statusText  = "🎯 CF M1: ปิดการใช้งาน";
      g_DTD_M1.mmPlanText  = "-";
      g_DTD_M1.statusColor = clrSilver;
      return;
   }

   MqlRates ratesM1[];
   ArraySetAsSeries(ratesM1, true);
   int copied = CopyRates(_Symbol, InpLTF, 0, 100, ratesM1);
   if(copied < 25)
   {
      copied = CopyRates(_Symbol, _Period, 0, 100, ratesM1);
   }
   if(copied < 10)
   {
      g_DTD_M1.statusText  = "🎯 CF M1: กำลังเตรียมข้อมูลแท่งเทียน...";
      g_DTD_M1.mmPlanText  = "💵 แผน MM (1R/2R/3R): กำลังคำนวณระยะ SL และขนาด Lot...";
      g_DTD_M1.statusColor = clrSilver;
      return;
   }

   // 1. ตรวจจับโครงสร้างสวิงบน M1 ("ขึ้น" / "ลง") ใน 25 แท่งล่าสุด สไตล์อาจารย์เดช
   int highestM1Bar = 1;
   int lowestM1Bar = 1;
   double highestM1High = ratesM1[1].high;
   double lowestM1Low = ratesM1[1].low;

   for(int i = 1; i < 25 && i < copied; i++)
   {
      if(ratesM1[i].high > highestM1High)
      {
         highestM1High = ratesM1[i].high;
         highestM1Bar = i;
      }
      if(ratesM1[i].low < lowestM1Low)
      {
         lowestM1Low = ratesM1[i].low;
         lowestM1Bar = i;
      }
   }

   g_DTD_M1.m1SwingHighPrice = highestM1High;
   g_DTD_M1.m1SwingHighTime  = ratesM1[highestM1Bar].time;
   g_DTD_M1.m1SwingLowPrice  = lowestM1Low;
   g_DTD_M1.m1SwingLowTime   = ratesM1[lowestM1Bar].time;

   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(curBid <= 0) curBid = ratesM1[0].close;
   if(curAsk <= 0) curAsk = curBid;

   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0) { tickVal = 1.0; tickSize = _Point; }
   double ptValPerLot = (tickVal / tickSize) * _Point;

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minLot <= 0.0) minLot = 0.01;
   if(maxLot <= 0.0) maxLot = 100.0;
   if(stepLot <= 0.0) stepLot = 0.01;

   double buffer = InpDTD_SL_BufferPts * _Point;
   string moneyUnit = IsCentAccount() ? "USC" : "$";

   // =========================================================================
   // 2. คำนวณแผน BUY อิสระ (Bullish DTD Candidate)
   // =========================================================================
   bool buyHasShift = (ratesM1[0].close >= highestM1High || ratesM1[1].close >= highestM1High || highestM1Bar >= 3);
   int buyLookBack = 15;
   double shortestUpperWick = 999999.0;
   double buyTargetPrice = ratesM1[1].high;
   datetime buyTargetTime = ratesM1[1].time;
   double lowestLow = ratesM1[1].low;

   for(int b = 1; b <= buyLookBack && b < copied; b++)
   {
      double bodyTop = MathMax(ratesM1[b].open, ratesM1[b].close);
      double upperWick = ratesM1[b].high - bodyTop;
      if(ratesM1[b].low < lowestLow) lowestLow = ratesM1[b].low;

      if(upperWick < shortestUpperWick && upperWick >= 0.0)
      {
         shortestUpperWick = upperWick;
         buyTargetPrice   = ratesM1[b].high;
         buyTargetTime    = ratesM1[b].time;
      }
   }

   bool buyConfirmed = (ratesM1[1].close > buyTargetPrice || ratesM1[2].close > buyTargetPrice);
   bool buyIsTestingNow = (!buyConfirmed && ratesM1[0].close > buyTargetPrice);

   double buyEntryPrice = curAsk;
   double buySLPrice = lowestLow - buffer;
   if((buyEntryPrice - buySLPrice) < 80.0 * _Point)
      buySLPrice = buyEntryPrice - (80.0 * _Point);

   double buySLPoints = (buyEntryPrice - buySLPrice) / _Point;
   if(buySLPoints <= 0.0) buySLPoints = 100.0;

   double buyTP1RPrice = buyEntryPrice + (buySLPoints * _Point * 1.0);
   double buyTP2RPrice = buyEntryPrice + (buySLPoints * _Point * 2.0);
   double buyTP3RPrice = buyEntryPrice + (buySLPoints * _Point * InpTargetRR);

   double buyLossPerLot = buySLPoints * ptValPerLot;
   double buyCalcLot = InpDefaultLot;
   if(buyLossPerLot > 0.0 && InpRiskMoney > 0.0)
      buyCalcLot = InpRiskMoney / buyLossPerLot;
   buyCalcLot = MathFloor(buyCalcLot / stepLot) * stepLot;
   if(buyCalcLot < minLot) buyCalcLot = minLot;
   if(buyCalcLot > maxLot) buyCalcLot = maxLot;
   double buyRecommendedLot = NormalizeDouble(buyCalcLot, 2);

   g_DTD_M1.buyEngulfConfirmed   = buyConfirmed;
   g_DTD_M1.buyShortestWickPrice = buyTargetPrice;
   g_DTD_M1.buyShortestWickTime  = buyTargetTime;
   g_DTD_M1.buyConfirmEntryPrice = buyEntryPrice;
   g_DTD_M1.buyConfirmSLPrice    = buySLPrice;
   g_DTD_M1.buyConfirmTP1RPrice  = buyTP1RPrice;
   g_DTD_M1.buyConfirmTP2RPrice  = buyTP2RPrice;
   g_DTD_M1.buyConfirmTP3RPrice  = buyTP3RPrice;
   g_DTD_M1.buySlPoints          = buySLPoints;
   g_DTD_M1.buyRecommendedLot    = buyRecommendedLot;

   // =========================================================================
   // 3. คำนวณแผน SELL อิสระ (Bearish DTD Candidate)
   // =========================================================================
   bool sellHasShift = (ratesM1[0].close <= lowestM1Low || ratesM1[1].close <= lowestM1Low || lowestM1Bar >= 3);
   int sellLookBack = 15;
   double shortestLowerWick = 999999.0;
   double sellTargetPrice = ratesM1[1].low;
   datetime sellTargetTime = ratesM1[1].time;
   double highestHigh = ratesM1[1].high;

   for(int b = 1; b <= sellLookBack && b < copied; b++)
   {
      double bodyBottom = MathMin(ratesM1[b].open, ratesM1[b].close);
      double lowerWick = bodyBottom - ratesM1[b].low;
      if(ratesM1[b].high > highestHigh) highestHigh = ratesM1[b].high;

      if(lowerWick < shortestLowerWick && lowerWick >= 0.0)
      {
         shortestLowerWick = lowerWick;
         sellTargetPrice   = ratesM1[b].low;
         sellTargetTime    = ratesM1[b].time;
      }
   }

   bool sellConfirmed = (ratesM1[1].close < sellTargetPrice || ratesM1[2].close < sellTargetPrice);
   bool sellIsTestingNow = (!sellConfirmed && ratesM1[0].close < sellTargetPrice);

   double sellEntryPrice = curBid;
   double sellSLPrice = highestHigh + buffer;
   if((sellSLPrice - sellEntryPrice) < 80.0 * _Point)
      sellSLPrice = sellEntryPrice + (80.0 * _Point);

   double sellSLPoints = (sellSLPrice - sellEntryPrice) / _Point;
   if(sellSLPoints <= 0.0) sellSLPoints = 100.0;

   double sellTP1RPrice = sellEntryPrice - (sellSLPoints * _Point * 1.0);
   double sellTP2RPrice = sellEntryPrice - (sellSLPoints * _Point * 2.0);
   double sellTP3RPrice = sellEntryPrice - (sellSLPoints * _Point * InpTargetRR);

   double sellLossPerLot = sellSLPoints * ptValPerLot;
   double sellCalcLot = InpDefaultLot;
   if(sellLossPerLot > 0.0 && InpRiskMoney > 0.0)
      sellCalcLot = InpRiskMoney / sellLossPerLot;
   sellCalcLot = MathFloor(sellCalcLot / stepLot) * stepLot;
   if(sellCalcLot < minLot) sellCalcLot = minLot;
   if(sellCalcLot > maxLot) sellCalcLot = maxLot;
   double sellRecommendedLot = NormalizeDouble(sellCalcLot, 2);

   g_DTD_M1.sellEngulfConfirmed   = sellConfirmed;
   g_DTD_M1.sellShortestWickPrice = sellTargetPrice;
   g_DTD_M1.sellShortestWickTime  = sellTargetTime;
   g_DTD_M1.sellConfirmEntryPrice = sellEntryPrice;
   g_DTD_M1.sellConfirmSLPrice    = sellSLPrice;
   g_DTD_M1.sellConfirmTP1RPrice  = sellTP1RPrice;
   g_DTD_M1.sellConfirmTP2RPrice  = sellTP2RPrice;
   g_DTD_M1.sellConfirmTP3RPrice  = sellTP3RPrice;
   g_DTD_M1.sellSlPoints          = sellSLPoints;
   g_DTD_M1.sellRecommendedLot    = sellRecommendedLot;

   // =========================================================================
   // 1B. ตรวจสอบสถานะการล็อกและตรึงกรอบแผนเทรด (SETUP FREEZE & LATCH CHECK)
   // =========================================================================
   if(g_DTD_M1.isLatched)
   {
      bool unlatch = false;
      string unlatchReason = "";

      // 1) Target TP3 or Stop Loss Hit
      if(g_DTD_M1.latchedSide == 1)
      {
         if(curBid >= g_DTD_M1.latchedTP3Price) { unlatch = true; unlatchReason = "แตะเป้าหมายหลัก TP3 สำเร็จ"; }
         else if(curBid <= g_DTD_M1.latchedSLPrice) { unlatch = true; unlatchReason = "ราคาหลุดระดับ Stop Loss"; }
      }
      else if(g_DTD_M1.latchedSide == -1)
      {
         if(curAsk <= g_DTD_M1.latchedTP3Price) { unlatch = true; unlatchReason = "แตะเป้าหมายหลัก TP3 สำเร็จ"; }
         else if(curAsk >= g_DTD_M1.latchedSLPrice) { unlatch = true; unlatchReason = "ราคาหลุดระดับ Stop Loss"; }
      }

      // 2) MTF / Macro Trend Flip & Reversal Guard (ป้องกันการล็อกแผนค้างผิดฝั่ง 100%)
      if(!unlatch)
      {
         int m15Dir = GetM15_TrendDirection();
         if(g_DTD_M1.latchedSide == 1) // ล็อกฝั่ง BUY อยู่
         {
            if(InpRequireM15_Alignment && m15Dir == -1)
            {
               unlatch = true;
               unlatchReason = "เทรนด์ M15 พลิกเป็นขาลง (SELL) ตัดสิทธิ์แผน BUY ทันที";
            }
            else if((ratesM1[0].time - g_DTD_M1.latchedTime) > 25 * 60 && curBid < g_DTD_M1.latchedEntryPrice)
            {
               unlatch = true;
               unlatchReason = "เวลาแผนเทรดหมดอายุ (25 นาที) และราคาติดลบ";
            }
            else if(g_DTD_M1.m1SwingLowPrice > 0.0 && curBid < g_DTD_M1.m1SwingLowPrice)
            {
               unlatch = true;
               unlatchReason = "โครงสร้าง M1 เสียทรง (ราคาหลุด Swing Low)";
            }
         }
         else if(g_DTD_M1.latchedSide == -1) // ล็อกฝั่ง SELL อยู่
         {
            if(InpRequireM15_Alignment && m15Dir == 1)
            {
               unlatch = true;
               unlatchReason = "เทรนด์ M15 พลิกเป็นขาขึ้น (BUY) ตัดสิทธิ์แผน SELL ทันที";
            }
            else if((ratesM1[0].time - g_DTD_M1.latchedTime) > 25 * 60 && curAsk > g_DTD_M1.latchedEntryPrice)
            {
               unlatch = true;
               unlatchReason = "เวลาแผนเทรดหมดอายุ (25 นาที) และราคาติดลบ";
            }
            else if(g_DTD_M1.m1SwingHighPrice > 0.0 && curAsk > g_DTD_M1.m1SwingHighPrice)
            {
               unlatch = true;
               unlatchReason = "โครงสร้าง M1 เสียทรง (ราคาทะลุ Swing High)";
            }
         }
      }

      if(unlatch)
      {
         Print(">>> [DTD_Multiverse] 🔓 ปลดล็อกแผนเทรดเดิมทันที! เหตุผล: ", unlatchReason);
         g_DTD_M1.isLatched           = false;
         g_DTD_M1.latchedSide         = 0;
         g_DTD_M1.latchedTime         = 0;
         g_DTD_M1.latchedEntryPrice   = 0.0;
         g_DTD_M1.latchedSLPrice      = 0.0;
         g_DTD_M1.latchedTP1Price     = 0.0;
         g_DTD_M1.latchedTP2Price     = 0.0;
         g_DTD_M1.latchedTP3Price     = 0.0;
         g_DTD_M1.latchedSLPoints     = 0.0;
         g_DTD_M1.latchedLot          = 0.0;
         g_DTD_M1.latchedShortestWick = 0.0;
         g_DTD_M1.isEngulfConfirmed   = false;
         g_DTD_M1.buyEngulfConfirmed  = false;
         g_DTD_M1.sellEngulfConfirmed = false;
         g_DTD_M1.confirmEntryPrice   = 0.0;
         g_DTD_M1.confirmSLPrice      = 0.0;
         g_DTD_M1.confirmTP1RPrice    = 0.0;
         g_DTD_M1.confirmTP2RPrice    = 0.0;
         g_DTD_M1.confirmTP3RPrice    = 0.0;
         g_DTD_M1.slPoints            = 0.0;
         g_DTD_M1.tp1RPoints          = 0.0;
         g_DTD_M1.tp2RPoints          = 0.0;
         g_DTD_M1.tp3RPoints          = 0.0;

         // ลบกล่อง TradingView Box และเส้นเป้าหมายเก่าทันที
         ObjectDelete(0, DTD_PREFIX + "M1_BOX_SL");
         ObjectDelete(0, DTD_PREFIX + "M1_BOX_TP");
         ObjectDelete(0, DTD_PREFIX + "M1_LINE_TP1R");
         ObjectDelete(0, DTD_PREFIX + "M1_LBL_TP1R");
         ObjectDelete(0, DTD_PREFIX + "M1_LINE_TP2R");
         ObjectDelete(0, DTD_PREFIX + "M1_LBL_TP2R");
         ObjectDelete(0, DTD_PREFIX + "M1_LINE_TP3R");
         ObjectDelete(0, DTD_PREFIX + "M1_LBL_TP3R");
         ObjectDelete(0, DTD_PREFIX + "M1_LINE_SL");
         ObjectDelete(0, DTD_PREFIX + "M1_LBL_SL");
         ObjectDelete(0, DTD_PREFIX + "M1_MARK_ENTRY");
      }
      else
      {
         g_DTD_M1.setupSide         = g_DTD_M1.latchedSide;
         g_DTD_M1.shortestWickPrice = g_DTD_M1.latchedShortestWick;
         g_DTD_M1.confirmEntryPrice = g_DTD_M1.latchedEntryPrice;
         g_DTD_M1.confirmSLPrice    = g_DTD_M1.latchedSLPrice;
         g_DTD_M1.confirmTP1RPrice  = g_DTD_M1.latchedTP1Price;
         g_DTD_M1.confirmTP2RPrice  = g_DTD_M1.latchedTP2Price;
         g_DTD_M1.confirmTP3RPrice  = g_DTD_M1.latchedTP3Price;
         g_DTD_M1.slPoints          = g_DTD_M1.latchedSLPoints;
         g_DTD_M1.tp1RPoints        = g_DTD_M1.latchedSLPoints * 1.0;
         g_DTD_M1.tp2RPoints        = g_DTD_M1.latchedSLPoints * 2.0;
         g_DTD_M1.tp3RPoints        = g_DTD_M1.latchedSLPoints * InpTargetRR;
         g_DTD_M1.recommendedLot    = g_DTD_M1.latchedLot;
         g_DTD_M1.isEngulfConfirmed = true;

         if(g_DTD_M1.latchedSide == 1)
         {
            g_DTD_M1.buyEngulfConfirmed   = true;
            g_DTD_M1.buyConfirmEntryPrice = g_DTD_M1.latchedEntryPrice;
            g_DTD_M1.buyConfirmSLPrice    = g_DTD_M1.latchedSLPrice;
            g_DTD_M1.buyConfirmTP1RPrice  = g_DTD_M1.latchedTP1Price;
            g_DTD_M1.buyConfirmTP2RPrice  = g_DTD_M1.latchedTP2Price;
            g_DTD_M1.buyConfirmTP3RPrice  = g_DTD_M1.latchedTP3Price;
            g_DTD_M1.buySlPoints          = g_DTD_M1.latchedSLPoints;
            g_DTD_M1.buyRecommendedLot    = g_DTD_M1.latchedLot;

            double pnlPts     = (curBid - g_DTD_M1.latchedEntryPrice) / _Point;
            double distRetest = (curBid - g_DTD_M1.shortestWickPrice) / _Point;
            bool isHitTP3     = (g_DTD_M1.latchedTP3Price > 0.0 && curBid >= g_DTD_M1.latchedTP3Price);
            bool isHitTP2     = (g_DTD_M1.latchedTP2Price > 0.0 && curBid >= g_DTD_M1.latchedTP2Price);
            bool isHitTP1     = (g_DTD_M1.latchedTP1Price > 0.0 && curBid >= g_DTD_M1.latchedTP1Price);

            if(isHitTP3)
            {
               g_DTD_M1.statusText  = StringFormat("🏆 CF M1: 🟢 [บรรลุเป้าหมาย 3R สำเร็จ! (+%.0f pts)] ➔ พิจารณาปิดทำกำไรเข้าพอร์ต", pnlPts);
               g_DTD_M1.statusColor = C'0,255,200';
            }
            else if(isHitTP2)
            {
               g_DTD_M1.statusText  = StringFormat("🎯 CF M1: 🟢 [บรรลุเป้า TP 2R (+%.0f pts)] ➔ เลื่อน SL ล็อกกำไรใต้ฐาน TP1 รันสู่ TP3", pnlPts);
               g_DTD_M1.statusColor = C'50,255,180';
            }
            else if(isHitTP1)
            {
               g_DTD_M1.statusText  = StringFormat("🛡️ CF M1: 🟢 [บรรลุเป้า TP 1R (+%.0f pts)] ➔ กดบังทุนทันที ตัดความเสี่ยงเหลือ 0!", pnlPts);
               g_DTD_M1.statusColor = C'100,245,160';
            }
            else if(MathAbs(distRetest) <= 40.0)
            {
               g_DTD_M1.statusText  = StringFormat("🎯 CF M1: 🟢 [จังหวะย่อรีเทส!] ราคาแตะเส้นไส้สั้นสุด %s • จุดขึ้นรถ BUY ราคาดีที่สุด!", DoubleToString(g_DTD_M1.shortestWickPrice, _Digits));
               g_DTD_M1.statusColor = C'0,255,200';
            }
            else if(pnlPts > (StringFind(_Symbol, "BTC") >= 0 ? 2500.0 : ((StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0) ? MathMax(250.0, g_DTD_M1.slPoints * 0.45) : 80.0)))
            {
               g_DTD_M1.statusText  = StringFormat("⚠️ CF M1: 🟢 [แผน BUY วิ่งทำกำไร (+%.0f pts) • ห้ามไล่ราคาเด็ดขาด!]", pnlPts);
               g_DTD_M1.statusColor = clrGold;
            }
            else
            {
               g_DTD_M1.statusText  = "🟢 CF M1: 🟢 จบแท่งกลืนกิน BUY สำเร็จ! (1R/2R/3R พร้อมลั่นไก)";
               g_DTD_M1.statusColor = C'0,255,136';
            }
         }
         else
         {
            g_DTD_M1.sellEngulfConfirmed   = true;
            g_DTD_M1.sellConfirmEntryPrice = g_DTD_M1.latchedEntryPrice;
            g_DTD_M1.sellConfirmSLPrice    = g_DTD_M1.latchedSLPrice;
            g_DTD_M1.sellConfirmTP1RPrice  = g_DTD_M1.latchedTP1Price;
            g_DTD_M1.sellConfirmTP2RPrice  = g_DTD_M1.latchedTP2Price;
            g_DTD_M1.sellConfirmTP3RPrice  = g_DTD_M1.latchedTP3Price;
            g_DTD_M1.sellSlPoints          = g_DTD_M1.latchedSLPoints;
            g_DTD_M1.sellRecommendedLot    = g_DTD_M1.latchedLot;

            double pnlPts     = (g_DTD_M1.latchedEntryPrice - curAsk) / _Point;
            double distRetest = (g_DTD_M1.shortestWickPrice - curAsk) / _Point;
            bool isHitTP3     = (g_DTD_M1.latchedTP3Price > 0.0 && curAsk <= g_DTD_M1.latchedTP3Price);
            bool isHitTP2     = (g_DTD_M1.latchedTP2Price > 0.0 && curAsk <= g_DTD_M1.latchedTP2Price);
            bool isHitTP1     = (g_DTD_M1.latchedTP1Price > 0.0 && curAsk <= g_DTD_M1.latchedTP1Price);

            if(isHitTP3)
            {
               g_DTD_M1.statusText  = StringFormat("🏆 CF M1: 🔴 [บรรลุเป้าหมาย 3R สำเร็จ! (+%.0f pts)] ➔ พิจารณาปิดทำกำไรเข้าพอร์ต", pnlPts);
               g_DTD_M1.statusColor = C'255,80,90';
            }
            else if(isHitTP2)
            {
               g_DTD_M1.statusText  = StringFormat("🎯 CF M1: 🔴 [บรรลุเป้า TP 2R (+%.0f pts)] ➔ เลื่อน SL ล็อกกำไรเหนือฐาน TP1 รันสู่ TP3", pnlPts);
               g_DTD_M1.statusColor = C'255,100,120';
            }
            else if(isHitTP1)
            {
               g_DTD_M1.statusText  = StringFormat("🛡️ CF M1: 🔴 [บรรลุเป้า TP 1R (+%.0f pts)] ➔ กดบังทุนทันที ตัดความเสี่ยงเหลือ 0!", pnlPts);
               g_DTD_M1.statusColor = C'255,120,135';
            }
            else if(MathAbs(distRetest) <= 40.0)
            {
               g_DTD_M1.statusText  = StringFormat("🎯 CF M1: 🔴 [จังหวะดีดรีเทส!] ราคาแตะเส้นไส้สั้นสุด %s • จุดขึ้นรถ SELL ราคาดีที่สุด!", DoubleToString(g_DTD_M1.shortestWickPrice, _Digits));
               g_DTD_M1.statusColor = C'255,180,80';
            }
            else if(pnlPts > (StringFind(_Symbol, "BTC") >= 0 ? 2500.0 : ((StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0) ? MathMax(250.0, g_DTD_M1.slPoints * 0.45) : 80.0)))
            {
               g_DTD_M1.statusText  = StringFormat("⚠️ CF M1: 🔴 [แผน SELL วิ่งทำกำไร (+%.0f pts) • ห้ามไล่ราคาเด็ดขาด!]", pnlPts);
               g_DTD_M1.statusColor = clrGold;
            }
            else
            {
               g_DTD_M1.statusText  = "🔴 CF M1: 🔴 จบแท่งกลืนกิน SELL สำเร็จ! (1R/2R/3R พร้อมลั่นไก)";
               g_DTD_M1.statusColor = C'255,80,90';
            }
         }

         g_DTD_M1.mmPlanText = StringFormat("💵 แผน MM (1R/2R/3R): SL %s | TP1 %s | TP2 %s | TP3 %s | Lot: %.2f (เสี่ยง %s%.1f)", FormatMoneyOrPoints(g_DTD_M1.slPoints), FormatMoneyOrPoints(g_DTD_M1.tp1RPoints), FormatMoneyOrPoints(g_DTD_M1.tp2RPoints), FormatMoneyOrPoints(g_DTD_M1.tp3RPoints), g_DTD_M1.recommendedLot, moneyUnit, InpRiskMoney);
         return;
      }
   }

   // =========================================================================
   // 4. SMART CONTEXT ARBITRATOR (POI Proximity & Confluence Selector)
   // =========================================================================
   string sym = _Symbol; StringToUpper(sym);
   double zoneTol = (StringFind(sym, "BTC") >= 0) ? (curAsk * 0.003) : (((StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)) ? 100.0 * _Point : 25.0 * _Point);

   double distBuyPOI = 9999999.0;
   double distSellPOI = 9999999.0;
   for(int p = 0; p < g_POI_Count; p++)
   {
      if(!g_POI_Zones[p].isActive) continue;
      if(g_POI_Zones[p].isBuy)
      {
         double d = MathAbs(curBid - g_POI_Zones[p].high);
         if(d < distBuyPOI) distBuyPOI = d;
      }
      else
      {
         double d = MathAbs(curAsk - g_POI_Zones[p].low);
         if(d < distSellPOI) distSellPOI = d;
      }
   }

   int m15Dir = GetM15_TrendDirection();
   bool m15AllowsBuy  = (!InpRequireM15_Alignment || m15Dir == 1);
   bool m15AllowsSell = (!InpRequireM15_Alignment || m15Dir == -1);

   int activeSide = 0;
   if(distBuyPOI <= zoneTol)
      activeSide = 1;
   else if(distSellPOI <= zoneTol)
      activeSide = -1;
   else
   {
      if(buyConfirmed && !sellConfirmed)
         activeSide = 1;
      else if(sellConfirmed && !buyConfirmed)
         activeSide = -1;
      else if(buyConfirmed && sellConfirmed)
         activeSide = (buyTargetTime >= sellTargetTime) ? 1 : -1;
      else
      {
         if(distBuyPOI < distSellPOI) activeSide = 1;
         else if(distSellPOI < distBuyPOI) activeSide = -1;
         else if(g_ABCD.isFormed && g_ABCD.waveDir != 0) activeSide = g_ABCD.waveDir;
         else if(g_HTF_Trend != 0) activeSide = g_HTF_Trend;
         else activeSide = 1;
      }
   }

   g_DTD_M1.setupSide = activeSide;

   // =========================================================================
   // 5. ซิงค์ค่าของฝั่งที่แอคทีฟเข้าสู่โครงสร้างหลัก g_DTD_M1
   // =========================================================================
   if(activeSide == 1)
   {
      g_DTD_M1.hasM1Shift        = buyHasShift;
      g_DTD_M1.shortestWickPrice = buyTargetPrice;
      g_DTD_M1.shortestWickTime  = buyTargetTime;
      g_DTD_M1.isEngulfConfirmed = buyConfirmed;
      g_DTD_M1.confirmEntryPrice = buyEntryPrice;
      g_DTD_M1.confirmSLPrice    = buySLPrice;
      g_DTD_M1.slPoints          = buySLPoints;
      g_DTD_M1.confirmTP1RPrice  = buyTP1RPrice;
      g_DTD_M1.confirmTP2RPrice  = buyTP2RPrice;
      g_DTD_M1.confirmTP3RPrice  = buyTP3RPrice;
      g_DTD_M1.tp1RPoints        = buySLPoints * 1.0;
      g_DTD_M1.tp2RPoints        = buySLPoints * 2.0;
      g_DTD_M1.tp3RPoints        = buySLPoints * InpTargetRR;
      g_DTD_M1.recommendedLot    = buyRecommendedLot;

      if(buyConfirmed)
      {
         if(!g_DTD_M1.isLatched && m15AllowsBuy)
         {
            g_DTD_M1.isLatched           = true;
            g_DTD_M1.latchedSide         = 1;
            g_DTD_M1.latchedTime         = ratesM1[1].time;
            g_DTD_M1.latchedEntryPrice   = buyEntryPrice;
            g_DTD_M1.latchedSLPrice      = buySLPrice;
            g_DTD_M1.latchedTP1Price     = buyTP1RPrice;
            g_DTD_M1.latchedTP2Price     = buyTP2RPrice;
            g_DTD_M1.latchedTP3Price     = buyTP3RPrice;
            g_DTD_M1.latchedSLPoints     = buySLPoints;
            g_DTD_M1.latchedLot          = buyRecommendedLot;
            g_DTD_M1.latchedShortestWick = buyTargetPrice;
            Print(">>> [DTD_Multiverse] 🔒 ล็อกกรอบแผนเทรด BUY นิ่งสนิท! Entry: ", buyEntryPrice, " SL: ", buySLPrice, " TP3: ", buyTP3RPrice);
         }
         g_DTD_M1.statusText  = "🎯 CF M1: 🟢 จบกลืนกิน BUY สำเร็จ! (1R/2R/3R พร้อมลั่นไก)";
         g_DTD_M1.statusColor = C'0,255,136';
      }
      else if(buyIsTestingNow)
      {
         double dist = (buyTargetPrice - curAsk) / _Point;
         g_DTD_M1.statusText  = StringFormat("⚡ CF M1: 🟢 แท่งสด M1 กำลังเบรกทดสอบ %s (ห่าง %s จุด • รอจบแท่งคอนเฟิร์ม)", DoubleToString(buyTargetPrice, _Digits), DoubleToString(dist, 0));
         g_DTD_M1.statusColor = clrOrange;
      }
      else
      {
         double dist = (buyTargetPrice - curAsk) / _Point;
         g_DTD_M1.statusText  = (buyHasShift ? StringFormat("🎯 CF M1: 🟢 ทะลุ 'ขึ้น' แล้ว ➔ รอ M1 รีเทสต์+กลืนกิน %s (ห่าง %s จุด)", DoubleToString(buyTargetPrice, _Digits), DoubleToString(dist, 0)) : StringFormat("🎯 CF M1: ⏳ รอแท่ง M1 เบรกทะลุเส้น 'ขึ้น' %s", DoubleToString(highestM1High, _Digits)));
         g_DTD_M1.statusColor = clrGold;
      }

      g_DTD_M1.mmPlanText = StringFormat("💵 แผน MM (1R/2R/3R): SL %s | TP1 %s | TP2 %s | TP3 %s | Lot: %.2f (เสี่ยง %s%.1f)", FormatMoneyOrPoints(g_DTD_M1.slPoints), FormatMoneyOrPoints(g_DTD_M1.tp1RPoints), FormatMoneyOrPoints(g_DTD_M1.tp2RPoints), FormatMoneyOrPoints(g_DTD_M1.tp3RPoints), g_DTD_M1.recommendedLot, moneyUnit, InpRiskMoney);
   }
   else
   {
      g_DTD_M1.hasM1Shift        = sellHasShift;
      g_DTD_M1.shortestWickPrice = sellTargetPrice;
      g_DTD_M1.shortestWickTime  = sellTargetTime;
      g_DTD_M1.isEngulfConfirmed = sellConfirmed;
      g_DTD_M1.confirmEntryPrice = sellEntryPrice;
      g_DTD_M1.confirmSLPrice    = sellSLPrice;
      g_DTD_M1.slPoints          = sellSLPoints;
      g_DTD_M1.confirmTP1RPrice  = sellTP1RPrice;
      g_DTD_M1.confirmTP2RPrice  = sellTP2RPrice;
      g_DTD_M1.confirmTP3RPrice  = sellTP3RPrice;
      g_DTD_M1.tp1RPoints        = sellSLPoints * 1.0;
      g_DTD_M1.tp2RPoints        = sellSLPoints * 2.0;
      g_DTD_M1.tp3RPoints        = sellSLPoints * InpTargetRR;
      g_DTD_M1.recommendedLot    = sellRecommendedLot;

      if(sellConfirmed)
      {
         if(!g_DTD_M1.isLatched && m15AllowsSell)
         {
            g_DTD_M1.isLatched           = true;
            g_DTD_M1.latchedSide         = -1;
            g_DTD_M1.latchedTime         = ratesM1[1].time;
            g_DTD_M1.latchedEntryPrice   = sellEntryPrice;
            g_DTD_M1.latchedSLPrice      = sellSLPrice;
            g_DTD_M1.latchedTP1Price     = sellTP1RPrice;
            g_DTD_M1.latchedTP2Price     = sellTP2RPrice;
            g_DTD_M1.latchedTP3Price     = sellTP3RPrice;
            g_DTD_M1.latchedSLPoints     = sellSLPoints;
            g_DTD_M1.latchedLot          = sellRecommendedLot;
            g_DTD_M1.latchedShortestWick = sellTargetPrice;
            Print(">>> [DTD_Multiverse] 🔒 ล็อกกรอบแผนเทรด SELL นิ่งสนิท! Entry: ", sellEntryPrice, " SL: ", sellSLPrice, " TP3: ", sellTP3RPrice);
         }
         g_DTD_M1.statusText  = "🎯 CF M1: 🔴 จบกลืนกิน SELL สำเร็จ! (1R/2R/3R พร้อมลั่นไก)";
         g_DTD_M1.statusColor = C'255,80,90';
      }
      else if(sellIsTestingNow)
      {
         double dist = (curBid - sellTargetPrice) / _Point;
         g_DTD_M1.statusText  = StringFormat("⚡ CF M1: 🔴 แท่งสด M1 กำลังทุบทดสอบ %s (ห่าง %s จุด • รอจบแท่งคอนเฟิร์ม)", DoubleToString(sellTargetPrice, _Digits), DoubleToString(dist, 0));
         g_DTD_M1.statusColor = clrOrange;
      }
      else
      {
         double dist = (curBid - sellTargetPrice) / _Point;
         g_DTD_M1.statusText  = (sellHasShift ? StringFormat("🎯 CF M1: 🔴 หลุด 'ลง' แล้ว ➔ รอ M1 รีเทสต์+กลืนกิน %s (ห่าง %s จุด)", DoubleToString(sellTargetPrice, _Digits), DoubleToString(dist, 0)) : StringFormat("🎯 CF M1: ⏳ รอแท่ง M1 หลุดทะลุเส้น 'ลง' %s", DoubleToString(lowestM1Low, _Digits)));
         g_DTD_M1.statusColor = clrGold;
      }

      g_DTD_M1.mmPlanText = StringFormat("💵 แผน MM (1R/2R/3R): SL %s | TP1 %s | TP2 %s | TP3 %s | Lot: %.2f (เสี่ยง %s%.1f)", FormatMoneyOrPoints(g_DTD_M1.slPoints), FormatMoneyOrPoints(g_DTD_M1.tp1RPoints), FormatMoneyOrPoints(g_DTD_M1.tp2RPoints), FormatMoneyOrPoints(g_DTD_M1.tp3RPoints), g_DTD_M1.recommendedLot, moneyUnit, InpRiskMoney);
   }
}
//+------------------------------------------------------------------+
void DrawMultiverseVisuals()
{
   int tfSec = PeriodSeconds((ENUM_TIMEFRAMES)_Period);

   // 1. วาดป้ายสวิงโครงสร้างภาษาไทย ("ขึ้น" / "ลง")
   if(InpShowThaiStructText)
   {
      for(int i = 0; i < MathMin(g_HTF_SwingCount, 6); i++)
      {
         string lblName = DTD_PREFIX + "SW_LBL_" + IntegerToString(i);
         color  lblCol  = g_HTF_Swings[i].isHigh ? InpColorBullBreak : InpColorBearBreak;
         string txt     = StringFormat("◆ โครงสร้าง: %s (%s)", g_HTF_Swings[i].thaiLabel, DoubleToString(g_HTF_Swings[i].price, _Digits));

         if(ObjectFind(0, lblName) < 0)
         {
            ObjectCreate(0, lblName, OBJ_TEXT, 0, g_HTF_Swings[i].time, g_HTF_Swings[i].price);
            ObjectSetString(0, lblName, OBJPROP_TEXT, txt);
            ObjectSetString(0, lblName, OBJPROP_FONT, "Segoe UI Semibold");
            ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, lblName, OBJPROP_COLOR, lblCol);
            ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, g_HTF_Swings[i].isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
         }
         else
         {
            ObjectSetInteger(0, lblName, OBJPROP_TIME, 0, g_HTF_Swings[i].time);
            ObjectSetDouble(0, lblName, OBJPROP_PRICE, 0, g_HTF_Swings[i].price);
            ObjectSetString(0, lblName, OBJPROP_TEXT, txt);
            ObjectSetInteger(0, lblName, OBJPROP_COLOR, lblCol);
         }
      }
   }

   // 2. วาดกล่องโซนคุณภาพ POI BUY & POI SELL
   if(InpDrawPOI_Zones)
   {
      for(int i = 0; i < MathMin(g_POI_Count, 6); i++)
      {
         if(!g_POI_Zones[i].isActive) continue;
         string boxName = DTD_PREFIX + "POI_BOX_" + IntegerToString(i);
         datetime tEnd = TimeCurrent() + (tfSec * 20);
         color boxCol = g_POI_Zones[i].isBuy ? InpColorPOI_Buy : InpColorPOI_Sell;

         if(ObjectFind(0, boxName) < 0)
         {
            ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, g_POI_Zones[i].time, g_POI_Zones[i].high, tEnd, g_POI_Zones[i].low);
            ObjectSetInteger(0, boxName, OBJPROP_COLOR, boxCol);
            ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, boxCol);
            ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
            ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
         }
         else
         {
            ObjectSetInteger(0, boxName, OBJPROP_TIME, 0, g_POI_Zones[i].time);
            ObjectSetDouble(0, boxName, OBJPROP_PRICE, 0, g_POI_Zones[i].high);
            ObjectSetInteger(0, boxName, OBJPROP_TIME, 1, tEnd);
            ObjectSetDouble(0, boxName, OBJPROP_PRICE, 1, g_POI_Zones[i].low);
         }
      }
   }

   // 3. วาดคลื่น A-B-C-D และระดับทองคำ Fibonacci OTE
   if(InpUseABCD_Wave && g_ABCD.isFormed && InpDrawFiboLevels)
   {
      datetime tStart = g_ABCD.timeA;
      datetime tEnd   = TimeCurrent() + (tfSec * 25);

      string fiboOTE = DTD_PREFIX + "FIBO_OTE";
      if(ObjectFind(0, fiboOTE) < 0)
      {
         ObjectCreate(0, fiboOTE, OBJ_TREND, 0, tStart, g_ABCD.fibo618, tEnd, g_ABCD.fibo618);
         ObjectSetInteger(0, fiboOTE, OBJPROP_COLOR, InpColorFiboOTE);
         ObjectSetInteger(0, fiboOTE, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, fiboOTE, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, fiboOTE, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, fiboOTE, OBJPROP_BACK, true);
      }
      else
      {
         ObjectSetInteger(0, fiboOTE, OBJPROP_TIME, 0, tStart);
         ObjectSetDouble(0, fiboOTE, OBJPROP_PRICE, 0, g_ABCD.fibo618);
         ObjectSetInteger(0, fiboOTE, OBJPROP_TIME, 1, tEnd);
         ObjectSetDouble(0, fiboOTE, OBJPROP_PRICE, 1, g_ABCD.fibo618);
      }

      string targetLine = DTD_PREFIX + "FIBO_TARGET_D";
      if(ObjectFind(0, targetLine) < 0)
      {
         ObjectCreate(0, targetLine, OBJ_TREND, 0, tStart, g_ABCD.targetD_1618, tEnd, g_ABCD.targetD_1618);
         ObjectSetInteger(0, targetLine, OBJPROP_COLOR, InpColorFiboTarget);
         ObjectSetInteger(0, targetLine, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, targetLine, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, targetLine, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, targetLine, OBJPROP_BACK, true);
      }
      else
      {
         ObjectSetInteger(0, targetLine, OBJPROP_TIME, 0, tStart);
         ObjectSetDouble(0, targetLine, OBJPROP_PRICE, 0, g_ABCD.targetD_1618);
         ObjectSetInteger(0, targetLine, OBJPROP_TIME, 1, tEnd);
         ObjectSetDouble(0, targetLine, OBJPROP_PRICE, 1, g_ABCD.targetD_1618);
      }
   }

   // 4. วาดเส้นเกณฑ์ CF M1, ป้ายภาษาไทย "ขึ้น"/"ลง", Entry Tick & Multi-Tier 1R, 2R, 3R
   if(InpUseDTD_CF_M1 && InpDrawM1Visuals && g_DTD_M1.shortestWickPrice > 0)
   {
      int forwardBars = 12;
      if(_Period == PERIOD_M1)       forwardBars = 15;
      else if(_Period <= PERIOD_M5)  forwardBars = 8;
      else if(_Period <= PERIOD_M15) forwardBars = 6;
      else if(_Period <= PERIOD_M30) forwardBars = 5;
      else                           forwardBars = 4;

      datetime tStart   = (g_DTD_M1.isLatched && g_DTD_M1.latchedTime > 0) ? g_DTD_M1.latchedTime : ((g_DTD_M1.shortestWickTime > 0) ? g_DTD_M1.shortestWickTime : (TimeCurrent() - (tfSec * 4)));
      datetime tEnd     = TimeCurrent() + (tfSec * forwardBars);
      datetime tWickLbl = tEnd;

      // 4A. เส้นแนวนอนและป้ายภาษาไทย "ขึ้น" (Swing High M1)
      if(g_DTD_M1.m1SwingHighPrice > 0.0)
      {
         string lineUp = DTD_PREFIX + "M1_LINE_UP";
         datetime tUpStart = (g_DTD_M1.m1SwingHighTime > 0) ? g_DTD_M1.m1SwingHighTime : (TimeCurrent() - (tfSec * 15));
         if(ObjectFind(0, lineUp) < 0)
         {
            ObjectCreate(0, lineUp, OBJ_TREND, 0, tUpStart, g_DTD_M1.m1SwingHighPrice, tEnd, g_DTD_M1.m1SwingHighPrice);
            ObjectSetInteger(0, lineUp, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, lineUp, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lineUp, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lineUp, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lineUp, OBJPROP_BACK, true);
         }
         else
         {
            ObjectSetInteger(0, lineUp, OBJPROP_TIME, 0, tUpStart);
            ObjectSetDouble(0, lineUp, OBJPROP_PRICE, 0, g_DTD_M1.m1SwingHighPrice);
            ObjectSetInteger(0, lineUp, OBJPROP_TIME, 1, tEnd);
            ObjectSetDouble(0, lineUp, OBJPROP_PRICE, 1, g_DTD_M1.m1SwingHighPrice);
            ObjectSetInteger(0, lineUp, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, lineUp, OBJPROP_BACK, true);
         }

         string lblUp = DTD_PREFIX + "M1_LBL_UP";
         string txtUp = StringFormat("ขึ้น (%s)", DoubleToString(g_DTD_M1.m1SwingHighPrice, _Digits));
         datetime tUpLbl = tEnd - (tfSec * 2);
         if(ObjectFind(0, lblUp) < 0)
         {
            ObjectCreate(0, lblUp, OBJ_TEXT, 0, tUpLbl, g_DTD_M1.m1SwingHighPrice);
            ObjectSetString(0, lblUp, OBJPROP_TEXT, txtUp);
            ObjectSetString(0, lblUp, OBJPROP_FONT, "Segoe UI Black");
            ObjectSetInteger(0, lblUp, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, lblUp, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, lblUp, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
            ObjectSetInteger(0, lblUp, OBJPROP_BACK, false);
         }
         else
         {
            ObjectSetInteger(0, lblUp, OBJPROP_TIME, 0, tUpLbl);
            ObjectSetDouble(0, lblUp, OBJPROP_PRICE, 0, g_DTD_M1.m1SwingHighPrice);
            ObjectSetString(0, lblUp, OBJPROP_TEXT, txtUp);
            ObjectSetInteger(0, lblUp, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, lblUp, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
            ObjectSetString(0, lblUp, OBJPROP_FONT, "Segoe UI Black");
         }
      }

      // 4B. เส้นแนวนอนและป้ายภาษาไทย "ลง" (Swing Low M1)
      if(g_DTD_M1.m1SwingLowPrice > 0.0)
      {
         string lineDn = DTD_PREFIX + "M1_LINE_DOWN";
         datetime tDnStart = (g_DTD_M1.m1SwingLowTime > 0) ? g_DTD_M1.m1SwingLowTime : (TimeCurrent() - (tfSec * 15));
         if(ObjectFind(0, lineDn) < 0)
         {
            ObjectCreate(0, lineDn, OBJ_TREND, 0, tDnStart, g_DTD_M1.m1SwingLowPrice, tEnd, g_DTD_M1.m1SwingLowPrice);
            ObjectSetInteger(0, lineDn, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, lineDn, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lineDn, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lineDn, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lineDn, OBJPROP_BACK, true);
         }
         else
         {
            ObjectSetInteger(0, lineDn, OBJPROP_TIME, 0, tDnStart);
            ObjectSetDouble(0, lineDn, OBJPROP_PRICE, 0, g_DTD_M1.m1SwingLowPrice);
            ObjectSetInteger(0, lineDn, OBJPROP_TIME, 1, tEnd);
            ObjectSetDouble(0, lineDn, OBJPROP_PRICE, 1, g_DTD_M1.m1SwingLowPrice);
            ObjectSetInteger(0, lineDn, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, lineDn, OBJPROP_BACK, true);
         }

         string lblDn = DTD_PREFIX + "M1_LBL_DOWN";
         string txtDn = StringFormat("ลง (%s)", DoubleToString(g_DTD_M1.m1SwingLowPrice, _Digits));
         datetime tDnLbl = tEnd - (tfSec * 2);
         if(ObjectFind(0, lblDn) < 0)
         {
            ObjectCreate(0, lblDn, OBJ_TEXT, 0, tDnLbl, g_DTD_M1.m1SwingLowPrice);
            ObjectSetString(0, lblDn, OBJPROP_TEXT, txtDn);
            ObjectSetString(0, lblDn, OBJPROP_FONT, "Segoe UI Black");
            ObjectSetInteger(0, lblDn, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, lblDn, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, lblDn, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
            ObjectSetInteger(0, lblDn, OBJPROP_BACK, false);
         }
         else
         {
            ObjectSetInteger(0, lblDn, OBJPROP_TIME, 0, tDnLbl);
            ObjectSetDouble(0, lblDn, OBJPROP_PRICE, 0, g_DTD_M1.m1SwingLowPrice);
            ObjectSetString(0, lblDn, OBJPROP_TEXT, txtDn);
            ObjectSetInteger(0, lblDn, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, lblDn, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
            ObjectSetString(0, lblDn, OBJPROP_FONT, "Segoe UI Black");
         }
      }

      // 4C. เส้นเกณฑ์ปลายไส้สั้นสุด
      string wickLine = DTD_PREFIX + "M1_WICK_LINE";
      color  wickCol  = g_DTD_M1.isEngulfConfirmed ? (g_DTD_M1.setupSide == 1 ? C'0,255,136' : C'255,80,90') : clrGold;

      if(ObjectFind(0, wickLine) < 0)
      {
         ObjectCreate(0, wickLine, OBJ_TREND, 0, tStart, g_DTD_M1.shortestWickPrice, tEnd, g_DTD_M1.shortestWickPrice);
         ObjectSetInteger(0, wickLine, OBJPROP_COLOR, wickCol);
         ObjectSetInteger(0, wickLine, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, wickLine, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, wickLine, OBJPROP_RAY_RIGHT, false);
      }
      else
      {
         ObjectSetInteger(0, wickLine, OBJPROP_TIME, 0, tStart);
         ObjectSetDouble(0, wickLine, OBJPROP_PRICE, 0, g_DTD_M1.shortestWickPrice);
         ObjectSetInteger(0, wickLine, OBJPROP_TIME, 1, tEnd);
         ObjectSetDouble(0, wickLine, OBJPROP_PRICE, 1, g_DTD_M1.shortestWickPrice);
         ObjectSetInteger(0, wickLine, OBJPROP_COLOR, wickCol);
      }

      string wickLbl = DTD_PREFIX + "M1_WICK_LBL";
      string lblTxt  = StringFormat("🎯 เกณฑ์ CF M1 (ไส้สั้นสุด): %s %s", 
                                    DoubleToString(g_DTD_M1.shortestWickPrice, _Digits),
                                    (g_DTD_M1.isEngulfConfirmed ? "★ [CF กลืนกินสำเร็จ!]" : "[รอปิดแท่งกลืนกิน]"));
      if(ObjectFind(0, wickLbl) < 0)
      {
         ObjectCreate(0, wickLbl, OBJ_TEXT, 0, tWickLbl, g_DTD_M1.shortestWickPrice);
         ObjectSetString(0, wickLbl, OBJPROP_TEXT, lblTxt);
         ObjectSetString(0, wickLbl, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, wickLbl, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, wickLbl, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, wickLbl, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, wickLbl, OBJPROP_BACK, false);
      }
      else
      {
         ObjectSetInteger(0, wickLbl, OBJPROP_TIME, 0, tWickLbl);
         ObjectSetDouble(0, wickLbl, OBJPROP_PRICE, 0, g_DTD_M1.shortestWickPrice);
         ObjectSetString(0, wickLbl, OBJPROP_TEXT, lblTxt);
         ObjectSetInteger(0, wickLbl, OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, wickLbl, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, wickLbl, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }

      // 4D. สัญลักษณ์จุดลั่นไก (Entry Tick Mark สไตล์อาจารย์เดช)
      if(g_DTD_M1.isEngulfConfirmed && g_DTD_M1.confirmEntryPrice > 0.0)
      {
         string markName = DTD_PREFIX + "M1_MARK_ENTRY";
         if(ObjectFind(0, markName) < 0)
         {
            ObjectCreate(0, markName, OBJ_ARROW_CHECK, 0, TimeCurrent(), g_DTD_M1.confirmEntryPrice);
            ObjectSetInteger(0, markName, OBJPROP_COLOR, (g_DTD_M1.setupSide == 1 ? C'0,255,136' : C'255,80,90'));
            ObjectSetInteger(0, markName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, markName, OBJPROP_ANCHOR, (g_DTD_M1.setupSide == 1 ? ANCHOR_TOP : ANCHOR_BOTTOM));
         }
         else
         {
            ObjectSetInteger(0, markName, OBJPROP_TIME, 0, TimeCurrent());
            ObjectSetDouble(0, markName, OBJPROP_PRICE, 0, g_DTD_M1.confirmEntryPrice);
         }
      }
      else
      {
         ObjectDelete(0, DTD_PREFIX + "M1_MARK_ENTRY");
      }

      // 4E. กล่อง 1R : 3R สไตล์ TradingView และเส้น Multi-Tier 1R, 2R, 3R
      if(g_DTD_M1.confirmSLPrice > 0 && g_DTD_M1.confirmTP3RPrice > 0)
      {
         datetime bStart = (g_DTD_M1.isLatched && g_DTD_M1.latchedTime > 0) ? g_DTD_M1.latchedTime : ((g_DTD_M1.shortestWickTime > 0) ? g_DTD_M1.shortestWickTime : TimeCurrent());
         datetime bEnd   = TimeCurrent() + (tfSec * forwardBars);
         double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(curBid <= 0) curBid = iClose(_Symbol, _Period, 0);

         // กล่อง SL (1R Risk Box)
         string boxSL = DTD_PREFIX + "BOX_1R_SL";
         double slTop = MathMax(g_DTD_M1.confirmEntryPrice, g_DTD_M1.confirmSLPrice);
         double slBtm = MathMin(g_DTD_M1.confirmEntryPrice, g_DTD_M1.confirmSLPrice);
         if(ObjectFind(0, boxSL) < 0)
         {
            ObjectCreate(0, boxSL, OBJ_RECTANGLE, 0, bStart, slTop, bEnd, slBtm);
            ObjectSetInteger(0, boxSL, OBJPROP_COLOR, C'180,40,50');
            ObjectSetInteger(0, boxSL, OBJPROP_BGCOLOR, C'80,20,25');
            ObjectSetInteger(0, boxSL, OBJPROP_FILL, true);
            ObjectSetInteger(0, boxSL, OBJPROP_BACK, true);
         }
         else
         {
            ObjectSetInteger(0, boxSL, OBJPROP_TIME, 0, bStart);
            ObjectSetDouble(0, boxSL, OBJPROP_PRICE, 0, slTop);
            ObjectSetInteger(0, boxSL, OBJPROP_TIME, 1, bEnd);
            ObjectSetDouble(0, boxSL, OBJPROP_PRICE, 1, slBtm);
         }

         // กล่อง TP (3R Reward Box)
         string boxTP = DTD_PREFIX + "BOX_3R_TP";
         double tpTop = MathMax(g_DTD_M1.confirmEntryPrice, g_DTD_M1.confirmTP3RPrice);
         double tpBtm = MathMin(g_DTD_M1.confirmEntryPrice, g_DTD_M1.confirmTP3RPrice);
         if(ObjectFind(0, boxTP) < 0)
         {
            ObjectCreate(0, boxTP, OBJ_RECTANGLE, 0, bStart, tpTop, bEnd, tpBtm);
            ObjectSetInteger(0, boxTP, OBJPROP_COLOR, C'30,140,80');
            ObjectSetInteger(0, boxTP, OBJPROP_BGCOLOR, C'15,60,35');
            ObjectSetInteger(0, boxTP, OBJPROP_FILL, true);
            ObjectSetInteger(0, boxTP, OBJPROP_BACK, true);
         }
         else
         {
            ObjectSetInteger(0, boxTP, OBJPROP_TIME, 0, bStart);
            ObjectSetDouble(0, boxTP, OBJPROP_PRICE, 0, tpTop);
            ObjectSetInteger(0, boxTP, OBJPROP_TIME, 1, bEnd);
            ObjectSetDouble(0, boxTP, OBJPROP_PRICE, 1, tpBtm);
         }

         // เส้น & ป้าย TP 1R (1:1)
         if(g_DTD_M1.confirmTP1RPrice > 0.0)
         {
            string lineTP1 = DTD_PREFIX + "M1_LINE_TP1R";
            if(ObjectFind(0, lineTP1) < 0)
            {
               ObjectCreate(0, lineTP1, OBJ_TREND, 0, bStart, g_DTD_M1.confirmTP1RPrice, bEnd, g_DTD_M1.confirmTP1RPrice);
               ObjectSetInteger(0, lineTP1, OBJPROP_COLOR, C'100,210,140');
               ObjectSetInteger(0, lineTP1, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, lineTP1, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, lineTP1, OBJPROP_RAY_RIGHT, false);
            }
            else
            {
               ObjectSetInteger(0, lineTP1, OBJPROP_TIME, 0, bStart);
               ObjectSetDouble(0, lineTP1, OBJPROP_PRICE, 0, g_DTD_M1.confirmTP1RPrice);
               ObjectSetInteger(0, lineTP1, OBJPROP_TIME, 1, bEnd);
               ObjectSetDouble(0, lineTP1, OBJPROP_PRICE, 1, g_DTD_M1.confirmTP1RPrice);
            }

            string lblTP1 = DTD_PREFIX + "M1_LBL_TP1R";
            double tp1Dist = (g_DTD_M1.tp1RPoints > 0.0) ? g_DTD_M1.tp1RPoints : (MathAbs(g_DTD_M1.confirmTP1RPrice - g_DTD_M1.confirmEntryPrice) / _Point);
            string tp1Txt  = StringFormat(" 🛡️ TP 1R (1:1): %s (+%s) ", DoubleToString(g_DTD_M1.confirmTP1RPrice, _Digits), FormatMoneyOrPoints(tp1Dist));
            if(ObjectFind(0, lblTP1) < 0)
            {
               ObjectCreate(0, lblTP1, OBJ_TEXT, 0, bEnd, g_DTD_M1.confirmTP1RPrice);
               ObjectSetString(0, lblTP1, OBJPROP_TEXT, tp1Txt);
               ObjectSetString(0, lblTP1, OBJPROP_FONT, "Segoe UI Black");
               ObjectSetInteger(0, lblTP1, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, lblTP1, OBJPROP_COLOR, clrWhite);
               ObjectSetInteger(0, lblTP1, OBJPROP_ANCHOR, ANCHOR_LEFT);
               ObjectSetInteger(0, lblTP1, OBJPROP_BACK, false);
            }
            else
            {
               ObjectSetInteger(0, lblTP1, OBJPROP_TIME, 0, bEnd);
               ObjectSetDouble(0, lblTP1, OBJPROP_PRICE, 0, g_DTD_M1.confirmTP1RPrice);
               ObjectSetString(0, lblTP1, OBJPROP_TEXT, tp1Txt);
               ObjectSetInteger(0, lblTP1, OBJPROP_COLOR, clrWhite);
               ObjectSetString(0, lblTP1, OBJPROP_FONT, "Segoe UI Black");
            }
         }

         // เส้น & ป้าย TP 2R (1:2)
         if(g_DTD_M1.confirmTP2RPrice > 0.0)
         {
            string lineTP2 = DTD_PREFIX + "M1_LINE_TP2R";
            if(ObjectFind(0, lineTP2) < 0)
            {
               ObjectCreate(0, lineTP2, OBJ_TREND, 0, bStart, g_DTD_M1.confirmTP2RPrice, bEnd, g_DTD_M1.confirmTP2RPrice);
               ObjectSetInteger(0, lineTP2, OBJPROP_COLOR, C'70,235,160');
               ObjectSetInteger(0, lineTP2, OBJPROP_STYLE, STYLE_DASH);
               ObjectSetInteger(0, lineTP2, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, lineTP2, OBJPROP_RAY_RIGHT, false);
            }
            else
            {
               ObjectSetInteger(0, lineTP2, OBJPROP_TIME, 0, bStart);
               ObjectSetDouble(0, lineTP2, OBJPROP_PRICE, 0, g_DTD_M1.confirmTP2RPrice);
               ObjectSetInteger(0, lineTP2, OBJPROP_TIME, 1, bEnd);
               ObjectSetDouble(0, lineTP2, OBJPROP_PRICE, 1, g_DTD_M1.confirmTP2RPrice);
            }

            string lblTP2 = DTD_PREFIX + "M1_LBL_TP2R";
            double tp2Dist = (g_DTD_M1.tp2RPoints > 0.0) ? g_DTD_M1.tp2RPoints : (MathAbs(g_DTD_M1.confirmTP2RPrice - g_DTD_M1.confirmEntryPrice) / _Point);
            string tp2Txt  = StringFormat(" 🎯 TP 2R (1:2): %s (+%s) ", DoubleToString(g_DTD_M1.confirmTP2RPrice, _Digits), FormatMoneyOrPoints(tp2Dist));
            if(ObjectFind(0, lblTP2) < 0)
            {
               ObjectCreate(0, lblTP2, OBJ_TEXT, 0, bEnd, g_DTD_M1.confirmTP2RPrice);
               ObjectSetString(0, lblTP2, OBJPROP_TEXT, tp2Txt);
               ObjectSetString(0, lblTP2, OBJPROP_FONT, "Segoe UI Black");
               ObjectSetInteger(0, lblTP2, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, lblTP2, OBJPROP_COLOR, clrWhite);
               ObjectSetInteger(0, lblTP2, OBJPROP_ANCHOR, ANCHOR_LEFT);
               ObjectSetInteger(0, lblTP2, OBJPROP_BACK, false);
            }
            else
            {
               ObjectSetInteger(0, lblTP2, OBJPROP_TIME, 0, bEnd);
               ObjectSetDouble(0, lblTP2, OBJPROP_PRICE, 0, g_DTD_M1.confirmTP2RPrice);
               ObjectSetString(0, lblTP2, OBJPROP_TEXT, tp2Txt);
               ObjectSetInteger(0, lblTP2, OBJPROP_COLOR, clrWhite);
               ObjectSetString(0, lblTP2, OBJPROP_FONT, "Segoe UI Black");
            }
         }

         // เส้น & ป้าย TP 3R (1:3 เป้าหลักอาจารย์เดช)
         string lineTP3 = DTD_PREFIX + "M1_LINE_TP3R";
         if(ObjectFind(0, lineTP3) < 0)
         {
            ObjectCreate(0, lineTP3, OBJ_TREND, 0, bStart, g_DTD_M1.confirmTP3RPrice, bEnd, g_DTD_M1.confirmTP3RPrice);
            ObjectSetInteger(0, lineTP3, OBJPROP_COLOR, C'50,255,130');
            ObjectSetInteger(0, lineTP3, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lineTP3, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, lineTP3, OBJPROP_RAY_RIGHT, false);
         }
         else
         {
            ObjectSetInteger(0, lineTP3, OBJPROP_TIME, 0, bStart);
            ObjectSetDouble(0, lineTP3, OBJPROP_PRICE, 0, g_DTD_M1.confirmTP3RPrice);
            ObjectSetInteger(0, lineTP3, OBJPROP_TIME, 1, bEnd);
            ObjectSetDouble(0, lineTP3, OBJPROP_PRICE, 1, g_DTD_M1.confirmTP3RPrice);
         }

         string lblTP3 = DTD_PREFIX + "M1_LBL_TP3R";
         double tpDist = (g_DTD_M1.tp3RPoints > 0.0) ? g_DTD_M1.tp3RPoints : (MathAbs(g_DTD_M1.confirmTP3RPrice - g_DTD_M1.confirmEntryPrice) / _Point);
         string tpTxt  = StringFormat(" 🏆 TP 3R (1:3): %s (+%s) ★เป้าหลัก ", DoubleToString(g_DTD_M1.confirmTP3RPrice, _Digits), FormatMoneyOrPoints(tpDist));
         if(ObjectFind(0, lblTP3) < 0)
         {
            ObjectCreate(0, lblTP3, OBJ_TEXT, 0, bEnd, g_DTD_M1.confirmTP3RPrice);
            ObjectSetString(0, lblTP3, OBJPROP_TEXT, tpTxt);
            ObjectSetString(0, lblTP3, OBJPROP_FONT, "Segoe UI Black");
            ObjectSetInteger(0, lblTP3, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, lblTP3, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, lblTP3, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, lblTP3, OBJPROP_BACK, false);
         }
         else
         {
            ObjectSetInteger(0, lblTP3, OBJPROP_TIME, 0, bEnd);
            ObjectSetDouble(0, lblTP3, OBJPROP_PRICE, 0, g_DTD_M1.confirmTP3RPrice);
            ObjectSetString(0, lblTP3, OBJPROP_TEXT, tpTxt);
            ObjectSetInteger(0, lblTP3, OBJPROP_COLOR, clrWhite);
            ObjectSetString(0, lblTP3, OBJPROP_FONT, "Segoe UI Black");
         }

         // เส้น & ป้าย SL (1R)
         string lineSL = DTD_PREFIX + "M1_LINE_SL";
         if(ObjectFind(0, lineSL) < 0)
         {
            ObjectCreate(0, lineSL, OBJ_TREND, 0, bStart, g_DTD_M1.confirmSLPrice, bEnd, g_DTD_M1.confirmSLPrice);
            ObjectSetInteger(0, lineSL, OBJPROP_COLOR, C'255,80,90');
            ObjectSetInteger(0, lineSL, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lineSL, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lineSL, OBJPROP_RAY_RIGHT, false);
         }
         else
         {
            ObjectSetInteger(0, lineSL, OBJPROP_TIME, 0, bStart);
            ObjectSetDouble(0, lineSL, OBJPROP_PRICE, 0, g_DTD_M1.confirmSLPrice);
            ObjectSetInteger(0, lineSL, OBJPROP_TIME, 1, bEnd);
            ObjectSetDouble(0, lineSL, OBJPROP_PRICE, 1, g_DTD_M1.confirmSLPrice);
         }

         string lblSL = DTD_PREFIX + "M1_LBL_SL";
         double slDist = (g_DTD_M1.slPoints > 0.0) ? g_DTD_M1.slPoints : (MathAbs(g_DTD_M1.confirmEntryPrice - g_DTD_M1.confirmSLPrice) / _Point);
         string slPosTag = (g_DTD_M1.setupSide == 1) ? "[ใต้ชุดคอนเฟิร์ม]" : "[เหนือชุดคอนเฟิร์ม]";
         string slTxt  = StringFormat(" 🛑 SL 1R: %s (-%s) %s ", DoubleToString(g_DTD_M1.confirmSLPrice, _Digits), FormatMoneyOrPoints(slDist), slPosTag);
         if(ObjectFind(0, lblSL) < 0)
         {
            ObjectCreate(0, lblSL, OBJ_TEXT, 0, bEnd, g_DTD_M1.confirmSLPrice);
            ObjectSetString(0, lblSL, OBJPROP_TEXT, slTxt);
            ObjectSetString(0, lblSL, OBJPROP_FONT, "Segoe UI Black");
            ObjectSetInteger(0, lblSL, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, lblSL, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, lblSL, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, lblSL, OBJPROP_BACK, false);
         }
         else
         {
            ObjectSetInteger(0, lblSL, OBJPROP_TIME, 0, bEnd);
            ObjectSetDouble(0, lblSL, OBJPROP_PRICE, 0, g_DTD_M1.confirmSLPrice);
            ObjectSetString(0, lblSL, OBJPROP_TEXT, slTxt);
            ObjectSetInteger(0, lblSL, OBJPROP_COLOR, clrWhite);
            ObjectSetString(0, lblSL, OBJPROP_FONT, "Segoe UI Black");
         }
      }
      else
      {
         ObjectDelete(0, DTD_PREFIX + "BOX_1R_SL");
         ObjectDelete(0, DTD_PREFIX + "BOX_3R_TP");
         ObjectDelete(0, DTD_PREFIX + "M1_LINE_TP1R");
         ObjectDelete(0, DTD_PREFIX + "M1_LBL_TP1R");
         ObjectDelete(0, DTD_PREFIX + "M1_LINE_TP2R");
         ObjectDelete(0, DTD_PREFIX + "M1_LBL_TP2R");
         ObjectDelete(0, DTD_PREFIX + "M1_LINE_TP3R");
         ObjectDelete(0, DTD_PREFIX + "M1_LBL_TP3R");
         ObjectDelete(0, DTD_PREFIX + "M1_LINE_SL");
         ObjectDelete(0, DTD_PREFIX + "M1_LBL_SL");
      }
   }
   else
   {
      ObjectDelete(0, DTD_PREFIX + "M1_LINE_UP");
      ObjectDelete(0, DTD_PREFIX + "M1_LBL_UP");
      ObjectDelete(0, DTD_PREFIX + "M1_LINE_DOWN");
      ObjectDelete(0, DTD_PREFIX + "M1_LBL_DOWN");
      ObjectDelete(0, DTD_PREFIX + "M1_MARK_ENTRY");
      ObjectDelete(0, DTD_PREFIX + "M1_WICK_LINE");
      ObjectDelete(0, DTD_PREFIX + "M1_WICK_LBL");
      ObjectDelete(0, DTD_PREFIX + "BOX_1R_SL");
      ObjectDelete(0, DTD_PREFIX + "BOX_3R_TP");
      ObjectDelete(0, DTD_PREFIX + "M1_LINE_TP1R");
      ObjectDelete(0, DTD_PREFIX + "M1_LBL_TP1R");
      ObjectDelete(0, DTD_PREFIX + "M1_LINE_TP2R");
      ObjectDelete(0, DTD_PREFIX + "M1_LBL_TP2R");
      ObjectDelete(0, DTD_PREFIX + "M1_LINE_TP3R");
      ObjectDelete(0, DTD_PREFIX + "M1_LBL_TP3R");
      ObjectDelete(0, DTD_PREFIX + "M1_LINE_SL");
      ObjectDelete(0, DTD_PREFIX + "M1_LBL_SL");
   }
}
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int baseX = InpHUD_X;
   int curY  = InpHUD_Y;
   int w     = InpHUD_Width;

   // Header Bar
   CreateRect(DTD_PREFIX + "HDR_BG", baseX, curY, w, 32, C'15,22,35', C'40,80,140');
   CreateLabel(DTD_PREFIX + "HDR_TITLE", baseX + 14, curY + 7, "🎓 DTD MULTIVERSE ค็อกพิทฝึกเทรด (อาจารย์เดช)", clrGold, 10, true);
   curY += 38;

   // CARD 1: สรุปภาพรวม Multiverse & เจตนาตลาด
   string trendStr = (g_HTF_Trend == 1) ? "เจตนาตลาด HTF: 🟢 ขาขึ้น (แผน Buy ได้เปรียบ)" : "เจตนาตลาด HTF: 🔴 ขาลง (แผน Sell ได้เปรียบ)";
   color  trendCol = (g_HTF_Trend == 1) ? C'0,255,136' : C'255,80,90';
   string multiStr = StringFormat("โครงสร้าง: %s ➔ โซน POI: %s ➔ คอนเฟิร์ม: %s", EnumToString(InpHTF), EnumToString(InpMTF), EnumToString(InpLTF));

   int cardH1 = 24;
   if(g_Card1_Expanded)
   {
      cardH1 = 24 + 18 + 18 + 10;
   }

   CreateRect(DTD_PREFIX + "C1_BG", baseX, curY, w, cardH1, C'12,20,30', C'25,50,85');
   CreateLabel(DTD_PREFIX + "C1_TITLE", baseX + 12, curY + 5, "🌐 1. เจตนาตลาด & ลำดับ MULTIVERSE", C'100,200,255', 8, true);
   CreateButton(DTD_PREFIX + "BTN_MIN_C1", baseX + w - 24, curY + 3, 18, 18, (g_Card1_Expanded ? "—" : "+"), C'35,50,70', clrSilver, 8);

   if(g_Card1_Expanded)
   {
      int lineY = curY + 24;
      CreateLabel(DTD_PREFIX + "C1_L1", baseX + 14, lineY, trendStr, trendCol, 8, true);
      lineY += 18;
      CreateLabel(DTD_PREFIX + "C1_L2", baseX + 14, lineY, multiStr, clrWhite, 8, false);
   }
   else
   {
      ObjectDelete(0, DTD_PREFIX + "C1_L1");
      ObjectDelete(0, DTD_PREFIX + "C1_L2");
   }

   curY += cardH1 + 6;

   // CARD 2: คลื่น A-B-C-D & โซนคุณภาพ POI
   string abcdStr = "คลื่น ABCD: กำลังค้นหารอบคลื่นสวิงหลัก...";
   color  abcdCol = clrSilver;
   if(g_ABCD.isFormed)
   {
      abcdStr = StringFormat("คลื่น %s: A=%s ➔ B=%s ➔ C=%s | OTE 61.8%%: %s",
                             (g_ABCD.waveDir == 1 ? "BUY 🟢" : "SELL 🔴"),
                             DoubleToString(g_ABCD.priceA, _Digits),
                             DoubleToString(g_ABCD.priceB, _Digits),
                             DoubleToString(g_ABCD.priceC, _Digits),
                             DoubleToString(g_ABCD.fibo618, _Digits));
      abcdCol = clrGold;
   }
   string targetStr = (g_ABCD.isFormed) ? StringFormat("🏆 เป้าคลื่น D: 127.2%%=%s | 161.8%%=%s", DoubleToString(g_ABCD.targetD_1272, _Digits), DoubleToString(g_ABCD.targetD_1618, _Digits)) : "เป้าคลื่น D: — (รอคลื่นคอนเฟิร์ม)";

   int cardH2 = 24;
   if(g_Card2_Expanded)
   {
      cardH2 = 24 + 18 + 18 + 10;
   }

   CreateRect(DTD_PREFIX + "C2_BG", baseX, curY, w, cardH2, C'15,22,25', C'30,65,60');
   CreateLabel(DTD_PREFIX + "C2_TITLE", baseX + 12, curY + 5, "🌊 2. คลื่น A-B-C-D & ระดับทองคำ FIBONACCI", C'100,240,180', 8, true);
   CreateButton(DTD_PREFIX + "BTN_MIN_C2", baseX + w - 24, curY + 3, 18, 18, (g_Card2_Expanded ? "—" : "+"), C'35,50,70', clrSilver, 8);

   if(g_Card2_Expanded)
   {
      int lineY = curY + 24;
      CreateLabel(DTD_PREFIX + "C2_L1", baseX + 14, lineY, abcdStr, abcdCol, 8, true);
      lineY += 18;
      CreateLabel(DTD_PREFIX + "C2_L2", baseX + 14, lineY, targetStr, C'50,225,130', 8, false);
   }
   else
   {
      ObjectDelete(0, DTD_PREFIX + "C2_L1");
      ObjectDelete(0, DTD_PREFIX + "C2_L2");
   }

   curY += cardH2 + 6;

   // CARD 3: ห้องควบคุมการฝึกเทรด & คอนเฟิร์ม M1 เสมอ (1:3R)
   string dtdPlanStr = (g_DTD_M1.mmPlanText != "" ? g_DTD_M1.mmPlanText : StringFormat("💵 แผน MM (1R/2R/3R): SL %.0f pts | TP3R %.0f pts | Lot แนะนำ: %.2f (เสี่ยง $%.1f)", g_DTD_M1.slPoints, g_DTD_M1.tp3RPoints, g_DTD_M1.recommendedLot, InpRiskMoney));

   int totalPos = 0;
   double totalProfit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || m_position.Magic() == 0))
         {
            totalPos++;
            totalProfit += m_position.Profit() + m_position.Swap();
         }
      }
   }
   string posInfo = StringFormat("📊 ถือ: %d ไม้ | กำไรรวม: $%.2f", totalPos, totalProfit);

   int cardH3 = 24;
   if(g_Card3_Expanded)
   {
      int h3 = 24;
      h3 += (StringLen(g_DTD_M1.statusText) > 56 ? 32 : 16);
      h3 += (StringLen(dtdPlanStr) > 56 ? 32 : 16);
      h3 += 16; // posInfo
      h3 += 6;  // spacing
      h3 += 28; // row 1
      h3 += 6;
      h3 += 26; // dtd lot btn
      h3 += 8;
      h3 += 38; // buy / sell
      h3 += 12;
      cardH3 = h3;
   }

   CreateRect(DTD_PREFIX + "C3_BG", baseX, curY, w, cardH3, C'20,18,28', C'65,45,95');
   CreateLabel(DTD_PREFIX + "C3_TITLE", baseX + 12, curY + 5, "🎯 3. คอนเฟิร์ม CF M1 เสมอ & ห้องควบคุมมือถือ", C'220,160,255', 8, true);
   CreateButton(DTD_PREFIX + "BTN_MIN_C3", baseX + w - 24, curY + 3, 18, 18, (g_Card3_Expanded ? "—" : "+"), C'35,50,70', clrSilver, 8);

   if(g_Card3_Expanded)
   {
      int lineY = curY + 24;
      RenderWrappedLabel(DTD_PREFIX + "C3_L_CF", baseX + 14, lineY, g_DTD_M1.statusText, g_DTD_M1.statusColor, 8, true, 56, 16);
      string buyFcStr  = StringFormat("🟢 คาดการณ์ BUY: ดักย่อ/เข้า %s | SL %s | TP3 %s (Lot %.2f)",
                                      DoubleToString(g_DTD_M1.buyShortestWickPrice, _Digits),
                                      DoubleToString(g_DTD_M1.buyConfirmSLPrice, _Digits),
                                      DoubleToString(g_DTD_M1.buyConfirmTP3RPrice, _Digits),
                                      g_DTD_M1.buyRecommendedLot);
      string sellFcStr = StringFormat("🔴 คาดการณ์ SELL: ดักเด้ง/เข้า %s | SL %s | TP3 %s (Lot %.2f)",
                                      DoubleToString(g_DTD_M1.sellShortestWickPrice, _Digits),
                                      DoubleToString(g_DTD_M1.sellConfirmSLPrice, _Digits),
                                      DoubleToString(g_DTD_M1.sellConfirmTP3RPrice, _Digits),
                                      g_DTD_M1.sellRecommendedLot);
      RenderWrappedLabel(DTD_PREFIX + "C3_L_FCB", baseX + 14, lineY, buyFcStr, C'70,255,155', 8, true, 58, 16);
      RenderWrappedLabel(DTD_PREFIX + "C3_L_FCS", baseX + 14, lineY, sellFcStr, C'255,115,125', 8, true, 58, 16);
      RenderWrappedLabel(DTD_PREFIX + "C3_L_PLAN", baseX + 14, lineY, dtdPlanStr, clrGold, 8, true, 56, 16);
      CreateLabel(DTD_PREFIX + "C3_L_POS", baseX + 14, lineY, posInfo, clrWhite, 8, false);
      lineY += 16;

      int btnY1 = lineY + 6;
      int btnY_DTD = btnY1 + 34;
      int btnY2 = btnY_DTD + 32;

      CreateButton(DTD_PREFIX + "LOT_MINUS",   baseX + 14,  btnY1, 30, 28, "-", C'45,55,75', clrWhite, 11);
      CreateButton(DTD_PREFIX + "LOT_VAL",     baseX + 47,  btnY1, 70, 28, DoubleToString(g_CurrentLot, 2), C'30,40,55', clrGold, 10);
      CreateButton(DTD_PREFIX + "LOT_PLUS",    baseX + 120, btnY1, 30, 28, "+", C'45,55,75', clrWhite, 11);

      CreateButton(DTD_PREFIX + "BTN_BE",      baseX + 158, btnY1, 72, 28, "🛡️ บังทุน", C'35,70,120', clrWhite, 8);
      CreateButton(DTD_PREFIX + "BTN_PARTIAL", baseX + 236, btnY1, 72, 28, "💰 ปิด 80%", C'145,100,20', clrWhite, 8);
      CreateButton(DTD_PREFIX + "BTN_CLOSE",   baseX + 314, btnY1, 72, 28, "❌ ปิดหมด", C'140,40,50', clrWhite, 8);

      CreateButton(DTD_PREFIX + "BTN_DTD_LOT", baseX + 14, btnY_DTD, w - 28, 26, StringFormat("🎯 คลิกใช้ขนาด Lot อ.เดช: %.2f (แผน MM 1R:3R)", g_DTD_M1.recommendedLot), C'25,55,90', clrGold, 8);

      double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(curBid <= 0) curBid = iClose(_Symbol, _Period, 0);
      if(curAsk <= 0) curAsk = curBid;

      CreateButton(DTD_PREFIX + "BTN_BUY",  baseX + 14,  btnY2, 181, 38, "🟢 กด BUY", C'30,120,60', clrWhite, 11);
      CreateButton(DTD_PREFIX + "BTN_SELL", baseX + 205, btnY2, 181, 38, "🔴 กด SELL", C'150,40,40', clrWhite, 11);

      cardH3 = (btnY2 + 38 - curY) + 10;
      if(ObjectGetInteger(0, DTD_PREFIX + "C3_BG", OBJPROP_YSIZE) != cardH3)
         ObjectSetInteger(0, DTD_PREFIX + "C3_BG", OBJPROP_YSIZE, cardH3);
   }
   else
   {
      ObjectsDeleteAll(0, DTD_PREFIX + "C3_L");
      ObjectsDeleteAll(0, DTD_PREFIX + "LOT_");
      ObjectsDeleteAll(0, DTD_PREFIX + "BTN_BE");
      ObjectsDeleteAll(0, DTD_PREFIX + "BTN_PARTIAL");
      ObjectsDeleteAll(0, DTD_PREFIX + "BTN_CLOSE");
      ObjectsDeleteAll(0, DTD_PREFIX + "BTN_BUY");
      ObjectsDeleteAll(0, DTD_PREFIX + "BTN_SELL");
      ObjectDelete(0, DTD_PREFIX + "BTN_DTD_LOT");
   }
}

//+------------------------------------------------------------------+
//| 7. MANUAL TRADING ACTIONS (BUY, SELL, BE, PARTIAL, CLOSE ALL)    |
//+------------------------------------------------------------------+
void ExecuteManualTrade(ENUM_ORDER_TYPE orderType)
{
   m_symbol.RefreshRates();
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   if(ask <= 0.0 || bid <= 0.0)
   {
      Print(">>> [DTD_Multiverse] ⚠️ ไม่สามารถอ่านราคาตลาดได้!");
      return;
   }

   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = MathMax((double)stopsLevel * _Point, 25.0 * _Point);

   double price = 0.0;
   double sl = 0.0;
   double tp = 0.0;

   if(orderType == ORDER_TYPE_BUY)
   {
      price = ask;
      if(g_DTD_M1.buyEngulfConfirmed && g_DTD_M1.buyConfirmSLPrice > 0.0 && g_DTD_M1.buyConfirmSLPrice < bid - minStopDist)
         sl = g_DTD_M1.buyConfirmSLPrice;
      else if(g_DTD_M1.isEngulfConfirmed && g_DTD_M1.setupSide == 1 && g_DTD_M1.confirmSLPrice > 0.0 && g_DTD_M1.confirmSLPrice < bid - minStopDist)
         sl = g_DTD_M1.confirmSLPrice;
      else
         sl = bid - (500 * _Point);

      if(g_DTD_M1.buyEngulfConfirmed && g_DTD_M1.buyConfirmTP3RPrice > ask + minStopDist)
         tp = g_DTD_M1.buyConfirmTP3RPrice;
      else if(g_DTD_M1.isEngulfConfirmed && g_DTD_M1.setupSide == 1 && g_DTD_M1.confirmTP3RPrice > ask + minStopDist)
         tp = g_DTD_M1.confirmTP3RPrice;
      else
         tp = ask + (1500 * _Point);

      sl    = NormalizeDouble(sl, _Digits);
      tp    = NormalizeDouble(tp, _Digits);
      price = NormalizeDouble(price, _Digits);

      if(m_trade.Buy(g_CurrentLot, _Symbol, price, sl, tp, "DTD_Buy"))
      {
         Print(">>> [DTD_Multiverse] 🟢 เปิดไม้ BUY สำเร็จ! Ticket: ", m_trade.ResultOrder(), " Lot: ", g_CurrentLot, " Price: ", price, " SL: ", sl, " TP: ", tp);
      }
      else
      {
         Print(">>> [DTD_Multiverse] ⚠️ เปิดไม้ BUY ไม่สำเร็จ! Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      price = bid;
      if(g_DTD_M1.sellEngulfConfirmed && g_DTD_M1.sellConfirmSLPrice > ask + minStopDist)
         sl = g_DTD_M1.sellConfirmSLPrice;
      else if(g_DTD_M1.isEngulfConfirmed && g_DTD_M1.setupSide == -1 && g_DTD_M1.confirmSLPrice > ask + minStopDist)
         sl = g_DTD_M1.confirmSLPrice;
      else
         sl = ask + (500 * _Point);

      if(g_DTD_M1.sellEngulfConfirmed && g_DTD_M1.sellConfirmTP3RPrice > 0.0 && g_DTD_M1.sellConfirmTP3RPrice < bid - minStopDist)
         tp = g_DTD_M1.sellConfirmTP3RPrice;
      else if(g_DTD_M1.isEngulfConfirmed && g_DTD_M1.setupSide == -1 && g_DTD_M1.confirmTP3RPrice > 0.0 && g_DTD_M1.confirmTP3RPrice < bid - minStopDist)
         tp = g_DTD_M1.confirmTP3RPrice;
      else
         tp = bid - (1500 * _Point);

      sl    = NormalizeDouble(sl, _Digits);
      tp    = NormalizeDouble(tp, _Digits);
      price = NormalizeDouble(price, _Digits);

      if(m_trade.Sell(g_CurrentLot, _Symbol, price, sl, tp, "DTD_Sell"))
      {
         Print(">>> [DTD_Multiverse] 🔴 เปิดไม้ SELL สำเร็จ! Ticket: ", m_trade.ResultOrder(), " Lot: ", g_CurrentLot, " Price: ", price, " SL: ", sl, " TP: ", tp);
      }
      else
      {
         Print(">>> [DTD_Multiverse] ⚠️ เปิดไม้ SELL ไม่สำเร็จ! Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
      }
   }
}

void ExecuteBreakEven()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int modified = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || m_position.Magic() == 0))
         {
            double openP = m_position.PriceOpen();
            double curSL = m_position.StopLoss();
            double curTP = m_position.TakeProfit();

            if(m_position.PositionType() == POSITION_TYPE_BUY)
            {
               double bePrice = openP + (10 * _Point);
               if(bid > bePrice && (curSL < openP || curSL == 0.0))
               {
                  if(m_trade.PositionModify(m_position.Ticket(), bePrice, curTP))
                     modified++;
               }
            }
            else if(m_position.PositionType() == POSITION_TYPE_SELL)
            {
               double bePrice = openP - (10 * _Point);
               if(ask < bePrice && (curSL > openP || curSL == 0.0))
               {
                  if(m_trade.PositionModify(m_position.Ticket(), bePrice, curTP))
                     modified++;
               }
            }
         }
      }
   }
   Print(">>> [DTD_Multiverse] 🛡️ ดำเนินการขยับบังทุนเสร็จสิ้น: ", modified, " ไม้");
}

void ExecutePartialClose(double pct = 0.80)
{
   int closed = 0;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(step <= 0.0) step = 0.01;
   if(minLot <= 0.0) minLot = 0.01;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || m_position.Magic() == 0))
         {
            if(m_position.Profit() > 0.0)
            {
               double vol = m_position.Volume();
               double closeVol = MathFloor((vol * pct) / step) * step;
               if(closeVol >= minLot && (vol - closeVol) >= minLot)
               {
                  if(m_trade.PositionClosePartial(m_position.Ticket(), closeVol))
                     closed++;
               }
            }
         }
      }
   }
   Print(">>> [DTD_Multiverse] 💰 ดำเนินการแบ่งปิดกำไร 80% สำเร็จ: ", closed, " ไม้");
}

void ExecuteCloseAll()
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || m_position.Magic() == 0))
         {
            if(m_trade.PositionClose(m_position.Ticket()))
               closed++;
         }
      }
   }
   Print(">>> [DTD_Multiverse] ❌ ดำเนินการปิดคำสั่งทั้งหมด: ", closed, " ไม้");
}

//+------------------------------------------------------------------+
//| 8. DUMP ACCOUNT TRADE HISTORY TO CSV (JOURNAL SYNC)              |
//+------------------------------------------------------------------+
void DumpAccountTradeHistory()
{
   if(!HistorySelect(0, TimeCurrent())) return;

   int fileHandle = FileOpen("Good_Trade_History_Dump.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
   if(fileHandle == INVALID_HANDLE) return;

   FileWriteString(fileHandle, "Ticket,Login,Symbol,Type,Volume,OpenPrice,ClosePrice,OpenTime,CloseTime,Profit,Swap,Commission,SL,TP,Comment\n");

   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT) continue;

      string sym      = HistoryDealGetString(ticket, DEAL_SYMBOL);
      long dealType   = HistoryDealGetInteger(ticket, DEAL_TYPE);
      double vol      = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      double price    = HistoryDealGetDouble(ticket, DEAL_PRICE);
      datetime time   = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      double profit   = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double swap     = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double comm     = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      string comment  = HistoryDealGetString(ticket, DEAL_COMMENT);

      string typeStr = (dealType == DEAL_TYPE_BUY) ? "BUY" : "SELL";
      string line = StringFormat("%d,%d,%s,%s,%.2f,0.00,%.2f,%s,%s,%.2f,%.2f,%.2f,0.00,0.00,%s\n",
                                 ticket, AccountInfoInteger(ACCOUNT_LOGIN), sym, typeStr, vol, price,
                                 TimeToString(time, TIME_DATE|TIME_SECONDS), TimeToString(time, TIME_DATE|TIME_SECONDS),
                                 profit, swap, comm, comment);
      FileWriteString(fileHandle, line);
   }

   FileClose(fileHandle);
   Print(">>> [DTD_Multiverse] 📓 ส่งออกประวัติการเทรดบันทึกลง CSV เรียบร้อยแล้ว");
}

//+------------------------------------------------------------------+
//| 9. HUD HELPER DRAWING FUNCTIONS                                  |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize = 8, bool isBold = false)
{
   if(StringLen(text) == 0) text = " ";
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 50);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   string font = isBold ? "Segoe UI Black" : "Segoe UI Semibold";
   ObjectSetString(0, name, OBJPROP_FONT, font);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color bgClr, color txtClr, int fontSize = 8)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 60);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI Bold");
}

void CreateRect(string name, int x, int y, int w, int h, color bgClr, color borderClr)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
}

void RenderWrappedLabel(string prefix, int x, int &curY, string text, color clr, int fontSize = 8, bool isBold = false, int maxChars = 56, int lineSpacing = 16)
{
   if(StringLen(text) == 0)
   {
      ObjectDelete(0, prefix);
      ObjectDelete(0, prefix + "_2");
      return;
   }
   if(StringLen(text) <= maxChars)
   {
      CreateLabel(prefix, x, curY, text, clr, fontSize, isBold);
      curY += lineSpacing;
      ObjectDelete(0, prefix + "_2");
   }
   else
   {
      int splitPos = maxChars;
      for(int i = maxChars; i >= 10; i--)
      {
         ushort uChar = StringGetCharacter(text, i);
         if(uChar == ' ' || uChar == '|' || uChar == '-' || uChar == ':')
         {
            splitPos = i + 1;
            break;
         }
      }
      string part1 = StringSubstr(text, 0, splitPos);
      string part2 = StringSubstr(text, splitPos);

      CreateLabel(prefix, x, curY, part1, clr, fontSize, isBold);
      curY += lineSpacing;
      CreateLabel(prefix + "_2", x, curY, part2, clr, fontSize, isBold);
      curY += lineSpacing;
   }
}
//+------------------------------------------------------------------+
