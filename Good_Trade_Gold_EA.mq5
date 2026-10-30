//+------------------------------------------------------------------+
//|                                           Good_Trade_Gold_EA.mq5 |
//|                                  Copyright 2026, Good Trade Gold |
//|                                       https://goodtradegold.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Good Trade Gold"
#property link      "https://goodtradegold.com"
#property version   "8.09"
#property description "Good Trade Gold - V8.09 CME Options Wall 21/10/2569 Calibration & Master Trading Suite"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMS & DEFINITIONS                                              |
//+------------------------------------------------------------------+
enum ENUM_TRADE_MODE
{
   TRADE_MODE_SAFE_COPILOT       = 0, // 🛡️ SAFE (ยิงมือ Co-Pilot / เปิดเกราะเทรนด์แม่ H1+H4 100%)
   TRADE_MODE_AGGRESSIVE_SNIPER  = 1  // ⚡ AGGRESSIVE (สไนเปอร์ Auto 100% / สวิงสั้น ปลดล็อกเกราะ)
};

enum ENUM_LOT_MODE
{
   LOT_FIXED        = 0, // ใช้ขนาด Lot คงที่ (Fixed Lot)
   LOT_RISK_PERCENT = 1  // ใช้ % ความเสี่ยงจาก Balance (Risk %)
};

enum ENUM_DAILY_GUARD_SCOPE
{
   GUARD_SCOPE_BOT_ONLY     = 0, // 🤖 บอทเท่านั้น (Bot Trades Only - ป้องกันเฉพาะไม้บอท ไม่ดึงไม้มือถือมาบล็อก)
   GUARD_SCOPE_ALL_COMBINED = 1  // 🌐 รวมทั้งพอร์ต (Bot + Mobile Co-Pilot รวมกัน)
};

enum ENUM_MARKET_TREND
{
   TREND_BULLISH = 1,    // ขาขึ้น (Higher High + Higher Low / Bullish BOS)
   TREND_BEARISH = -1,   // ขาลง (Lower Low + Lower High / Bearish BOS)
   TREND_SIDEWAY = 0     // ออกข้าง / พักตัว
};

enum ENUM_BOT_STATE
{
   STATE_WAIT_STRUCTURE, // กำลังรอตรวจจับโครงสร้างคลื่น Dow Theory / BOS / ChoCH
   STATE_WAIT_PULLBACK,  // เทรนด์ชัด รอราคาย่อตัวหาโซน Fibo (Wave 2 Pullback)
   STATE_PULLBACK_ARMED, // แตะโซน Fibo แล้ว (ARMED) - รอไกปืน Pure PA Rejection
   STATE_TRIGGER_READY,  // สัญญาณครบ พร้อมยิงออเดอร์เกาะคลื่น Wave 3
   STATE_IN_POSITION,    // มีออเดอร์ถืออยู่ กำลังดูแล Trailing & Partial TP
   STATE_DAILY_TARGET_HIT,// ถึงเป้ากำไรรายวันแล้ว (+2500 Cent) - ล็อกกำไรหยุดเทรดวันนี้ 🏆
   STATE_DAILY_LOSS_HIT   // ถึงขีดจำกัดขาดทุนรายวัน (-10%) - พักระบบรักษาเงินทุน 🛑
};

enum ENUM_SWING_TYPE
{
   SWING_NONE = 0,
   SWING_HH   = 1,  // Higher High
   SWING_HL   = 2,  // Higher Low
   SWING_LH   = 3,  // Lower High
   SWING_LL   = 4   // Lower Low
};

enum ENUM_STRUCTURE_EVENT
{
   STRUCT_NONE          = 0,
   STRUCT_BULLISH_BOS   = 1, // Break of Structure ขาขึ้น (ทำ HH ทะลุยอดเดิม)
   STRUCT_BEARISH_BOS   = 2, // Break of Structure ขาลง (ทำ LL ทะลุก้นเดิม)
   STRUCT_BULLISH_CHOCH = 3, // Change of Character กลับตัวขึ้น (ทะลุ LH เดิม)
   STRUCT_BEARISH_CHOCH = 4  // Change of Character กลับตัวลง (หลุด HL เดิม)
};

// ABCD Wave Structure & Leg Phases (Ep เสริม 4 Fibonacci Master Model)
enum ENUM_ABCD_LEG
{
   ABCD_LEG_NONE = 0,
   ABCD_LEG_A,       // ขา A 📈 (Impulse ต้นน้ำ)
   ABCD_LEG_B,       // ขา B ⏸️ (ยอดสวิงแรก / พักตัว)
   ABCD_LEG_C,       // ขา C 🛒 (ย่อโซน OTE 61.8-78.6% ช้อนซื้อ/ขาย)
   ABCD_LEG_D,       // ขา D 🚀 (ขยายคลื่น Target 161.8-200%)
   ABCD_LEG_SW       // ไซด์เวย์ ⏸️ (ในกรอบแคบ)
};

struct SABCDWaveData
{
   ENUM_ABCD_LEG leg;
   int           direction; // 1 = Bullish, -1 = Bearish, 0 = Sideway
   double        priceA;
   datetime      timeA;
   double        priceB;
   datetime      timeB;
   double        priceC;    // OTE midpoint or current pullback level
   double        priceD;    // 161.8% Target
   double        oteHigh;   // Box top
   double        oteLow;    // Box bottom
   string        legName;   // e.g. "ขา C 🛒"
   string        desc;      // e.g. "ย่อเข้า OTE 61.8%-78.6% (เตรียมช้อน)"
};

// Comprehensive Price Action & Pattern Encyclopedia
enum ENUM_PA_PATTERN
{
   PA_NONE = 0,
   // 1. Three-Candle Master Formations (จากรูป Morning/Evening Star & Soldiers)
   PA_MORNING_STAR,           // Morning Star (ดาวรุ่ง 3 แท่งกลับตัวขึ้น) ⭐️
   PA_EVENING_STAR,           // Evening Star (ดาวพลบค่ำ 3 แท่งกลับตัวลง) 💫
   PA_THREE_WHITE_SOLDIERS,   // Three White Soldiers (3 ทหารเสือเขียวดันเทรนด์) 💂‍♂️
   PA_THREE_BLACK_CROWS,      // Three Black Crows (3 อีกาดำทุบเทรนด์) 🦅
   PA_THREE_INSIDE_UP,        // Three Inside Up (Harami ยืนยันขึ้น) 📈
   PA_THREE_INSIDE_DOWN,      // Three Inside Down (Harami ยืนยันลง) 📉
   PA_THREE_OUTSIDE_UP,       // Three Outside Up (Engulfing ยืนยันขึ้น) 🚀
   PA_THREE_OUTSIDE_DOWN,     // Three Outside Down (Engulfing ยืนยันลง) 💥

   // 2. Two-Candle Formations (จากรูปคู่แท่งเทียน)
   PA_BULLISH_ENGULFING,      // Bullish Engulfing (แท่งเขียวกลืนกิน) 🟢
   PA_BEARISH_ENGULFING,      // Bearish Engulfing (แท่งแดงกลืนกิน) 🔴
   PA_PIERCING_LINE,          // Piercing Line (แทงทะลุ 50%) ⚡
   PA_DARK_CLOUD_COVER,       // Dark Cloud Cover (เมฆดำคลุม 50%) ☁️
   PA_TWEEZER_BOTTOM,         // Tweezer Bottom (แหนบคู่ก้นเท่า) 🥢
   PA_TWEEZER_TOP,            // Tweezer Top (แหนบคู่ยอดเท่า) 🥢
   PA_BULLISH_HARAMI,         // Bullish Harami (แท่งลูกในท้องแม่ขาขึ้น) 🤰
   PA_BEARISH_HARAMI,         // Bearish Harami (แท่งลูกในท้องแม่ขาลง) 🤰
   PA_BULLISH_KICKER,         // Bullish Kicker (กระโดดเปิดข้ามแท่ง) 🚀
   PA_BEARISH_KICKER,         // Bearish Kicker (กระโดดทุบข้ามแท่ง) 💥

   // 3. Single-Candle Sniper Patterns
   PA_BULLISH_PINBAR,         // Bullish Pin Bar / Hammer 🔨
   PA_BEARISH_PINBAR,         // Bearish Shooting Star / Hanging Man 💫
   PA_INVERTED_HAMMER,        // Inverted Hammer (ค้อนกลับหัว) 🔨
   PA_DRAGONFLY_DOJI,         // Dragonfly Doji (โดจิแมลงปอหางยาวล่าง) 🪓
   PA_GRAVESTONE_DOJI,        // Gravestone Doji (โดจิหินสลักหางยาวบน) 🪦
   PA_BULLISH_MARUBOZU,       // Bullish Marubozu (แท่งเขียวเต็มแท่งสถาบัน) 🟩
   PA_BEARISH_MARUBOZU,       // Bearish Marubozu (แท่งแดงเต็มแท่งสถาบัน) 🟥

   // 4. Chart Patterns & SMC Formations (จากรูป W-Bottom, Head & Shoulders, Wedges)
   PA_DOUBLE_BOTTOM,          // Double Bottom (W-Pattern) 📈
   PA_DOUBLE_TOP,             // Double Top (M-Pattern) 📉
   PA_TRIPLE_BOTTOM,          // Triple Bottom (ก้น 3 ชั้น) 🔱
   PA_TRIPLE_TOP,             // Triple Top (ยอด 3 ชั้น) 🔱
   PA_INVERTED_HEAD_SHOULDERS,// Inverted Head & Shoulders (หัวไหล่กลับหัว) 👤
   PA_HEAD_SHOULDERS,         // Head & Shoulders (หัวและไหล่กลับตัวลง) 👤
   PA_FALLING_WEDGE,          // Falling Wedge (ลิ่มลู่ลงเบรกขึ้น) 📐
   PA_LIQUIDITY_SWEEP_BUY,    // Liquidity Sweep Buy (สลัดหลุด Low ดึงกลับ) ⚡
   PA_LIQUIDITY_SWEEP_SELL,   // Liquidity Sweep Sell (ทิ่มทะลุ High ตบลง) ⚡
   PA_CRT_TURTLE_SOUP_BUY,    // CRT Turtle Soup Buy (กวาด SSL แล้วดีด) 🐢
   PA_CRT_TURTLE_SOUP_SELL,   // CRT Turtle Soup Sell (กวาด BSL แล้วรูด) 🔴
   PA_UNICORN_BUY,            // ICT Unicorn Model Buy (Breaker Block + Bullish FVG) 🦄
   PA_UNICORN_SELL,           // ICT Unicorn Model Sell (Breaker Block + Bearish FVG) 🦄
   PA_MOTHER_BAR_BUY,         // Sig ค้ำ Sig (Bullish Mother Bar Inside-Bar Reload) 🐟
   PA_MOTHER_BAR_SELL         // Sig ค้ำ Sig (Bearish Mother Bar Inside-Bar Reload) 🐟
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
//--- 1. STRATEGY SETTINGS (การตั้งค่ากลยุทธ์ Dow Wave & BOS)
input group "=== 1. กลยุทธ์นับคลื่นสวิง DOW WAVE + BOS + CHOCH ==="
input ENUM_TIMEFRAMES InpTimeframe         = PERIOD_CURRENT; // ไทม์เฟรมวิเคราะห์ (PERIOD_CURRENT / H1 / M15 / M5)
input int             InpSwingLookback     = 4;              // จำนวนแท่งสำหรับตรวจ Swing High/Low (3-5 กำลังดี)
input int             InpMinSwingPoints    = 350;            // ระยะสวิงคลื่นขั้นต่ำ (Points) ปรับตาม TF อัตโนมัติ
input bool            InpUseBOSFilter      = true;           // บังคับคอนเฟิร์ม Break of Structure (BOS) ก่อนเข้า
input bool            InpUseEMAFilter      = true;           // เปิดใช้ตัวกรองแนวโน้มหลักด้วย EMA (Trend Bias)
input int             InpEMAPeriod         = 50;             // คาบเวลาเส้น EMA (EMA 50)
input double          InpMinRR             = 1.00;           // อัตราความคุ้มค่า RR ขั้นต่ำ (TP / SL ต้อง >= 1.00)
input double          InpMinRejectionWickRatio = 0.30;       // สัดส่วนไส้เทียนปฏิเสธราคาขั้นต่ำ (Rejection Wick Ratio >= 30%)
input bool            InpRequireCandleColorFlip= true;       // คอนเฟิร์มการสลับสีแท่งเทียน (Candle Color Reversal Trigger)
input bool            InpUsePurePriceActionTrigger = true;   // เปิดระบบไกปืน Pure Price Action & Candlestick Rejection 🎯
input double          InpFiboGoldenMin     = 38.2;           // Fibo โซนเริ่มย่อ (% Retracement 38.2% หรือ 50%)
input double          InpFiboGoldenMax     = 78.6;           // Fibo โซนลึกสุด (% Retracement 78.6%)
input bool            InpUseFiboZoneGuard  = true;           // เปิดระบบกรองโซน Fibo Premium / Discount (ซื้อถูก ขายแพง ใน Safe Mode)
input int             InpArmedMaxBars      = 12;             // อายุการจำสถานะ Armed หลังแตะโซน (Bars)

//--- 2. PRICE ACTION & PATTERN RECOGNITION
input group "=== 2. รูปแบบ PRICE ACTION & AI PATTERN RECOGNITION ==="
input bool            InpUsePriceAction    = true;           // เปิดระบบจดจำ Price Action & Chart Patterns
input bool            InpUseSMC_Sweep      = true;           // เปิดระบบตรวจจับ Liquidity Sweep (SMC Spring/Upthrust)
input int             InpMinPatternScore   = 50;             // คะแนน Pattern ขั้นต่ำที่อนุญาตให้ออกไม้ (0-100)
input bool            InpUseVPAEngine      = true;           // เปิดระบบวิเคราะห์ VPA (Volume Absorption & Effort vs Result)
input bool            InpUseVPAClimaxGuard = true;           // เปิดระบบป้องกันดักยอด Volume Climax (Anti-Blowoff Spike)

//--- 3. MONEY & RISK MANAGEMENT (การจัดการเงินทุน)
input group "=== 3. จัดการเงินทุน (MONEY MANAGEMENT) ==="
input ENUM_TRADE_MODE InpStartTradeMode    = TRADE_MODE_SAFE_COPILOT; // โหมดการทำงานเริ่มต้น (🛡️ SAFE: ยิงมือ Co-Pilot / ⚡ AGGRESSIVE: สไนเปอร์ Auto)
input bool            InpStartAutoTrade    = true;           // เริ่มต้นเปิดเทรดอัตโนมัติ (Auto Trade)
input bool            InpAllowMultiPos     = false;          // อนุญาตให้เปิดหลายไม้พร้อมกัน
input ENUM_LOT_MODE   InpStartLotMode      = LOT_FIXED;      // โหมดคำนวณขนาดไม้
input double          InpStartFixedLot     = 0.02;           // ขนาด Lot เมื่อใช้โหมด Fixed Lot
input double          InpStartRiskPercent  = 1.0;            // % ความเสี่ยงต่อไม้ (เมื่อใช้โหมด Risk %)
input int             InpMaxOpenPos        = 3;              // จำนวนไม้สูงสุดที่อนุญาตให้เปิด
input int             InpMultiPosMinDist   = 250;            // ระยะห่างขั้นต่ำระหว่างไม้เมื่อเปิดหลายไม้ (Points / 25 pips)
input int             InpMaxSpreadPoints   = 80;             // สเปรดสูงสุดที่ยอมรับได้ (Points)
input ulong           InpMagicNumber       = 888999;         // Magic Number ประจำตัวบอท

//--- 4. SL, TP & PARTIAL TAKE-PROFIT MANAGEMENT
input group "=== 4. การจัดการ SL / TP / แบ่งปิดกำไร (PARTIAL TP) ==="
input bool            InpUseFiboTarget     = true;           // คำนวณ SL/TP อัตโนมัติจากโครงสร้าง Fibo & Dow
input int             InpFallbackSL_Points = 777;            // SL สำรองพ้นโซน Stop-Hunt (Points) (77.7 pips)
input int             InpFallbackTP_Points = 950;            // TP1 สำรองดักเก็บก่อนแนวต้าน (Points) (95 pips)
input int             InpFallbackTP2_Points= 1900;           // TP2 สำรองเป้าที่สอง (Points) (190 pips)
input int             InpFallbackTP3_Points= 2850;           // TP3 สำรองเป้าที่สาม (Points) (285 pips)
input bool            InpUsePartialTP      = true;           // เปิดใช้งานระบบแบ่งปิดกำไร 2 สเต็ป (Partial TP 80:20)
input double          InpPartialClosePct   = 80.0;           // % ขนาด Lot ที่จะแบ่งปิดกำไรเป้าแรก (80%)
input double          InpPartialTP_RR      = 1.23;           // ระยะ RR ของเป้าแรกก่อนปล่อยรันเทรนด์ (1.23 เท่าของ SL 777)
input bool            InpUseBreakEven      = true;           // เปิดใช้งานระบบกันทุน (Break Even)
input int             InpBreakEvenTrigger  = 450;            // ระยะกำไรที่ให้ขยับกันทุน (Points) (45 pips)
input int             InpBreakEvenLock     = 80;             // ระยะล็อกกำไรเหนือจุดเข้า (Points) (8 pips)
input bool            InpUseStepLocking    = true;           // เปิดระบบล็อกกำไรขั้นบันได 4 ระดับ (Milestone Step-Locking)
input int             InpStep2Trigger      = 700;            // ขั้น 2: ระยะกำไรถึง (Points) -> ล็อกกำไร +350 pts
input int             InpStep2Lock         = 350;            // ขั้น 2: ระยะล็อกกำไร (Points)
input int             InpStep3Trigger      = 950;            // ขั้น 3 (TP1): ระยะกำไรถึง (Points) -> ล็อกกำไร +800 pts
input int             InpStep3Lock         = 800;            // ขั้น 3: ระยะล็อกกำไรใต้ฐาน TP1 (Points)
input int             InpStep4Trigger      = 1900;           // ขั้น 4 (TP2): ระยะกำไรถึง (Points) -> ล็อกกำไร +1650 pts + Trailing
input int             InpStep4Lock         = 1650;           // ขั้น 4: ระยะล็อกกำไรใต้ฐาน TP2 (Points)
input bool            InpUseTrailing       = true;           // เปิดใช้งานระบบ Trailing Stop
input bool            InpUseAdaptiveTrailing = true;         // เปิดระบบ Adaptive Runner Trailing (ปรับระยะ Trailing ตาม ADX & ATR ยืดหยุ่น)
input int             InpTrailingStart     = 1900;           // ระยะกำไรเริ่มเปิด Trailing ปกติ (Points) (190 pips)
input int             InpTrailingDist      = 250;            // ระยะห่าง Trailing แนบกระชับหลังชน TP2 (Points) (25 pips)
input int             InpTrailingStep      = 80;             // ขยับ Trailing ทุกๆ (Points)

//--- 4.1 MOBILE CO-PILOT ASSISTANT (ดูแลไม้มือถือ / MANUAL TRADES)
input group "=== 📱 ผู้ช่วยอัจฉริยะคุมไม้มือถือ (MOBILE CO-PILOT) ==="
input bool            InpManageManualTrades = true;          // เปิดระบบ Mobile Co-Pilot ช่วยดูแลไม้ที่เปิดจากมือถือ (Magic 0)
input bool            InpAutoAddSL_Manual   = false;         // เติม SL อัตโนมัติให้ไม้มือถือ (false = ไม่ตั้ง SL ตามสั่งคุณเอ้)
input bool            InpAutoAddTP_Manual   = false;         // เติม TP อัตโนมัติให้ไม้มือถือ (false = ปล่อยอิสระ)
input int             InpManualDefaultSLPts = 0;             // ระยะ SL สำรองสำหรับไม้มือถือ (Points) (0 = ไม่ตั้ง SL)
input int             InpManualDefaultTPPts = 950;           // ระยะ TP สำรองสำหรับไม้มือถือ (Points) (0 = ไม่ตั้ง TP)
input bool            InpManualTrailingSync = true;          // เปิดใช้ Trailing Stop & Step-Locking ให้ไม้มือถือเมื่อมีกำไร

//--- 5. INSTITUTIONAL FILTERS & SESSION BOOSTER
input group "=== 5. ตัวกรองสถาบัน ข่าวแรง & ช่วงเวลาเทรด ==="
input bool            InpUseNewsShield        = true;           // เปิดระบบป้องกันสเปรดถ่างและแท่งกระชากผิดปกติ (News Shield)
input int             InpMaxNewsSpread        = 75;             // สเปรดสูงสุดที่ยอมให้เปิดไม้ (Points)
input bool            InpUseSpreadSpikeShield = true;           // เปิดระบบ Spread Spike Shield (ป้องกันสเปรดถ่างก่อนข่าว)
input int             InpSpreadSpikeMax       = 55;             // สเปรดสูงสุดที่ยอมให้ออกไม้ช่วงข่าว (Points / 5.5 pips รองรับทั้ง PU Prime & ETO Markets)
input bool            InpUseNewsCalendarGuard = true;           // เปิดเกราะดักข่าวแดง USD อัตโนมัติ (MQL5 Native Calendar Guard)
input int             InpNewsPreMinutes       = 15;             // ระยะเวลาก่อนข่าวออกที่ให้พักเปิดไม้ (นาที)
input int             InpNewsPostMinutes      = 10;             // ระยะเวลาหลังข่าวออกที่ให้รอความสงบ (นาที)
input bool            InpNewsStandDownAutoTrades = true;        // พักออกไม้ออโต้ช่วงข่าวแดงในโหมด Safe (true = เซฟพอร์ต / false = ปล่อยเทรดปกติ)
input bool            InpSessionBooster       = true;           // ตรวจจับช่วงเวลาทองคำ (London & NY) *นอกเวลาก็ออกไม้ปกติ
input int             InpLondonStartHour      = 10;             // เวลาเริ่มตลาดลอนดอน (Server Time)
input int             InpNYEndHour            = 22;             // เวลาปิดตลาดนิวยอร์ก (Server Time)
input bool            InpUseAsianRangeJudas   = true;           // เปิดระบบกรอบ Asian Range & ดักกิน London Judas Swing (14:00-18:00)
input double          InpMinWickToBodyRatio   = 1.2;            // สัดส่วนไส้เทียนต่อเนื้อเทียนขั้นต่ำของ CRT Turtle Soup (Wick >= 1.2 * Body)
input bool            InpUseMTFConfluence     = true;           // ระบบตรวจความสอดคล้อง Multi-Timeframe (M5+M15+H1)

//--- 6. PROP-FIRM DISCIPLINE & CAPITAL PROTECTION (ข้อ 3)
input group "=== 6. วินัยกองทุน ล็อกเป้ารายวัน & กัน DRAWDOWN (PROP FIRM) ==="
input bool            InpUseDailyGuard        = true;                  // เปิดระบบล็อกเป้ากำไรรายวัน & หยุดขาดทุน (Daily Guard)
input ENUM_DAILY_GUARD_SCOPE InpDailyGuardScope = GUARD_SCOPE_BOT_ONLY; // ขอบเขตระบบล็อกเป้า & ขาดทุน (Daily Guard Scope)
input double          InpDailyProfitTarget    = 2500.0;                // เป้ากำไรรายวันล็อกพอร์ต (+2500 Cent / +$25.00)
input double          InpDailyMaxLossPct      = 10.0;                  // ขีดจำกัดขาดทุนสูงสุดต่อวัน (% Balance เช่น -10%)
input bool            InpResetDailyGuardNow   = false;                 // สั่งรีเซ็ต Daily Guard ทันทีเมื่อเปิดพารามิเตอร์ (Reset Guard Now)
input bool            InpUseMobileAlerts      = true;                  // ส่งการแจ้งเตือน Push Notification เข้ามือถือ Real-time

//--- 6.1 KHUN ANN ANGEL & EMOTIONAL DISCIPLINE SHIELD (เกราะคุมสติ & ความปลอดภัยครอบครัว)
input group "=== ❤️ 6.1 เกราะคุมสติ & ความปลอดภัยครอบครัว (KHUN ANN ANGEL SHIELD) ==="
input bool            InpEnableEmotionalGuard     = true;   // เปิดระบบเกราะคุมสติ & ตักเตือนอารมณ์ (Khun Ann Angel Shield)
input bool            InpEnableRevengeShield      = false;  // [DEPRECATED / OFF] กฎล็อกสติ 15 นาที (ถอนออกตาม Master Plan - ใช้ Daily Max Loss แทน)
input int             InpRevengeCooldownMinutes   = 15;     // ระยะเวลาพักใจหลังปิดไม้ลบ (นาที) (Default: 15 นาที)
input bool            InpEnablePostSLBECooldown   = false;  // [DEPRECATED / OFF] พักระบบ 15 นาทีหลังโดน SL หรือกันหน้าทุน (ถอนออกตาม Master Plan)
input int             InpPostSLBECooldownMinutes  = 15;     // ระยะเวลาพักระบบหลังโดน SL หรือกันหน้าทุน (นาที) (Default: 15 นาที)
input bool            InpEnableRapidClickGuard    = true;   // เกราะป้องกันการกดรัวไม้ (Anti-Spam Rapid Entry)
input int             InpMinEntrySpacingSeconds   = 30;     // ระยะห่างเวลาขั้นต่ำระหว่างการออกไม้ (วินาที) (Default: 30 วิ)
input bool            InpEnableMaxVolumeCeiling   = true;   // เพดานกั้นขนาด Lot รวมทั้งพอร์ต (Max Volume Ceiling Guard)
input double          InpMaxTotalVolumeCap        = 1.00;   // ขนาด Lot รวมสูงสุดที่ยอมให้เปิดค้างในพอร์ต (Lots) (ป้องกัน 6.0 Lots)
input bool            InpLockManualOnMaxLoss      = true;   // ล็อกปุ่มกดเทรดมือบนหน้าจอทันทีเมื่อชน Max Daily Loss

//--- 6.2 SMART STRUCTURAL RE-ENTRY GUARD & ZONE RECOVERY SUITE
input group "=== 🎯 6.2 เกราะสไนเปอร์แก้มือในโซน (SMART STRUCTURAL RE-ENTRY GUARD) ==="
input bool            InpEnableSmartReEntryGuard  = true;   // เปิดระบบ Smart Re-Entry Guard (บล็อกราคาเดิม เว้นแต่อยู่ใน DZ/SZ + PA + Score 70%+)
input int             InpSamePriceLockBufferPts   = 250;    // รัศมีล็อกราคาเดิมที่เพิ่งโดน SL (Points) (Default: 250 จุด / 25 pips)
input int             InpReEntryMinScore          = 70;     // คะแนนคุณภาพขั้นต่ำสำหรับปลดล็อกยิงไม้แก้ตัวในโซน (%) (Default: 70%)
input bool            InpAllowReEntryOnBE         = true;   // ปลดล็อกทันทีเมื่อปิดไม้ชน Break-Even (มีกำไร/เท่าทุน) ไม่บล็อกราคา

//--- 7. ADVANCED SMC FAIR VALUE GAP & DYNAMIC ATR (ข้อ 1 & 2)
input group "=== 7. สไนเปอร์ SMC FAIR VALUE GAP (FVG) & DYNAMIC ATR ==="
input bool            InpUseFVG            = true;           // เปิดระบบตรวจจับ Fair Value Gap (FVG / Imbalance)
input int             InpMinFVG_Points     = 50;             // ขนาดช่องว่าง FVG ขั้นต่ำ (Points)
input color           InpColorBullishFVG   = C'0,180,255';   // สีกรอบ Bullish FVG (สีฟ้าสว่าง)
input color           InpColorBearishFVG   = C'235,110,20';  // สีกรอบ Bearish FVG (สีแสดโปร่ง)
input bool            InpUseDynamicATR     = true;           // เปิดระบบปรับ SL/TP ตามความผันผวนจริง (Dynamic ATR)
input int             InpATR_Period        = 14;             // คาบเวลาคำนวณ ATR (ATR 14)
input double          InpATR_Multiplier    = 1.5;            // ตัวคูณความผันผวน ATR สำหรับระยะบัฟเฟอร์ SL

//--- 8. SMC ORDER BLOCK & SUPPLY/DEMAND ZONES (OB / SZ)
input group "=== 8. โครงสร้างราคา ORDER BLOCK, UNICORN & CRT TURTLE SOUP ==="
input bool            InpUseOrderBlock     = true;           // เปิดระบบตรวจจับ Order Block & Supply/Demand (OB/SZ)
input bool            InpUseICT_Unicorn    = true;           // เปิดเรดาร์ ICT Unicorn Model (Breaker Block + FVG Confluence)
input bool            InpUseCRT_TurtleSoup = true;           // เปิดโหมด Candle Range Theory (CRT) & 3-Candle Turtle Soup
input bool            InpUseWickReversalSniper = true;       // เปิดใช้งานระบบสไนเปอร์ 50% Wick H1 + 3 แท่งมหาประลัย (Forex Lab)
input double          InpWickMinLengthPts     = 350.0;      // ความยาวไส้เทียน H1 ขั้นต่ำ (จุด) (Default: 350 pts / $3.50)
input double          InpWickMaxCounterRatio  = 0.30;       // สัดส่วนไส้เทียนต้านสูงสุดของแท่งยืนยัน (Default: 0.30 / 30%)
input bool            InpWickRequireRetest    = true;       // ดักย่อ Retest ครึ่งแท่ง (50% Retest) กรองไส้หลอก 100%
input int             InpOB_Lookback       = 30;             // จำนวนแท่งเทียนที่ใช้ค้นหา Base Candle ของ OB
input int             InpSniperMaxEntryTolerancePts = 80;    // ระยะคลาดเคลื่อนสูงสุดของราคาเข้าสไนเปอร์ (Points) (8 pips / $0.80)
input color           InpColorDemandOB     = C'20,80,185';   // สีกรอบ Bullish Demand OB (สีน้ำเงินโปร่งสว่าง)
input color           InpColorSupplyOB     = C'215,40,95';   // สีกรอบ Bearish Supply SZ (ชมพูแดง โปร่ง)

//--- 8.1 TWO-WAY BREAKOUT / BREAKDOWN SNIPER & ANTI-FAKEOUT SUITE
input group "=== 🚀 8.1 สไนเปอร์ BREAKOUT / BREAKDOWN & ระบบกรองเบรกหลอก (ANTI-FAKEOUT) ==="
input bool            InpUseBreakoutSniper        = true;   // เปิดสไนเปอร์ Breakout / Breakdown (Trend-Confirmed)
input int             InpBreakoutMinScore         = 60;     // คะแนนคุณภาพขั้นต่ำของ Breakout/Breakdown (55 - 65%)
input double          InpBreakoutWickMaxRatio     = 0.35;   // สัดส่วนไส้เทียนสูงสุดที่ยอมรับได้ (Wick Ratio <= 35%) ป้องกันไส้กวาดหลอก
input int             InpBreakoutMinBodyPts       = 100;    // ขนาดเนื้อเทียนทะลุขั้นต่ำสำหรับทองคำ (Points) (100 pts / $1.00)
input bool            InpBreakoutRequireTrend     = true;   // บังคับเบรกตามแนวโน้มหลัก H1/H4 เท่านั้น (ห้ามเบรกสวนเทรนด์)

//--- 9. การจัดการความเสี่ยง & FAST TRAILING (55 จุด)
input group "=== 9. การจัดการความเสี่ยง & FAST TRAILING (55 จุด) ==="
input bool            InpUseSweepFastTrail = true;           // เปิด Trailing แบบรวดเร็วพิเศษ 55 จุด (สำหรับไม้เปิดมือ/จังหวะฉาบฉวย)
input int             InpSweepTrailStart   = 100;            // ระยะกำไรเริ่มเปิด Trailing (Points) (10 pips)
input int             InpSweepTrailStep    = 55;             // ขยับ Trailing ทุกๆ (Points) (55 จุดตามสั่ง)

//--- 10. VISUALS & GUI (การแสดงผลบนกราฟ)
input group "=== 10. หน้าต่างควบคุมและกราฟิก (VISUALS & GUI) ==="
input bool            InpShowVisuals       = true;           // แสดงเส้น Fibo, จุด Swing (HH/HL) และ BOS
input bool            InpShowDashboardGUI  = true;           // แสดงหน้าต่างรายงานสถานะ (Dashboard) เริ่มต้น
input bool            InpShowControlsGUI   = true;           // แสดงหน้าต่างแผงควบคุม (Controls) เริ่มต้น
input color           InpColorBullish      = clrLime;        // สีฝั่ง Buy / Bullish
input color           InpColorBearish      = clrCrimson;     // สีฝั่ง Sell / Bearish
input color           InpColorFiboZone     = clrDarkSlateGray;// สีโซน Golden Zone Fibo

//--- 11. SMC INSTITUTIONAL VISUAL SUITE (BOS, LIQUIDITY, POC & ZONES)
input group "=== 11. กราฟิกสถาบัน SMC VISUAL SUITE (BOS, LIQUIDITY, POC & ZONES) ==="
input bool            InpShowSMC_BOS       = true;           // แสดงเส้น Break of Structure (BOS / CHoCH / MSS)
input bool            InpShowSMC_Liquidity = true;           // แสดงโซนสภาพคล่อง Equal Highs / Lows (EQH / EQL)
input bool            InpShowSMC_StrongWeak= true;           // แสดงป้าย Strong Low / Weak High & Strong High / Weak Low
input bool            InpShowSMC_MTFZones  = true;           // แสดงกล่อง Demand & Supply ซ้อนระดับ (M5, M15, H1)
input bool            InpShowSMC_POC       = true;           // แสดงเส้น Point of Control (POC) & Low Volume Node (LVN)
input bool            InpShowSMC_BSL_SSL   = true;           // แสดงระบบเรดาร์สภาพคล่อง BSL / SSL Multi-TF บนชาร์ต
input color           InpColorBSL          = C'244,63,94';   // สีเส้น BSL (จุดดักกิน SL Sell เพื่อทุบลง)
input color           InpColorSSL          = C'16,185,129';  // สีเส้น SSL (จุดดักกิน SL Buy เพื่อช้อนขึ้น)
input color           InpColorBSL_Text     = clrWhite;       // สีตัวหนังสือ BSL (ขาวสว่าง คอนทราสต์สูง ไม่กลืนกับโซน Supply)
input color           InpColorSSL_Text     = clrWhite;       // สีตัวหนังสือ SSL (ขาวสว่าง คอนทราสต์สูง ไม่กลืนกับโซน Demand)

enum ENUM_SPIKE_MODE
{
   SPIKE_SEMI_AUTO = 0, // โหมดเรดาร์แจ้งเตือน (กดยิงมือ 🎯 Semi-Auto)
   SPIKE_FULL_AUTO = 1  // โหมดเทรดอัตโนมัติ (Full-Auto)
};

//--- 12. SPIKE REVERSAL & FLASH SNIPER ENGINE
input group "=== 12. ระบบดักแท่งกระชากกลับตัว (SPIKE REVERSAL & FLASH SNIPER) ==="
input bool            InpEnableSpikeSniper = true;            // เปิดระบบตรวจจับ Spike Reversal & Sniper Radar
input ENUM_SPIKE_MODE InpSpikeMode         = SPIKE_SEMI_AUTO; // โหมดการทำงาน (แนะนำ: Semi-Auto สั่งมือ)
input int             InpSpikeMinPoints    = 400;             // ระยะกระชากขั้นต่ำของแท่งเทียน (Points)
input double          InpMinWickPercent    = 40.0;            // สัดส่วนไส้เทียนปฏิเสธราคาขั้นต่ำ (%)
input bool            InpRequireHTFZone    = true;            // บังคับต้องพุ่งชนโซนสถาบัน (H1/H4/D1 หรือ Fibo)
input int             InpSpikeSL_Buffer    = 80;              // ระยะบัฟเฟอร์ SL แนบปลายไส้ (Points)
input int             InpSpikeTP_Target    = 500;             // ระยะทำกำไรเป้าหมาย Quick Reversal (Points)

//--- 13. ADX MOMENTUM TURBO GATE & ELLIOTT WAVE DUAL SWING
input group "=== 13. ADX MOMENTUM TURBO GATE & ELLIOTT WAVE DUAL SWING ==="
input bool               InpUseADXTurboGate   = true;             // เปิดระบบ ADX Momentum Turbo Gate (ปรับเป้าหมาย TP ตามความแรงตลาด)
input int                InpADX_Period        = 14;               // ADX Period
input double             InpADX_TurboLevel    = 25.0;             // เกณฑ์ Super Turbo Trend (>= 25)
input double             InpADX_RangeLevel    = 20.0;             // เกณฑ์ Sideway / Range Scalp (< 20)
input bool               InpEnableElliottWave = true;             // เปิดระบบ Elliott Wave Dual Swing (P0 ➔ P1 ➔ P2)
input bool               InpUseADXFilter      = false;            // เปิดตัวกรองแรงเทรนด์ ADX Multi-TF (ค่าเริ่มต้น: ปิดเพื่อไม่ให้หน่วงการออกไม้)
input int                InpADX_Threshold     = 20;               // ระดับความแรง ADX ขั้นต่ำ (> 20 ถือว่ามีเทรนด์)
input ENUM_TIMEFRAMES    InpADX_TF1           = PERIOD_M5;        // ADX Timeframe 1
input ENUM_TIMEFRAMES    InpADX_TF2           = PERIOD_M15;       // ADX Timeframe 2
input ENUM_TIMEFRAMES    InpADX_TF3           = PERIOD_H1;        // ADX Timeframe 3
input bool               InpShowElliottVisuals= true;             // แสดงเส้นสวิงหลัก (P0-P1-P2) และป้าย c = P2 (Buy Zone)

//--- 14. INSTITUTIONAL ANTI-PEAK & ANTI-BOTTOM EXHAUSTION GUARDS
input group "=== 14. เกราะป้องกัน BUY ยอดดอย & SELL ก้นเหว (ANTI-EXHAUSTION GUARDS) ==="
input bool   InpUseATRExtensionGuard    = true;  // เปิดเกราะป้องกันคลื่นยืดตัวเกินพิกัด (ATR Over-Extension)
input double InpMaxImpulseATRFactor     = 3.2;   // ระยะวิ่งต่อเนื่องสูงสุดที่ยอมให้ออกไม้ (เท่าของ ATR)
input bool   InpUseHTFMacroGuard        = true;  // เปิดเกราะป้องกันการเทรดสวนทางเทรนด์ใหญ่ (H1+H4 Macro Lock)
input bool   InpUseHTFPrecisionGuard    = true;  // เปิดเกราะ HTF Samurai Midline & Falling Knife Guard
input int    InpH1FallingKnifeDumpPts   = 400;   // เกณฑ์ตรวจจับแท่งมีดร่วง H1 (Points จาก Open) (40 pips)
input bool   InpH1MidlineCheck          = true;  // บังคับราคาต้องอยู่เหนือเส้นกลาง H1 สำหรับ BUY (และใต้เส้นกลางสำหรับ SELL)
input bool   InpH1SingleBarEMACheck     = true;  // ดักจับ H1 หลุด EMA50 ทันทีโดยไม่ต้องรอ H4 (H1 Decoupling)

//--- 14.1 INSTITUTIONAL Z-SCORE & CME OPTIONS WALL SUPER-CONFLUENCE
input group "=== 14.1 สถิติ Z-SCORE & กำแพงเจ้ามือ CME OPTIONS WALL ==="
input bool   InpUseZScoreGuard          = true;    // 📊 เปิดระบบสถิติความเบี่ยงเบน Z-Score Mean Reversion
input int    InpZScorePeriod            = 50;      // ช่วงแท่งเทียนคำนวณ Z-Score (Lookback Period)
input double InpZScoreThreshold         = 2.0;     // ระดับความเบี่ยงเบนวิกฤตดักกลับตัว Extreme SD (±2.0 SD)
input bool   InpUseCMEWallGuard         = true;    // 🏛️ เปิดระบบกำแพงสภาพคล่องเจ้ามือ CME Options Wall Guard
input double InpCME_CallWall            = 4400.0;  // 🔴 CME Call Wall (เพดานเจ้ามือ Strike 4400 • 2,871 OI • ดักทุบ Sell)
input double InpCME_MegaCallWall        = 4500.0;  // 🚨 CME MEGA Call Wall (ซูเปอร์เพดานสถาบัน Strike 4500 • 10,133 OI)
input double InpCME_IntermediateCall    = 4350.0;  // 🔶 CME Intermediate Call (แนวต้านย่อย Half-Century Strike 4350 • 1,439 OI)
input double InpCME_PutWall             = 4300.0;  // 🟢 CME Put Wall (พื้นเจ้ามือ Strike 4300 • 3,293 OI • ดักช้อน Buy)
input double InpCME_IntermediatePut     = 4250.0;  // 🔷 CME Intermediate Put (แนวรับย่อย Half-Century Strike 4250 • 2,466 OI)
input double InpCME_MacroPutWall        = 4200.0;  // 🛡️ CME Macro Put Base (ฐานรับใหญ่สถาบัน Strike 4200 • 2,525 OI / 2,489 Call OI)
input int    InpCME_ProximityPts        = 600;     // 🛡️ ระยะดักตรวจจับก่อนถึงกำแพงหลัก (Points) (600 pts = $6.00 ดักล้างไม้ Sell 4305 และยอดดอย/ก้นเหว)
input int    InpCME_IntermedProxPts     = 300;     // 🛡️ ระยะดักตรวจจับแนวปะทะย่อย .50 (Points) (300 pts = $3.00)
input bool   InpCME_ReversalSniper      = true;    // 🎯 เปิดระบบ CME Reversal Sniper Flip (ดักช้อน Buy ก้นเหว & ดักทุบ Sell ยอดดอย)
input datetime InpCME_ExpiryDate        = D'2026.11.24'; // ⏳ วันหมดอายุของสัญญาออปชันหลัก (OGZ6)
input int    InpCME_DTE                 = 35;      // ⏳ จำนวนวันคงเหลือก่อนหมดอายุ (Days To Expiration - 34.67 DTE)
input bool   InpDrawCMEWalls            = true;    // แสดงเส้นระดับกำแพง CME ทุกระดับบนชาร์ต
input bool   InpSafeRequireReversalConfirm = true; // 🛡️ Safe Mode: บังคับแท่งเทียนคอนเฟิร์มสมบูรณ์ก่อนออกไม้กลับตัว (True Reversal Confirmation)
input bool   InpCME_WallCautionEngine   = true;    // 🏛️ เปิดเกราะระวังโซนกำแพง CME Wall (บล็อกออกไม้ผิดฝั่ง + ดักคอนเฟิร์มก่อนสวน)

//--- 15. HTF ZONE & CANDLESTICK REVERSAL SNIPER ENGINE
input group "=== 15. สไนเปอร์แท่งเทียนกลับตัวที่โซนสถาบัน (HTF ZONE CANDLESTICK REVERSAL) ==="
input bool   InpEnableHTFReversalSniper  = false; // เปิดระบบสไนเปอร์ช้อนซื้อ Demand & ดักขาย Supply สถาบัน (ค่าเริ่มต้น ปิด เพื่อเน้น Fibo 61.8% บริสุทธิ์)
input bool   InpRequireCandleReversal    = true;  // บังคับต้องมีแท่งเทียนคอนเฟิร์ม (Pinbar/Hammer/Engulfing/PA Rejection)
input int    InpHTFReversalSL_Buffer     = 60;    // ระยะบัฟเฟอร์ SL นอกกล่องโซน (Points)
input double InpHTFReversalMinRR         = 2.5;   // อัตรา Risk:Reward ขั้นต่ำของการช้อนโซนสถาบัน (1:2.5+)

//--- 16. ATH SMART CONFLUENCE & MACRO GPS ENGINE (กรอบราคา ATH พ่อชล & แม่ปลา)
input group "=== 16. กรอบราคา ATH SMART CONFLUENCE & MACRO GPS ENGINE ==="
input bool   InpUseATHGrid               = true;  // เปิดระบบกรอบราคา ATH (Macro GPS Grid)
input bool   InpDrawATHLines             = true;  // แสดงเส้นแนวรับ-ต้าน ATH อัตโนมัติบนชาร์ต (Smart 2-Lines)
input bool   InpUseATHFrontRunning       = true;  // เปิดระบบชิงปิดกำไรตัดหน้าแนวต้าน ATH (Front-Running TP)
input bool   InpUseATRAntiPeakGuard      = true;  // เปิดเกราะป้องกันการเปิด BUY จ่อแนวต้าน ATH (Anti-Peak Guard)
input int    InpATHProximityPts          = 120;   // รัศมีตรวจจับแนวต้าน ATH (Points) (12 pips)
input int    InpATHFrontRunOffset        = 70;    // ระยะหด TP ใต้แนวต้าน ATH (Points) (7 pips)

//--- 18. SAMURAI-EA MTF STRIP & COUNTDOWN FUSION ENGINE
input group "=== 18. แถบแท่งเทียน MTF SAMURAI (SAMURAI-EA MTF FUSION) ==="
input bool   InpUseSamuraiMTFStrip       = true;  // ผสานระบบแถบแท่งเทียน MTF ของ Samurai-EA อัตโนมัติ (เปิดแสดงผลอัตโนมัติ)
input bool   InpSamuraiGoldenAlert       = true;  // เปิดระบบไฟเตือนสีทอง (Golden Flash Alert เมื่อเหลือ <= 15 วินาที)
input bool   InpUseSamuraiMTFConfluence  = true;  // ผสานระบบวิเคราะห์แนวโน้ม Samurai MTF กับทุกระบบเทรด (+15 Confluence Bonus)
input bool   InpUseSamuraiHTFGuard       = true;  // ป้องกันการเปิดไม้ออโต้สวนทางเทรนด์ใหญ่ H1/H4 ของ Samurai MTF (HTF Guard)

//--- 19. LINEAR REGRESSION CHANNEL & DUAL-PERIOD HYBRID ENGINE
enum ENUM_LRL_CHANNEL_MODE
{
   LRL_MODE_EXACT_WICKS     = 0, // 🎯 Samurai Exact Wicks (แนบปลายไส้สูงสุดและต่ำสุดพอดีเป๊ะ 100%)
   LRL_MODE_SYMMETRIC_WICKS = 1, // 📐 Samurai Symmetric Wicks (กรอบคู่ขนานสมมาตรระยะเท่ากัน)
   LRL_MODE_STDDEV_CLOSE    = 2  // 📊 Standard Deviation (±2.0σ ของราคาปิดแบบเดิม)
};

input group "=== 19. ระบบ LINEAR REGRESSION CHANNEL & DUAL-PERIOD HYBRID ==="
input bool                  InpEnableLRLChannel         = true;                  // เปิดใช้งานระบบ Linear Regression Channel
input ENUM_LRL_CHANNEL_MODE InpLRL_ChannelMode          = LRL_MODE_EXACT_WICKS;  // โหมดกรอบราคา (🎯 Samurai Exact Wicks แนบปลายไส้พอดีเป๊ะ)
input int                   InpLRL_ChartBars            = 100;                   // จำนวนแท่งคำนวณบนชาร์ตปัจจุบัน (Execution TF) (100 แท่ง)
input int                   InpLRL_HTFBars              = 200;                   // จำนวนแท่งคำนวณบน Timeframe สูงกว่า (HTF Anchor) (200 แท่ง)
input double                InpLRL_WickMultiplier       = 1.0;                   // ตัวคูณขยายกรอบปลายไส้ (1.0 = แนบปลายไส้พอดี 100%)
input double                InpLRL_StdDevMultiplier     = 2.0;                   // ตัวคูณความกว้าง Channel (สำหรับโหมด StdDev ±2.0σ)
input double                InpLRL_TrendAngleThreshold  = 12.0;                  // องศาความชันขั้นต่ำสำหรับยืนยันเทรนด์ (องศา) (±12°)
input bool                  InpLRL_FilterEntries        = true;                  // บังคับกรองเทรนด์ด้วย LRL HTF (ห้ามเทรดสวนเทรนด์แม่ 200 แท่ง)
input bool                  InpLRL_BonusDipBuy          = true;                  // เพิ่มคะแนนสัญญาณเมื่อราคาย่อแตะขอบล่าง/บน Channel
input bool                  InpLRL_ShowCloud            = false;                 // เปิดแถบสีเมฆโปร่งแสงในกรอบ (Default: false เพื่อชาร์ตคลีน โปร่ง สบายตาระดับ Samurai Workstation)
input bool                  InpLRL_RayRight             = false;                 // ยิงเส้นต่อเข้าสู่อนาคตทะลุขอบจอ (Ray Right: ปิดไว้เพื่อให้กรอบครอบพอดีแท่งเทียน)

//--- 20. MULTI-TF EMA 14 MATRIX & INSTITUTIONAL EMA 200 SUITE (FOREX LAB P'CHANUT STYLE)
input group "=== 🟣 20. ระบบแถบเส้นม่วง MULTI-TF EMA 14 & สถาบัน EMA 200 (FOREX LAB) ==="
input bool            InpShowMultiTF_EMA14       = true;           // แสดงเส้นสีม่วง Multi-TF EMA 14 บนชาร์ต (W1, D1, H4, H1, M30, M15, M5, M1)
input bool            InpUseMultiTF_EMA14_Logic  = true;           // นำโครงสร้าง Multi-TF EMA 14 น้ำตก & ชนไส้ มาคำนวณ Confluence Score (+15 pts)
input color           InpColorEMA14_Lines        = C'185,100,255'; // สีเส้น Multi-TF EMA 14 (สีม่วงนีออน FOREX LAB)
input bool            InpShowEMA200_Line         = true;           // แสดงเส้นหลักสถาบัน EMA 200 บนชาร์ตปัจจุบัน
input color           InpColorEMA200_Line        = C'255,215,0';   // สีเส้นสถาบัน EMA 200 (สีทองอำพัน Bright Gold)
input bool            InpUseEMA200_Filter        = true;           // ใช้ EMA 200 เป็นตัวกรองเทรนด์ใหญ่และโบนัสซูเปอร์สไนเปอร์ (+10-15 pts)

enum ENUM_ADX_TURBO_MODE
{
   ADX_MODE_TURBO = 0,   // 🚀 SUPER TURBO RUNNER (ADX >= 25)
   ADX_MODE_NORMAL = 1,  // 🟢 STANDARD WAVE 3 (20 <= ADX < 25)
   ADX_MODE_RANGE = 2    // 🟡 RANGE / QUICK SCALP (ADX < 20)
};

enum ENUM_ASSET_CLASS
{
   ASSET_GOLD = 0,    // 🥇 ทองคำ (XAUUSD, GOLD)
   ASSET_SILVER = 1,  // 🥈 แร่เงิน (XAGUSD, SILVER)
   ASSET_FOREX = 2,   // 💱 คู่เงิน Forex (EURUSD, GBPUSD, ฯลฯ)
   ASSET_CRYPTO = 3,  // ₿ คริปโต (BTCUSD, ETHUSD, ฯลฯ)
   ASSET_INDEX = 4    // 📊 ดัชนี (US30, NAS100, ฯลฯ)
};

struct S_AssetProfile
{
   ENUM_ASSET_CLASS assetType;
   string           categoryName;
   string           iconStr;
   int              maxSpread;
   int              minSwing;
   int              fallbackSL;
   int              fallbackTP;
   int              spikeMinPts;
   int              newsBodyPts;
   int              beTrigger;
   int              beLock;
   int              trailStart;
   int              trailDist;
   int              trailStep;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES & STRUCTURES                                    |
//+------------------------------------------------------------------+
struct SSwingPoint
{
   datetime        time;
   double          price;
   int             type;       // 1 = High, -1 = Low
   ENUM_SWING_TYPE labelType;  // HH, HL, LH, LL
   string          labelStr;   // "HH", "HL", "LH", "LL"
   int             barIndex;
};

struct SFiboLevels
{
   double p0;
   double p236;
   double p382;
   double p500;
   double p618;
   double p786;
   double p100;
   double p1272;
   double p1618;
   double p2618;
   double zoneHigh;
   double zoneLow;
   bool   isInsideZone;
   double distanceToZone;
};

struct SFVGZone
{
   datetime time;
   double   topPrice;
   double   bottomPrice;
   int      direction; // 1 = Bullish FVG, -1 = Bearish FVG
   bool     isActive;
};

struct S_OrderBlock
{
   datetime time;
   double   topPrice;
   double   bottomPrice;
   int      direction; // 1 = Bullish Demand, -1 = Bearish Supply
   bool     isActive;
   string   label;
};

struct S_BOS_Line
{
   datetime timeStart;
   datetime timeEnd;
   double   price;
   string   tag;       // "BOS", "CHoCH", "MSS"
   color    col;
   bool     isActive;
};

struct S_LiquidityPool
{
   datetime timeStart;
   datetime timeEnd;
   double   price;
   string   tag;       // "EQH", "EQL"
   color    col;
   bool     isActive;
};

struct S_LiquidityTarget
{
   double          price;
   int             distancePts;
   ENUM_TIMEFRAMES tf;
   string          tfStr;
   string          typeStr;    // "EQH", "SWING", "PDH", "EQL", "PDL"
   datetime        time;
   bool            isValid;
   bool            isSwept;
};

struct S_BSL_SSL_Radar
{
   S_LiquidityTarget bsl;      // Buy-Side Liquidity (จุดดักกิน SL SELL เพื่อทุบ Sell กลับลงมา!)
   S_LiquidityTarget ssl;      // Sell-Side Liquidity (จุดดักกิน SL BUY เพื่อช้อน Buy บินกลับขึ้นไป!)
   datetime          lastScanTime;
   bool              bslSwept;
   bool              sslSwept;
   datetime          bslSweptTime;
   datetime          sslSweptTime;
};

struct S_MTF_Zone
{
   datetime        timeStart;
   datetime        timeEnd;
   double          topPrice;
   double          bottomPrice;
   int             direction;  // 1 = Demand, -1 = Supply
   string          tfName;     // "Demand M5", "Demand M15", etc.
   color           boxColor;
   bool            isActive;
};

struct S_SpikeSignal
{
   bool     isValid;
   int      direction;     // 1 = Buy Reversal, -1 = Sell Reversal
   datetime barTime;
   double   entryPrice;
   double   slPrice;
   double   tpPrice;
   double   spikeRange;
   double   wickRange;
   string   reason;
};

struct S_HTFReversalSignal
{
   bool     isValid;
   int      direction;     // 1 = Buy (Demand Reversal), -1 = Sell (Supply Reversal)
   datetime barTime;
   double   entryPrice;
   double   slPrice;
   double   tpPrice;
   double   tp1Price;
   double   tp2Price;
   double   tp3Price;
   string   zoneName;
   string   patternName;
   string   reason;
};

//+------------------------------------------------------------------+
//| CRT & ICT UNICORN STRUCTURES & GLOBAL STATES                     |
//+------------------------------------------------------------------+
enum ENUM_CRT_STATE
{
   CRT_NONE = 0,
   CRT_BULLISH_SWEEP, // กวาด LQ ด้านล่าง (SSL) แล้วรูดกลับเข้ากรอบ • ดัก BUY 🟢
   CRT_BEARISH_SWEEP  // กวาด LQ ด้านบน (BSL) แล้วรูดกลับเข้ากรอบ • ดัก SELL 🔴
};

enum ENUM_UNICORN_STATE
{
   UNICORN_NONE = 0,
   UNICORN_BULLISH,   // Bullish Unicorn (Breaker Block + FVG ซ้อนทับ) 🟢
   UNICORN_BEARISH    // Bearish Unicorn (Breaker Block + FVG ซ้อนทับ) 🔴
};

struct S_CRT_Setup
{
   ENUM_CRT_STATE state;
   datetime       triggerTime;
   double         refLevel;       // ระดับ Swing High/Low ของแท่งที่ 1
   double         sweepExtreme;   // ปลายไส้แท่งที่ 2 (จุดวาง SL สไนเปอร์)
   double         retestMidpoint; // ระดับ 50% กึ่งกลางสำหรับดักเข้า
   int            barIndex;
   bool           isActive;
};

struct S_Unicorn_Setup
{
   ENUM_UNICORN_STATE state;
   datetime           triggerTime;
   double             breakerTop;     // ขอบบนของ Breaker Block
   double             breakerBottom;  // ขอบล่างของ Breaker Block
   double             fvgTop;         // ขอบบนของ FVG
   double             fvgBottom;      // ขอบล่างของ FVG
   double             overlapTop;     // ขอบบนโซนซ้อนทับ
   double             overlapBottom;  // ขอบล่างโซนซ้อนทับ
   bool               isActive;
};

struct S_ElliottSubWave
{
   datetime time;
   double   price;
   string   label;       // "1", "2", "3", "4", "5", "a", "b", "c"
   int      type;        // 1 = High, -1 = Low
};

struct S_ElliottState
{
   SSwingPoint       P0;
   SSwingPoint       P1;
   SSwingPoint       P2;
   S_ElliottSubWave  subWaves[8]; // 1, 2, 3, 4, 5, a, b, c
   int               subWaveCount;
   bool              isImpulseValid;
   bool              isCorrectionValid;
   bool              isCConfirmed;
   bool              isADXValid;
   string            statusStr;
};

// Global Trading Objects
CTrade         m_trade;
CPositionInfo  m_position;
CAccountInfo   m_account;
CSymbolInfo    m_symbol;

// Indicator Handles
int            m_hEMA      = INVALID_HANDLE;
int            m_hEMA_M1   = INVALID_HANDLE;
int            m_hEMA_M5   = INVALID_HANDLE;
int            m_hEMA_M15  = INVALID_HANDLE;
int            m_hEMA_M30  = INVALID_HANDLE;
int            m_hEMA_H1   = INVALID_HANDLE;
int            m_hEMA_H4   = INVALID_HANDLE;
int            m_hEMA_D1   = INVALID_HANDLE;
int            m_hEMA_W1   = INVALID_HANDLE;
int            m_hEMA200   = INVALID_HANDLE;
int            m_hATR      = INVALID_HANDLE;
int            m_hADX_TF1  = INVALID_HANDLE;
int            m_hADX_TF2  = INVALID_HANDLE;
int            m_hADX_TF3  = INVALID_HANDLE;

// State Variables
bool              g_AutoTradeEnabled   = true;
bool              g_AllowMultiPos      = false;
ENUM_LOT_MODE     g_LotMode            = LOT_FIXED;
double            g_CurrentLot         = 0.02;
double            g_RiskPercent        = 1.0;
bool              g_BreakEvenEnabled   = true;
bool              g_ShowVisuals        = true;
bool              g_ShowDashboard      = true;
bool              g_ShowControls       = true;
bool              g_Card1_Expanded     = true;
bool              g_Card2_Expanded     = true;
bool              g_Card3_Expanded     = true;
bool              g_Card4_Expanded     = true;
bool              g_Ctrl_Expanded      = true;
bool              g_ShowMTFStrip       = true;
bool              g_ShowABCDWave       = true;
bool              g_ShowEMAVisuals     = true;
string            g_SmartActionCommand = "⏸️ ตลาด SIDEWAY (นั่งทับมือก่อน ⏳)";
string            g_SmartActionSubtext = "↳ ยังไม่เกิด ChoCH / BOS ➔ ห้ามออกไม้เด็ดขาด (รอฟอร์มคลื่น)!";
color             g_SmartActionColor   = clrGold;
string            g_MTF_ABCD_Summary   = "";
string            g_MTF_ABCD_Sub       = "";
string            g_MTF_ABCD_Macro     = "";

// Dual-Mode Hybrid Trading Engine State
ENUM_TRADE_MODE   g_TradeMode          = TRADE_MODE_SAFE_COPILOT;
bool              g_HTFMacroGuardActive = true;
bool              g_LRLFilterActive     = true;
bool              g_AutoSniperActive    = false;
bool              g_FiboGuardActive     = true;

ENUM_MARKET_TREND    g_MarketTrend        = TREND_SIDEWAY;
ENUM_BOT_STATE       g_BotState           = STATE_WAIT_STRUCTURE;
ENUM_STRUCTURE_EVENT g_StructEvent        = STRUCT_NONE;
string               g_StructEventName    = "NONE";
double               g_StructLevel        = 0;
datetime             g_StructTime         = 0;
string               g_WaveStatusStr      = "WAVE 1 (ค้นหาโครงสร้าง)";
bool                 g_BOS_Confirmed      = false;
double               g_BOS_Level          = 0;
string               g_SessionName        = "ACTIVE";
string               g_MTF_StatusStr      = "M5:🟢 M15:🟢 M30:🟢 H1:🟢 H4:🟢 D1:🟢 (100%)";
string               g_EMACrossStatusStr  = "EMA Cross: กำลังประมวลผล...";
color                g_EMACrossValCol     = clrGold;
color                g_EMACrossBarCol     = clrDarkGoldenrod;
color                g_EMACrossTitleCol   = clrKhaki;
string               g_ExhaustionGuardMsg = "";
bool                 g_ExhaustionActive   = false;

// Directional Bias & Probability Weighting Engine (BUY 0-100% vs SELL 0-100%)
int                  g_MarketBiasBuyPct    = 50;
int                  g_MarketBiasSellPct   = 50;
string               g_MarketBiasAdvice    = "🟡 ตลาดไซด์เวย์ 50:50 (พักมือ / รอเลือกข้าง)";
color                g_MarketBiasAdviceCol = clrGold;
int                  g_MTF_BullPct         = 50;

// Price Action, FVG & Pattern State
ENUM_PA_PATTERN      g_DetectedPattern    = PA_NONE;
string               g_PatternName        = "กำลังสแกนหาแท่งเทียน...";
int                  g_PatternScore       = 0;
string               g_SetupGrade         = "NORMAL";
SFVGZone             g_ActiveFVG;
bool                 g_FVG_Active         = false;
S_OrderBlock         g_ActiveOB;
bool                 g_OB_Active          = false;

SSwingPoint       g_LastSwingHigh;
SSwingPoint       g_LastSwingLow;
SSwingPoint       g_PrevSwingHigh;
SSwingPoint       g_PrevSwingLow;
SFiboLevels       g_Fibo;

// Pullback Armed State Machine
bool              g_PullbackArmed      = false;
datetime          g_ArmedTime          = 0;
int               g_ArmedBarCount      = 0;
datetime          g_LastTradeBarTime   = 0;

// Pure Price Action & Candlestick Rejection Triggers (Option A Institutional Clean Build)
bool              g_PABuyTrigger       = false;
bool              g_PASellTrigger      = false;
string            g_PARejectionType    = "";

// Planned Trade Setup
double            g_PlanEntry = 0, g_PlanSL = 0, g_PlanTP = 0, g_PlanRR = 0;
double            g_PlanTP1 = 0, g_PlanTP2 = 0, g_PlanTP3 = 0;
double            g_PlanRR1 = 0, g_PlanRR2 = 0, g_PlanRR3 = 0;
int               g_PlanDirection = 0; // +1 = BUY, -1 = SELL, 0 = NONE
string            g_PlanSource    = ""; // "WAVE", "SPIKE", "HTF_REVERSAL"

// Partial TP Ticket Tracking Memory
ulong             g_PartialTP_Tickets[];

// Prop Firm Daily Target State
bool              g_DailyTargetReached       = false;
bool              g_DailyMaxLossReached      = false;
bool              g_DailyGuardManualUnlocked = false; // True when user manually clicks [🔓 ปลดล็อก]
double            g_DailyGuardBaselinePnL    = 0.0;   // Baseline closed PnL at the moment of reset
datetime          g_DailyGuardResetDay       = 0;     // Day (startOfDay) of manual unlock
double            g_TodayPnL                 = 0.0;
double            g_TodayPnLPct              = 0.0;

// Khun Ann Angel & Emotional Discipline Shield Global State
datetime          g_RevengeCooldownUntil = 0;
int               g_PostCloseCooldownRemainSec = 0;
double            g_LastLossAmount       = 0.0;
datetime          g_LastLossTime         = 0;
datetime          g_LastAnyOrderTime     = 0;

// 🛡️ Post-SL & Post-BE 15-Minute Cooldown Guard State
datetime          g_PostSLBECooldownUntil  = 0;
string            g_PostSLBECooldownReason = "";

// 🎯 Smart Structural Re-Entry Guard State (No same-price spam unless in DZ/SZ + PA + Score >= 70%)
// 🔭 50% Wick Equilibrium & 3-Candle Sniper State (Forex Lab P'Chanut Style)
struct S_WickSniper_Setup
{
   bool              isActive;             // True when a valid 50% Wick setup is detected
   ENUM_ORDER_TYPE   direction;            // ORDER_TYPE_BUY or ORDER_TYPE_SELL
   datetime          h1BarTime;            // Timestamp of H1 candle
   double            wickHigh;             // Wick high price
   double            wickLow;              // Wick low price
   double            wickEquilibrium;      // 50% midpoint of wick
   double            wickLengthPts;        // Length of wick in points
   double            entryPrice;           // Suggested entry price
   double            stopLoss;             // Stop Loss price
   double            takeProfit1;          // TP1 level
   double            takeProfit2;          // TP2 level
   bool              priceInWickZone;      // Price testing wick area
   bool              candleCloseConfirmed; // Candle 2 closed with solid body & small counter-wick
   bool              retestArmed;          // Candle 3 micro-retest armed
   int               qualityScore;         // Quality score (0-100)
   string            description;          // Thai description
};
S_WickSniper_Setup   g_WickSniper_Setup;

double            g_LastStoppedPrice       = 0.0;
int               g_LastStoppedDir         = 0;   // 1 = BUY, -1 = SELL
datetime          g_LastStoppedTime        = 0;
double            g_LastStoppedProfit      = 0.0;
bool              g_ReEntryUnlocked        = false;
string            g_ReEntryUnlockReason    = "";

// 🟣 Multi-TF EMA 14 Matrix & Institutional EMA 200 State (FOREX LAB P'Chanut Style)
struct S_MultiTF_EMA14
{
   ENUM_TIMEFRAMES tf;
   string          tfName;
   double          val;
   color           col;
};
S_MultiTF_EMA14   g_MultiTF_EMA14[8]; // W1, D1, H4, H1, M30, M15, M5, M1
double            g_CurrentEMA200     = 0.0;
double            g_HTF_EMA200        = 0.0;
bool              g_EMA14_CascadeDown = false; // H4 > H1 > M30 > M15 > M5 (Sell Cascade)
bool              g_EMA14_CascadeUp   = false; // H4 < H1 < M30 < M15 < M5 (Buy Cascade)
bool              g_EMA14_NearTest    = false; // Near any key EMA14
string            g_EMA14_StatusText  = "↳ 🟡 สถานะ EMA 14: รอการประมวลผล ⏳";
color             g_EMA14_StatusCol   = clrGold;

// ⚔️ SAMURAI-EA MULTI-TIMEFRAME CONFLUENCE & MOMENTUM STRUCTURE
struct SSamuraiMTFState
{
   bool              isBullish[6];     // M1, M5, M15, M30, H1, H4
   bool              isBearish[6];
   double            momentumPct[6];   // Momentum % per TF (Samurai Momentum Meter)
   double            bullScore;        // 0.0 to 100.0%
   int               consensusDir;     // +1 Bullish, -1 Bearish, 0 Neutral
   string            summaryStr;       // e.g. "M1:🟢 M5:🟢 M15:🟢 M30:🟢 H1:🔴 H4:🟢"
   string            gradeStr;         // e.g. "⚔️ SAMURAI MTF: STRONG BUY (83%)"
   bool              htfAgreesBuy;     // H1 & H4 agree Bullish
   bool              htfAgreesSell;    // H1 & H4 agree Bearish
};
SSamuraiMTFState g_SamuraiMTF;

// 🟣 Multi-TF EMA 14 & EMA 200 Indicator Handles
int               m_hEMA14_W1         = INVALID_HANDLE;
int               m_hEMA14_D1         = INVALID_HANDLE;
int               m_hEMA14_H4         = INVALID_HANDLE;
int               m_hEMA14_H1         = INVALID_HANDLE;
int               m_hEMA14_M30        = INVALID_HANDLE;
int               m_hEMA14_M15        = INVALID_HANDLE;
int               m_hEMA14_M5         = INVALID_HANDLE;
int               m_hEMA14_M1         = INVALID_HANDLE;
int               m_hEMA200_Current   = INVALID_HANDLE;
int               m_hEMA200_H1        = INVALID_HANDLE;

// ADX Momentum Turbo Gate & Adaptive Trailing Global State
int                 m_hADX_Current       = INVALID_HANDLE;
double              g_LiveADX_Val        = 0.0;
ENUM_ADX_TURBO_MODE g_ADXMode            = ADX_MODE_NORMAL;
string              g_ADXStatusStr       = "ADX: Initializing...";
string              g_AdaptiveTrailModeStr = "STANDARD (1.5x ATR)";

// SMC Institutional Visual Arrays & Spike Signal & Elliott State & Asset Profile
S_BOS_Line          g_SMC_BOS_Lines[];
S_LiquidityPool     g_SMC_LiquidityPools[];
S_MTF_Zone          g_SMC_MTF_Zones[];
double              g_SessionPOC = 0;
double              g_SessionLVN = 0;
S_SpikeSignal       g_SpikeSignal;
S_HTFReversalSignal g_HTFReversal;
S_ElliottState      g_ElliottState;
S_AssetProfile      g_AssetProfile;
S_BSL_SSL_Radar     g_LQ_Radar;
S_CRT_Setup         g_CRT_Setup;
S_Unicorn_Setup     g_Unicorn_Setup;

// 📰 MQL5 Native News Calendar Guard State
bool              g_NewsStandDownActive  = false;
string            g_NewsEventTitle       = "";
int               g_NewsMinutesUntil     = 0;
datetime          g_LastNewsCheckTime    = 0;

// 🏛️ Asian Range & London Judas Swing State
double            g_AsianRangeHigh       = 0.0;
double            g_AsianRangeLow        = 0.0;
datetime          g_AsianRangeDate       = 0;
bool              g_AsianRangeValid      = false;
bool              g_JudasSellActive      = false;
bool              g_JudasBuyActive       = false;

// 📊 Institutional Z-Score Mean Reversion & CME Wall Global State
double            g_LiveZScore           = 0.0;
string            g_ZScoreStatusStr      = "Z: 0.00 SD";
bool              g_ZScoreExtremePeak    = false; // Z >= +2.0 SD (Extreme Peak)
bool              g_ZScoreExtremeValley  = false; // Z <= -2.0 SD (Extreme Abyss)
bool              g_CME_NearCallWall     = false;
bool              g_CME_NearMegaCallWall = false;
bool              g_CME_NearPutWall      = false;
bool              g_CME_NearMacroPutWall = false;
bool              g_CME_NearIntermedCall = false;
bool              g_CME_NearIntermedPut  = false;
bool              g_CME_ExpirationAlert  = false; // DTE <= 3 days (Gamma Pinning Zone)
int               g_CME_LiveDTE          = 56;    // Real-time Days To Expiration

// 🛡️ Safe Mode True Reversal Confirmation & CME Wall Caution States
bool              g_ReversalArmedPendingConfirm = false;
int               g_ReversalPendingDir          = 0;
string            g_ReversalPendingReason       = "";

// GUI Object Prefix & In-EA Auto-Updater Config
#define GUI_PREFIX               "GTG_UI_"
#define BOT_VERSION              "8.09"
#define UPDATE_MANIFEST_URL      "https://raw.githubusercontent.com/eaeybaent51-creator/Good-Trade-Gold-Releases/main/version.json"
#define UPDATE_EX5_FALLBACK_URL  "https://raw.githubusercontent.com/eaeybaent51-creator/Good-Trade-Gold-Releases/main/Good_Trade_Gold_EA.ex5"

// In-EA Auto-Updater State
string            g_LatestVersion      = BOT_VERSION;
string            g_DownloadUrl        = UPDATE_EX5_FALLBACK_URL;
string            g_ReleaseNotes       = "";
bool              g_UpdateAvailable    = false;
datetime          g_LastUpdateCheck    = 0;
string            g_UpdateStatusText   = "v8.05 â— à¸¥à¹ˆà¸²à¸ªà¸¸à¸”";
bool              g_ShowATHGrid        = true;

// Linear Regression Channel & Dual-Period Hybrid State
enum ENUM_LRL_TREND
{
   LRL_TREND_BULLISH = 1,  // ขาขึ้น (Slope > 0, Angle > Threshold)
   LRL_TREND_BEARISH = -1, // ขาลง (Slope < 0, Angle < -Threshold)
   LRL_TREND_SIDEWAY = 0   // ไซด์เวย์ (แบนราบ |Angle| <= Threshold)
};

struct SLinearRegressionResult
{
   ENUM_LRL_TREND  trend;
   double          slope;
   double          angle;
   double          intercept;
   double          stdDev;
   double          devUpper;
   double          devLower;
   double          upperPrice;
   double          medianPrice;
   double          lowerPrice;
   datetime        timeStart;
   datetime        timeEnd;
};

bool                    g_ShowLRLChannel       = true;
SLinearRegressionResult g_LRL_Chart;
ENUM_LRL_TREND          g_LRL_HTF_Consensus    = LRL_TREND_SIDEWAY;
double                  g_LRL_HTF_AvgAngle     = 0.0;
string                  g_LRL_MTF_Summary      = "";

// Forward Declarations
void CheckRemoteUpdate(bool isManual=false);
void TriggerAutoUpdate();
bool CalculateLinearRegression(ENUM_TIMEFRAMES tf, int period, SLinearRegressionResult &res);
void UpdateLinearRegressionEngine();
void DrawLinearRegressionVisuals();
void RemoveLinearRegressionVisuals();
void UpdateMultiTF_EMA14_Engine();
void DrawMultiTF_EMA14_Visuals();
void RemoveMultiTF_EMA14_Visuals();
bool IsPriceInsideDemandZone(double price, double bufferPts = 30.0);
bool IsPriceInsideSupplyZone(double price, double bufferPts = 30.0);
bool CheckSmartReEntryGuard(ENUM_ORDER_TYPE orderType, double currentPrice, int qualityScore, string &blockReason);
string ExtractJsonValue(const string &json, const string &key);
void AutoDetectAssetProfile();
void UpdateADXMomentumTurboGate();
void GetTimeframeAdaptiveSLTP(ENUM_TIMEFRAMES tf, int &slPts, int &tp1Pts, int &tp2Pts, int &tp3Pts);
//+------------------------------------------------------------------+
//| GET ADAPTIVE DYNAMIC SL BOUNDS BY MODE & ASSET TYPE              |
//+------------------------------------------------------------------+
void GetDynamicSLBounds(double &outMinSL, double &outMaxSL)
{
   if(g_AssetProfile.assetType == ASSET_GOLD)
   {
      if(g_TradeMode == TRADE_MODE_SAFE_COPILOT)
      {
         outMinSL = 777.0;  // 🛡️ SAFE: ล็อก SL ขั้นต่ำ 777 จุด (.77) ทนเหวี่ยง กินคำใหญ่ รัน H1/Wave 3
         outMaxSL = 1000.0; // เพดานสูงสุด 1,000 จุด (.00) ป้องกันการลากเกินกรอบ
      }
      else // TRADE_MODE_AGGRESSIVE_SNIPER
      {
         outMinSL = 250.0; // ⚡ AGGRESSIVE: สไนเปอร์คมกริบ SL ตามไส้จริง ขั้นต่ำ 250 จุด (.50)
         outMaxSL = 777.0; // เพดานสูงสุดไม่เกิน 777 จุด (.77) เป็นตาข่ายนิรภัยสูงสุด
      }
   }
   else if(g_AssetProfile.assetType == ASSET_CRYPTO)
   {
      outMinSL = (double)g_AssetProfile.fallbackSL * 0.50;
      outMaxSL = (double)g_AssetProfile.fallbackSL * 2.0;
   }
   else // ASSET_FOREX or others
   {
      if(g_TradeMode == TRADE_MODE_SAFE_COPILOT)
      {
         outMinSL = MathMax((double)g_AssetProfile.fallbackSL * 0.80, 200.0);
         outMaxSL = MathMax((double)g_AssetProfile.fallbackSL * 2.0, 500.0);
      }
      else
      {
         outMinSL = MathMax((double)g_AssetProfile.fallbackSL * 0.40, 100.0);
         outMaxSL = MathMax((double)g_AssetProfile.fallbackSL * 1.50, 400.0);
      }
   }
}
void CalculateAdaptiveTrailingDistance(ulong ticket, double &trailDistPts, double &trailStepPts, string &trailModeStr);
bool IsSniperPlan(string src)
{
   return (src == "UNICORN" || src == "CRT" || src == "SPIKE" || src == "HTF_REVERSAL" || src == "REVERSAL" || src == "BREAKDOWN" || src == "BREAKOUT");
}
bool CheckDemandZoneProximityGuard(ENUM_ORDER_TYPE orderType, double currentPrice, string &blockReason);
bool CheckSupplyZoneProximityGuard(ENUM_ORDER_TYPE orderType, double currentPrice, string &blockReason);
bool CheckAntiPeakGuard(ENUM_ORDER_TYPE orderType, double currentPrice, string &blockReason, bool isSniperSetup=false);
bool CheckAntiBottomGuard(ENUM_ORDER_TYPE orderType, double currentPrice, string &blockReason, bool isSniperSetup=false);
bool IsTradeAllowedByExhaustionGuard(ENUM_ORDER_TYPE orderType, string &blockReason, bool isSniperSetup=false);
bool CheckHTFPrecisionTrendGuard(ENUM_ORDER_TYPE orderType, string &blockReason);
bool CheckRevengeCooldownGuard(string &blockReason);
bool CheckPostSLBECooldownGuard(string &blockReason);
bool CheckAntiSpamRapidEntryGuard(string &blockReason);
bool CheckMaxVolumeCeilingGuard(double nextLot, string &blockReason);
double GetTotalOpenVolume();
void GetNearestATHLevels(double currentPrice, double &nearestSupport, double &nearestResistance);
double AdjustTPForATHFrontRunning(ENUM_ORDER_TYPE orderType, double entryPrice, double standardTP, double nearestSup, double nearestRes);
bool IsATHPeakGuardBlocked(ENUM_ORDER_TYPE orderType, double currentPrice, string &blockReason);
void UpdateATHGridLines(double currentPrice);
void UpdateZScoreEngine();
void UpdateCMEWallEngine();
void DrawCMEWallVisuals();
void SmartWrapText(const string rawText, int maxCharsLine1, string &line1, string &line2);
void SmartWrapText3(const string rawText, int maxCharsLine1, int maxCharsLine2, string &line1, string &line2, string &line3);
void FormatStateBannerLines(const string rawState, color stateCol, string &line1, string &line2, color &col1, color &col2);
void DetectHTFZoneReversalTrigger();
void ExecuteHTFReversalOrder();
void AnalyzeMarketStructure();
void CalculateFibonacci();
void DetectFairValueGaps();
void DetectOrderBlocks();
void DetectUnicornModel();
void DetectCandleRangeTheory();
void DetectWickReversalSniper();
void AnalyzePriceActionAndPatterns();
void UpdatePriceActionTriggers();
void UpdateEMACrossStatus();
void UpdateMarketSessionAndMTF();
void CheckDailyGuard();
void CalculateMarketDirectionalBias();
void EvaluateBotStateAndPlan();
bool IsDistanceAllowedForMultiPos(ENUM_ORDER_TYPE orderType, double currentPrice);
void ManageOpenPositions();
void ExecuteAutoTradeLogic();
void ExecuteManualOrder(ENUM_ORDER_TYPE orderType);
void ExecuteSpikeSniperOrder();
void CloseAllPositions();
double CalculateLotSize(double entryPrice, double stopLoss);
void AdjustLot(double delta);
int CountOpenPositions(bool includeManual=false);
double CalculateTotalProfit();
void GetClosedTradeStats(int &total, int &wins, int &losses, double &netPnl, double &winRate);
void GetTodayClosedTradeStats(int &todayTotal, int &todayWins, int &todayLosses, double &todayNetPnl, double &todayWinRate,
                              int &manTotal, int &manWins, int &manLosses, double &manNetPnl);
string GetGVKey(string tag);
void ApplyTradeMode(ENUM_TRADE_MODE mode);
void SavePersistentGUIState();
void LoadPersistentGUIState();
bool IsPartialTP_Executed(ulong ticket);
void MarkPartialTP_Executed(ulong ticket);
void SendTradeNotification(string msg);
bool IsCentAccount();
string FormatMoney(double amount, bool showSign=false);
void CreateFullGUI();
void UpdateHUDValues();
void SetRow(string rowTag, string title, string val, color valCol=clrWhite, color barCol=clrSteelBlue, color titleCol=clrSilver);
void SyncSamuraiMTFIndicator(bool enable);
void UpdateSamuraiMTFGoldenAlert();
void UpdateSamuraiMTFConfluenceEngine();
void DrawChartVisuals();
void DrawFiboLine(string name, string desc, double price, color col, ENUM_LINE_STYLE style, int width=1);
void DrawPlanLine(string name, string desc, double price, color col, ENUM_LINE_STYLE style, int width=2);
void RemoveActivePlanVisuals();
string FormatPlanDistStr(double pts, bool isLoss);
void DrawSwingText(string name, datetime t, double price, string text, color col);
void DrawStructureLine(string name, string desc, double price, color col);
void DetectStructureBreaks(const SSwingPoint &rawSwings[], int count, const MqlRates &rates[], int totalBars);
void DetectLiquidityPools(const SSwingPoint &rawSwings[], int count);
bool CheckMQL5NewsCalendarGuard(string &eventTitle, int &minsUntil);
void AutoPreNewsBreakevenGuard();
void UpdateAsianRangeAndJudasEngine();
void DrawAsianRangeBox();
SABCDWaveData CalculateABCDWave(ENUM_TIMEFRAMES tf, string symbol="");
string GetMultiTimeframeABCDSummary();
string GetMultiTimeframeABCDSummary_Sub();
string GetMultiTimeframeABCDSummary_Macro();
void UpdateSmartActionCommand(int openCount);
void DrawABCDWaveVisuals();

//+------------------------------------------------------------------+
//| TIME-FRAME HIERARCHY HELPER (ACTIVE TF UP TO D1)                 |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetCurrentExecutionTF()
{
   if(InpTimeframe == PERIOD_CURRENT)
      return (ENUM_TIMEFRAMES)_Period;
   return InpTimeframe;
}

int GetTFRank(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return 1;
      case PERIOD_M5:  return 2;
      case PERIOD_M15: return 3;
      case PERIOD_M30: return 4;
      case PERIOD_H1:  return 5;
      case PERIOD_H4:  return 6;
      case PERIOD_D1:  return 7;
      case PERIOD_W1:  return 8;
      case PERIOD_MN1: return 9;
      default:         return 3;
   }
}

void DetectMTFOrderBlocks();
void CalculateSessionPOC();
void DetectSpikeReversalSignal();
void AnalyzeElliottDualSwings();
bool ValidateADXTrend();
void DrawElliottVisuals();
void DrawSMCVisuals();
void UpdateLiquidityRadar();
void DrawLiquidityRadarVisuals();
void RemoveLiquidityRadarVisuals();
void DrawSwingBadge(string name, datetime t, double price, string text, color col, bool isHigh);
void RemoveVisualDrawings();
void CreateRectLabel(string name, int x, int y, int w, int h, color bg, color border, int borderWidth=1);
void CreateLabel(string name, int x, int y, string text, string font="Segoe UI", int size=9, color col=clrWhite);
void CreateButton(string name, int x, int y, int w, int h, string text, color bg, color textCol=clrWhite);
void CreateEdit(string name, int x, int y, int w, int h, string text, color bg, color textCol=clrLime);
void UpdateButtonState(string name, string text, color bg);
void DestroyGUI();

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // 0. Auto-Detect Asset Profile (Gold, Silver, Forex, Crypto, Indices)
   AutoDetectAssetProfile();

   // 1. Initialize Symbol & Trade
   if(!m_symbol.Name(_Symbol))
   {
      Print("Error: Failed to initialize Symbol ", _Symbol);
      return INIT_FAILED;
   }
   m_symbol.Refresh();
   Print(">>> [BROKER AUDIT] Symbol: ", _Symbol, " LotsMin: ", m_symbol.LotsMin(), " LotsStep: ", m_symbol.LotsStep(), " LotsMax: ", m_symbol.LotsMax(), " TradeAllowed: ", TerminalInfoInteger(TERMINAL_TRADE_ALLOWED), " MQLAllowed: ", MQLInfoInteger(MQL_TRADE_ALLOWED));

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(30);

   // Adaptive Broker Trade Filling Engine (Ensures 100% execution across PU Prime, ETO Markets, Exness, IC Markets)
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_IOC) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else if((filling & SYMBOL_FILLING_FOK) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   // 2. Initialize Indicator Handles (EMA, MTF, ATR)
   m_hEMA    = iMA(_Symbol, InpTimeframe, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_hEMA200 = iMA(_Symbol, InpTimeframe, 200, 0, MODE_EMA, PRICE_CLOSE);

   if(InpUseMTFConfluence || InpUseHTFMacroGuard)
   {
      m_hEMA_M1  = iMA(_Symbol, PERIOD_M1,  50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA_M5  = iMA(_Symbol, PERIOD_M5,  50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA_M15 = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA_M30 = iMA(_Symbol, PERIOD_M30, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA_H1  = iMA(_Symbol, PERIOD_H1,  50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA_H4  = iMA(_Symbol, PERIOD_H4,  50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA_D1  = iMA(_Symbol, PERIOD_D1,  50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA_W1  = iMA(_Symbol, PERIOD_W1,  50, 0, MODE_EMA, PRICE_CLOSE);
   }

   if(InpUseDynamicATR || InpUseATRExtensionGuard)
   {
      m_hATR = iATR(_Symbol, InpTimeframe, InpATR_Period);
   }

   if(InpUseADXTurboGate)
   {
      m_hADX_Current = iADX(_Symbol, InpTimeframe, InpADX_Period);
   }

   if(InpUseADXFilter)
   {
      m_hADX_TF1 = iADX(_Symbol, InpADX_TF1, 14);
      m_hADX_TF2 = iADX(_Symbol, InpADX_TF2, 14);
      m_hADX_TF3 = iADX(_Symbol, InpADX_TF3, 14);
   }

   // 2.1 Multi-TF EMA 14 Matrix & Institutional EMA 200 Handles (FOREX LAB P'Chanut Style)
   if(InpShowMultiTF_EMA14 || InpUseMultiTF_EMA14_Logic)
   {
      m_hEMA14_W1  = iMA(_Symbol, PERIOD_W1,  14, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA14_D1  = iMA(_Symbol, PERIOD_D1,  14, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA14_H4  = iMA(_Symbol, PERIOD_H4,  14, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA14_H1  = iMA(_Symbol, PERIOD_H1,  14, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA14_M30 = iMA(_Symbol, PERIOD_M30, 14, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA14_M15 = iMA(_Symbol, PERIOD_M15, 14, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA14_M5  = iMA(_Symbol, PERIOD_M5,  14, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA14_M1  = iMA(_Symbol, PERIOD_M1,  14, 0, MODE_EMA, PRICE_CLOSE);
   }

   if(InpShowEMA200_Line || InpUseEMA200_Filter)
   {
      m_hEMA200_Current = iMA(_Symbol, InpTimeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA200_H1      = iMA(_Symbol, PERIOD_H1,    200, 0, MODE_EMA, PRICE_CLOSE);
   }

   // 3. Load Persistent Interactive States from GlobalVariables / Inputs
   LoadPersistentGUIState();

   // 4. Clean Chart & Create Graphical HUD
   ChartSetInteger(0, CHART_SHOW_ONE_CLICK, false);
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, false);
   DestroyGUI();
   ObjectsDeleteAll(0, GUI_PREFIX + "MTF_");
   UpdateSamuraiMTFConfluenceEngine();
   CreateFullGUI();

   // 4.0 Auto-Sync Samurai-EA MTF Strip Indicator if enabled
   if(InpUseSamuraiMTFStrip && g_ShowMTFStrip)
   {
      SyncSamuraiMTFIndicator(true);
   }

   // 4.1 Synchronize State with Existing Open Positions (Anti-TF Switch Guard)
   int existingPos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol)
         existingPos++;
   }
   if(existingPos > 0)
   {
      g_BotState = STATE_IN_POSITION;
      g_PullbackArmed = false;
      g_LastTradeBarTime = (datetime)SeriesInfoInteger(_Symbol, InpTimeframe, SERIES_LASTBAR_DATE);
      Print(">>> 🛡️ [ANTI-TF SWITCH GUARD] Detected ", existingPos, " active position(s). Synced BotState to IN_POSITION.");
   }

   // 5. Remote Version Check (Background)
   CheckRemoteUpdate(false);

   // 6. Enable Event Timer
   EventSetTimer(1);

   if(InpUseAsianRangeJudas)
      UpdateAsianRangeAndJudasEngine();
   if(InpUseNewsCalendarGuard)
   {
      string dummyNews = "";
      int dummyMins = 0;
      CheckMQL5NewsCalendarGuard(dummyNews, dummyMins);
   }

   UpdateMarketSessionAndMTF();
   CalculateMarketDirectionalBias();
   UpdateSmartActionCommand(existingPos);
   if(g_ShowDashboard)
      UpdateHUDValues();

   ChartRedraw();
   Print("Good Trade Gold EA V", BOT_VERSION, " Initialized with In-EA Auto-Updater & Anti-Peak Guard.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   SavePersistentGUIState();
   EventKillTimer();
   
   if(m_hEMA != INVALID_HANDLE)
      IndicatorRelease(m_hEMA);

   if(m_hEMA200 != INVALID_HANDLE)
      IndicatorRelease(m_hEMA200);

   if(m_hEMA_M1 != INVALID_HANDLE)
      IndicatorRelease(m_hEMA_M1);

   if(m_hEMA_M5 != INVALID_HANDLE)
      IndicatorRelease(m_hEMA_M5);

   if(m_hEMA_M15 != INVALID_HANDLE)
      IndicatorRelease(m_hEMA_M15);

   if(m_hEMA_M30 != INVALID_HANDLE)
      IndicatorRelease(m_hEMA_M30);

   if(m_hEMA_H1 != INVALID_HANDLE)
      IndicatorRelease(m_hEMA_H1);

   if(m_hEMA_H4 != INVALID_HANDLE)
      IndicatorRelease(m_hEMA_H4);

   if(m_hEMA_D1 != INVALID_HANDLE)
      IndicatorRelease(m_hEMA_D1);

   if(m_hEMA_W1 != INVALID_HANDLE)
      IndicatorRelease(m_hEMA_W1);

   if(m_hATR != INVALID_HANDLE)
      IndicatorRelease(m_hATR);

   if(m_hADX_Current != INVALID_HANDLE)
      IndicatorRelease(m_hADX_Current);

   if(m_hADX_TF1 != INVALID_HANDLE)
      IndicatorRelease(m_hADX_TF1);

   if(m_hADX_TF2 != INVALID_HANDLE)
      IndicatorRelease(m_hADX_TF2);

   if(m_hADX_TF3 != INVALID_HANDLE)
      IndicatorRelease(m_hADX_TF3);

   if(m_hEMA14_W1 != INVALID_HANDLE)  IndicatorRelease(m_hEMA14_W1);
   if(m_hEMA14_D1 != INVALID_HANDLE)  IndicatorRelease(m_hEMA14_D1);
   if(m_hEMA14_H4 != INVALID_HANDLE)  IndicatorRelease(m_hEMA14_H4);
   if(m_hEMA14_H1 != INVALID_HANDLE)  IndicatorRelease(m_hEMA14_H1);
   if(m_hEMA14_M30 != INVALID_HANDLE) IndicatorRelease(m_hEMA14_M30);
   if(m_hEMA14_M15 != INVALID_HANDLE) IndicatorRelease(m_hEMA14_M15);
   if(m_hEMA14_M5 != INVALID_HANDLE)  IndicatorRelease(m_hEMA14_M5);
   if(m_hEMA14_M1 != INVALID_HANDLE)  IndicatorRelease(m_hEMA14_M1);
   if(m_hEMA200_Current != INVALID_HANDLE) IndicatorRelease(m_hEMA200_Current);
   if(m_hEMA200_H1 != INVALID_HANDLE)      IndicatorRelease(m_hEMA200_H1);

   RemoveMultiTF_EMA14_Visuals();

   DestroyGUI();
   RemoveVisualDrawings();
   
   ChartRedraw();
   Print("Good Trade Gold EA Removed. Cleanup done.");
}

//+------------------------------------------------------------------+
//| EXPERT TICK HANDLER (ULTRA-LOW LATENCY EXECUTION + SILKY SMOOTH GUI) |
//+------------------------------------------------------------------+
void OnTick()
{
   m_symbol.RefreshRates();

   ulong curTickMs = GetTickCount64();
   static ulong lastAnalysisTickMs = 0;
   static ulong lastGuiTickMs = 0;
   static double lastPriceCheck = 0;
   double curBid = m_symbol.Bid();

   // 1. High-Efficiency Analysis Engine (Micro-throttled to 150ms or on 10 pts price jump)
   bool needAnalysis = (curTickMs - lastAnalysisTickMs >= 150) || (MathAbs(curBid - lastPriceCheck) >= (10 * _Point));
   if(needAnalysis)
   {
      lastAnalysisTickMs = curTickMs;
      lastPriceCheck = curBid;

      AnalyzeMarketStructure();
      CalculateFibonacci();
      DetectFairValueGaps();
      DetectOrderBlocks();
      if(InpUseICT_Unicorn)
         DetectUnicornModel();
      if(InpUseCRT_TurtleSoup)
         DetectCandleRangeTheory();
      if(InpUseWickReversalSniper)
         DetectWickReversalSniper();
      if(InpUseAsianRangeJudas)
         UpdateAsianRangeAndJudasEngine();
      UpdateLiquidityRadar();
      UpdateMultiTF_EMA14_Engine();
      UpdateSamuraiMTFConfluenceEngine();
      AnalyzePriceActionAndPatterns();
      UpdatePriceActionTriggers();
      UpdateEMACrossStatus();
      UpdateADXMomentumTurboGate();
      UpdateMarketSessionAndMTF();
      string newsEvent = "";
      int minsUntil = 0;
      CheckMQL5NewsCalendarGuard(newsEvent, minsUntil);
      UpdateLinearRegressionEngine();
      CheckDailyGuard();
      if(InpEnableSpikeSniper || g_AutoSniperActive)
         DetectSpikeReversalSignal();
      if(InpEnableHTFReversalSniper || g_AutoSniperActive)
         DetectHTFZoneReversalTrigger();
      if(InpEnableElliottWave)
         AnalyzeElliottDualSwings();
      UpdateZScoreEngine();
      UpdateCMEWallEngine();
      CalculateMarketDirectionalBias();
      EvaluateBotStateAndPlan();
   }

   // 2. Position Management (ZERO-LAG 0.00ms on EVERY SINGLE TICK - Break Even, Trailing, Step Trailing & Partial TP)
   ManageOpenPositions();
   if(InpUseNewsCalendarGuard && g_NewsStandDownActive)
      AutoPreNewsBreakevenGuard();

   // 3. Auto Trade Execution (ZERO-LAG 0.00ms on EVERY SINGLE TICK)
   if(g_AutoTradeEnabled && !g_DailyTargetReached && !g_DailyMaxLossReached)
   {
      ExecuteAutoTradeLogic();
   }

   // 4. GUI & Visuals Update (Throttled to 180ms = 5.5 FPS Silky Smooth, Zero CPU/GUI Bottleneck)
   if(curTickMs - lastGuiTickMs >= 180)
   {
      lastGuiTickMs = curTickMs;

      if(g_ShowDashboard)
         UpdateHUDValues();

      if(InpUseSamuraiMTFStrip && g_ShowMTFStrip)
         UpdateSamuraiMTFGoldenAlert();

      if(g_ShowVisuals)
         DrawChartVisuals();
      else
         RemoveVisualDrawings();
   }
}

//+------------------------------------------------------------------+
//| TRADE TRANSACTION HANDLER (DEAL TRACKING & ANGEL SHIELD)         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(dealTicket > 0 && HistoryDealSelect(dealTicket))
      {
         long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         string symbol  = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         if(symbol == _Symbol && (entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT || entryType == DEAL_ENTRY_OUT_BY))
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                          + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                          + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            long dealReason = HistoryDealGetInteger(dealTicket, DEAL_REASON);
            string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
            
            // 🧘‍♂️ Post-SL & Post-BE 15-Minute Cooldown Guard Activation
            bool isSL = (dealReason == DEAL_REASON_SL) || (StringFind(dealComment, "[sl") >= 0);
            bool isLoss = (profit < -0.01);
            bool isBreakEven = isSL && !isLoss; // Closed at Break-Even (+points or near 0)
            
            // 🎯 Smart Structural Re-Entry Guard State Update
            g_LastStoppedPrice    = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            g_LastStoppedProfit   = profit;
            g_LastStoppedTime     = TimeCurrent();
            long dealType         = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            g_LastStoppedDir      = (dealType == DEAL_TYPE_SELL) ? 1 : ((dealType == DEAL_TYPE_BUY) ? -1 : 0);
            g_ReEntryUnlocked     = false;
            g_ReEntryUnlockReason = "";

            if(isBreakEven && InpAllowReEntryOnBE)
            {
               // Closed at Break-Even: Zero risk, immediately clear price lock
               g_LastStoppedPrice = 0.0;
               g_ReEntryUnlocked = true;
               g_ReEntryUnlockReason = "BE Protection Active (Risk-Free)";
               Print(">>> 🛡️ [SMART RE-ENTRY] Position closed at Break-Even (Profit: ", FormatMoney(profit, true), ") - No lock applied, ready for sniper re-entry!");
            }
            else if(isLoss)
            {
               Print(">>> 🛡️ [SMART RE-ENTRY GUARD ARMED] SL Loss @ ", DoubleToString(g_LastStoppedPrice, _Digits),
                     " (Profit: ", FormatMoney(profit, true), "). Same-price re-entry locked within ", InpSamePriceLockBufferPts,
                     " pts unless in DZ/SZ + PA + Score >= ", InpReEntryMinScore, "%");
            }

            // Post-Loss Cooldown Guard (Only active if InpEnablePostSLBECooldown is true AND it's a real loss)
            if(InpEnablePostSLBECooldown && isLoss && !isBreakEven)
            {
               g_PostSLBECooldownUntil = TimeCurrent() + (InpPostSLBECooldownMinutes * 60);
               g_PostSLBECooldownReason = "SL ขาดทุน";
               GlobalVariableSet(GetGVKey("POST_SLBE_UNTIL"), (double)g_PostSLBECooldownUntil);
               
               string beMsg = StringFormat("🧘‍♂️ [POST-LOSS 15-MIN COOLDOWN] ปิดไม้ขาดทุน (%s) | พักระบบความปลอดภัย %d นาที เพื่อความปลอดภัยและป้องกันเบรกหลอกซ้ำ ❤️",
                                           FormatMoney(profit, true), InpPostSLBECooldownMinutes);
               Print(">>> ", beMsg);
               SendTradeNotification(beMsg);
               UpdateHUDValues();
               ChartRedraw();
            }
            
            // If trade closed in a loss, activate Khun Ann Angel Shield 15-Minute Cooldown (Only in Safe Co-Pilot mode)
            if(profit < -0.01 && InpEnableRevengeShield && g_TradeMode == TRADE_MODE_SAFE_COPILOT)
            {
               g_RevengeCooldownUntil = TimeCurrent() + (InpRevengeCooldownMinutes * 60);
               g_LastLossAmount = profit;
               g_LastLossTime = TimeCurrent();
               GlobalVariableSet(GetGVKey("REVENGE_UNTIL"), (double)g_RevengeCooldownUntil);
               
               string msg = StringFormat("🧘‍♂️ [KHUN ANN ANGEL SHIELD] ปิดไม้ขาดทุน (%s) | เกราะคุมสติเริ่มทำงาน: พักใจ %d นาที เพื่อความปลอดภัยของครอบครัวคุณเอ้ ❤️",
                                         FormatMoney(profit, true), InpRevengeCooldownMinutes);
               Print(">>> ", msg);
               SendTradeNotification(msg);
               PlaySound("alert.wav");
               UpdateHUDValues();
               ChartRedraw();
            }
         }
      }
   }
}

void DumpAccountTradeHistory()
{
   string filename = StringFormat("trade_history_%I64d.csv", AccountInfoInteger(ACCOUNT_LOGIN));
   int fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
   if(fileHandle != INVALID_HANDLE)
   {
      FileWrite(fileHandle, "CATEGORY", "TICKET", "ORDER", "TIME", "SYMBOL", "TYPE", "ENTRY", "VOLUME", "PRICE", "PROFIT", "COMMISSION", "SWAP", "MAGIC", "COMMENT");
      
      FileWrite(fileHandle, "ACCOUNT", IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)), AccountInfoString(ACCOUNT_NAME),
                DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
                AccountInfoString(ACCOUNT_CURRENCY), IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)));
                
      if(HistorySelect(0, TimeCurrent()))
      {
         int dealsTotal = HistoryDealsTotal();
         PrintFormat(">>> DUMPING FULL HISTORY: Account %I64d dealsTotal=%d", AccountInfoInteger(ACCOUNT_LOGIN), dealsTotal);
         for(int i = 0; i < dealsTotal; i++)
         {
            ulong t = HistoryDealGetTicket(i);
            if(t > 0)
            {
               ulong ord = HistoryDealGetInteger(t, DEAL_ORDER);
               datetime tm = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
               string sym = HistoryDealGetString(t, DEAL_SYMBOL);
               long tp = HistoryDealGetInteger(t, DEAL_TYPE);
               long en = HistoryDealGetInteger(t, DEAL_ENTRY);
               double vol = HistoryDealGetDouble(t, DEAL_VOLUME);
               double pr = HistoryDealGetDouble(t, DEAL_PRICE);
               double pnl = HistoryDealGetDouble(t, DEAL_PROFIT);
               double comm = HistoryDealGetDouble(t, DEAL_COMMISSION);
               double sw = HistoryDealGetDouble(t, DEAL_SWAP);
               long mg = HistoryDealGetInteger(t, DEAL_MAGIC);
               string cmt = HistoryDealGetString(t, DEAL_COMMENT);
               
               string tpStr = (tp == DEAL_TYPE_BUY) ? "BUY" : (tp == DEAL_TYPE_SELL) ? "SELL" : IntegerToString(tp);
               string enStr = (en == DEAL_ENTRY_IN) ? "IN" : (en == DEAL_ENTRY_OUT) ? "OUT" : (en == DEAL_ENTRY_INOUT) ? "INOUT" : (en == DEAL_ENTRY_OUT_BY) ? "OUT_BY" : IntegerToString(en);
               string tmStr = TimeToString(tm, TIME_DATE | TIME_SECONDS);
               
               FileWrite(fileHandle, "DEAL", IntegerToString(t), IntegerToString(ord), tmStr, sym, tpStr, enStr,
                         DoubleToString(vol, 2), DoubleToString(pr, 2), DoubleToString(pnl, 2),
                         DoubleToString(comm, 2), DoubleToString(sw, 2), IntegerToString(mg), cmt);
            }
         }
      }
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong pt = PositionGetTicket(i);
         if(pt > 0)
         {
            FileWrite(fileHandle, "OPEN_POS", IntegerToString(pt), "", "", PositionGetString(POSITION_SYMBOL),
                      IntegerToString(PositionGetInteger(POSITION_TYPE)), "",
                      DoubleToString(PositionGetDouble(POSITION_VOLUME), 2),
                      DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), 2),
                      DoubleToString(PositionGetDouble(POSITION_PROFIT), 2),
                      "", "", IntegerToString(PositionGetInteger(POSITION_MAGIC)),
                      PositionGetString(POSITION_COMMENT));
         }
      }
      
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| TIMER HANDLER                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   static int s_dumpCount = 0;
   s_dumpCount++;
   if(s_dumpCount == 3 || s_dumpCount == 6 || s_dumpCount == 10)
   {
      DumpAccountTradeHistory();
   }
   m_symbol.RefreshRates();
   UpdateEMACrossStatus();
   UpdateADXMomentumTurboGate();
   UpdateMarketSessionAndMTF();
   UpdateLinearRegressionEngine();
   CheckDailyGuard();
   if(InpEnableSpikeSniper || g_AutoSniperActive)
      DetectSpikeReversalSignal();
   if(InpEnableHTFReversalSniper || g_AutoSniperActive)
      DetectHTFZoneReversalTrigger();
   if(InpEnableElliottWave)
      AnalyzeElliottDualSwings();
   if(InpUseICT_Unicorn)
      DetectUnicornModel();
   if(InpUseCRT_TurtleSoup)
      DetectCandleRangeTheory();
   if(InpUseWickReversalSniper)
      DetectWickReversalSniper();
   if(InpUseAsianRangeJudas)
      UpdateAsianRangeAndJudasEngine();
   string timerNews = "";
   int timerMins = 0;
   if(InpUseNewsCalendarGuard)
      CheckMQL5NewsCalendarGuard(timerNews, timerMins);
   UpdateLiquidityRadar();
   CalculateMarketDirectionalBias();
   UpdateSmartActionCommand(CountOpenPositions(InpManageManualTrades));
   if(g_ShowDashboard)
      UpdateHUDValues();
   if(InpUseSamuraiMTFStrip && g_ShowMTFStrip)
      UpdateSamuraiMTFGoldenAlert();

   // Periodic Background Update Check (Every 2 Hours)
   if(TimeCurrent() - g_LastUpdateCheck > 7200)
      CheckRemoteUpdate(false);
}

//+------------------------------------------------------------------+
//| CHART EVENT HANDLER                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // HUD UPDATE BUTTON (IN-EA AUTO-UPDATER)
      if(sparam == GUI_PREFIX + "HUD_BTN_UPDATE")
      {
         if(g_UpdateAvailable)
            TriggerAutoUpdate();
         else
            CheckRemoteUpdate(true);
      }
      // TOP NAVIGATION TOGGLE BUTTONS
      else if(sparam == GUI_PREFIX + "NAV_TOGGLE_HUD" || sparam == GUI_PREFIX + "HUD_BTN_MIN")
      {
         g_ShowDashboard = !g_ShowDashboard;
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "NAV_TOGGLE_CTRL")
      {
         g_ShowControls = !g_ShowControls;
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "CTRL_BTN_MIN" || sparam == GUI_PREFIX + "CTRL_TITLE")
      {
         g_Ctrl_Expanded = !g_Ctrl_Expanded;
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "HUD_BTN_MIN_C1" || sparam == GUI_PREFIX + "HUD_CARD_MKT_TITLE")
      {
         g_Card1_Expanded = !g_Card1_Expanded;
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "HUD_BTN_MIN_C2" || sparam == GUI_PREFIX + "HUD_CARD_PLAN_TITLE")
      {
         g_Card2_Expanded = !g_Card2_Expanded;
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "HUD_BTN_MIN_C3" || sparam == GUI_PREFIX + "HUD_CARD_PROP_TITLE")
      {
         g_Card3_Expanded = !g_Card3_Expanded;
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "HUD_BTN_RESET_GUARD")
      {
         // 1. Get Day Start Time
         datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0);
         if(startOfDay <= 0)
         {
            datetime tc = TimeCurrent();
            MqlDateTime dt;
            TimeToStruct(tc, dt);
            dt.hour = 0; dt.min = 0; dt.sec = 0;
            startOfDay = StructToTime(dt);
         }

         // 2. Sum closed deals today according to scope to set as baseline
         double currentClosedToday = 0.0;
         if(startOfDay > 0 && HistorySelect(startOfDay, TimeCurrent()))
         {
            int dealsTotal = HistoryDealsTotal();
            for(int i = 0; i < dealsTotal; i++)
            {
               ulong dealTicket = HistoryDealGetTicket(i);
               if(dealTicket > 0)
               {
                  datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                  if(dealTime < startOfDay) continue;
                  long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
                  if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;
                  long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
                  string sym = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
                  long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

                  bool isMatch = (InpDailyGuardScope == GUARD_SCOPE_BOT_ONLY) ? (magic == InpMagicNumber) : (magic == InpMagicNumber || (InpManageManualTrades && magic == 0) || magic == 888999);
                  if(isMatch && sym == _Symbol && (entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT || entryType == DEAL_ENTRY_OUT_BY))
                  {
                     currentClosedToday += HistoryDealGetDouble(dealTicket, DEAL_PROFIT) 
                                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP) 
                                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                  }
               }
            }
         }

         // 3. Set Manual Unlock & Baseline
         g_DailyGuardManualUnlocked = true;
         g_DailyGuardBaselinePnL    = currentClosedToday;
         g_DailyGuardResetDay       = startOfDay;
         g_DailyTargetReached       = false;
         g_DailyMaxLossReached      = false;
         g_PostSLBECooldownUntil    = 0;
         g_PostSLBECooldownReason   = "";
         g_RevengeCooldownUntil     = 0;
         GlobalVariableSet(GetGVKey("POST_SLBE_UNTIL"), 0.0);
         GlobalVariableSet(GetGVKey("REVENGE_UNTIL"), 0.0);

         // 4. Save to Persistent Memory
         SavePersistentGUIState();

         // 5. Recalculate Daily Guard immediately so values are fresh
         CheckDailyGuard();

         Print(">>> 🔓 [MANUAL RESET] Daily Target & Max Loss Guard unlocked! Baseline set to: ", FormatMoney(currentClosedToday, true));
         SendTradeNotification(StringFormat("🔓 [Good Trade Gold] Daily Guard ปลดล็อกสำเร็จ! รีเซ็ตฐานทุน (%s) พร้อมลุยต่อทันที ⚡", FormatMoney(currentClosedToday, true)));
         UpdateHUDValues();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "HUD_BTN_MIN_C4" || sparam == GUI_PREFIX + "HUD_CARD_STATS_TITLE")
      {
         g_Card4_Expanded = !g_Card4_Expanded;
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "NAV_TOGGLE_DRAW" || sparam == GUI_PREFIX + "BTN_VISUAL")
      {
         g_ShowVisuals = !g_ShowVisuals;
         if(!g_ShowVisuals)
            RemoveVisualDrawings();
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "NAV_TOGGLE_MTF")
      {
         g_ShowMTFStrip = !g_ShowMTFStrip;
         SyncSamuraiMTFIndicator(g_ShowMTFStrip);
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "NAV_TOGGLE_ATH")
      {
         g_ShowATHGrid = !g_ShowATHGrid;
         if(!g_ShowATHGrid)
         {
            ObjectDelete(0, GUI_PREFIX + "ATH_RES_LINE");
            ObjectDelete(0, GUI_PREFIX + "ATH_SUP_LINE");
         }
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "NAV_TOGGLE_LRL")
      {
         g_ShowLRLChannel = !g_ShowLRLChannel;
         if(!g_ShowLRLChannel)
            RemoveLinearRegressionVisuals();
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "NAV_TOGGLE_ABCD")
      {
         g_ShowABCDWave = !g_ShowABCDWave;
         if(!g_ShowABCDWave)
            ObjectsDeleteAll(0, GUI_PREFIX + "ABCD_");
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "NAV_TOGGLE_EMA")
      {
         g_ShowEMAVisuals = !g_ShowEMAVisuals;
         if(!g_ShowEMAVisuals)
            RemoveMultiTF_EMA14_Visuals();
         else
            DrawMultiTF_EMA14_Visuals();
         SavePersistentGUIState();
         CreateFullGUI();
         ChartRedraw();
      }
      // CONTROL PANEL BUTTONS
      else if(sparam == GUI_PREFIX + "BTN_AUTO")
      {
         g_AutoTradeEnabled = !g_AutoTradeEnabled;
         SavePersistentGUIState();
         UpdateButtonState("BTN_AUTO", g_AutoTradeEnabled ? "ออโต้ ● ON" : "ออโต้ ● OFF", 
                            g_AutoTradeEnabled ? clrSeaGreen : clrDimGray);
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_MULTI")
      {
         g_AllowMultiPos = !g_AllowMultiPos;
         SavePersistentGUIState();
         UpdateButtonState("BTN_MULTI", g_AllowMultiPos ? "หลายไม้ ● ON" : "หลายไม้ ● OFF", 
                            g_AllowMultiPos ? clrDodgerBlue : clrDimGray);
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_LOTMODE")
      {
         if(g_LotMode == LOT_FIXED)
            g_LotMode = LOT_RISK_PERCENT;
         else
            g_LotMode = LOT_FIXED;

         SavePersistentGUIState();
         UpdateButtonState("BTN_LOTMODE", g_LotMode == LOT_FIXED ? "โหมด: Lot" : "โหมด: % ทุน", 
                            g_LotMode == LOT_FIXED ? clrOrange : clrDarkCyan);
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_BE")
      {
         g_BreakEvenEnabled = !g_BreakEvenEnabled;
         SavePersistentGUIState();
         UpdateButtonState("BTN_BE", g_BreakEvenEnabled ? "กันทุน ● ON" : "กันทุน ● OFF", 
                            g_BreakEvenEnabled ? clrMediumSlateBlue : clrDimGray);
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_LOT_MINUS10")
      {
         AdjustLot(-0.10);
      }
      else if(sparam == GUI_PREFIX + "BTN_LOT_MINUS1")
      {
         AdjustLot(-0.01);
      }
      else if(sparam == GUI_PREFIX + "BTN_LOT_PLUS1")
      {
         AdjustLot(+0.01);
      }
      else if(sparam == GUI_PREFIX + "BTN_LOT_PLUS10")
      {
         AdjustLot(+0.10);
      }
      else if(sparam == GUI_PREFIX + "BTN_MANUAL_BUY")
      {
         ExecuteManualOrder(ORDER_TYPE_BUY);
      }
      else if(sparam == GUI_PREFIX + "BTN_MANUAL_SELL")
      {
         ExecuteManualOrder(ORDER_TYPE_SELL);
      }
      else if(sparam == GUI_PREFIX + "BTN_TRADE_MODE")
      {
         if(g_TradeMode == TRADE_MODE_SAFE_COPILOT)
         {
            ApplyTradeMode(TRADE_MODE_AGGRESSIVE_SNIPER);
            g_AutoTradeEnabled = true;
            UpdateButtonState("BTN_AUTO", "ออโต้ ● ON", clrSeaGreen);
         }
         else
         {
            ApplyTradeMode(TRADE_MODE_SAFE_COPILOT);
            g_AutoTradeEnabled = false;
            UpdateButtonState("BTN_AUTO", "ออโต้ ● OFF", clrDimGray);
         }

         SavePersistentGUIState();
         UpdateButtonState("BTN_TRADE_MODE", 
                           (g_TradeMode == TRADE_MODE_SAFE_COPILOT ? "🛡️ SAFE: ยิงมือ Co-Pilot" : "⚡ AGGRESSIVE: สไนเปอร์ AUTO"), 
                           (g_TradeMode == TRADE_MODE_SAFE_COPILOT ? C'18,90,55' : C'195,80,15'));
         
         string modeNotice = (g_TradeMode == TRADE_MODE_SAFE_COPILOT) ? 
            "🛡️ [MODE SWITCH] สลับเป็นโหมด SAFE (เปิดเกราะ HTF H1/H4 + เกราะพักใจคุณแอน 15 นาที | ยิงมือ Co-Pilot)" :
            "⚡ [MODE SWITCH] สลับเป็นโหมด AGGRESSIVE (ปลดล็อกเกราะ HTF, Fibo & เกราะพักใจ 15 นาที | สไนเปอร์ Auto 100%)";
         Print(">>> ", modeNotice);
         SendTradeNotification(modeNotice);
         CreateFullGUI();
         UpdateHUDValues();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_SPIKE_SNIPER")
      {
         ExecuteSpikeSniperOrder();
      }
      else if(sparam == GUI_PREFIX + "BTN_CLOSE_ALL")
      {
         CloseAllPositions();
         g_AutoTradeEnabled = false;
         SavePersistentGUIState();
         UpdateButtonState("BTN_AUTO", "ออโต้ ● OFF", clrDimGray);
         ChartRedraw();
         Print(">>> 🛑 [SAFE CLOSE ALL] Closed all positions and paused Auto-Trade automatically.");
      }
   }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == GUI_PREFIX + "EDIT_LOT")
      {
         string text = ObjectGetString(0, sparam, OBJPROP_TEXT);
         double val = StringToDouble(text);
         if(g_LotMode == LOT_FIXED)
         {
            double step = m_symbol.LotsStep();
            double minLot = m_symbol.LotsMin();
            double maxLot = m_symbol.LotsMax();
            if(InpEnableMaxVolumeCeiling && InpMaxTotalVolumeCap > 0 && maxLot > InpMaxTotalVolumeCap)
               maxLot = InpMaxTotalVolumeCap;
            g_CurrentLot = MathMax(minLot, MathMin(maxLot, MathFloor(val / step) * step));
            ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
         }
         else
         {
            g_RiskPercent = MathMax(0.1, MathMin(10.0, val));
            ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(g_RiskPercent, 1) + "%");
         }
         SavePersistentGUIState();
      }
   }
   else if(id == CHARTEVENT_CHART_CHANGE)
   {
      static long lastChartH = 0, lastChartW = 0;
      long curH = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      long curW = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      if(MathAbs(curH - lastChartH) > 40 || MathAbs(curW - lastChartW) > 40)
      {
         lastChartH = curH;
         lastChartW = curW;
         CreateFullGUI();
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| 1. DOW THEORY & WAVE COUNTING: DETECT SWINGS, HH/HL/LH/LL & BOS  |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure()
{
   int lookback = MathMax(2, InpSwingLookback);
   int totalBars = 200;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpTimeframe, 0, totalBars, rates) < totalBars)
      return;

   SSwingPoint rawSwings[];
   ArrayResize(rawSwings, 0);

   // 1. Scan for Fractal/Swing Points
   for(int i = lookback; i < totalBars - lookback; i++)
   {
      bool isHigh = true;
      bool isLow = true;

      for(int k = 1; k <= lookback; k++)
      {
         if(rates[i].high < rates[i - k].high || rates[i].high < rates[i + k].high)
            isHigh = false;
         if(rates[i].low > rates[i - k].low || rates[i].low > rates[i + k].low)
            isLow = false;
      }

      if(isHigh)
      {
         int size = ArraySize(rawSwings);
         ArrayResize(rawSwings, size + 1);
         rawSwings[size].time = rates[i].time;
         rawSwings[size].price = rates[i].high;
         rawSwings[size].type = 1;
         rawSwings[size].barIndex = i;
      }
      if(isLow)
      {
         int size = ArraySize(rawSwings);
         ArrayResize(rawSwings, size + 1);
         rawSwings[size].time = rates[i].time;
         rawSwings[size].price = rates[i].low;
         rawSwings[size].type = -1;
         rawSwings[size].barIndex = i;
      }
   }

   int count = ArraySize(rawSwings);
   if(count < 4)
   {
      g_MarketTrend = TREND_SIDEWAY;
      g_WaveStatusStr = "รอสวิง High/Low ก่อตัว";
      return;
   }

   // 2. Filter Alternate Highs and Lows
   SSwingPoint lastH, prevH, lastL, prevL;
   ZeroMemory(lastH); ZeroMemory(prevH); ZeroMemory(lastL); ZeroMemory(prevL);
   bool foundLastH = false, foundPrevH = false;
   bool foundLastL = false, foundPrevL = false;

   for(int i = 0; i < count; i++)
   {
      if(rawSwings[i].type == 1)
      {
         if(!foundLastH) { lastH = rawSwings[i]; foundLastH = true; }
         else if(!foundPrevH) { prevH = rawSwings[i]; foundPrevH = true; }
      }
      else if(rawSwings[i].type == -1)
      {
         if(!foundLastL) { lastL = rawSwings[i]; foundLastL = true; }
         else if(!foundPrevL) { prevL = rawSwings[i]; foundPrevL = true; }
      }
      if(foundLastH && foundPrevH && foundLastL && foundPrevL)
         break;
   }

   // 3. Label ALL Swings across history (HH, LH, HL, LL)
   double lastHighP = 0;
   double lastLowP  = 0;
   for(int i = count - 1; i >= 0; i--)
   {
      if(rawSwings[i].type == 1) // High
      {
         if(lastHighP > 0)
         {
            if(rawSwings[i].price >= lastHighP)
            {
               rawSwings[i].labelType = SWING_HH;
               rawSwings[i].labelStr  = "HH";
            }
            else
            {
               rawSwings[i].labelType = SWING_LH;
               rawSwings[i].labelStr  = "LH";
            }
         }
         else
         {
            rawSwings[i].labelType = SWING_HH;
            rawSwings[i].labelStr  = "HH";
         }
         lastHighP = rawSwings[i].price;
      }
      else if(rawSwings[i].type == -1) // Low
      {
         if(lastLowP > 0)
         {
            if(rawSwings[i].price >= lastLowP)
            {
               rawSwings[i].labelType = SWING_HL;
               rawSwings[i].labelStr  = "HL";
            }
            else
            {
               rawSwings[i].labelType = SWING_LL;
               rawSwings[i].labelStr  = "LL";
            }
         }
         else
         {
            rawSwings[i].labelType = SWING_HL;
            rawSwings[i].labelStr  = "HL";
         }
         lastLowP = rawSwings[i].price;
      }
   }

   // Set primary swing references
   if(foundLastH)
   {
      lastH.labelType = (lastH.price >= prevH.price) ? SWING_HH : SWING_LH;
      lastH.labelStr  = (lastH.labelType == SWING_HH) ? "HH" : "LH";
   }
   if(foundLastL)
   {
      lastL.labelType = (lastL.price >= prevL.price) ? SWING_HL : SWING_LL;
      lastL.labelStr  = (lastL.labelType == SWING_HL) ? "HL" : "LL";
   }

   g_LastSwingHigh = lastH;
   g_PrevSwingHigh = prevH;
   g_LastSwingLow  = lastL;
   g_PrevSwingLow  = prevL;

   // 4. Dynamic Timeframe Minimum Swing Range Filter
   int baseMinSwing = g_AssetProfile.minSwing;
   int effectiveMinSwing = baseMinSwing;
   ENUM_TIMEFRAMES currentTF = (InpTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTimeframe);
   switch(currentTF)
   {
      case PERIOD_M1:  effectiveMinSwing = (int)(baseMinSwing * 0.40); break;
      case PERIOD_M5:  effectiveMinSwing = (int)(baseMinSwing * 0.70); break;
      case PERIOD_M15: effectiveMinSwing = (int)(baseMinSwing * 1.40); break;
      case PERIOD_M30: effectiveMinSwing = (int)(baseMinSwing * 2.00); break;
      case PERIOD_H1:  effectiveMinSwing = (int)(baseMinSwing * 3.20); break;
      case PERIOD_H4:  effectiveMinSwing = (int)(baseMinSwing * 5.50); break;
      case PERIOD_D1:  effectiveMinSwing = (int)(baseMinSwing * 9.00); break;
      default:         effectiveMinSwing = baseMinSwing; break;
   }

   double swingRange = (lastH.price - lastL.price) / _Point;
   if(swingRange < effectiveMinSwing)
   {
      g_MarketTrend = TREND_SIDEWAY;
      g_WaveStatusStr = "กรอบสวิงแคบ (พักตัว Sideway)";
      return;
   }

   // 5. EMA Trend Filter
   double emaVal[1];
   double currentClose = rates[0].close;
   bool emaBullish = true;
   bool emaBearish = true;

   if(InpUseEMAFilter && m_hEMA != INVALID_HANDLE)
   {
      if(CopyBuffer(m_hEMA, 0, 0, 1, emaVal) > 0)
      {
         emaBullish = (currentClose >= emaVal[0]);
         emaBearish = (currentClose <= emaVal[0]);
      }
   }

   // 6. Break of Structure (BOS) & Change of Character (ChoCH) Engine (Strict Candle Close Confirmation)
   g_BOS_Confirmed = false;
   double triggerHigh = (lastH.price > 0) ? lastH.price : prevH.price;
   double triggerLow  = (lastL.price > 0) ? lastL.price : prevL.price;
   
   // A. Bullish Structure Break (BOS / ChoCH) - Requires solid close above triggerHigh
   if(currentClose > triggerHigh || rates[1].close > triggerHigh)
   {
      if(lastH.labelType == SWING_LH || g_MarketTrend == TREND_BEARISH)
      {
         g_StructEvent     = STRUCT_BULLISH_CHOCH;
         g_StructEventName = "ChoCH 🔄 🟢";
         g_MarketTrend     = TREND_BULLISH;
         g_BOS_Level       = triggerHigh;
         g_StructLevel     = triggerHigh;
         g_BOS_Confirmed   = true;
         g_WaveStatusStr   = "ChoCH 🔄 (กลับตัวขึ้น) 🟢";
      }
      else
      {
         g_StructEvent     = STRUCT_BULLISH_BOS;
         g_StructEventName = "BOS ➔ 🟢";
         g_MarketTrend     = TREND_BULLISH;
         g_BOS_Level       = triggerHigh;
         g_StructLevel     = triggerHigh;
         g_BOS_Confirmed   = true;
         g_WaveStatusStr   = "BOS ➔ รัน Wave 3 ต่อ 🟢";
      }
   }
   // B. Bearish Structure Break (BOS / ChoCH) - Requires solid close below triggerLow
   else if(currentClose < triggerLow || rates[1].close < triggerLow)
   {
      if(lastL.labelType == SWING_HL || g_MarketTrend == TREND_BULLISH)
      {
         g_StructEvent     = STRUCT_BEARISH_CHOCH;
         g_StructEventName = "ChoCH 🔄 🔴";
         g_MarketTrend     = TREND_BEARISH;
         g_BOS_Level       = triggerLow;
         g_StructLevel     = triggerLow;
         g_BOS_Confirmed   = true;
         g_WaveStatusStr   = "ChoCH 🔄 (กลับตัวลง) 🔴";
      }
      else
      {
         g_StructEvent     = STRUCT_BEARISH_BOS;
         g_StructEventName = "BOS ➔ 🔴";
         g_MarketTrend     = TREND_BEARISH;
         g_BOS_Level       = triggerLow;
         g_StructLevel     = triggerLow;
         g_BOS_Confirmed   = true;
         g_WaveStatusStr   = "BOS ➔ รัน Wave 3 ต่อ 🔴";
      }
   }
   // C. Established Trend Structure inside Wave (HH + HL or LH + LL with Clear EMA Separation)
   else if(lastH.labelType == SWING_HH && lastL.labelType == SWING_HL && emaBullish)
   {
      g_MarketTrend     = TREND_BULLISH;
      g_BOS_Level       = lastH.price;
      g_StructLevel     = lastH.price;
      g_StructEventName = "BOS ➔ 🟢";
      g_WaveStatusStr   = "BULLISH (ย่อ Wave 2) 🟢";
   }
   else if(lastH.labelType == SWING_LH && lastL.labelType == SWING_LL && emaBearish)
   {
      g_MarketTrend     = TREND_BEARISH;
      g_BOS_Level       = lastL.price;
      g_StructLevel     = lastL.price;
      g_StructEventName = "BOS ➔ 🔴";
      g_WaveStatusStr   = "BEARISH (เด้ง Wave 2) 🔴";
   }
   // D. Fallback Directional Structure: If EMA confirms strong breakdown/breakout past trigger levels
   else if(emaBearish && (currentClose < triggerLow || rates[1].close < triggerLow))
   {
      g_MarketTrend     = TREND_BEARISH;
      g_BOS_Level       = triggerLow;
      g_StructLevel     = triggerLow;
      g_StructEventName = "BOS ➔ 🔴";
      g_WaveStatusStr   = "BEARISH (ทุบทะลุสวิงโลว์) 🔴";
   }
   else if(emaBullish && (currentClose > triggerHigh || rates[1].close > triggerHigh))
   {
      g_MarketTrend     = TREND_BULLISH;
      g_BOS_Level       = triggerHigh;
      g_StructLevel     = triggerHigh;
      g_StructEventName = "BOS ➔ 🟢";
      g_WaveStatusStr   = "BULLISH (พุ่งทะลุสวิงไฮ) 🟢";
   }
   // E. Inside Symmetrical Triangle / Contracting Range / Sideway Chop (LH + HL or ADX < 20)
   else
   {
      g_MarketTrend     = TREND_SIDEWAY;
      g_StructEvent     = STRUCT_NONE;
      g_StructEventName = "SIDEWAY 🟡";
      g_WaveStatusStr   = (g_LiveADX_Val < 20.0) ? "SIDEWAY (โวลุ่มเบาบาง ADX < 20) 🟡" : "SIDEWAY (บีบตัวในกรอบ LH+HL) 🟡";
   }

   // 7. Detect Advanced SMC Structures, Liquidity Pools, MTF Zones & POC (Throttled for Ultra-Low Latency Execution)
   if(InpShowSMC_BOS)
      DetectStructureBreaks(rawSwings, count, rates, totalBars);
   if(InpShowSMC_Liquidity)
      DetectLiquidityPools(rawSwings, count);

   static datetime lastHeavySMCScan = 0;
   datetime curSec = TimeCurrent();
   if(curSec - lastHeavySMCScan >= 3)
   {
      lastHeavySMCScan = curSec;
      if(InpShowSMC_MTFZones)
         DetectMTFOrderBlocks();
      if(InpShowSMC_POC)
         CalculateSessionPOC();
   }
}

//+------------------------------------------------------------------+
//| 2. FIBONACCI RETRACEMENT & ARMED STATE ENGINE                    |
//+------------------------------------------------------------------+
void CalculateFibonacci()
{
   ZeroMemory(g_Fibo);
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double currentPrice = (ask + bid) / 2.0;

   MqlRates currentBar[];
   ArraySetAsSeries(currentBar, true);
   CopyRates(_Symbol, InpTimeframe, 0, 100, currentBar);

   double low = g_LastSwingLow.price;
   double high = g_LastSwingHigh.price;

   // Dynamic Impulse Wave Peak & Valley Expansion across the current wave
   if(g_MarketTrend == TREND_BULLISH && ArraySize(currentBar) > 0)
   {
      double maxH = high;
      datetime maxT = g_LastSwingHigh.time;
      for(int b = 0; b < ArraySize(currentBar); b++)
      {
         if(g_LastSwingLow.time > 0 && currentBar[b].time < g_LastSwingLow.time)
            break;
         if(currentBar[b].high >= maxH)
         {
            maxH = currentBar[b].high;
            maxT = currentBar[b].time;
         }
      }
      if(maxH >= high)
      {
         high = maxH;
         g_LastSwingHigh.price = high;
         g_LastSwingHigh.time = maxT;
         g_LastSwingHigh.labelStr = "HH";
         g_LastSwingHigh.labelType = SWING_HH;
      }
   }
   else if(g_MarketTrend == TREND_BEARISH && ArraySize(currentBar) > 0)
   {
      double minL = (low > 0) ? low : currentBar[0].low;
      datetime minT = g_LastSwingLow.time;
      for(int b = 0; b < ArraySize(currentBar); b++)
      {
         if(g_LastSwingHigh.time > 0 && currentBar[b].time < g_LastSwingHigh.time)
            break;
         if(currentBar[b].low <= minL && currentBar[b].low > 0)
         {
            minL = currentBar[b].low;
            minT = currentBar[b].time;
         }
      }
      if(minL <= low && minL > 0)
      {
         low = minL;
         g_LastSwingLow.price = low;
         g_LastSwingLow.time = minT;
         g_LastSwingLow.labelStr = "LL";
         g_LastSwingLow.labelType = SWING_LL;
      }
   }

   double range = high - low;

   if(range <= 0 || low <= 0 || high <= 0)
      return;

   // Wave & Trend Invalidation Guard: Reset Pullback Armed when Trend flips or new Major Swing forms
   static ENUM_MARKET_TREND s_lastFiboTrend = TREND_SIDEWAY;
   static datetime s_lastArmSwingTime = 0;
   datetime currentSwingTime = (g_MarketTrend == TREND_BULLISH) ? g_LastSwingHigh.time : ((g_MarketTrend == TREND_BEARISH) ? g_LastSwingLow.time : 0);
   if(s_lastFiboTrend != g_MarketTrend || s_lastArmSwingTime != currentSwingTime)
   {
      g_PullbackArmed = false;
      s_lastFiboTrend = g_MarketTrend;
      s_lastArmSwingTime = currentSwingTime;
   }

   if(g_MarketTrend == TREND_BULLISH)
   {
      g_Fibo.p0    = high;
      g_Fibo.p236  = high - range * 0.236;
      g_Fibo.p382  = high - range * 0.382;
      g_Fibo.p500  = high - range * 0.500;
      g_Fibo.p618  = high - range * 0.618;
      g_Fibo.p786  = high - range * 0.786;
      g_Fibo.p100  = low;
      g_Fibo.p1272 = high + range * 0.272;
      g_Fibo.p1618 = high + range * 0.618;
      g_Fibo.p2618 = high + range * 1.618;

      double goldenMinFrac = MathMax(0.500, MathMin(InpFiboGoldenMin, InpFiboGoldenMax) / 100.0); // SMC Rule: Discount is STRICTLY <= 50% Equilibrium!
      double goldenMaxFrac = MathMax(0.786, MathMax(InpFiboGoldenMin, InpFiboGoldenMax) / 100.0);

      g_Fibo.zoneHigh = high - range * goldenMinFrac; // Dynamic Discount Top (Equilibrium 50.0%)
      g_Fibo.zoneLow  = high - range * goldenMaxFrac; // Dynamic Discount Bottom (OTE 78.6%)

      g_Fibo.isInsideZone = (currentPrice <= g_Fibo.zoneHigh && currentPrice >= g_Fibo.zoneLow);
      
      // Arming trigger: Check if any recent bar dipped cleanly into the SMC Discount Zone (<= 50% or EMA retest in Discount)
      double emaValBull[1];
      bool emaRetestBull = (m_hEMA != INVALID_HANDLE && CopyBuffer(m_hEMA, 0, 0, 1, emaValBull) > 0 && currentBar[0].low <= (emaValBull[0] + (30 * _Point)) && currentBar[0].low <= g_Fibo.p500);

      for(int b = 0; b < MathMin(6, ArraySize(currentBar)); b++)
      {
         if((currentBar[b].low <= g_Fibo.zoneHigh && currentBar[b].high >= g_Fibo.zoneLow) ||
            (currentBar[b].low <= g_Fibo.p500 && currentBar[b].low >= g_Fibo.p786) || emaRetestBull)
         {
            g_PullbackArmed = true;
            break;
         }
      }

      // Smart Pullback Latch: Disarm if price breaks below Swing Low (structure failed),
      // or if price rallies back up into Premium / Peak (Anti-Peak: >= high - 20% range), or explodes above Swing High
      if(currentPrice < (low - (30 * _Point)) || currentPrice > (high + (30 * _Point)) || currentPrice >= (high - (range * 0.20)))
         g_PullbackArmed = false;

      if(currentPrice > g_Fibo.zoneHigh)
         g_Fibo.distanceToZone = (currentPrice - g_Fibo.zoneHigh) / _Point;
      else if(currentPrice < g_Fibo.zoneLow)
         g_Fibo.distanceToZone = (g_Fibo.zoneLow - currentPrice) / _Point;
      else
         g_Fibo.distanceToZone = 0.0;
   }
   else if(g_MarketTrend == TREND_BEARISH)
   {
      g_Fibo.p0    = low;
      g_Fibo.p236  = low + range * 0.236;
      g_Fibo.p382  = low + range * 0.382;
      g_Fibo.p500  = low + range * 0.500;
      g_Fibo.p618  = low + range * 0.618;
      g_Fibo.p786  = low + range * 0.786;
      g_Fibo.p100  = high;
      g_Fibo.p1272 = low - range * 0.272;
      g_Fibo.p1618 = low - range * 0.618;
      g_Fibo.p2618 = low - range * 1.618;

      double goldenMinFrac = MathMax(0.500, MathMin(InpFiboGoldenMin, InpFiboGoldenMax) / 100.0); // SMC Rule: Premium is STRICTLY >= 50% Equilibrium!
      double goldenMaxFrac = MathMax(0.786, MathMax(InpFiboGoldenMin, InpFiboGoldenMax) / 100.0);

      g_Fibo.zoneLow  = low + range * goldenMinFrac; // Dynamic Premium Bottom (Equilibrium 50.0%)
      g_Fibo.zoneHigh = low + range * goldenMaxFrac; // Dynamic Premium Top (OTE 78.6%)

      g_Fibo.isInsideZone = (currentPrice >= g_Fibo.zoneLow && currentPrice <= g_Fibo.zoneHigh);
      
      // Arming trigger: Check if any recent bar rallied cleanly into the SMC Premium Zone (>= 50% or EMA retest in Premium)
      double emaValBear[1];
      bool emaRetestBear = (m_hEMA != INVALID_HANDLE && CopyBuffer(m_hEMA, 0, 0, 1, emaValBear) > 0 && currentBar[0].high >= (emaValBear[0] - (30 * _Point)) && currentBar[0].high >= g_Fibo.p500);

      for(int b = 0; b < MathMin(6, ArraySize(currentBar)); b++)
      {
         if((currentBar[b].high >= g_Fibo.zoneLow && currentBar[b].low <= g_Fibo.zoneHigh) ||
            (currentBar[b].high >= g_Fibo.p500 && currentBar[b].high <= g_Fibo.p786) || emaRetestBear)
         {
            g_PullbackArmed = true;
            break;
         }
      }

      // Smart Pullback Latch: Disarm if price breaks above Swing High (structure failed),
      // or if price dumps back down into Discount / Trough (Anti-Bottom: <= low + 20% range), or drops below Swing Low
      if(currentPrice > (high + (30 * _Point)) || currentPrice < (low - (30 * _Point)) || currentPrice <= (low + (range * 0.20)))
         g_PullbackArmed = false;

      if(currentPrice < g_Fibo.zoneLow)
         g_Fibo.distanceToZone = (g_Fibo.zoneLow - currentPrice) / _Point;
      else if(currentPrice > g_Fibo.zoneHigh)
         g_Fibo.distanceToZone = (currentPrice - g_Fibo.zoneHigh) / _Point;
      else
         g_Fibo.distanceToZone = 0.0;
   }
   else // TREND_SIDEWAY: Maintain active Fibo Retracement levels from last major swing!
   {
      double goldenMinFrac = MathMin(InpFiboGoldenMin, InpFiboGoldenMax) / 100.0;
      double goldenMaxFrac = MathMax(InpFiboGoldenMin, InpFiboGoldenMax) / 100.0;
      if(goldenMinFrac <= 0.10) goldenMinFrac = 0.382;
      if(goldenMaxFrac <= 0.10) goldenMaxFrac = 0.786;

      bool isLastSwingUp = (g_LastSwingHigh.time >= g_LastSwingLow.time);
      if(isLastSwingUp)
      {
         g_Fibo.p0    = high;
         g_Fibo.p236  = high - range * 0.236;
         g_Fibo.p382  = high - range * 0.382;
         g_Fibo.p500  = high - range * 0.500;
         g_Fibo.p618  = high - range * 0.618;
         g_Fibo.p786  = high - range * 0.786;
         g_Fibo.p100  = low;
         g_Fibo.p1272 = high + range * 0.272;
         g_Fibo.p1618 = high + range * 0.618;
         g_Fibo.p2618 = high + range * 1.618;
         g_Fibo.zoneHigh = high - range * goldenMinFrac;
         g_Fibo.zoneLow  = high - range * goldenMaxFrac;
      }
      else
      {
         g_Fibo.p0    = low;
         g_Fibo.p236  = low + range * 0.236;
         g_Fibo.p382  = low + range * 0.382;
         g_Fibo.p500  = low + range * 0.500;
         g_Fibo.p618  = low + range * 0.618;
         g_Fibo.p786  = low + range * 0.786;
         g_Fibo.p100  = high;
         g_Fibo.p1272 = low - range * 0.272;
         g_Fibo.p1618 = low - range * 0.618;
         g_Fibo.p2618 = low - range * 1.618;
         g_Fibo.zoneLow  = low + range * goldenMinFrac;
         g_Fibo.zoneHigh = low + range * goldenMaxFrac;
      }
      g_Fibo.isInsideZone = (currentPrice <= g_Fibo.zoneHigh && currentPrice >= g_Fibo.zoneLow);
      g_PullbackArmed = false;
   }
}

//+------------------------------------------------------------------+
//| 3. SMC FAIR VALUE GAP (FVG / IMBALANCE) DETECTOR                 |
//+------------------------------------------------------------------+
void DetectFairValueGaps()
{
   ZeroMemory(g_ActiveFVG);
   g_FVG_Active = false;

   if(!InpUseFVG)
      return;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpTimeframe, 0, 15, r) < 15)
      return;

   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double curPrice = (ask + bid) / 2.0;

   double fvgBuffer = MathMax(50.0, (double)g_AssetProfile.fallbackSL * 0.08) * _Point;
   double minGapPts = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpMinFVG_Points : MathMax((double)InpMinFVG_Points, (double)g_AssetProfile.fallbackSL * 0.15);

   // Scan for most recent Bullish / Bearish FVG
   for(int i = 1; i <= 10; i++)
   {
      // Bullish FVG: Gap between Bar i+2 High and Bar i Low
      if(g_MarketTrend == TREND_BULLISH && (r[i].low - r[i+2].high) >= (minGapPts * _Point))
      {
         double top = r[i].low;
         double btm = r[i+2].high;
         if(curPrice >= btm && curPrice <= top + fvgBuffer)
         {
            g_ActiveFVG.time = r[i+1].time;
            g_ActiveFVG.topPrice = top;
            g_ActiveFVG.bottomPrice = btm;
            g_ActiveFVG.direction = 1;
            g_ActiveFVG.isActive = true;
            g_FVG_Active = true;
            break;
         }
      }
      // Bearish FVG: Gap between Bar i+2 Low and Bar i High
      else if(g_MarketTrend == TREND_BEARISH && (r[i+2].low - r[i].high) >= (minGapPts * _Point))
      {
         double top = r[i+2].low;
         double btm = r[i].high;
         if(curPrice <= top && curPrice >= btm - fvgBuffer)
         {
            g_ActiveFVG.time = r[i+1].time;
            g_ActiveFVG.topPrice = top;
            g_ActiveFVG.bottomPrice = btm;
            g_ActiveFVG.direction = -1;
            g_ActiveFVG.isActive = true;
            g_FVG_Active = true;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 3.1 SMC ORDER BLOCK (OB / SUPPLY & DEMAND) DETECTOR              |
//+------------------------------------------------------------------+
void DetectOrderBlocks()
{
   ZeroMemory(g_ActiveOB);
   g_OB_Active = false;

   if(!InpUseOrderBlock)
      return;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int lookback = MathMax(15, InpOB_Lookback);
   if(CopyRates(_Symbol, InpTimeframe, 0, lookback, r) < lookback)
      return;

   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double curPrice = (ask + bid) / 2.0;

   double obMarginNear = MathMax(30.0, (double)g_AssetProfile.fallbackSL * 0.05) * _Point;
   double obMarginFar  = MathMax(150.0, (double)g_AssetProfile.fallbackSL * 0.25) * _Point;

   // 1. DUAL SMC ORDER BLOCK ENGINE (Scans Both Demand & Supply Overhead/Underneath)
   // A. Bearish Supply Order Block (Overhead Resistance / Peak Protection)
   for(int i = 1; i < lookback - 2; i++)
   {
      if(r[i].close > r[i].open)
      {
         if(r[i-1].close < r[i].low)
         {
            double top = r[i].high;
            double btm = MathMin(r[i].open, r[i].low);
            
            if(curPrice <= top + obMarginNear && curPrice >= btm - obMarginFar)
            {
               g_ActiveOB.time = r[i].time;
               g_ActiveOB.topPrice = top;
               g_ActiveOB.bottomPrice = btm;
               g_ActiveOB.direction = -1;
               g_ActiveOB.isActive = true;
               g_ActiveOB.label = StringFormat("💎 SUPPLY OB [%.2f - %.2f]", btm, top);
               g_OB_Active = true;
               break;
            }
         }
      }
   }

   // B. Bullish Demand Order Block (Underneath Support / Dip Protection)
   if(!g_OB_Active)
   {
      for(int i = 1; i < lookback - 2; i++)
      {
         if(r[i].close < r[i].open)
         {
            if(r[i-1].close > r[i].high)
            {
               double top = MathMax(r[i].open, r[i].high);
               double btm = r[i].low;
               
               if(curPrice >= btm - obMarginNear && curPrice <= top + obMarginFar)
               {
                  g_ActiveOB.time = r[i].time;
                  g_ActiveOB.topPrice = top;
                  g_ActiveOB.bottomPrice = btm;
                  g_ActiveOB.direction = 1;
                  g_ActiveOB.isActive = true;
                  g_ActiveOB.label = StringFormat("💎 DEMAND OB [%.2f - %.2f]", btm, top);
                  g_OB_Active = true;
                  break;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 3.2 ICT UNICORN MODEL (BREAKER BLOCK + FVG CONFLUENCE ENGINE)    |
//+------------------------------------------------------------------+
void DetectUnicornModel()
{
   ZeroMemory(g_Unicorn_Setup);
   g_Unicorn_Setup.state = UNICORN_NONE;
   g_Unicorn_Setup.isActive = false;

   if(!InpUseICT_Unicorn)
      return;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int lookback = MathMax(25, InpOB_Lookback + 5);
   if(CopyRates(_Symbol, InpTimeframe, 0, lookback, r) < 15)
      return;

   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double curPrice = (ask + bid) / 2.0;
   double buffer = MathMax(30.0, (double)g_AssetProfile.fallbackSL * 0.05) * _Point;
   double minGapPts = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpMinFVG_Points : MathMax((double)InpMinFVG_Points, (double)g_AssetProfile.fallbackSL * 0.15);
   double maxApproachDist = (g_AssetProfile.assetType == ASSET_GOLD) ? (800.0 * _Point) : (g_AssetProfile.fallbackSL * 1.5 * _Point);
   double targetExpansionPts = MathMax(350.0 * _Point, (double)g_AssetProfile.fallbackSL * 0.60 * _Point);

   S_Unicorn_Setup bestBullish;
   ZeroMemory(bestBullish);
   bestBullish.state = UNICORN_NONE;
   bestBullish.isActive = false;
   int bestBullishAge = 999;

   S_Unicorn_Setup bestBearish;
   ZeroMemory(bestBearish);
   bestBearish.state = UNICORN_NONE;
   bestBearish.isActive = false;
   int bestBearishAge = 999;

   // 1. BULLISH UNICORN (Bearish OB failed via Bullish MSS + Bullish FVG overlap)
   for(int b = 2; b < lookback - 4; b++)
   {
      if(r[b].close > r[b].open)
      {
         double bTop = MathMax(r[b].open, r[b].high);
         double bBtm = MathMin(r[b].open, r[b].low);

         bool brokenAbove = false;
         int breakBar = -1;
         for(int k = b - 1; k >= 1; k--)
         {
            if(r[k].close > bTop)
            {
               brokenAbove = true;
               breakBar = k;
               break;
            }
         }

         if(brokenAbove && breakBar >= 1)
         {
            for(int f = 1; f < b; f++)
            {
               if((r[f].low - r[f+2].high) >= (minGapPts * _Point))
               {
                  double fvgTop = r[f].low;
                  double fvgBtm = r[f+2].high;

                  double oTop = MathMin(bTop, fvgTop);
                  double oBtm = MathMax(bBtm, fvgBtm);

                  if(oTop >= oBtm - buffer)
                  {
                     // Invalidation 1: Price fell below breaker bottom
                     if(curPrice < bBtm - buffer)
                        continue;

                     // Invalidation 2 (Lifecycle Expiration):
                     // If price already rallied to target expansion and made swing high, setup is complete/expired!
                     bool alreadyTargetReached = false;
                     for(int h = f - 1; h >= 0; h--)
                     {
                        if(r[h].high >= oTop + targetExpansionPts)
                        {
                           alreadyTargetReached = true;
                           break;
                        }
                     }
                     if(g_LastSwingHigh.price > 0 && g_LastSwingHigh.price >= oTop + targetExpansionPts && g_LastSwingHigh.time >= r[f].time)
                     {
                        alreadyTargetReached = true;
                     }

                     if(alreadyTargetReached)
                        continue;

                     if(curPrice >= oBtm - buffer && curPrice <= oTop + maxApproachDist)
                     {
                        if(f < bestBullishAge)
                        {
                           bestBullishAge = f;
                           bestBullish.state         = UNICORN_BULLISH;
                           bestBullish.triggerTime   = r[f].time;
                           bestBullish.breakerTop    = bTop;
                           bestBullish.breakerBottom = bBtm;
                           bestBullish.fvgTop        = fvgTop;
                           bestBullish.fvgBottom     = fvgBtm;
                           bestBullish.overlapTop    = oTop;
                           bestBullish.overlapBottom = oBtm;
                           bestBullish.isActive      = true;
                        }
                     }
                  }
               }
            }
         }
      }
   }

   // 2. BEARISH UNICORN (Bullish OB failed via Bearish MSS + Bearish FVG overlap)
   for(int b = 2; b < lookback - 4; b++)
   {
      if(r[b].close < r[b].open)
      {
         double bTop = MathMax(r[b].open, r[b].high);
         double bBtm = MathMin(r[b].open, r[b].low);

         bool brokenBelow = false;
         int breakBar = -1;
         for(int k = b - 1; k >= 1; k--)
         {
            if(r[k].close < bBtm)
            {
               brokenBelow = true;
               breakBar = k;
               break;
            }
         }

         if(brokenBelow && breakBar >= 1)
         {
            for(int f = 1; f < b; f++)
            {
               if((r[f+2].low - r[f].high) >= (minGapPts * _Point))
               {
                  double fvgTop = r[f+2].low;
                  double fvgBtm = r[f].high;

                  double oTop = MathMin(bTop, fvgTop);
                  double oBtm = MathMax(bBtm, fvgBtm);

                  if(oTop >= oBtm - buffer)
                  {
                     // Invalidation 1: Price rose above breaker top
                     if(curPrice > bTop + buffer)
                        continue;

                     // Invalidation 2 (Lifecycle Expiration):
                     // If price already dumped to target expansion, setup is complete/expired!
                     bool alreadyTargetReached = false;
                     for(int h = f - 1; h >= 0; h--)
                     {
                        if(r[h].low <= oBtm - targetExpansionPts)
                        {
                           alreadyTargetReached = true;
                           break;
                        }
                     }
                     if(g_LastSwingLow.price > 0 && g_LastSwingLow.price <= oBtm - targetExpansionPts && g_LastSwingLow.time >= r[f].time)
                     {
                        alreadyTargetReached = true;
                     }

                     if(alreadyTargetReached)
                        continue;

                     if(curPrice <= oTop + buffer && curPrice >= oBtm - maxApproachDist)
                     {
                        if(f < bestBearishAge)
                        {
                           bestBearishAge = f;
                           bestBearish.state         = UNICORN_BEARISH;
                           bestBearish.triggerTime   = r[f].time;
                           bestBearish.breakerTop    = bTop;
                           bestBearish.breakerBottom = bBtm;
                           bestBearish.fvgTop        = fvgTop;
                           bestBearish.fvgBottom     = fvgBtm;
                           bestBearish.overlapTop    = oTop;
                           bestBearish.overlapBottom = oBtm;
                           bestBearish.isActive      = true;
                        }
                     }
                  }
               }
            }
         }
      }
   }

   // Select the most recent active setup
   if(bestBullish.isActive && bestBearish.isActive)
   {
      if(bestBullishAge <= bestBearishAge)
         g_Unicorn_Setup = bestBullish;
      else
         g_Unicorn_Setup = bestBearish;
   }
   else if(bestBullish.isActive)
   {
      g_Unicorn_Setup = bestBullish;
   }
   else if(bestBearish.isActive)
   {
      g_Unicorn_Setup = bestBearish;
   }
   else
   {
      g_Unicorn_Setup.state = UNICORN_NONE;
      g_Unicorn_Setup.isActive = false;
   }
}

//+------------------------------------------------------------------+
//| 3.3 CANDLE RANGE THEORY (CRT) & 3-CANDLE TURTLE SOUP ENGINE      |
//+------------------------------------------------------------------+
void DetectCandleRangeTheory()
{
   ZeroMemory(g_CRT_Setup);
   g_CRT_Setup.state = CRT_NONE;
   g_CRT_Setup.isActive = false;

   if(!InpUseCRT_TurtleSoup)
      return;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int lookback = 20;
   if(CopyRates(_Symbol, InpTimeframe, 0, lookback, r) < 8)
      return;

   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double curPrice = (ask + bid) / 2.0;
   double crtBufNear = MathMax(20.0, (double)g_AssetProfile.fallbackSL * 0.04) * _Point;
   double crtBufFar  = MathMax(40.0, (double)g_AssetProfile.fallbackSL * 0.08) * _Point;

   // Scan recent completed bars for 3-Candle CRT Turtle Soup
   double swingRng = (g_LastSwingHigh.price > g_LastSwingLow.price) ? (g_LastSwingHigh.price - g_LastSwingLow.price) : 0;
   double discountCeiling = (swingRng > 100 * _Point) ? (g_LastSwingLow.price + (swingRng * 0.45)) : 0;
   double premiumFloor    = (swingRng > 100 * _Point) ? (g_LastSwingHigh.price - (swingRng * 0.45)) : 0;

   for(int s = 1; s <= 5; s++)
   {
      // 1. BULLISH CRT TURTLE SOUP (SSL Sweep Rejection)
      // Must be in Discount/Valley zone, price must reject back above swept level, and current bar cannot be a dumping knife
      bool inDiscountZone = (discountCeiling <= 0 || curPrice <= discountCeiling || g_LQ_Radar.sslSwept);
      bool isDumpingBar0  = (r[0].close < r[0].open && (r[0].open - r[0].close) > (25 * _Point) && (r[0].close - r[0].low) < (r[0].open - r[0].close) * 0.4);

      if(inDiscountZone && !isDumpingBar0 && r[s].low < r[s+1].low && r[s].close > r[s+1].low)
      {
         double lowerWickLen = MathMin(r[s].open, r[s].close) - r[s].low;
         double candleBody   = MathAbs(r[s].close - r[s].open);
         double minWick = MathMax(20.0 * _Point, (double)g_AssetProfile.fallbackSL * 0.05 * _Point);
         bool wickRatioOk = (candleBody > 5.0 * _Point) ? (lowerWickLen >= candleBody * InpMinWickToBodyRatio) : true;

         if(lowerWickLen >= minWick && wickRatioOk)
         {
            double retestMid = r[s].low + (lowerWickLen * 0.5);
            double maxCRTApproach = (g_AssetProfile.assetType == ASSET_GOLD) ? (800.0 * _Point) : (g_AssetProfile.fallbackSL * 1.5 * _Point);
            if(curPrice >= r[s].low - crtBufNear && curPrice <= MathMin(r[s].open, r[s].close) + maxCRTApproach)
            {
               g_CRT_Setup.state          = CRT_BULLISH_SWEEP;
               g_CRT_Setup.triggerTime    = r[s].time;
               g_CRT_Setup.refLevel       = r[s+1].low;
               g_CRT_Setup.sweepExtreme   = r[s].low;
               g_CRT_Setup.retestMidpoint = retestMid;
               g_CRT_Setup.barIndex       = s;
               g_CRT_Setup.isActive       = true;
               break;
            }
         }
      }

      // 2. BEARISH CRT TURTLE SOUP (BSL Sweep Rejection)
      // Must be in Premium/Peak zone, price must reject back below swept level, and current bar cannot be a pumping rocket
      bool inPremiumZone = (premiumFloor <= 0 || curPrice >= premiumFloor || g_LQ_Radar.bslSwept);
      bool isPumpingBar0 = (r[0].close > r[0].open && (r[0].close - r[0].open) > (25 * _Point) && (r[0].high - r[0].close) < (r[0].close - r[0].open) * 0.4);

      if(inPremiumZone && !isPumpingBar0 && r[s].high > r[s+1].high && r[s].close < r[s+1].high)
      {
         double upperWickLen = r[s].high - MathMax(r[s].open, r[s].close);
         double candleBody   = MathAbs(r[s].close - r[s].open);
         double minWick = MathMax(20.0 * _Point, (double)g_AssetProfile.fallbackSL * 0.05 * _Point);
         bool wickRatioOk = (candleBody > 5.0 * _Point) ? (upperWickLen >= candleBody * InpMinWickToBodyRatio) : true;

         if(upperWickLen >= minWick && wickRatioOk)
         {
            double retestMid = r[s].high - (upperWickLen * 0.5);
            double maxCRTApproach = (g_AssetProfile.assetType == ASSET_GOLD) ? (800.0 * _Point) : (g_AssetProfile.fallbackSL * 1.5 * _Point);
            if(curPrice <= r[s].high + crtBufNear && curPrice >= MathMax(r[s].open, r[s].close) - maxCRTApproach)
            {
               g_CRT_Setup.state          = CRT_BEARISH_SWEEP;
               g_CRT_Setup.triggerTime    = r[s].time;
               g_CRT_Setup.refLevel       = r[s+1].high;
               g_CRT_Setup.sweepExtreme   = r[s].high;
               g_CRT_Setup.retestMidpoint = retestMid;
               g_CRT_Setup.barIndex       = s;
               g_CRT_Setup.isActive       = true;
               break;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 3.4 FOREX LAB P'CHANUT 50% WICK EQUILIBRIUM & 3-CANDLE SNIPER   |
//+------------------------------------------------------------------+
void DetectWickReversalSniper()
{
   ZeroMemory(g_WickSniper_Setup);
   g_WickSniper_Setup.isActive = false;

   if(!InpUseWickReversalSniper) return;

   // 1. Fetch last 24 H1 candles
   MqlRates h1Rates[];
   ArraySetAsSeries(h1Rates, true);
   int copiedH1 = CopyRates(_Symbol, PERIOD_H1, 0, 24, h1Rates);
   if(copiedH1 < 10) return;

   double minWickPts = (g_AssetProfile.assetType == ASSET_GOLD) ? InpWickMinLengthPts : (InpWickMinLengthPts * 0.7);
   double curPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Search H1 candles from shift 1 to 20 for the most prominent rejection wick
   for(int i = 1; i < copiedH1 - 1; i++)
   {
      double h = h1Rates[i].high;
      double l = h1Rates[i].low;
      double o = h1Rates[i].open;
      double c = h1Rates[i].close;
      double bodyTop = MathMax(o, c);
      double bodyBottom = MathMin(o, c);
      double candleRange = (h - l) / _Point;
      double bodyPts = (bodyTop - bodyBottom) / _Point;

      // --- BULLISH 50% WICK (Long Lower Wick at Swing Low / Support) ---
      double lowerWickPts = (bodyBottom - l) / _Point;
      if(lowerWickPts >= minWickPts && (lowerWickPts >= bodyPts * 1.4 || bodyPts <= 150))
      {
         double wickEq = NormalizeDouble((bodyBottom + l) / 2.0, _Digits);
         double distToEq = MathAbs(curPrice - wickEq) / _Point;
         if(distToEq <= 180.0 || (curPrice >= l - (30 * _Point) && curPrice <= bodyBottom + (50 * _Point)))
         {
            g_WickSniper_Setup.isActive = true;
            g_WickSniper_Setup.direction = ORDER_TYPE_BUY;
            g_WickSniper_Setup.h1BarTime = h1Rates[i].time;
            g_WickSniper_Setup.wickHigh = bodyBottom;
            g_WickSniper_Setup.wickLow = l;
            g_WickSniper_Setup.wickEquilibrium = wickEq;
            g_WickSniper_Setup.wickLengthPts = lowerWickPts;
            g_WickSniper_Setup.stopLoss = NormalizeDouble(l - (50 * _Point), _Digits);
            g_WickSniper_Setup.entryPrice = curPrice;
            g_WickSniper_Setup.takeProfit1 = NormalizeDouble(wickEq + (MathMax(250.0, lowerWickPts * 1.5) * _Point), _Digits);
            g_WickSniper_Setup.takeProfit2 = NormalizeDouble(wickEq + (lowerWickPts * 2.8 * _Point), _Digits);
            g_WickSniper_Setup.priceInWickZone = true;
            g_WickSniper_Setup.description = StringFormat("50%% Wick H1 [%.2f] (ไส้ล่าง %.0f pts)", wickEq, lowerWickPts);
            break;
         }
      }

      // --- BEARISH 50% WICK (Long Upper Wick at Swing High / Resistance) ---
      double upperWickPts = (h - bodyTop) / _Point;
      if(upperWickPts >= minWickPts && (upperWickPts >= bodyPts * 1.4 || bodyPts <= 150))
      {
         double wickEq = NormalizeDouble((h + bodyTop) / 2.0, _Digits);
         double distToEq = MathAbs(curPrice - wickEq) / _Point;
         if(distToEq <= 180.0 || (curPrice <= h + (30 * _Point) && curPrice >= bodyTop - (50 * _Point)))
         {
            g_WickSniper_Setup.isActive = true;
            g_WickSniper_Setup.direction = ORDER_TYPE_SELL;
            g_WickSniper_Setup.h1BarTime = h1Rates[i].time;
            g_WickSniper_Setup.wickHigh = h;
            g_WickSniper_Setup.wickLow = bodyTop;
            g_WickSniper_Setup.wickEquilibrium = wickEq;
            g_WickSniper_Setup.wickLengthPts = upperWickPts;
            g_WickSniper_Setup.stopLoss = NormalizeDouble(h + (50 * _Point), _Digits);
            g_WickSniper_Setup.entryPrice = curPrice;
            g_WickSniper_Setup.takeProfit1 = NormalizeDouble(wickEq - (MathMax(250.0, upperWickPts * 1.5) * _Point), _Digits);
            g_WickSniper_Setup.takeProfit2 = NormalizeDouble(wickEq - (upperWickPts * 2.8 * _Point), _Digits);
            g_WickSniper_Setup.priceInWickZone = true;
            g_WickSniper_Setup.description = StringFormat("50%% Wick H1 [%.2f] (ไส้บน %.0f pts)", wickEq, upperWickPts);
            break;
         }
      }
   }

   // 2. Validate with 3-Candle Confirmation on Current Timeframe (or M5)
   if(g_WickSniper_Setup.isActive)
   {
      MqlRates currentRates[];
      ArraySetAsSeries(currentRates, true);
      int copiedCur = CopyRates(_Symbol, _Period, 0, 5, currentRates);
      if(copiedCur >= 3)
      {
         // Candle 1 (bar[2]): Extreme Wick / Sweep
         // Candle 2 (bar[1]): Solid Candle Body Close Confirmation
         double c2Open = currentRates[1].open;
         double c2Close = currentRates[1].close;
         double c2High = currentRates[1].high;
         double c2Low = currentRates[1].low;
         double c2Range = c2High - c2Low;

         if(g_WickSniper_Setup.direction == ORDER_TYPE_BUY)
         {
            double body = c2Close - c2Open;
            double upperWick = c2High - c2Close;
            // Confirm: Candle 2 closed bullish, body >= 70 pts, upper wick <= InpWickMaxCounterRatio of range
            if(body >= (70 * _Point) && (c2Range <= 0 || (upperWick / c2Range) <= InpWickMaxCounterRatio))
            {
               g_WickSniper_Setup.candleCloseConfirmed = true;
               // Candle 3 (live bar[0]): Check if retesting 50% of bar[1]
               double bar1Mid = (c2Open + c2Close) / 2.0;
               if(currentRates[0].low <= (c2Close - (20 * _Point)) || curPrice <= bar1Mid + (30 * _Point) || !InpWickRequireRetest)
                  g_WickSniper_Setup.retestArmed = true;
            }
         }
         else if(g_WickSniper_Setup.direction == ORDER_TYPE_SELL)
         {
            double body = c2Open - c2Close;
            double lowerWick = c2Close - c2Low;
            if(body >= (70 * _Point) && (c2Range <= 0 || (lowerWick / c2Range) <= InpWickMaxCounterRatio))
            {
               g_WickSniper_Setup.candleCloseConfirmed = true;
               double bar1Mid = (c2Open + c2Close) / 2.0;
               if(currentRates[0].high >= (c2Close + (20 * _Point)) || curPrice >= bar1Mid - (30 * _Point) || !InpWickRequireRetest)
                  g_WickSniper_Setup.retestArmed = true;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 4. COMPREHENSIVE AI PRICE ACTION & PATTERN ENCYCLOPEDIA          |
//+------------------------------------------------------------------+
void AnalyzePriceActionAndPatterns()
{
   g_DetectedPattern = PA_NONE;
   g_PatternName = "กำลังสแกนหาแท่งเทียน...";
   g_PatternScore = 0;

   if(!InpUsePriceAction)
      return;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int copiedRates = CopyRates(_Symbol, InpTimeframe, 0, 25, r);
   if(copiedRates < 8)
      return;

   // Dynamic Multi-Asset Proportional Thresholds
   double dynamicMinSwing = g_AssetProfile.minSwing * _Point;
   double minPatternBody  = MathMax(25 * _Point, dynamicMinSwing * 0.08);
   double minPinbarRange  = MathMax(40 * _Point, dynamicMinSwing * 0.12);
   double minMarubozuBody = MathMax(60 * _Point, dynamicMinSwing * 0.20);
   double tweezerTol      = MathMax(15 * _Point, dynamicMinSwing * 0.05);
   double doubleTopTol    = MathMax(60 * _Point, dynamicMinSwing * 0.25);

   // Candle Dimensions for Bar 0, 1, 2
   double body0 = MathAbs(r[0].close - r[0].open);
   double range0 = r[0].high - r[0].low;
   double lowerWick0 = MathMin(r[0].open, r[0].close) - r[0].low;
   double upperWick0 = r[0].high - MathMax(r[0].open, r[0].close);

   double body1 = MathAbs(r[1].close - r[1].open);
   double range1 = r[1].high - r[1].low;
   double lowerWick1 = MathMin(r[1].open, r[1].close) - r[1].low;
   double upperWick1 = r[1].high - MathMax(r[1].open, r[1].close);

   double body2 = MathAbs(r[2].close - r[2].open);

   // -------------------------------------------------------------
   // 0. INSTITUTIONAL LIQUIDITY SWEEP & REVERSAL PATTERNS (TREND-AGNOSTIC)
   // -------------------------------------------------------------
   if(InpUseICT_Unicorn && g_Unicorn_Setup.isActive)
   {
      if(g_Unicorn_Setup.state == UNICORN_BULLISH)
      {
         g_DetectedPattern = PA_UNICORN_BUY;
         g_PatternName = "🦄 Bullish Unicorn 🟢";
      }
      else if(g_Unicorn_Setup.state == UNICORN_BEARISH)
      {
         g_DetectedPattern = PA_UNICORN_SELL;
         g_PatternName = "🦄 Bearish Unicorn 🔴";
      }
   }
   else if(InpUseCRT_TurtleSoup && g_CRT_Setup.isActive)
   {
      if(g_CRT_Setup.state == CRT_BULLISH_SWEEP)
      {
         g_DetectedPattern = PA_CRT_TURTLE_SOUP_BUY;
         g_PatternName = (g_JudasBuyActive) ? "🎯 London Judas + CRT Buy 🟢" : "🐢 CRT Turtle Soup 🟢";
      }
      else if(g_CRT_Setup.state == CRT_BEARISH_SWEEP)
      {
         g_DetectedPattern = PA_CRT_TURTLE_SOUP_SELL;
         g_PatternName = (g_JudasSellActive) ? "🎯 London Judas + CRT Sell 🔴" : "🐢 CRT Turtle Soup 🔴";
      }
   }

   // -------------------------------------------------------------
   // A. BULLISH TREND PATTERNS (เมื่อเทรนด์เป็นขาขึ้น หรือ ไซด์เวย์)
   // -------------------------------------------------------------
   if((g_MarketTrend == TREND_BULLISH || g_MarketTrend == TREND_SIDEWAY) && g_DetectedPattern == PA_NONE)
   {
      // 0.1 Sig ค้ำ Sig (Bullish Mother Bar Inside-Bar Reload) 🐟
      if(r[1].close > r[1].open && range1 >= dynamicMinSwing && body1 >= range1 * 0.55 &&
              r[0].high <= r[1].high && r[0].low >= r[1].low &&
              r[0].low <= (r[1].open + r[1].close) / 2.0 && lowerWick0 >= body0 * 0.4)
      {
         g_DetectedPattern = PA_MOTHER_BAR_BUY;
         g_PatternName = "🐟 Bullish Sig ค้ำ Sig (Mother Bar) 🟢";
      }
      // 1. Morning Star ⭐️ (Bar 2 Red -> Bar 1 Small Doji -> Bar 0 Green closing > 50% Bar 2)
      else if(r[2].close < r[2].open && body2 >= minPatternBody &&
         body1 <= (body2 * 0.55) && r[1].low <= r[2].low &&
         r[0].close > r[0].open && r[0].close >= (r[2].open + r[2].close) / 2.0)
      {
         g_DetectedPattern = PA_MORNING_STAR;
         g_PatternName = "Morning Star ⭐️ (กลับตัวขึ้น 3 แท่ง)";
      }
      // 2. Three White Soldiers 💂‍♂️
      else if(r[2].close > r[2].open && r[1].close > r[1].open && r[0].close > r[0].open &&
              r[0].close > r[1].close && r[1].close > r[2].close &&
              body0 >= minPatternBody && body1 >= minPatternBody && body2 >= minPatternBody)
      {
         g_DetectedPattern = PA_THREE_WHITE_SOLDIERS;
         g_PatternName = "Three White Soldiers 💂‍♂️ (3 ทหารเสือ)";
      }
      // 3. Three Inside Up 📈
      else if(r[2].close < r[2].open && r[1].close > r[1].open &&
              r[1].open > r[2].close && r[1].close < r[2].open &&
              r[0].close > r[2].open)
      {
         g_DetectedPattern = PA_THREE_INSIDE_UP;
         g_PatternName = "Three Inside Up 📈 (Harami คอนเฟิร์ม)";
      }
      // 4. Liquidity Sweep Buy ⚡ (SMC)
      else if(InpUseSMC_Sweep && g_LastSwingLow.price > 0 && r[0].low < g_LastSwingLow.price && r[0].close > g_LastSwingLow.price)
      {
         g_DetectedPattern = PA_LIQUIDITY_SWEEP_BUY;
         g_PatternName = "Liquidity Sweep Buy ⚡ (SMC Spring)";
      }
      // 5. Inverted Head & Shoulders 👤
      else if(g_LastSwingLow.price > 0 && g_PrevSwingLow.price > 0 && g_LastSwingLow.price < g_PrevSwingLow.price && r[0].close > r[1].high)
      {
         g_DetectedPattern = PA_INVERTED_HEAD_SHOULDERS;
         g_PatternName = "Inverted Head & Shoulders 👤";
      }
      // 6. Double Bottom (W) 📈
      else if(g_LastSwingLow.price > 0 && g_PrevSwingLow.price > 0 && MathAbs(g_LastSwingLow.price - g_PrevSwingLow.price) <= doubleTopTol && r[0].close > r[1].high)
      {
         g_DetectedPattern = PA_DOUBLE_BOTTOM;
         g_PatternName = "Double Bottom (W-Pattern) 📈";
      }
      // 7. Tweezer Bottom 🥢
      else if(MathAbs(r[0].low - r[1].low) <= tweezerTol && lowerWick0 >= body0 * 0.7 && lowerWick1 >= body1 * 0.7 && r[0].close > r[0].open)
      {
         g_DetectedPattern = PA_TWEEZER_BOTTOM;
         g_PatternName = "Tweezer Bottom 🥢 (แหนบคู่ก้นเท่า)";
      }
      // 8. Piercing Line ⚡
      else if(r[1].close < r[1].open && r[0].close > r[0].open &&
              r[0].open <= r[1].close && r[0].close >= (r[1].open + r[1].close) / 2.0 && r[0].close < r[1].open)
      {
         g_DetectedPattern = PA_PIERCING_LINE;
         g_PatternName = "Piercing Line ⚡ (แทงทะลุ 50%)";
      }
      // 9. Bullish Engulfing 🟢
      else if(r[0].close > r[0].open && r[1].close < r[1].open && r[0].close >= r[1].open && r[0].open <= r[1].close)
      {
         g_DetectedPattern = PA_BULLISH_ENGULFING;
         g_PatternName = "Bullish Engulfing 🟢 (กลืนกินขาขึ้น)";
      }
      // 10. Bullish Harami 🤰
      else if(r[1].close < r[1].open && r[0].close > r[0].open && r[0].open > r[1].close && r[0].close < r[1].open)
      {
         g_DetectedPattern = PA_BULLISH_HARAMI;
         g_PatternName = "Bullish Harami 🤰 (คนท้องขาขึ้น)";
      }
      // 11. Dragonfly Doji 🪓
      else if(body0 <= (minPatternBody * 0.3) && lowerWick0 >= minPinbarRange && upperWick0 <= (minPatternBody * 0.25))
      {
         g_DetectedPattern = PA_DRAGONFLY_DOJI;
         g_PatternName = "Dragonfly Doji 🪓 (โดจิหางยาวล่าง)";
      }
      // 12. Bullish Pin Bar / Hammer 🔨
      else if((lowerWick0 >= body0 * 1.8 && upperWick0 <= body0 * 0.8 && range0 >= minPinbarRange) ||
              (lowerWick1 >= body1 * 1.8 && upperWick1 <= body1 * 0.8 && range1 >= minPinbarRange))
      {
         g_DetectedPattern = PA_BULLISH_PINBAR;
         g_PatternName = "Bullish Pin Bar / Hammer 🔨";
      }
      // 13. Bullish Marubozu 🟩
      else if(r[0].close > r[0].open && body0 >= minMarubozuBody && lowerWick0 <= (minPatternBody * 0.3) && upperWick0 <= (minPatternBody * 0.3))
      {
         g_DetectedPattern = PA_BULLISH_MARUBOZU;
         g_PatternName = "Bullish Marubozu 🟩 (แท่งเขียวเต็มแท่ง)";
      }
   }

   // -------------------------------------------------------------
   // B. BEARISH TREND PATTERNS (เมื่อเทรนด์เป็นขาลง หรือ ไซด์เวย์)
   // -------------------------------------------------------------
   if((g_MarketTrend == TREND_BEARISH || g_MarketTrend == TREND_SIDEWAY) && g_DetectedPattern == PA_NONE)
   {
      // 0.1 Sig ค้ำ Sig (Bearish Mother Bar Inside-Bar Reload) 🐟
      if(r[1].close < r[1].open && range1 >= dynamicMinSwing && body1 >= range1 * 0.55 &&
              r[0].high <= r[1].high && r[0].low >= r[1].low &&
              r[0].high >= (r[1].open + r[1].close) / 2.0 && upperWick0 >= body0 * 0.4)
      {
         g_DetectedPattern = PA_MOTHER_BAR_SELL;
         g_PatternName = "🐟 Bearish Sig ค้ำ Sig (Mother Bar) 🔴";
      }
      // 1. Evening Star 💫
      else if(r[2].close > r[2].open && body2 >= minPatternBody &&
         body1 <= (body2 * 0.55) && r[1].high >= r[2].high &&
         r[0].close < r[0].open && r[0].close <= (r[2].open + r[2].close) / 2.0)
      {
         g_DetectedPattern = PA_EVENING_STAR;
         g_PatternName = "Evening Star 💫 (กลับตัวลง 3 แท่ง)";
      }
      // 2. Three Black Crows 🦅
      else if(r[2].close < r[2].open && r[1].close < r[1].open && r[0].close < r[0].open &&
              r[0].close < r[1].close && r[1].close < r[2].close &&
              body0 >= minPatternBody && body1 >= minPatternBody && body2 >= minPatternBody)
      {
         g_DetectedPattern = PA_THREE_BLACK_CROWS;
         g_PatternName = "Three Black Crows 🦅 (3 อีกาดำ)";
      }
      // 3. Three Inside Down 📉
      else if(r[2].close > r[2].open && r[1].close < r[1].open &&
              r[1].open < r[2].close && r[1].close > r[2].open &&
              r[0].close < r[2].open)
      {
         g_DetectedPattern = PA_THREE_INSIDE_DOWN;
         g_PatternName = "Three Inside Down 📉 (Harami คอนเฟิร์ม)";
      }
      // 4. Liquidity Sweep Sell ⚡ (SMC)
      else if(InpUseSMC_Sweep && g_LastSwingHigh.price > 0 && r[0].high > g_LastSwingHigh.price && r[0].close < g_LastSwingHigh.price)
      {
         g_DetectedPattern = PA_LIQUIDITY_SWEEP_SELL;
         g_PatternName = "Liquidity Sweep Sell ⚡ (SMC Upthrust)";
      }
      // 5. Double Top (M) 📉
      else if(g_LastSwingHigh.price > 0 && g_PrevSwingHigh.price > 0 && MathAbs(g_LastSwingHigh.price - g_PrevSwingHigh.price) <= doubleTopTol && r[0].close < r[1].low)
      {
         g_DetectedPattern = PA_DOUBLE_TOP;
         g_PatternName = "Double Top (M-Pattern) 📉";
      }
      // 6. Tweezer Top 🥢
      else if(MathAbs(r[0].high - r[1].high) <= tweezerTol && upperWick0 >= body0 * 0.7 && upperWick1 >= body1 * 0.7 && r[0].close < r[0].open)
      {
         g_DetectedPattern = PA_TWEEZER_TOP;
         g_PatternName = "Tweezer Top 🥢 (แหนบคู่ยอดเท่า)";
      }
      // 7. Dark Cloud Cover ☁️
      else if(r[1].close > r[1].open && r[0].close < r[0].open &&
              r[0].open >= r[1].close && r[0].close <= (r[1].open + r[1].close) / 2.0 && r[0].close > r[1].open)
      {
         g_DetectedPattern = PA_DARK_CLOUD_COVER;
         g_PatternName = "Dark Cloud Cover ☁️ (เมฆดำคลุม 50%)";
      }
      // 8. Bearish Engulfing 🔴
      else if(r[0].close < r[0].open && r[1].close > r[1].open && r[0].close <= r[1].open && r[0].open >= r[1].close)
      {
         g_DetectedPattern = PA_BEARISH_ENGULFING;
         g_PatternName = "Bearish Engulfing 🔴 (กลืนกินขาลง)";
      }
      // 9. Bearish Harami 🤰
      else if(r[1].close > r[1].open && r[0].close < r[0].open && r[0].open < r[1].close && r[0].close > r[1].open)
      {
         g_DetectedPattern = PA_BEARISH_HARAMI;
         g_PatternName = "Bearish Harami 🤰 (คนท้องขาลง)";
      }
      // 10. Gravestone Doji 🪦
      else if(body0 <= (minPatternBody * 0.3) && upperWick0 >= minPinbarRange && lowerWick0 <= (minPatternBody * 0.25))
      {
         g_DetectedPattern = PA_GRAVESTONE_DOJI;
         g_PatternName = "Gravestone Doji 🪦 (โดจิหางยาวบน)";
      }
      // 11. Bearish Shooting Star 💫
      else if((upperWick0 >= body0 * 1.8 && lowerWick0 <= body0 * 0.8 && range0 >= minPinbarRange) ||
              (upperWick1 >= body1 * 1.8 && lowerWick1 <= body1 * 0.8 && range1 >= minPinbarRange))
      {
         g_DetectedPattern = PA_BEARISH_PINBAR;
         g_PatternName = "Bearish Shooting Star 💫";
      }
      // 12. Bearish Marubozu 🟥
      else if(r[0].close < r[0].open && body0 >= minMarubozuBody && lowerWick0 <= (minPatternBody * 0.3) && upperWick0 <= (minPatternBody * 0.3))
      {
         g_DetectedPattern = PA_BEARISH_MARUBOZU;
         g_PatternName = "Bearish Marubozu 🟥 (แท่งแดงเต็มแท่ง)";
      }
   }

   // Default text if no specific pattern is active
   if(g_DetectedPattern == PA_NONE)
   {
      if(g_MarketTrend == TREND_BULLISH)
         g_PatternName = "แท่งเทียนดันขึ้นตามเทรนด์ 🟢";
      else if(g_MarketTrend == TREND_BEARISH)
         g_PatternName = "แท่งเทียนทุบลงตามเทรนด์ 🔴";
      else
         g_PatternName = "พักตัวในกรอบ Sideway 🟡";
   }

   // FVG & OB Prefix if Active
   if(g_OB_Active && g_ActiveOB.isActive)
   {
      g_PatternName = (g_ActiveOB.direction == 1 ? "💎 Demand OB + " : "💎 Supply OB + ") + g_PatternName;
   }
   else if(g_FVG_Active)
   {
      g_PatternName = "💎 FVG + " + g_PatternName;
   }

   // -------------------------------------------------------------
   // C. CONFLUENCE QUALITY SCORING ENGINE (0 - 100%)
   // -------------------------------------------------------------
   int score = 0;
   // 1. Trend Alignment (25%)
   if(g_MarketTrend != TREND_SIDEWAY) score += 25;
   
   // 2. Fibo Golden Zone & OB Confluence (25%)
   if(g_PullbackArmed || g_Fibo.isInsideZone || (g_OB_Active && g_ActiveOB.isActive)) score += 25;
   else if(g_Fibo.distanceToZone < 150) score += 15;

   // 3. Price Action / Chart Pattern (20%)
   if(g_DetectedPattern != PA_NONE || (InpUseCRT_TurtleSoup && g_CRT_Setup.isActive) || (InpUseICT_Unicorn && g_Unicorn_Setup.isActive)) score += 20;
   else if(r[0].close > r[0].open && g_MarketTrend == TREND_BULLISH) score += 10;
   else if(r[0].close < r[0].open && g_MarketTrend == TREND_BEARISH) score += 10;

   // 4. SMC FVG & OB Imbalance Bonus (15%)
   if(g_OB_Active && g_ActiveOB.isActive) score += 15;
   else if(g_FVG_Active) score += 15;

   // 5. Pure Candlestick Rejection & Structure Shift Momentum (15%)
   if(g_PABuyTrigger || g_PASellTrigger) score += 15;
   else if(r[0].close > r[0].open && g_MarketTrend == TREND_BULLISH) score += 10;
   else if(r[0].close < r[0].open && g_MarketTrend == TREND_BEARISH) score += 10;

   // 6. Linear Regression Channel & HTF Alignment Confluence (Up to 15%)
   if(InpEnableLRLChannel)
   {
      if(InpLRL_BonusDipBuy && (g_LRL_Chart.devLower > 0 || g_LRL_Chart.stdDev > 0))
      {
         double curBid = m_symbol.Bid();
         double curAsk = m_symbol.Ask();
         if(g_MarketTrend == TREND_BULLISH && curAsk <= (g_LRL_Chart.lowerPrice + (50 * _Point)))
         {
            score += 15; // Golden Dip-Buy at Lower Wick Channel Support
            g_PatternName += " + LRL Dip";
         }
         else if(g_MarketTrend == TREND_BEARISH && curBid >= (g_LRL_Chart.upperPrice - (50 * _Point)))
         {
            score += 15; // Golden Rally-Sell at Upper Wick Channel Resistance
            g_PatternName += " + LRL Peak";
         }
         else if(g_LRL_HTF_Consensus == (g_MarketTrend == TREND_BULLISH ? LRL_TREND_BULLISH : LRL_TREND_BEARISH))
         {
            score += 10; // HTF 200-bar Linear Regression Confirms Trend
         }
      }
   }

   // 7. SMC Liquidity Sweep Confluence Bonus (Up to 15% - Trend-Agnostic Reversal Confluence)
   if(g_LQ_Radar.sslSwept)
   {
      score += 15; // SSL swept below: Stop hunt done, institutional dip-buy trigger
      g_PatternName += " + SSL Trap";
   }
   else if(g_LQ_Radar.bslSwept)
   {
      score += 15; // BSL swept above: Stop hunt done, institutional peak-sell trigger
      g_PatternName += " + BSL Trap";
   }

   // 8. VPA (Volume Price Analysis) Absorption & Effort vs Result Confluence (Up to 15%)
   if(InpUseVPAEngine && copiedRates >= 21)
   {
      double sumVol = 0;
      for(int vi = 1; vi <= 20; vi++)
      {
         sumVol += (double)r[vi].tick_volume;
      }
      double avgVol = sumVol / 20.0;
      if(avgVol > 0)
      {
         double curVolRatio  = (double)r[0].tick_volume / avgVol;
         double prevVolRatio = (double)r[1].tick_volume / avgVol;

         // A. Volume Absorption / Supply-Demand Dry-Up in Fibo Golden Zone or OB Support/Resistance
         if(g_PullbackArmed || g_Fibo.isInsideZone || (g_OB_Active && g_ActiveOB.isActive))
         {
            if(prevVolRatio < 0.85 || curVolRatio < 0.85)
            {
               score += 10;
               g_PatternName += " + VPA 🧪";
            }
         }

         // B. Effort vs Result: High Volume Confirmation on Breakout / Reversal Pattern
         if(g_DetectedPattern != PA_NONE && (curVolRatio >= 1.25 || prevVolRatio >= 1.25))
         {
            score += 15;
            g_PatternName += " + VPA 🚀";
         }
      }
   }

   // 9. CRT (Candle Range Theory) Turtle Soup Confluence Bonus (Up to +15 pts)
   if(InpUseCRT_TurtleSoup && g_CRT_Setup.isActive)
   {
      score += 15;
      if(StringFind(g_PatternName, "CRT") < 0)
         g_PatternName += " + CRT 🐢";
   }

   // 10. ICT Unicorn Model Confluence Bonus (Up to +15 pts)
   if(InpUseICT_Unicorn && g_Unicorn_Setup.isActive)
   {
      score += 15;
      if(StringFind(g_PatternName, "Unicorn") < 0)
         g_PatternName += " + Unicorn 🦄";
   }

   // 11. London Judas Swing Confluence Bonus (+15 pts)
   if(InpUseAsianRangeJudas)
   {
      if(g_JudasSellActive)
      {
         score += 15;
         if(StringFind(g_PatternName, "Judas") < 0)
            g_PatternName += " + Judas 🎯";
      }
      else if(g_JudasBuyActive)
      {
         score += 15;
         if(StringFind(g_PatternName, "Judas") < 0)
            g_PatternName += " + Judas 🎯";
      }
   }

   // 12. CME Options Polarity Flip Retest Confluence Bonus (+15 pts)
   if(InpUseCMEWallGuard)
   {
      double curBid = m_symbol.Bid();
      double curAsk = m_symbol.Ask();
      double retestCorridor = 150.0 * _Point;

      // Bullish Retest of broken Call strike (Support Role Reversal)
      bool isBullRetest = false;
      if(InpCME_IntermediateCall > 0 && curAsk >= InpCME_IntermediateCall && curAsk <= (InpCME_IntermediateCall + retestCorridor))
      {
         if(r[0].close >= r[0].open || (MathMin(r[0].open, r[0].close) - r[0].low) >= (15 * _Point))
            isBullRetest = true;
      }
      else if(InpCME_CallWall > 0 && curAsk >= InpCME_CallWall && curAsk <= (InpCME_CallWall + retestCorridor))
      {
         if(r[0].close >= r[0].open || (MathMin(r[0].open, r[0].close) - r[0].low) >= (15 * _Point))
            isBullRetest = true;
      }

      // Bearish Retest of broken Put strike (Resistance Role Reversal)
      bool isBearRetest = false;
      if(InpCME_IntermediatePut > 0 && curBid <= InpCME_IntermediatePut && curBid >= (InpCME_IntermediatePut - retestCorridor))
      {
         if(r[0].close <= r[0].open || (r[0].high - MathMax(r[0].open, r[0].close)) >= (15 * _Point))
            isBearRetest = true;
      }
      else if(InpCME_PutWall > 0 && curBid <= InpCME_PutWall && curBid >= (InpCME_PutWall - retestCorridor))
      {
         if(r[0].close <= r[0].open || (r[0].high - MathMax(r[0].open, r[0].close)) >= (15 * _Point))
            isBearRetest = true;
      }

      if((g_MarketTrend == TREND_BULLISH && isBullRetest) || (g_MarketTrend == TREND_BEARISH && isBearRetest))
      {
         score += 15;
         if(StringFind(g_PatternName, "CME Retest") < 0)
            g_PatternName += " + CME Retest 🏛️";
      }
   }

   // 13. Multi-TF EMA 14 Matrix Confluence Bonus (FOREX LAB P'Chanut Style)
   if(InpUseMultiTF_EMA14_Logic)
   {
      // A. Waterfall Cascade Alignment (+8 pts)
      if((g_MarketTrend == TREND_BEARISH && g_EMA14_CascadeDown) ||
         (g_MarketTrend == TREND_BULLISH && g_EMA14_CascadeUp))
      {
         score += 8;
         if(StringFind(g_PatternName, "EMA14 Cascade") < 0)
            g_PatternName += " + EMA14 🌊";
      }

      // B. EMA 14 Key Level Rejection / Touch (+7 pts)
      if(g_EMA14_NearTest)
      {
         score += 7;
         if(StringFind(g_PatternName, "EMA14 Touch") < 0)
            g_PatternName += " + EMA14 🟣";
      }
   }

   // 14. Institutional EMA 200 Confluence Bonus (+5 pts)
   if(InpUseEMA200_Filter && g_HTF_EMA200 > 0)
   {
      double curAsk = m_symbol.Ask();
      double curBid = m_symbol.Bid();
      if((g_MarketTrend == TREND_BULLISH && curAsk > g_HTF_EMA200) ||
         (g_MarketTrend == TREND_BEARISH && curBid < g_HTF_EMA200))
      {
         score += 5;
         if(StringFind(g_PatternName, "EMA200") < 0)
            g_PatternName += " + EMA200 🏛️";
      }
   }

      // 🔭 Forex Lab 50% Wick Sniper Quality Score Bonus
   if(InpUseWickReversalSniper && g_WickSniper_Setup.isActive)
   {
      score += 25;
      if(g_WickSniper_Setup.candleCloseConfirmed) score += 20;
      if(g_WickSniper_Setup.retestArmed) score += 15;
   }

   // 15. Samurai MTF Multi-Timeframe Alignment & Momentum Confluence (+15 pts)
   if(InpUseSamuraiMTFConfluence)
   {
      if(g_MarketTrend == TREND_BULLISH && (g_SamuraiMTF.consensusDir == 1 || g_SamuraiMTF.htfAgreesBuy))
      {
         score += 15;
         if(StringFind(g_PatternName, "Samurai MTF") < 0)
            g_PatternName += " + Samurai MTF ⚔️";
      }
      else if(g_MarketTrend == TREND_BEARISH && (g_SamuraiMTF.consensusDir == -1 || g_SamuraiMTF.htfAgreesSell))
      {
         score += 15;
         if(StringFind(g_PatternName, "Samurai MTF") < 0)
            g_PatternName += " + Samurai MTF ⚔️";
      }
      else if((g_MarketTrend == TREND_BULLISH && g_SamuraiMTF.htfAgreesSell) ||
              (g_MarketTrend == TREND_BEARISH && g_SamuraiMTF.htfAgreesBuy))
      {
         score -= 15;
      }
   }
   g_PatternScore = MathMin(100, score);

   if(g_PatternScore >= 85)
      g_SetupGrade = "👑 A+ INSTITUTIONAL";
   else if(g_PatternScore >= 70)
      g_SetupGrade = "⭐ GRADE A SETUP";
   else
      g_SetupGrade = "NORMAL SETUP";
}

//+------------------------------------------------------------------+
//| 5. PURE PRICE ACTION & CANDLESTICK REJECTION TRIGGER (OPTION A)  |
//+------------------------------------------------------------------+
void UpdatePriceActionTriggers()
{
   g_PABuyTrigger  = false;
   g_PASellTrigger = false;
   g_PARejectionType = "";

   MqlRates candleRates[];
   ArraySetAsSeries(candleRates, true);
   int count = CopyRates(_Symbol, InpTimeframe, 0, 3, candleRates);
   if(count < 2)
      return;

   // Current live bar (bar 0) metrics
   double range0 = candleRates[0].high - candleRates[0].low;
   double body0  = MathAbs(candleRates[0].close - candleRates[0].open);
   double lowerWick0 = MathMin(candleRates[0].open, candleRates[0].close) - candleRates[0].low;
   double upperWick0 = candleRates[0].high - MathMax(candleRates[0].open, candleRates[0].close);
   bool candle0Green = (candleRates[0].close > candleRates[0].open);
   bool candle0Red   = (candleRates[0].close < candleRates[0].open);

   // Previous closed bar (bar 1) metrics
   double range1 = candleRates[1].high - candleRates[1].low;
   double body1  = MathAbs(candleRates[1].close - candleRates[1].open);
   double lowerWick1 = MathMin(candleRates[1].open, candleRates[1].close) - candleRates[1].low;
   double upperWick1 = candleRates[1].high - MathMax(candleRates[1].open, candleRates[1].close);
   bool candle1Green = (candleRates[1].close > candleRates[1].open);
   bool candle1Red   = (candleRates[1].close < candleRates[1].open);

   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double currentPrice = (ask + bid) / 2.0;

   // 1. Institutional Chart & SMC Candlestick Patterns
   bool paBuyPattern = (g_DetectedPattern == PA_MORNING_STAR || g_DetectedPattern == PA_THREE_WHITE_SOLDIERS ||
                        g_DetectedPattern == PA_THREE_INSIDE_UP || g_DetectedPattern == PA_THREE_OUTSIDE_UP ||
                        g_DetectedPattern == PA_BULLISH_ENGULFING || g_DetectedPattern == PA_PIERCING_LINE ||
                        g_DetectedPattern == PA_TWEEZER_BOTTOM || g_DetectedPattern == PA_BULLISH_HARAMI ||
                        g_DetectedPattern == PA_BULLISH_KICKER || g_DetectedPattern == PA_BULLISH_PINBAR ||
                        g_DetectedPattern == PA_DRAGONFLY_DOJI || g_DetectedPattern == PA_INVERTED_HAMMER ||
                        g_DetectedPattern == PA_BULLISH_MARUBOZU || g_DetectedPattern == PA_DOUBLE_BOTTOM ||
                        g_DetectedPattern == PA_TRIPLE_BOTTOM || g_DetectedPattern == PA_INVERTED_HEAD_SHOULDERS ||
                        g_DetectedPattern == PA_FALLING_WEDGE || g_DetectedPattern == PA_LIQUIDITY_SWEEP_BUY ||
                        g_DetectedPattern == PA_CRT_TURTLE_SOUP_BUY || g_DetectedPattern == PA_UNICORN_BUY ||
                        g_DetectedPattern == PA_MOTHER_BAR_BUY || (InpUseAsianRangeJudas && g_JudasBuyActive));

   bool paSellPattern = (g_DetectedPattern == PA_EVENING_STAR || g_DetectedPattern == PA_THREE_BLACK_CROWS ||
                         g_DetectedPattern == PA_THREE_INSIDE_DOWN || g_DetectedPattern == PA_THREE_OUTSIDE_DOWN ||
                         g_DetectedPattern == PA_BEARISH_ENGULFING || g_DetectedPattern == PA_DARK_CLOUD_COVER ||
                         g_DetectedPattern == PA_TWEEZER_TOP || g_DetectedPattern == PA_BEARISH_HARAMI ||
                         g_DetectedPattern == PA_BEARISH_KICKER || g_DetectedPattern == PA_BEARISH_PINBAR ||
                         g_DetectedPattern == PA_GRAVESTONE_DOJI || g_DetectedPattern == PA_BEARISH_MARUBOZU ||
                         g_DetectedPattern == PA_DOUBLE_TOP || g_DetectedPattern == PA_TRIPLE_TOP ||
                         g_DetectedPattern == PA_HEAD_SHOULDERS || g_DetectedPattern == PA_LIQUIDITY_SWEEP_SELL ||
                         g_DetectedPattern == PA_CRT_TURTLE_SOUP_SELL || g_DetectedPattern == PA_UNICORN_SELL ||
                         g_DetectedPattern == PA_MOTHER_BAR_SELL || (InpUseAsianRangeJudas && g_JudasSellActive));

   // 2. Pure Candlestick Rejection Mechanics (Long Tail / Pinbar / Hammer / Shooting Star)
   bool bullLowerWick0 = (range0 > 0 && (lowerWick0 / range0) >= InpMinRejectionWickRatio);
   bool bullLowerWick1 = (range1 > 0 && (lowerWick1 / range1) >= InpMinRejectionWickRatio);
   bool bullPinbar0    = (body0 > 0 && lowerWick0 >= body0 * 1.5 && upperWick0 <= lowerWick0 * 0.35);
   bool bullPinbar1    = (body1 > 0 && lowerWick1 >= body1 * 1.5 && upperWick1 <= lowerWick1 * 0.35);
   bool bullColorFlip  = (candle1Red && candle0Green);
   bool bullEngulfing  = (candle0Green && candle1Red && candleRates[0].close > candleRates[1].high);
   double discCeil = (g_Fibo.p500 > 0) ? g_Fibo.p500 : ((g_Fibo.zoneHigh > 0) ? g_Fibo.zoneHigh : currentPrice);
   bool buyerPush      = (candle0Green && currentPrice <= discCeil + (30 * _Point));

   bool bearUpperWick0 = (range0 > 0 && (upperWick0 / range0) >= InpMinRejectionWickRatio);
   bool bearUpperWick1 = (range1 > 0 && (upperWick1 / range1) >= InpMinRejectionWickRatio);
   bool bearPinbar0    = (body0 > 0 && upperWick0 >= body0 * 1.5 && lowerWick0 <= upperWick0 * 0.35);
   bool bearPinbar1    = (body1 > 0 && upperWick1 >= body1 * 1.5 && lowerWick1 <= upperWick1 * 0.35);
   bool bearColorFlip  = (candle1Green && candle0Red);
   bool bearEngulfing  = (candle0Red && candle1Green && candleRates[0].close < candleRates[1].low);
   double premFloor = (g_Fibo.p500 > 0) ? g_Fibo.p500 : ((g_Fibo.zoneLow > 0) ? g_Fibo.zoneLow : currentPrice);
   bool sellerPush     = (candle0Red && currentPrice >= premFloor - (30 * _Point));

   // Bullish Final Trigger Assembly
   if(paBuyPattern || bullPinbar0 || bullPinbar1 || bullEngulfing ||
      ((bullLowerWick0 || bullLowerWick1 || bullColorFlip) && buyerPush))
   {
      g_PABuyTrigger = true;
      if(paBuyPattern) g_PARejectionType = g_PatternName;
      else if(bullPinbar0 || bullPinbar1) g_PARejectionType = "Bullish Pinbar Rejection";
      else if(bullEngulfing) g_PARejectionType = "Bullish Engulfing";
      else if(bullColorFlip) g_PARejectionType = "Bullish Color Flip";
      else g_PARejectionType = "Buyer Push";
   }

   // Bearish Final Trigger Assembly
   if(paSellPattern || bearPinbar0 || bearPinbar1 || bearEngulfing ||
      ((bearUpperWick0 || bearUpperWick1 || bearColorFlip) && sellerPush))
   {
      g_PASellTrigger = true;
      if(paSellPattern) g_PARejectionType = g_PatternName;
      else if(bearPinbar0 || bearPinbar1) g_PARejectionType = "Bearish Pinbar Rejection";
      else if(bearEngulfing) g_PARejectionType = "Bearish Engulfing";
      else if(bearColorFlip) g_PARejectionType = "Bearish Color Flip";
      else g_PARejectionType = "Seller Push";
   }
}

//+------------------------------------------------------------------+
//| 6. PROP FIRM DAILY TARGET & DRAWDOWN PROTECTION (ข้อ 3)          |
//+------------------------------------------------------------------+
void CheckDailyGuard()
{
   if(!InpUseDailyGuard)
   {
      g_DailyTargetReached = false;
      g_DailyMaxLossReached = false;
      return;
   }

   // 1. Get Day Start Time (00:00 Server Time) with StructToTime safety fallback
   datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0);
   if(startOfDay <= 0)
   {
      datetime tc = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(tc, dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      startOfDay = StructToTime(dt);
   }

   static datetime s_lastGuardDay = 0;
   if(s_lastGuardDay == 0)
   {
      datetime savedResetDay = (datetime)GlobalVariableGet(GetGVKey("GUARD_RESET_DAY"));
      if(savedResetDay > 0 && savedResetDay == startOfDay)
      {
         s_lastGuardDay = startOfDay;
         if(GlobalVariableGet(GetGVKey("GUARD_UNLOCKED")) > 0.5)
         {
            g_DailyGuardManualUnlocked = true;
            g_DailyGuardBaselinePnL    = GlobalVariableGet(GetGVKey("GUARD_BASE_PNL"));
            g_DailyGuardResetDay       = startOfDay;
         }
      }
   }

   if(startOfDay != s_lastGuardDay)
   {
      s_lastGuardDay = startOfDay;
      g_DailyTargetReached = false;
      g_DailyMaxLossReached = false;
      g_DailyGuardManualUnlocked = false;
      g_DailyGuardBaselinePnL = 0.0;
      g_DailyGuardResetDay = startOfDay;
      GlobalVariableDel(GetGVKey("GUARD_UNLOCKED"));
      GlobalVariableDel(GetGVKey("GUARD_BASE_PNL"));
      GlobalVariableDel(GetGVKey("GUARD_RESET_DAY"));
   }

   // 2. Sum today's closed PnL according to InpDailyGuardScope
   double closedToday = 0.0;
   if(startOfDay > 0 && HistorySelect(startOfDay, TimeCurrent()))
   {
      int dealsTotal = HistoryDealsTotal();
      for(int i = 0; i < dealsTotal; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket > 0)
         {
            datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            if(dealTime < startOfDay) continue;

            long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;

            long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

            bool isMatch = false;
            if(InpDailyGuardScope == GUARD_SCOPE_BOT_ONLY)
               isMatch = (magic == InpMagicNumber);
            else // GUARD_SCOPE_ALL_COMBINED
               isMatch = (magic == InpMagicNumber || (InpManageManualTrades && magic == 0) || magic == 888999);

            if(isMatch && symbol == _Symbol && (entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT || entryType == DEAL_ENTRY_OUT_BY))
            {
               closedToday += HistoryDealGetDouble(dealTicket, DEAL_PROFIT) 
                            + HistoryDealGetDouble(dealTicket, DEAL_SWAP) 
                            + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            }
         }
      }
   }

   // 2.1 Handle InpResetDailyGuardNow input toggle
   static bool s_lastResetNow = false;
   if(InpResetDailyGuardNow && !s_lastResetNow)
   {
      s_lastResetNow = true;
      g_DailyGuardManualUnlocked = true;
      g_DailyGuardBaselinePnL = closedToday;
      g_DailyGuardResetDay = startOfDay;
      g_DailyTargetReached = false;
      g_DailyMaxLossReached = false;
      GlobalVariableSet(GetGVKey("GUARD_UNLOCKED"), 1.0);
      GlobalVariableSet(GetGVKey("GUARD_BASE_PNL"), g_DailyGuardBaselinePnL);
      GlobalVariableSet(GetGVKey("GUARD_RESET_DAY"), (double)startOfDay);
   }
   else if(!InpResetDailyGuardNow)
   {
      s_lastResetNow = false;
   }

   // 3. Add Floating PnL according to Scope
   double openPnl = 0.0;
   if(InpDailyGuardScope == GUARD_SCOPE_BOT_ONLY)
   {
      for(int p = 0; p < PositionsTotal(); p++)
      {
         if(m_position.SelectByIndex(p) && m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
            openPnl += m_position.Profit() + m_position.Swap();
      }
   }
   else
   {
      openPnl = CalculateTotalProfit();
   }

   // 3.1 Effective PnL calculation considering Manual Unlock Baseline
   double effectiveClosed = closedToday;
   if(g_DailyGuardManualUnlocked && g_DailyGuardResetDay == startOfDay)
   {
      effectiveClosed = closedToday - g_DailyGuardBaselinePnL;
   }
   g_TodayPnL = effectiveClosed + openPnl;

   // 4. Calculate Drawdown % relative to Day's Starting Capital
   double balance = m_account.Balance();
   double startingCapital = balance - effectiveClosed;
   if(startingCapital <= 0.0) startingCapital = balance;

   g_TodayPnLPct = (startingCapital > 0) ? (g_TodayPnL / startingCapital) * 100.0 : 0.0;
   if(g_TodayPnLPct < -100.0) g_TodayPnLPct = -100.0; // Clamped to realistic limit

   // 5. Evaluate Targets & Hard Loss Locks (Adaptive for Cent and Standard USD accounts)
   double effDailyTarget = InpDailyProfitTarget;
   if(!IsCentAccount() && InpDailyProfitTarget >= 500.0)
      effDailyTarget = InpDailyProfitTarget / 100.0; // Auto-scale 2500c -> $25.00 on USD accounts

   if(g_TodayPnL >= effDailyTarget)
   {
      if(!g_DailyTargetReached)
      {
         g_DailyTargetReached = true;
         SendTradeNotification(StringFormat("🏆 [Good Trade Gold] Daily Target Reached: %s! Trading Locked for Today.", FormatMoney(g_TodayPnL, true)));
         Print(">>> PROP FIRM DAILY TARGET HIT: ", FormatMoney(g_TodayPnL, true), " - Auto Trade Paused.");
      }
   }
   else
   {
      g_DailyTargetReached = false;
   }

   if(g_TodayPnLPct <= -InpDailyMaxLossPct)
   {
      if(!g_DailyMaxLossReached)
      {
         g_DailyMaxLossReached = true;
         SendTradeNotification(StringFormat("🛑 [Good Trade Gold] Daily Max Loss Hit (%.1f%%)! Capital Protected.", g_TodayPnLPct));
         Print(">>> PROP FIRM MAX LOSS GUARD HIT: ", g_TodayPnLPct, "% - Trading Locked for Today.");
         PlaySound("alert.wav");
      }
   }
   else
   {
      g_DailyMaxLossReached = false;
   }
}

//+------------------------------------------------------------------+
//| 6.1 EMA 50 / 200 GOLDEN CROSS & DEATH CROSS DETECTION ENGINE     |
//+------------------------------------------------------------------+
void UpdateEMACrossStatus()
{
   if(m_hEMA == INVALID_HANDLE || m_hEMA200 == INVALID_HANDLE)
   {
      g_EMACrossStatusStr = "EMA Cross: กำลังประมวลผล...";
      g_EMACrossValCol    = clrSilver;
      g_EMACrossBarCol    = clrDimGray;
      g_EMACrossTitleCol  = clrLightGray;
      return;
   }

   double ema50[2];
   double ema200[2];
   if(CopyBuffer(m_hEMA, 0, 0, 2, ema50) < 2 || CopyBuffer(m_hEMA200, 0, 0, 2, ema200) < 2)
      return;

   // In CopyBuffer without ArraySetAsSeries: index 0 is oldest (bar 1), index 1 is newest (bar 0)
   double cur50   = ema50[1];
   double prev50  = ema50[0];
   double cur200  = ema200[1];
   double prev200 = ema200[0];

   double distPts = (cur50 - cur200) / _Point;
   double curPrice = m_symbol.Bid();
   if(curPrice <= 0) curPrice = (cur50 + cur200) / 2.0;

   if(cur50 >= cur200)
   {
      // Golden Cross State
      if(prev50 < prev200)
      {
         // Fresh Golden Cross
         g_EMACrossStatusStr = "⚡ FRESH GOLDEN CROSS (เพิ่งตัดขึ้น!)";
         g_EMACrossValCol    = clrAqua;
         g_EMACrossBarCol    = clrDeepSkyBlue;
         g_EMACrossTitleCol  = clrAqua;
      }
      else if(curPrice >= cur50)
      {
         g_EMACrossStatusStr = StringFormat("👑 GOLDEN CROSS (กระทิงคุมตลาด +%.0f pts)", MathAbs(distPts));
         g_EMACrossValCol    = clrGold;
         g_EMACrossBarCol    = clrDarkGoldenrod;
         g_EMACrossTitleCol  = clrKhaki;
      }
      else
      {
         g_EMACrossStatusStr = StringFormat("⚠️ GOLDEN CROSS (ราคาย่อพักฐาน +%.0f pts)", MathAbs(distPts));
         g_EMACrossValCol    = clrGoldenrod;
         g_EMACrossBarCol    = clrDarkOrange;
         g_EMACrossTitleCol  = clrOrange;
      }
   }
   else
   {
      // Death Cross State
      if(prev50 > prev200)
      {
         // Fresh Death Cross
         g_EMACrossStatusStr = "⚡ FRESH DEATH CROSS (เพิ่งตัดลง!)";
         g_EMACrossValCol    = clrOrangeRed;
         g_EMACrossBarCol    = clrCrimson;
         g_EMACrossTitleCol  = clrLightCoral;
      }
      else if(curPrice <= cur50)
      {
         g_EMACrossStatusStr = StringFormat("💀 DEATH CROSS (หมีคุมตลาด -%.0f pts)", MathAbs(distPts));
         g_EMACrossValCol    = clrTomato;
         g_EMACrossBarCol    = clrCrimson;
         g_EMACrossTitleCol  = clrLightCoral;
      }
      else
      {
         g_EMACrossStatusStr = StringFormat("⚠️ DEATH CROSS (ราคาเด้งรีบาวด์ -%.0f pts)", MathAbs(distPts));
         g_EMACrossValCol    = clrSandyBrown;
         g_EMACrossBarCol    = clrBrown;
         g_EMACrossTitleCol  = clrCoral;
      }
   }

   // 🟢/🔴/🟡 Multi-TF EMA 14 Status for Line 2 (Green = Buy, Red = Sell, Yellow = SW/Pullback)
   if(InpUseMultiTF_EMA14_Logic)
   {
      if(g_EMA14_CascadeDown)
      {
         g_EMA14_StatusText = "↳ 🔴 น้ำตก SELL (H4>M5) • โมเมนตัมเทขายกดทับสมบูรณ์";
         g_EMA14_StatusCol  = clrTomato;
         if(cur50 < cur200)
         {
            g_EMACrossValCol   = clrTomato;
            g_EMACrossBarCol   = clrCrimson;
            g_EMACrossTitleCol = clrLightCoral;
         }
      }
      else if(g_EMA14_CascadeUp)
      {
         g_EMA14_StatusText = "↳ 🟢 น้ำตก BUY (H4<M5) • สปีดแรงส่งขาขึ้นสมบูรณ์";
         g_EMA14_StatusCol  = clrLime;
         if(cur50 >= cur200)
         {
            g_EMACrossValCol   = clrLime;
            g_EMACrossBarCol   = clrSeaGreen;
            g_EMACrossTitleCol = clrPaleGreen;
         }
      }
      else
      {
         double h4  = g_MultiTF_EMA14[2].val;
         double h1  = g_MultiTF_EMA14[3].val;
         double m15 = g_MultiTF_EMA14[5].val;
         double m5  = g_MultiTF_EMA14[6].val;
         if(h4 > 0 && h1 > 0 && m15 > 0 && m5 > 0)
         {
            if(h4 > h1 && (m5 > m15 || curPrice > m5))
               g_EMA14_StatusText = "↳ 🟡 สถานะ EMA 14: พักตัว (HTFลง • LTFเด้งรีบาวด์)";
            else if(h4 < h1 && (m5 < m15 || curPrice < m5))
               g_EMA14_StatusText = "↳ 🟡 สถานะ EMA 14: ย่อตัว (HTFขึ้น • LTFย่อพักฐาน)";
            else
               g_EMA14_StatusText = "↳ 🟡 สถานะ EMA 14: SW ไซด์เวย์ (ไร้ทิศทางชัดเจน)";
         }
         else
         {
            g_EMA14_StatusText = "↳ 🟡 สถานะ EMA 14: ไซด์เวย์พักฐาน ⏳";
         }
         g_EMA14_StatusCol  = clrGold;
         g_EMACrossValCol   = clrGold;
         g_EMACrossBarCol   = clrDarkGoldenrod;
         g_EMACrossTitleCol = clrKhaki;
      }
   }
   else
   {
      g_EMA14_StatusText = "↳ ⚪ Multi-TF EMA 14: ปิดการประมวลผล";
      g_EMA14_StatusCol  = clrSilver;
   }
}

//+------------------------------------------------------------------+
//| 7. MARKET SESSIONS & MULTI-TIMEFRAME CONFLUENCE                  |
//+------------------------------------------------------------------+
void UpdateMarketSessionAndMTF()
{
   // 1. Session Detection (London & NY Booster)
   MqlDateTime dt;
   TimeCurrent(dt);
   int hour = dt.hour;

   if(hour >= InpLondonStartHour && hour < InpNYEndHour)
   {
      if(hour >= 13 && hour <= 17)
         g_SessionName = "LONDON/NY Overlap 👑";
      else if(hour < 13)
         g_SessionName = "LONDON (Prime) 🇬🇧";
      else
         g_SessionName = "NEW YORK (Prime) 🇺🇸";
   }
   else
   {
      g_SessionName = "ASIAN / EXTENDED 🌙";
   }

   // 2. Dynamic Multi-Trend Radar (From Active Chart TF up to D1, Throttled 2s for High Efficiency)
   static datetime lastMTFScanTime = 0;
   datetime curTimeSec = TimeCurrent();
   if(curTimeSec - lastMTFScanTime < 2 && g_MTF_StatusStr != "")
      return;
   lastMTFScanTime = curTimeSec;

   ENUM_TIMEFRAMES activeTF = GetCurrentExecutionTF();
   int activeRank = GetTFRank(activeTF);

   ENUM_TIMEFRAMES chainTFs[]     = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1};
   string          chainNames[]   = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1"};
   int             chainHandles[] = {m_hEMA_M1, m_hEMA_M5, m_hEMA_M15, m_hEMA_M30, m_hEMA_H1, m_hEMA_H4, m_hEMA_D1, m_hEMA_W1};

   string mtfStr = "";
   int totalChecked = 0;
   double bullSum = 0.0;
   double emaVal[1];
   MqlRates r[];
   ArraySetAsSeries(r, true);

   for(int c = 0; c < 8; c++)
   {
      if(GetTFRank(chainTFs[c]) < activeRank)
         continue; // Only evaluate from active TF upwards!

      string dot = "🟡";
      double bullScore = 0.5;

      if(chainHandles[c] != INVALID_HANDLE && CopyRates(_Symbol, chainTFs[c], 0, 2, r) >= 1 && CopyBuffer(chainHandles[c], 0, 0, 1, emaVal) > 0)
      {
         double ema = emaVal[0];
         double cl  = r[0].close;
         double threshold = MathMax(20.0, g_AssetProfile.minSwing * 0.06) * _Point;

         if(cl > ema + threshold)
         {
            dot = "🟢"; // BUY / Bullish
            bullScore = 1.0;
         }
         else if(cl < ema - threshold)
         {
            dot = "🔴"; // SELL / Bearish
            bullScore = 0.0;
         }
         else
         {
            dot = "🟡"; // SIDEWAY / Neutral
            bullScore = 0.5;
         }
      }
      else
      {
         if(g_MarketTrend == TREND_BULLISH)
         {
            dot = "🟢";
            bullScore = 1.0;
         }
         else if(g_MarketTrend == TREND_BEARISH)
         {
            dot = "🔴";
            bullScore = 0.0;
         }
         else
         {
            dot = "🟡";
            bullScore = 0.5;
         }
      }

      totalChecked++;
      bullSum += bullScore;

      if(mtfStr != "") mtfStr += " ";
      mtfStr += StringFormat("%s:%s", chainNames[c], dot);
   }

   int pct = (totalChecked > 0) ? (int)MathRound((bullSum / (double)totalChecked) * 100.0) : 50;
   g_MTF_BullPct = pct;
   g_MTF_StatusStr = StringFormat("%s (%d%%)", mtfStr, pct);
   g_MTF_ABCD_Summary = GetMultiTimeframeABCDSummary();
   g_MTF_ABCD_Sub     = GetMultiTimeframeABCDSummary_Sub();
   g_MTF_ABCD_Macro   = GetMultiTimeframeABCDSummary_Macro();
   
   // Refresh Samurai MTF Confluence State
   UpdateSamuraiMTFConfluenceEngine();
}

//+------------------------------------------------------------------+
//| ⚔️ SAMURAI-EA MULTI-TIMEFRAME CONFLUENCE & MOMENTUM ENGINE       |
//+------------------------------------------------------------------+
void UpdateSamuraiMTFConfluenceEngine()
{
   static datetime lastSamuraiScanTime = 0;
   datetime curTimeSec = TimeCurrent();
   if(curTimeSec - lastSamuraiScanTime < 1 && g_SamuraiMTF.summaryStr != "")
      return;
   lastSamuraiScanTime = curTimeSec;
   
   const ENUM_TIMEFRAMES tfs[6] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
   const string tfNames[6]      = {"M1", "M5", "M15", "M30", "H1", "H4"};
   const double tfWeights[6]    = {1.0, 1.0, 1.2, 1.5, 2.0, 2.0}; // Higher weight for H1 & H4 (Samurai HTZ style)
   
   double totalWeight = 0.0;
   double weightedBullSum = 0.0;
   string str = "";
   double liveBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   for(int i = 0; i < 6; i++)
   {
      MqlRates rates[4];
      int copied = CopyRates(_Symbol, tfs[i], 0, 4, rates);
      
      bool bull = false;
      bool bear = false;
      double mom = 50.0;
      
      if(copied >= 4)
      {
         if(liveBid > 0) rates[3].close = liveBid;
         
         double c0 = rates[3].close;
         double o0 = rates[3].open;
         double c1 = rates[2].close;
         double o1 = rates[2].open;
         
         double body0 = MathAbs(c0 - o0);
         double rng0  = rates[3].high - rates[3].low;
         mom = (rng0 > _Point) ? MathMin(100.0, (body0 / rng0) * 100.0) : 50.0;
         
         // 4-Bar Multi-Candle Structure & Midpoint calculation
         double highestH = rates[0].high;
         double lowestL  = rates[0].low;
         for(int b = 1; b < 4; b++)
         {
            if(rates[b].high > highestH) highestH = rates[b].high;
            if(rates[b].low  < lowestL)  lowestL  = rates[b].low;
         }
         double midPoint = (highestH + lowestL) / 2.0;
         
         // Bullish: current bar green & above 4-bar mid, or higher high & higher close
         if((c0 >= o0 && c0 > midPoint) || (c0 > c1 && rates[3].high >= rates[2].high))
            bull = true;
         else if((c0 < o0 && c0 < midPoint) || (c0 < c1 && rates[3].low <= rates[2].low))
            bear = true;
      }
      else
      {
         if(g_MarketTrend == TREND_BULLISH) bull = true;
         else if(g_MarketTrend == TREND_BEARISH) bear = true;
      }
      
      g_SamuraiMTF.isBullish[i]   = bull;
      g_SamuraiMTF.isBearish[i]   = bear;
      g_SamuraiMTF.momentumPct[i] = mom;
      
      string dot = bull ? "🟢" : (bear ? "🔴" : "🟡");
      if(str != "") str += " ";
      str += StringFormat("%s:%s", tfNames[i], dot);
      
      totalWeight += tfWeights[i];
      if(bull) weightedBullSum += tfWeights[i];
      else if(!bear) weightedBullSum += (tfWeights[i] * 0.5);
   }
   
   double pct = (totalWeight > 0) ? (weightedBullSum / totalWeight) * 100.0 : 50.0;
   g_SamuraiMTF.bullScore  = pct;
   g_SamuraiMTF.summaryStr = str;
   
   if(pct >= 62.0)
   {
      g_SamuraiMTF.consensusDir = 1;
      g_SamuraiMTF.gradeStr     = StringFormat("⚔️ SAMURAI MTF: STRONG BUY (%d%%)", (int)MathRound(pct));
   }
   else if(pct <= 38.0)
   {
      g_SamuraiMTF.consensusDir = -1;
      g_SamuraiMTF.gradeStr     = StringFormat("⚔️ SAMURAI MTF: STRONG SELL (%d%%)", (int)MathRound(100.0 - pct));
   }
   else
   {
      g_SamuraiMTF.consensusDir = 0;
      g_SamuraiMTF.gradeStr     = StringFormat("⚔️ SAMURAI MTF: NEUTRAL/SIDEWAY (%d%%)", (int)MathRound(pct));
   }
   
   g_SamuraiMTF.htfAgreesBuy  = (g_SamuraiMTF.isBullish[4] && g_SamuraiMTF.isBullish[5]);
   g_SamuraiMTF.htfAgreesSell = (g_SamuraiMTF.isBearish[4] && g_SamuraiMTF.isBearish[5]);
}

//+------------------------------------------------------------------+
//| 🏛️ ABCD WAVE STRUCTURE ENGINE (EP เสริม 4 FIBONACCI MODEL)        |
//+------------------------------------------------------------------+
SABCDWaveData CalculateABCDWave(ENUM_TIMEFRAMES tf, string symbol="")
{
   SABCDWaveData res;
   ZeroMemory(res);
   res.leg = ABCD_LEG_SW;
   res.legName = "SIDEWAY ⏸️";
   res.desc = "ไม่มีโครงสร้างชัดเจน (รอเบรก)";

   if(symbol == "") symbol = _Symbol;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(symbol, tf, 0, 50, rates);
   if(copied < 15)
      return res;

   // Find recent Swing High and Swing Low using 2-bar left & right fractal
   int lastH_idx = -1;
   int lastL_idx = -1;
   double lastH_val = 0;
   double lastL_val = 0;

   for(int i = 2; i < copied - 2; i++)
   {
      if(lastH_idx < 0)
      {
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
            rates[i].high >= rates[i+1].high && rates[i].high >= rates[i+2].high)
         {
            lastH_idx = i;
            lastH_val = rates[i].high;
         }
      }
      if(lastL_idx < 0)
      {
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
            rates[i].low <= rates[i+1].low && rates[i].low <= rates[i+2].low)
         {
            lastL_idx = i;
            lastL_val = rates[i].low;
         }
      }
      if(lastH_idx >= 0 && lastL_idx >= 0)
         break;
   }

   if(lastH_idx < 0 || lastL_idx < 0 || lastH_idx == lastL_idx)
      return res;

   double curPrice = rates[0].close;
   double minRange = MathMax(100.0, (double)g_AssetProfile.minSwing * 0.5) * _Point;

   // Case 1: Bullish Impulse (Swing Low occurred before Swing High -> lastH_idx < lastL_idx because series is 0=newest)
   if(lastH_idx < lastL_idx)
   {
      res.direction = 1;
      res.priceA    = lastL_val;
      res.timeA     = rates[lastL_idx].time;
      res.priceB    = lastH_val;
      res.timeB     = rates[lastH_idx].time;
      double range  = res.priceB - res.priceA;

      if(range < minRange)
         return res;

      res.oteHigh   = res.priceB - (range * 0.500); // 50.0% Equilibrium
      res.oteLow    = res.priceB - (range * 0.786); // 78.6% OTE Bottom
      res.priceC    = (res.oteHigh + res.oteLow) / 2.0;
      res.priceD    = res.priceA + (range * 1.618); // 161.8% Target

      if(curPrice > res.priceB)
      {
         res.leg     = ABCD_LEG_D;
         res.legName = "ขาD 🚀";
         res.desc    = "ขยายคลื่นทะลุไฮ สู่เป้าหมาย D (161.8%)";
      }
      else if(curPrice <= res.oteHigh && curPrice >= res.oteLow)
      {
         res.leg     = ABCD_LEG_C;
         res.legName = "ขาC 🛒";
         res.desc    = "ย่อเข้าโซน OTE 61.8%-78.6% (เตรียม BUY)";
      }
      else if(curPrice > res.oteHigh)
      {
         res.leg     = ABCD_LEG_B;
         res.legName = "ขาB ⏸️";
         res.desc    = "ชะลอตัวจากยอด B (เริ่มย่อสะสม)";
      }
      else if(curPrice < res.oteLow && curPrice >= res.priceA)
      {
         res.leg     = ABCD_LEG_C;
         res.legName = "ขาC 🛒";
         res.desc    = "ย่อลึกทดสอบฐาน A (โซน Discount สูงสุด)";
      }
      else
      {
         res.leg     = ABCD_LEG_SW;
         res.legName = "หลุดฐาน⚠️";
         res.desc    = "หลุดฐาน Low A (ระวังเปลี่ยนโครงสร้าง)";
      }
   }
   // Case 2: Bearish Impulse (Swing High occurred before Swing Low -> lastL_idx < lastH_idx)
   else
   {
      res.direction = -1;
      res.priceA    = lastH_val;
      res.timeA     = rates[lastH_idx].time;
      res.priceB    = lastL_val;
      res.timeB     = rates[lastL_idx].time;
      double range  = res.priceA - res.priceB;

      if(range < minRange)
         return res;

      res.oteLow    = res.priceB + (range * 0.500); // 50.0% Equilibrium
      res.oteHigh   = res.priceB + (range * 0.786); // 78.6% OTE Top
      res.priceC    = (res.oteHigh + res.oteLow) / 2.0;
      res.priceD    = res.priceA - (range * 1.618); // 161.8% Target

      if(curPrice < res.priceB)
      {
         res.leg     = ABCD_LEG_D;
         res.legName = "ขาD 🚀";
         res.desc    = "ขยายคลื่นหลุดโลว สู่เป้าหมาย D (161.8%)";
      }
      else if(curPrice >= res.oteLow && curPrice <= res.oteHigh)
      {
         res.leg     = ABCD_LEG_C;
         res.legName = "ขาC 🛒";
         res.desc    = "เด้งเข้าโซน OTE 61.8%-78.6% (เตรียม SELL)";
      }
      else if(curPrice < res.oteLow)
      {
         res.leg     = ABCD_LEG_B;
         res.legName = "ขาB ⏸️";
         res.desc    = "ชะลอตัวจากก้น B (เริ่มเด้งทดสอบ)";
      }
      else if(curPrice > res.oteHigh && curPrice <= res.priceA)
      {
         res.leg     = ABCD_LEG_C;
         res.legName = "ขาC 🛒";
         res.desc    = "เด้งลึกทดสอบยอด A (โซน Premium สูงสุด)";
      }
      else
      {
         res.leg     = ABCD_LEG_SW;
         res.legName = "ทะลุยอด⚠️";
         res.desc    = "ทะลุยอด High A (ระวังเปลี่ยนโครงสร้าง)";
      }
   }

   return res;
}

//+------------------------------------------------------------------+
//| 📊 MULTI-TIMEFRAME ABCD WAVE SUMMARY                             |
//+------------------------------------------------------------------+
string GetMultiTimeframeABCDSummary()
{
   ENUM_TIMEFRAMES tfs[] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
   string tfNames[]      = {"M5", "M15", "M30", "H1", "H4"};
   string summary = "";

   for(int i = 0; i < 5; i++)
   {
      SABCDWaveData w = CalculateABCDWave(tfs[i]);
      if(summary != "") summary += " ";
      summary += StringFormat("%s:%s", tfNames[i], w.legName);
   }
   return summary;
}

string GetMultiTimeframeABCDSummary_Sub()
{
   ENUM_TIMEFRAMES tfs[] = {PERIOD_M5, PERIOD_M15, PERIOD_M30};
   string tfNames[]      = {"M5", "M15", "M30"};
   string summary = "";

   for(int i = 0; i < 3; i++)
   {
      SABCDWaveData w = CalculateABCDWave(tfs[i]);
      if(summary != "") summary += "  ";
      summary += StringFormat("%s:%s", tfNames[i], w.legName);
   }
   return summary;
}

string GetMultiTimeframeABCDSummary_Macro()
{
   ENUM_TIMEFRAMES tfs[] = {PERIOD_H1, PERIOD_H4};
   string tfNames[]      = {"H1", "H4"};
   string summary = "";

   for(int i = 0; i < 2; i++)
   {
      SABCDWaveData w = CalculateABCDWave(tfs[i]);
      if(summary != "") summary += "  ";
      summary += StringFormat("%s:%s", tfNames[i], w.legName);
   }
   return summary;
}

//+------------------------------------------------------------------+
//| 🎯 SMART QUASIMODO (QM) / SMC ACTION COMMAND ENGINE (SIMPLE THAI)|
//+------------------------------------------------------------------+
void UpdateSmartActionCommand(int openCount)
{
   if(openCount > 0 || g_BotState == STATE_IN_POSITION)
   {
      string posDir = (g_PlanDirection == 1 || g_MarketTrend == TREND_BULLISH) ? "BUY 🟢" : "SELL 🔴";
      g_SmartActionCommand = StringFormat("💎 กำลังดูแลไม้ (%s) • คุม Trailing Stop", posDir);
      g_SmartActionSubtext = "↳ ล็อกกำไรและรันเทรนด์สู่เป้าหมาย TP ตามวินัย 🏆";
      g_SmartActionColor   = clrAqua;
      return;
   }

   if(g_DailyTargetReached)
   {
      g_SmartActionCommand = "🏆 ถึงเป้ากำไรรายวันแล้ว (+2500 Cent)";
      g_SmartActionSubtext = "↳ ล็อกกำไร นั่งพักผ่อน ปิดจ๊อบวันนี้เรียบร้อย 👑";
      g_SmartActionColor   = clrGold;
      return;
   }

   if(g_DailyMaxLossReached)
   {
      g_SmartActionCommand = "🛑 ชนลิมิตขาดทุนรายวัน (-10%) รักษาเงินทุน";
      g_SmartActionSubtext = "↳ หยุดเทรดอัตโนมัติ รักษาวินัย ปลอดภัย 100% 🛡️";
      g_SmartActionColor   = clrTomato;
      return;
   }

   string dzStr = "";
   string szStr = "";
   double curBid = m_symbol.Bid();

   // 1. Scan for closest active MTF Demand and Supply Zones
   double bestDemandTop = 0, bestDemandBtm = 0;
   double bestSupplyTop = 0, bestSupplyBtm = 0;
   for(int z = 0; z < ArraySize(g_SMC_MTF_Zones); z++)
   {
      if(!g_SMC_MTF_Zones[z].isActive) continue;
      if(g_SMC_MTF_Zones[z].direction == 1) // Demand
      {
         if(g_SMC_MTF_Zones[z].topPrice <= curBid + (100 * _Point))
         {
            if(bestDemandTop == 0 || g_SMC_MTF_Zones[z].topPrice > bestDemandTop)
            {
               bestDemandTop = g_SMC_MTF_Zones[z].topPrice;
               bestDemandBtm = g_SMC_MTF_Zones[z].bottomPrice;
            }
         }
      }
      else if(g_SMC_MTF_Zones[z].direction == -1) // Supply
      {
         if(g_SMC_MTF_Zones[z].bottomPrice >= curBid - (100 * _Point))
         {
            if(bestSupplyTop == 0 || g_SMC_MTF_Zones[z].bottomPrice < bestSupplyBtm)
            {
               bestSupplyTop = g_SMC_MTF_Zones[z].topPrice;
               bestSupplyBtm = g_SMC_MTF_Zones[z].bottomPrice;
            }
         }
      }
   }

   // 2. Format dzStr (Demand / Discount Zone) - MUST BE AT OR BELOW CURRENT PRICE!
   string priceFmt = (_Digits > 2) ? "%.1f-%.1f" : ((curBid >= 1000.0) ? "%.0f-%.0f" : "%.2f-%.2f");
   if(bestDemandTop > 0 && bestDemandTop <= curBid + (50 * _Point))
      dzStr = StringFormat(priceFmt, bestDemandBtm, bestDemandTop);
   else if(g_MarketTrend == TREND_BULLISH && g_Fibo.zoneHigh <= curBid && g_Fibo.zoneLow > 0)
      dzStr = StringFormat(priceFmt, g_Fibo.zoneLow, g_Fibo.zoneHigh);
   else if(g_LastSwingLow.price > 0 && g_LastSwingLow.price <= curBid)
   {
      double dRng = (g_LastSwingHigh.price > g_LastSwingLow.price) ? (g_LastSwingHigh.price - g_LastSwingLow.price) : (100 * _Point);
      dzStr = StringFormat(priceFmt, g_LastSwingLow.price, g_LastSwingLow.price + (dRng * 0.20));
   }
   else
      dzStr = StringFormat(priceFmt, curBid - (150 * _Point), curBid - (30 * _Point));

   // 3. Format szStr (Supply / Premium Zone) - STRICTLY NEVER USE A BROKEN PEAK BELOW CURRENT PRICE!
   if(bestSupplyTop > 0 && bestSupplyTop >= curBid - (50 * _Point))
      szStr = StringFormat(priceFmt, bestSupplyBtm, bestSupplyTop);
   else if(g_LQ_Radar.bsl.price > curBid)
      szStr = StringFormat(priceFmt, g_LQ_Radar.bsl.price, g_LQ_Radar.bsl.price + (100 * _Point));
   else if(g_MarketTrend == TREND_BEARISH && g_Fibo.zoneLow >= curBid && g_Fibo.zoneLow > 0)
      szStr = StringFormat(priceFmt, g_Fibo.zoneLow, g_Fibo.zoneHigh);
   else if(g_LastSwingHigh.price >= curBid)
   {
      double sRng = (g_LastSwingHigh.price > g_LastSwingLow.price) ? (g_LastSwingHigh.price - g_LastSwingLow.price) : (100 * _Point);
      szStr = StringFormat(priceFmt, g_LastSwingHigh.price - (sRng * 0.20), g_LastSwingHigh.price);
   }
   else
   {
      // If price has broken out above previous swing high, resistance is ahead of price (Wave 3 Target or Runner Target)!
      double nextResist = (g_Fibo.p1618 > curBid) ? g_Fibo.p1618 : ((g_Fibo.p2618 > curBid) ? g_Fibo.p2618 : (curBid + (200 * _Point)));
      szStr = StringFormat(priceFmt, curBid + (50 * _Point), nextResist);
   }

   // Special: Reversal Armed Pending Confirmation (Institutional Peak / Valley Turn)
   if(g_ReversalArmedPendingConfirm)
   {
      if(g_ReversalPendingDir == -1)
      {
         g_SmartActionCommand = StringFormat("🎯 ดักยอดกลับตัว (PEAK REVERSAL SELL): โซนต้าน [%s]", szStr);
         string sub = (g_ReversalPendingReason != "") ? StringFormat("↳ %s • ห้าม Sell ใส่แนวรับ 🛡️", g_ReversalPendingReason) : "↳ รอแท่ง Rejection หลุด Low เพื่อยืนยันแรงขาย (เตรียม SELL 🔴)";
         g_SmartActionSubtext = sub;
         g_SmartActionColor   = clrTomato;
         return;
      }
      else if(g_ReversalPendingDir == 1)
      {
         g_SmartActionCommand = StringFormat("🎯 ดักก้นกลับตัว (VALLEY REVERSAL BUY): โซนรับ [%s]", dzStr);
         string sub = (g_ReversalPendingReason != "") ? StringFormat("↳ %s • ห้าม Buy ใส่แนวต้าน 🛡️", g_ReversalPendingReason) : "↳ รอแท่ง Rejection เบรก High เพื่อยืนยันแรงซื้อ (เตรียม BUY 🟢)";
         g_SmartActionSubtext = sub;
         g_SmartActionColor   = C'50,225,130';
         return;
      }
   }

   // 1. BUY Setup Evaluation (4 Steps of Quasimodo / SMC)
   if(g_BotState == STATE_TRIGGER_READY && (g_PlanDirection == 1 || g_MarketTrend == TREND_BULLISH))
   {
      g_SmartActionCommand = "🚀 สเต็ป 4 (ลั่นไก): แตะ Demand + ไส้ล่างชัด";
      g_SmartActionSubtext = "↳ ยิง BUY สไนเปอร์ทันที! เงื่อนไขครบถ้วน 🟢";
      g_SmartActionColor   = clrLime;
      return;
   }

   if(g_PullbackArmed && (g_PlanDirection == 1 || g_MarketTrend == TREND_BULLISH))
   {
      g_SmartActionCommand = StringFormat("🎯 สเต็ป 3: ราคาแตะ Demand [%s]", dzStr);
      g_SmartActionSubtext = "↳ รอแท่งเทียนปิดคอนเฟิร์ม (เตรียมลั่นไก BUY 🟢)";
      g_SmartActionColor   = C'50,225,130';
      return;
   }

   if((g_StructEvent == STRUCT_BULLISH_CHOCH || g_StructEvent == STRUCT_BULLISH_BOS || g_MarketTrend == TREND_BULLISH) && g_BotState == STATE_WAIT_PULLBACK)
   {
      g_SmartActionCommand = "🛒 สเต็ป 2: เกิด ChoCH+BOS แล้ว (ขาขึ้น 📈)";
      g_SmartActionSubtext = StringFormat("↳ รอราคาย่อเข้า Demand QM [%s] (เตรียม BUY 🟢)", dzStr);
      g_SmartActionColor   = clrSkyBlue;
      return;
   }

   if(g_LQ_Radar.sslSwept || (g_CRT_Setup.isActive && g_CRT_Setup.state == CRT_BULLISH_SWEEP) || g_JudasBuyActive)
   {
      g_SmartActionCommand = "⚠️ สเต็ป 1 (กวาด SL): หลุด Low (SSL Sweep)";
      g_SmartActionSubtext = "↳ รอแท่งเขียวเบรก High เดิมยืนยัน ChoCH ⏳";
      g_SmartActionColor   = clrGold;
      return;
   }

   // 2. SELL Setup Evaluation (4 Steps of Quasimodo / SMC)
   if(g_BotState == STATE_TRIGGER_READY && (g_PlanDirection == -1 || g_MarketTrend == TREND_BEARISH))
   {
      g_SmartActionCommand = "🚀 สเต็ป 4 (ลั่นไก): แตะ Supply + ไส้บนชัด";
      g_SmartActionSubtext = "↳ ยิง SELL สไนเปอร์ทันที! เงื่อนไขครบถ้วน 🔴";
      g_SmartActionColor   = clrCrimson;
      return;
   }

   if(g_PullbackArmed && (g_PlanDirection == -1 || g_MarketTrend == TREND_BEARISH))
   {
      g_SmartActionCommand = StringFormat("🎯 สเต็ป 3: ราคาแตะ Supply [%s]", szStr);
      g_SmartActionSubtext = "↳ รอแท่งเทียนปิดคอนเฟิร์ม (เตรียมลั่นไก SELL 🔴)";
      g_SmartActionColor   = clrTomato;
      return;
   }

   if((g_StructEvent == STRUCT_BEARISH_CHOCH || g_StructEvent == STRUCT_BEARISH_BOS || g_MarketTrend == TREND_BEARISH) && g_BotState == STATE_WAIT_PULLBACK)
   {
      g_SmartActionCommand = "🛒 สเต็ป 2: เกิด ChoCH+BOS แล้ว (ขาลง 📉)";
      g_SmartActionSubtext = StringFormat("↳ รอราคาเด้งเข้า Supply QM [%s] (เตรียม SELL 🔴)", szStr);
      g_SmartActionColor   = C'255,160,122';
      return;
   }

   if(g_LQ_Radar.bslSwept || (g_CRT_Setup.isActive && g_CRT_Setup.state == CRT_BEARISH_SWEEP) || g_JudasSellActive)
   {
      g_SmartActionCommand = "⚠️ สเต็ป 1 (กวาด SL): เบรก High (BSL Sweep)";
      g_SmartActionSubtext = "↳ รอแท่งแดงหลุด Low เดิมยืนยัน ChoCH ⏳";
      g_SmartActionColor   = clrOrange;
      return;
   }

   // 3. SIDEWAY (Default)
   g_SmartActionCommand = "⏸️ ตลาด SIDEWAY (นั่งทับมือก่อน ⏳)";
   g_SmartActionSubtext = "↳ ยังไม่เกิด ChoCH / BOS ➔ ห้ามออกไม้เด็ดขาด (รอฟอร์มคลื่น)!";
   g_SmartActionColor   = clrGold;
}

//+------------------------------------------------------------------+
//| 🏛️ UPDATE ASIAN RANGE HIGH / LOW & JUDAS SWING ENGINE            |
//+------------------------------------------------------------------+
void UpdateAsianRangeAndJudasEngine()
{
   if(!InpUseAsianRangeJudas)
   {
      g_AsianRangeValid = false;
      g_JudasSellActive = false;
      g_JudasBuyActive = false;
      return;
   }

   MqlDateTime dt;
   TimeCurrent(dt);

   // Asian Session is defined from 00:00 server time up to InpLondonStartHour (e.g. 10:00 server time)
   datetime dayStart = (datetime)(TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec));
   if(g_AsianRangeDate != dayStart)
   {
      g_AsianRangeValid = false;
      g_AsianRangeHigh  = 0.0;
      g_AsianRangeLow   = 0.0;
      g_JudasSellActive = false;
      g_JudasBuyActive  = false;
   }
   datetime asianEnd = dayStart + (InpLondonStartHour * 3600);

   // Scan bars of today to find Asian High / Low
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int copied = CopyRates(_Symbol, PERIOD_M15, dayStart, TimeCurrent(), r);
   if(copied <= 0)
      return;

   double aHigh = 0.0;
   double aLow  = 999999999.0;
   int asianBarsCount = 0;

   for(int i = 0; i < copied; i++)
   {
      if(r[i].time >= dayStart && r[i].time < asianEnd)
      {
         if(r[i].high > aHigh) aHigh = r[i].high;
         if(r[i].low < aLow)   aLow  = r[i].low;
         asianBarsCount++;
      }
   }

   if(asianBarsCount >= 4 && aHigh > 0 && aLow < 999999999.0 && aHigh > aLow)
   {
      g_AsianRangeHigh  = aHigh;
      g_AsianRangeLow   = aLow;
      g_AsianRangeDate  = dayStart;
      g_AsianRangeValid = true;
   }

   // 2. Detect London Judas Swing (During London Session: hour >= InpLondonStartHour && hour < InpLondonStartHour + 6)
   g_JudasSellActive = false;
   g_JudasBuyActive  = false;

   if(g_AsianRangeValid && dt.hour >= InpLondonStartHour && dt.hour < (InpLondonStartHour + 6))
   {
      double tol = MathMax(20.0 * _Point, g_AssetProfile.fallbackSL * 0.05 * _Point);

      // Check recent 3 bars for Judas Sweep
      for(int k = 0; k < MathMin(3, copied); k++)
      {
         // Judas Bearish Sweep (Price swept above Asian High and rejected back inside)
         if(r[k].high > g_AsianRangeHigh && r[k].close <= g_AsianRangeHigh + tol)
         {
            g_JudasSellActive = true;
            break;
         }
         // Judas Bullish Sweep (Price swept below Asian Low and rejected back inside)
         if(r[k].low < g_AsianRangeLow && r[k].close >= g_AsianRangeLow - tol)
         {
            g_JudasBuyActive = true;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 📰 CHECK MQL5 NATIVE NEWS CALENDAR GUARD                         |
//+------------------------------------------------------------------+
bool CheckMQL5NewsCalendarGuard(string &eventTitle, int &minsUntil)
{
   eventTitle = "";
   minsUntil = 0;

   if(!InpUseNewsCalendarGuard)
   {
      g_NewsStandDownActive = false;
      g_NewsEventTitle = "";
      g_NewsMinutesUntil = 0;
      return false;
   }

   // Throttle check every 30 seconds to conserve CPU
   datetime now = TimeCurrent();
   if(now - g_LastNewsCheckTime < 30 && g_LastNewsCheckTime > 0)
   {
      eventTitle = g_NewsEventTitle;
      minsUntil = g_NewsMinutesUntil;
      return g_NewsStandDownActive;
   }
   g_LastNewsCheckTime = now;

   // Check window: InpNewsPostMinutes in past to InpNewsPreMinutes in future
   datetime tFrom = now - (InpNewsPostMinutes * 60);
   datetime tTo   = now + (InpNewsPreMinutes * 60);

   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, tFrom, tTo, "US");
   if(count <= 0)
   {
      // Fail-safe: No news data or broker doesn't feed calendar -> bypass safely!
      g_NewsStandDownActive = false;
      g_NewsEventTitle = "";
      g_NewsMinutesUntil = 0;
      return false;
   }

   bool foundHighImpact = false;
   int closestDiffSec = 999999;
   string closestName = "";

   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent ev;
      if(CalendarEventById(values[i].event_id, ev))
      {
         if(ev.importance == CALENDAR_IMPORTANCE_HIGH)
         {
            datetime evTime = values[i].time;
            int diffSec = (int)(evTime - now);

            // Within pre-news or post-news window
            if(diffSec >= -(InpNewsPostMinutes * 60) && diffSec <= (InpNewsPreMinutes * 60))
            {
               foundHighImpact = true;
               if(MathAbs(diffSec) < MathAbs(closestDiffSec))
               {
                  closestDiffSec = diffSec;
                  closestName = ev.name;
               }
            }
         }
      }
   }

   if(foundHighImpact)
   {
      g_NewsStandDownActive = true;
      g_NewsEventTitle = (closestName != "") ? closestName : "USD High Impact News";
      g_NewsMinutesUntil = closestDiffSec / 60;
      eventTitle = g_NewsEventTitle;
      minsUntil = g_NewsMinutesUntil;
      return true;
   }

   g_NewsStandDownActive = false;
   g_NewsEventTitle = "";
   g_NewsMinutesUntil = 0;
   return false;
}

//+------------------------------------------------------------------+
//| 📰 AUTO PRE-NEWS BREAKEVEN GUARD                                 |
//+------------------------------------------------------------------+
void AutoPreNewsBreakevenGuard()
{
   if(!g_NewsStandDownActive || !InpUseNewsCalendarGuard)
      return;

   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minAllowedDist = MathMax((stopsLevel + 5) * _Point, (m_symbol.Spread() + 5) * _Point);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(magic == InpMagicNumber || (InpManageManualTrades && magic == 0))
         {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double curSL     = PositionGetDouble(POSITION_SL);
            double curTP     = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double beLockPts = (g_AssetProfile.assetType == ASSET_FOREX) ? (double)g_AssetProfile.beLock * _Point : MathMax((double)g_AssetProfile.beLock, 50.0) * _Point;

            if(pType == POSITION_TYPE_BUY)
            {
               double bid = m_symbol.Bid();
               double targetSL = NormalizeDouble(openPrice + beLockPts, _Digits);
               if((bid - targetSL) >= minAllowedDist && (curSL < targetSL || curSL == 0))
               {
                  m_trade.PositionModify(ticket, targetSL, curTP);
                  PrintFormat(">>> 📰 [NEWS GUARD AUTO-BE] Buy ticket #%I64u SL moved to BE+Lock %.2f before %s", ticket, targetSL, g_NewsEventTitle);
               }
            }
            else if(pType == POSITION_TYPE_SELL)
            {
               double ask = m_symbol.Ask();
               double targetSL = NormalizeDouble(openPrice - beLockPts, _Digits);
               if((targetSL - ask) >= minAllowedDist && (curSL > targetSL || curSL == 0))
               {
                  m_trade.PositionModify(ticket, targetSL, curTP);
                  PrintFormat(">>> 📰 [NEWS GUARD AUTO-BE] Sell ticket #%I64u SL moved to BE+Lock %.2f before %s", ticket, targetSL, g_NewsEventTitle);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 🏛️ DRAW ASIAN RANGE BOX & AH/AL LINES ON CHART                   |
//+------------------------------------------------------------------+
void DrawAsianRangeBox()
{
   string boxName = GUI_PREFIX + "ASIAN_BOX";
   string ahLine  = GUI_PREFIX + "ASIAN_AH";
   string alLine  = GUI_PREFIX + "ASIAN_AL";
   string ahLbl   = GUI_PREFIX + "ASIAN_AH_LBL";
   string alLbl   = GUI_PREFIX + "ASIAN_AL_LBL";

   if(!InpUseAsianRangeJudas || !g_AsianRangeValid)
   {
      ObjectDelete(0, boxName);
      ObjectDelete(0, ahLine);
      ObjectDelete(0, alLine);
      ObjectDelete(0, ahLbl);
      ObjectDelete(0, alLbl);
      return;
   }

   MqlDateTime dt;
   TimeCurrent(dt);
   datetime dayStart = (datetime)(TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec));
   datetime asianEnd = dayStart + (InpLondonStartHour * 3600);
   datetime londonEnd = dayStart + ((InpLondonStartHour + 6) * 3600);

   // Draw translucent Asian session box
   if(ObjectFind(0, boxName) < 0)
      ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, dayStart, g_AsianRangeHigh, asianEnd, g_AsianRangeLow);
   else
   {
      ObjectSetInteger(0, boxName, OBJPROP_TIME, 0, dayStart);
      ObjectSetDouble(0, boxName, OBJPROP_PRICE, 0, g_AsianRangeHigh);
      ObjectSetInteger(0, boxName, OBJPROP_TIME, 1, asianEnd);
      ObjectSetDouble(0, boxName, OBJPROP_PRICE, 1, g_AsianRangeLow);
   }
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, C'18,42,65');
   ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
   ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
   ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, false);

   // Draw Asian High line
   if(ObjectFind(0, ahLine) < 0)
      ObjectCreate(0, ahLine, OBJ_TREND, 0, asianEnd, g_AsianRangeHigh, londonEnd, g_AsianRangeHigh);
   else
   {
      ObjectSetInteger(0, ahLine, OBJPROP_TIME, 0, asianEnd);
      ObjectSetDouble(0, ahLine, OBJPROP_PRICE, 0, g_AsianRangeHigh);
      ObjectSetInteger(0, ahLine, OBJPROP_TIME, 1, londonEnd);
      ObjectSetDouble(0, ahLine, OBJPROP_PRICE, 1, g_AsianRangeHigh);
   }
   ObjectSetInteger(0, ahLine, OBJPROP_COLOR, C'245,160,80'); // Soft amber
   ObjectSetInteger(0, ahLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, ahLine, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, ahLine, OBJPROP_BACK, true);

   // Draw Asian Low line
   if(ObjectFind(0, alLine) < 0)
      ObjectCreate(0, alLine, OBJ_TREND, 0, asianEnd, g_AsianRangeLow, londonEnd, g_AsianRangeLow);
   else
   {
      ObjectSetInteger(0, alLine, OBJPROP_TIME, 0, asianEnd);
      ObjectSetDouble(0, alLine, OBJPROP_PRICE, 0, g_AsianRangeLow);
      ObjectSetInteger(0, alLine, OBJPROP_TIME, 1, londonEnd);
      ObjectSetDouble(0, alLine, OBJPROP_PRICE, 1, g_AsianRangeLow);
   }
   ObjectSetInteger(0, alLine, OBJPROP_COLOR, C'60,190,220'); // Soft cyan
   ObjectSetInteger(0, alLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, alLine, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, alLine, OBJPROP_BACK, true);

   // Asian High Label
   if(ObjectFind(0, ahLbl) < 0)
      ObjectCreate(0, ahLbl, OBJ_TEXT, 0, asianEnd, g_AsianRangeHigh);
   else
   {
      ObjectSetInteger(0, ahLbl, OBJPROP_TIME, asianEnd);
      ObjectSetDouble(0, ahLbl, OBJPROP_PRICE, g_AsianRangeHigh);
   }
   ObjectSetString(0, ahLbl, OBJPROP_TEXT, StringFormat("  [ AH • %s ]", DoubleToString(g_AsianRangeHigh, _Digits)));
   ObjectSetInteger(0, ahLbl, OBJPROP_COLOR, C'245,160,80');
   ObjectSetString(0, ahLbl, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetInteger(0, ahLbl, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, ahLbl, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, ahLbl, OBJPROP_BACK, false);

   // Asian Low Label
   if(ObjectFind(0, alLbl) < 0)
      ObjectCreate(0, alLbl, OBJ_TEXT, 0, asianEnd, g_AsianRangeLow);
   else
   {
      ObjectSetInteger(0, alLbl, OBJPROP_TIME, asianEnd);
      ObjectSetDouble(0, alLbl, OBJPROP_PRICE, g_AsianRangeLow);
   }
   ObjectSetString(0, alLbl, OBJPROP_TEXT, StringFormat("  [ AL • %s ]", DoubleToString(g_AsianRangeLow, _Digits)));
   ObjectSetInteger(0, alLbl, OBJPROP_COLOR, C'60,190,220');
   ObjectSetString(0, alLbl, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetInteger(0, alLbl, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, alLbl, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, alLbl, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| LINEAR REGRESSION CHANNEL & DUAL-PERIOD HYBRID CALCULATION ENGINE|
//+------------------------------------------------------------------+
bool CalculateLinearRegression(ENUM_TIMEFRAMES tf, int period, SLinearRegressionResult &res)
{
   if(period < 10) period = 100;
   MqlRates rates[];

   // ALWAYS use CLOSED bars: from index 1 to period (zero repaint!)
   int copied = CopyRates(_Symbol, tf, 1, period, rates);
   if(copied < period)
      return false;

   // CRUCIAL: Set array as timeseries AFTER CopyRates so rates[0] is newest closed bar (index 1 on chart)
   ArraySetAsSeries(rates, true);

   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   int n = period;

   for(int i = 0; i < n; i++)
   {
      double x = (double)(n - 1 - i);      // x runs from 0 (oldest: i=n-1) to n-1 (latest closed bar: i=0)
      double y = rates[i].close;           // rates[0] is latest closed bar, rates[n-1] is oldest closed bar
      sumX  += x;
      sumY  += y;
      sumXY += (x * y);
      sumX2 += (x * x);
   }

   double denom = (n * sumX2 - sumX * sumX);
   if(MathAbs(denom) < 1e-9) return false;

   res.slope = (n * sumXY - sumX * sumY) / denom;
   res.intercept = (sumY - res.slope * sumX) / n;

   // Calculate Angle (Degree) calibrated proportionally across all assets (Gold, Crypto, Forex, Indices)
   double priceRef = (rates[0].close > 0) ? rates[0].close : 2500.0;
   double normScale = MathMax(priceRef * 0.0004, (_Point * 10.0));
   res.angle = MathArctan(res.slope / normScale) * (180.0 / M_PI);

   // 1. Calculate Standard Error (StdDev of residuals on Close)
   double sumResidualSq = 0;
   for(int i = 0; i < n; i++)
   {
      double x = (double)(n - 1 - i);
      double yEst = res.intercept + res.slope * x;
      double diff = rates[i].close - yEst;
      sumResidualSq += (diff * diff);
   }

   res.stdDev = (n > 2) ? MathSqrt(sumResidualSq / (n - 2)) : 0.0;

   // 2. Extreme High/Low Wick Deviations (Samurai-EA & Raff Style)
   double maxHighDev = 0;
   double maxLowDev  = 0;
   for(int i = 0; i < n; i++)
   {
      double x = (double)(n - 1 - i);
      double yEst = res.intercept + res.slope * x;
      double diffHigh = rates[i].high - yEst;
      double diffLow  = yEst - rates[i].low;
      if(diffHigh > maxHighDev) maxHighDev = diffHigh;
      if(diffLow  > maxLowDev)  maxLowDev  = diffLow;
   }

   // 3. Determine Upper and Lower Channel Deviations based on Channel Mode
   if(InpLRL_ChannelMode == LRL_MODE_EXACT_WICKS)
   {
      // 🎯 Samurai Exact Wicks: แนบปลายไส้สูงสุดและต่ำสุดพอดี 100%
      res.devUpper = maxHighDev * InpLRL_WickMultiplier;
      res.devLower = maxLowDev  * InpLRL_WickMultiplier;
   }
   else if(InpLRL_ChannelMode == LRL_MODE_SYMMETRIC_WICKS)
   {
      // 📐 Samurai Symmetric Wicks: กรอบคู่ขนานสมมาตรระยะเท่ากัน
      double maxDev = MathMax(maxHighDev, maxLowDev);
      res.devUpper = maxDev * InpLRL_WickMultiplier;
      res.devLower = maxDev * InpLRL_WickMultiplier;
   }
   else // LRL_MODE_STDDEV_CLOSE
   {
      // 📊 Standard Deviation ของราคาปิดแบบเดิม
      res.devUpper = InpLRL_StdDevMultiplier * res.stdDev;
      res.devLower = InpLRL_StdDevMultiplier * res.stdDev;
   }

   // Coordinates for Drawing:
   // Oldest bar in window (x = 0)
   res.timeStart   = rates[n - 1].time;
   
   // Newest closed bar (x = n - 1): Extend time to current forming bar so channel embraces current price snugly
   long secPerBar  = PeriodSeconds(tf);
   res.timeEnd     = rates[0].time + (datetime)secPerBar;

   // Price at extended current forming bar (x = n)
   double lastX    = (double)n;
   res.medianPrice = res.intercept + res.slope * lastX;
   res.upperPrice  = res.medianPrice + res.devUpper;
   res.lowerPrice  = res.medianPrice - res.devLower;

   // Trend classification with InpLRL_TrendAngleThreshold
   if(res.angle > InpLRL_TrendAngleThreshold)
      res.trend = LRL_TREND_BULLISH;
   else if(res.angle < -InpLRL_TrendAngleThreshold)
      res.trend = LRL_TREND_BEARISH;
   else
      res.trend = LRL_TREND_SIDEWAY;

   return true;
}

void UpdateLinearRegressionEngine()
{
   if(!InpEnableLRLChannel)
      return;

   // Throttled scan: Run every 2 seconds or on new bar for maximum CPU efficiency
   static datetime lastLRLScan = 0;
   datetime curTime = TimeCurrent();
   if(curTime - lastLRLScan < 2 && g_LRL_MTF_Summary != "")
      return;
   lastLRLScan = curTime;

   // 1. Calculate Active Chart TF with 100 closed bars (Agile Execution)
   ENUM_TIMEFRAMES activeTF = GetCurrentExecutionTF();
   CalculateLinearRegression(activeTF, InpLRL_ChartBars, g_LRL_Chart);

   // 2. Hierarchical Top-Down Multi-TF: Calculate higher TFs with 200 closed bars (Solid Anchor)
   ENUM_TIMEFRAMES allTFs[]   = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1};
   string          tfNames[]  = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1"};
   int activeRank = GetTFRank(activeTF);

   int bullCount = 0;
   int bearCount = 0;
   int sidewayCount = 0;
   double angleSum = 0;
   int htfEvaluated = 0;
   string mtfSummary = "";
   int countFormatted = 0;

   for(int t = 0; t < 8; t++)
   {
      int rk = GetTFRank(allTFs[t]);
      if(rk < activeRank)
         continue; // Only evaluate active TF upwards!

      SLinearRegressionResult tfRes;
      int barsToUse = (rk == activeRank) ? InpLRL_ChartBars : InpLRL_HTFBars;
      if(CalculateLinearRegression(allTFs[t], barsToUse, tfRes))
      {
         string arrow = (tfRes.trend == LRL_TREND_BULLISH) ? "▲" : (tfRes.trend == LRL_TREND_BEARISH ? "▼" : "•");
         string signStr = (tfRes.angle > 0) ? "+" : "";

         if(rk > activeRank)
         {
            if(tfRes.trend == LRL_TREND_BULLISH)
               bullCount++;
            else if(tfRes.trend == LRL_TREND_BEARISH)
               bearCount++;
            else
               sidewayCount++;

            angleSum += tfRes.angle;
            htfEvaluated++;
         }

         if(countFormatted < 5)
         {
            if(mtfSummary != "") mtfSummary += " ";
            mtfSummary += StringFormat("%s:%s%s%.0f°", tfNames[t], arrow, signStr, tfRes.angle);
            countFormatted++;
         }
      }
   }

   g_LRL_MTF_Summary = mtfSummary;

   // Determine HTF Mother Trend Consensus
   if(htfEvaluated > 0)
   {
      g_LRL_HTF_AvgAngle = angleSum / (double)htfEvaluated;
      if(bullCount > bearCount && g_LRL_HTF_AvgAngle > InpLRL_TrendAngleThreshold * 0.5)
         g_LRL_HTF_Consensus = LRL_TREND_BULLISH;
      else if(bearCount > bullCount && g_LRL_HTF_AvgAngle < -InpLRL_TrendAngleThreshold * 0.5)
         g_LRL_HTF_Consensus = LRL_TREND_BEARISH;
      else
         g_LRL_HTF_Consensus = LRL_TREND_SIDEWAY;
   }
   else
   {
      g_LRL_HTF_Consensus = g_LRL_Chart.trend;
      g_LRL_HTF_AvgAngle  = g_LRL_Chart.angle;
   }
}

void RemoveLinearRegressionVisuals()
{
   ObjectsDeleteAll(0, GUI_PREFIX + "LRL_");
}

void DrawLinearRegressionVisuals()
{
   if(!InpEnableLRLChannel || !g_ShowLRLChannel || !g_ShowVisuals)
   {
      RemoveLinearRegressionVisuals();
      return;
   }

   if((g_LRL_Chart.devUpper <= 0 && g_LRL_Chart.devLower <= 0 && g_LRL_Chart.stdDev <= 0) || g_LRL_Chart.timeStart == 0 || g_LRL_Chart.timeEnd == 0)
      return;

   datetime t1 = g_LRL_Chart.timeStart;
   datetime t2 = g_LRL_Chart.timeEnd;
   double pStartMid   = g_LRL_Chart.intercept;
   double pEndMid     = g_LRL_Chart.medianPrice;
   double pStartUpper = pStartMid + g_LRL_Chart.devUpper;
   double pEndUpper   = pEndMid   + g_LRL_Chart.devUpper;
   double pStartLower = pStartMid - g_LRL_Chart.devLower;
   double pEndLower   = pEndMid   - g_LRL_Chart.devLower;

   color upperCol  = (g_LRL_Chart.trend == LRL_TREND_BULLISH) ? clrMediumSeaGreen : ((g_LRL_Chart.trend == LRL_TREND_BEARISH) ? clrCrimson : clrSlateGray);
   color medianCol = clrGold;
   color lowerCol  = (g_LRL_Chart.trend == LRL_TREND_BULLISH) ? clrDodgerBlue : ((g_LRL_Chart.trend == LRL_TREND_BEARISH) ? clrTomato : clrSlateGray);

   // -------------------------------------------------------------
   // A. CHANNEL SOFT CLOUD SHADING (TRANSLUCENT VALUE ZONES)
   // -------------------------------------------------------------
   string nameCloudUpper = GUI_PREFIX + "LRL_CLOUD_UPPER";
   string nameCloudLower = GUI_PREFIX + "LRL_CLOUD_LOWER";

   if(InpLRL_ShowCloud)
   {
      // 1. โซนบน (Premium Zone / Sell Area): เมฆสีแดงไวน์โปร่งแสง (Soft Burgundy Red)
      color cloudUpperCol = C'45,15,20'; // Soft Dark Wine Red (ไม่แยงตา ไม่บดบังแท่งเทียน)
      if(ObjectFind(0, nameCloudUpper) < 0)
         ObjectCreate(0, nameCloudUpper, OBJ_CHANNEL, 0, t1, pStartMid, t2, pEndMid, t1, pStartUpper);
      else
      {
         ObjectSetInteger(0, nameCloudUpper, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, nameCloudUpper, OBJPROP_PRICE, 0, pStartMid);
         ObjectSetInteger(0, nameCloudUpper, OBJPROP_TIME, 1, t2);
         ObjectSetDouble(0, nameCloudUpper, OBJPROP_PRICE, 1, pEndMid);
         ObjectSetInteger(0, nameCloudUpper, OBJPROP_TIME, 2, t1);
         ObjectSetDouble(0, nameCloudUpper, OBJPROP_PRICE, 2, pStartUpper);
      }
      ObjectSetInteger(0, nameCloudUpper, OBJPROP_COLOR, cloudUpperCol);
      ObjectSetInteger(0, nameCloudUpper, OBJPROP_FILL, true);
      ObjectSetInteger(0, nameCloudUpper, OBJPROP_BACK, true);
      ObjectSetInteger(0, nameCloudUpper, OBJPROP_RAY_RIGHT, InpLRL_RayRight);
      ObjectSetInteger(0, nameCloudUpper, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nameCloudUpper, OBJPROP_ZORDER, 0);

      // 2. โซนล่าง (Discount Zone / Buy Area): เมฆสีเขียวหัวเป็ดโปร่งแสง (Soft Forest Green)
      color cloudLowerCol = C'12,32,25'; // Soft Deep Forest Green (สง่างาม คมชัดระดับสถาบัน)
      if(ObjectFind(0, nameCloudLower) < 0)
         ObjectCreate(0, nameCloudLower, OBJ_CHANNEL, 0, t1, pStartMid, t2, pEndMid, t1, pStartLower);
      else
      {
         ObjectSetInteger(0, nameCloudLower, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, nameCloudLower, OBJPROP_PRICE, 0, pStartMid);
         ObjectSetInteger(0, nameCloudLower, OBJPROP_TIME, 1, t2);
         ObjectSetDouble(0, nameCloudLower, OBJPROP_PRICE, 1, pEndMid);
         ObjectSetInteger(0, nameCloudLower, OBJPROP_TIME, 2, t1);
         ObjectSetDouble(0, nameCloudLower, OBJPROP_PRICE, 2, pStartLower);
      }
      ObjectSetInteger(0, nameCloudLower, OBJPROP_COLOR, cloudLowerCol);
      ObjectSetInteger(0, nameCloudLower, OBJPROP_FILL, true);
      ObjectSetInteger(0, nameCloudLower, OBJPROP_BACK, true);
      ObjectSetInteger(0, nameCloudLower, OBJPROP_RAY_RIGHT, InpLRL_RayRight);
      ObjectSetInteger(0, nameCloudLower, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nameCloudLower, OBJPROP_ZORDER, 0);
   }
   else
   {
      ObjectDelete(0, nameCloudUpper);
      ObjectDelete(0, nameCloudLower);
   }

   // -------------------------------------------------------------
   // B. CHANNEL BORDER & MEDIAN LINES (CRISP OVERLAYS)
   // -------------------------------------------------------------
   // 1. เส้นบน (+Extreme Wick / +2σ): สไตล์หนาทึบ (STYLE_SOLID, Width 3)
   string nameUpper = GUI_PREFIX + "LRL_UPPER";
   if(ObjectFind(0, nameUpper) < 0)
      ObjectCreate(0, nameUpper, OBJ_TREND, 0, t1, pStartUpper, t2, pEndUpper);
   else
   {
      ObjectSetInteger(0, nameUpper, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0, nameUpper, OBJPROP_PRICE, 0, pStartUpper);
      ObjectSetInteger(0, nameUpper, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(0, nameUpper, OBJPROP_PRICE, 1, pEndUpper);
   }
   ObjectSetInteger(0, nameUpper, OBJPROP_COLOR, upperCol);
   ObjectSetInteger(0, nameUpper, OBJPROP_STYLE, STYLE_SOLID); // 🟢 เส้นทึบหนา
   ObjectSetInteger(0, nameUpper, OBJPROP_WIDTH, 3);           // 🟢 หนา 3 px
   ObjectSetInteger(0, nameUpper, OBJPROP_RAY_RIGHT, InpLRL_RayRight); // 🛑 false = กรอบพอดีแท่งเทียน ไม่ยิงทะลุขอบจอ
   ObjectSetInteger(0, nameUpper, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nameUpper, OBJPROP_BACK, true);
   ObjectSetInteger(0, nameUpper, OBJPROP_ZORDER, 1);

   // 2. เส้นกลาง (Median LRL): สไตล์เส้นปะ (STYLE_DASH, Width 1)
   string nameCenter = GUI_PREFIX + "LRL_MEDIAN";
   if(ObjectFind(0, nameCenter) < 0)
      ObjectCreate(0, nameCenter, OBJ_TREND, 0, t1, pStartMid, t2, pEndMid);
   else
   {
      ObjectSetInteger(0, nameCenter, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0, nameCenter, OBJPROP_PRICE, 0, pStartMid);
      ObjectSetInteger(0, nameCenter, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(0, nameCenter, OBJPROP_PRICE, 1, pEndMid);
   }
   ObjectSetInteger(0, nameCenter, OBJPROP_COLOR, medianCol);
   ObjectSetInteger(0, nameCenter, OBJPROP_STYLE, STYLE_DASH);  // 🟡 เส้นปะ
   ObjectSetInteger(0, nameCenter, OBJPROP_WIDTH, 1);           // 🟡 กว้าง 1 px
   ObjectSetInteger(0, nameCenter, OBJPROP_RAY_RIGHT, InpLRL_RayRight); // 🛑 false = กรอบพอดีแท่งเทียน
   ObjectSetInteger(0, nameCenter, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nameCenter, OBJPROP_BACK, true);
   ObjectSetInteger(0, nameCenter, OBJPROP_ZORDER, 1);

   // 3. เส้นล่าง (-Extreme Wick / -2σ): สไตล์หนาทึบ (STYLE_SOLID, Width 3)
   string nameLower = GUI_PREFIX + "LRL_LOWER";
   if(ObjectFind(0, nameLower) < 0)
      ObjectCreate(0, nameLower, OBJ_TREND, 0, t1, pStartLower, t2, pEndLower);
   else
   {
      ObjectSetInteger(0, nameLower, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0, nameLower, OBJPROP_PRICE, 0, pStartLower);
      ObjectSetInteger(0, nameLower, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(0, nameLower, OBJPROP_PRICE, 1, pEndLower);
   }
   ObjectSetInteger(0, nameLower, OBJPROP_COLOR, lowerCol);
   ObjectSetInteger(0, nameLower, OBJPROP_STYLE, STYLE_SOLID);  // 🔵 เส้นทึบหนา
   ObjectSetInteger(0, nameLower, OBJPROP_WIDTH, 3);           // 🔵 หนา 3 px
   ObjectSetInteger(0, nameLower, OBJPROP_RAY_RIGHT, InpLRL_RayRight); // 🛑 false = กรอบพอดีแท่งเทียน
   ObjectSetInteger(0, nameLower, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nameLower, OBJPROP_BACK, true);
   ObjectSetInteger(0, nameLower, OBJPROP_ZORDER, 1);
}

//+------------------------------------------------------------------+
//| KHUN ANN ANGEL & EMOTIONAL DISCIPLINE SHIELD HELPER FUNCTIONS    |
//+------------------------------------------------------------------+
double GetTotalOpenVolume()
{
   double totalVol = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol)
         totalVol += m_position.Volume();
   }
   return totalVol;
}

bool CheckMaxVolumeCeilingGuard(double nextLot, string &blockReason)
{
   if(!InpEnableMaxVolumeCeiling) return true;
   double currentVol = GetTotalOpenVolume();
   if((currentVol + nextLot) > (InpMaxTotalVolumeCap + 0.0001))
   {
      blockReason = StringFormat("🛑 MAX VOLUME CEILING (ถือ %.2f + %.2f = %.2f > เพดาน %.2f Lots) - ห้าม Over-leverage 🛡️",
                                 currentVol, nextLot, currentVol + nextLot, InpMaxTotalVolumeCap);
      return false;
   }
   return true;
}

bool CheckAntiSpamRapidEntryGuard(string &blockReason)
{
   if(!InpEnableRapidClickGuard) return true;
   datetime nowTime = TimeCurrent();
   if(g_LastAnyOrderTime > 0 && (nowTime - g_LastAnyOrderTime) < InpMinEntrySpacingSeconds)
   {
      int remainSec = (int)(InpMinEntrySpacingSeconds - (nowTime - g_LastAnyOrderTime));
      blockReason = StringFormat("⚠️ ANTI-SPAM GUARD (เพิ่งเปิดไม้ไปเมื่อครู่ รออีก %d วิ) - ใจเย็นๆ ครับคุณเอ้ ❤️", remainSec);
      return false;
   }
   return true;
}

bool CheckRevengeCooldownGuard(string &blockReason)
{
   return true; // Unblocked per V8.00 Master Plan
}

bool CheckPostSLBECooldownGuard(string &blockReason)
{
   return true; // Unblocked per V8.00 Master Plan
}

//+------------------------------------------------------------------+
//| 20. MULTI-TF EMA 14 MATRIX & INSTITUTIONAL EMA 200 ENGINE         |
//+------------------------------------------------------------------+
void UpdateMultiTF_EMA14_Engine()
{
   if(!InpShowMultiTF_EMA14 && !InpUseMultiTF_EMA14_Logic && !InpShowEMA200_Line && !InpUseEMA200_Filter)
      return;

   // Throttled scan: Run every 250ms for maximum efficiency
   static ulong lastEmaScanMs = 0;
   ulong curTickMs = GetTickCount64();
   if(curTickMs - lastEmaScanMs < 250)
      return;
   lastEmaScanMs = curTickMs;

   ENUM_TIMEFRAMES emaTFs[8] = {PERIOD_W1, PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15, PERIOD_M5, PERIOD_M1};
   string emaTFNames[8]      = {"W1", "D1", "H4", "H1", "M30", "M15", "M5", "M1"};
   int emaHandles[8];
   emaHandles[0] = m_hEMA14_W1;
   emaHandles[1] = m_hEMA14_D1;
   emaHandles[2] = m_hEMA14_H4;
   emaHandles[3] = m_hEMA14_H1;
   emaHandles[4] = m_hEMA14_M30;
   emaHandles[5] = m_hEMA14_M15;
   emaHandles[6] = m_hEMA14_M5;
   emaHandles[7] = m_hEMA14_M1;

   for(int i = 0; i < 8; i++)
   {
      g_MultiTF_EMA14[i].tf     = emaTFs[i];
      g_MultiTF_EMA14[i].tfName = emaTFNames[i];
      g_MultiTF_EMA14[i].col    = InpColorEMA14_Lines;

      if(emaHandles[i] == INVALID_HANDLE)
      {
         emaHandles[i] = iMA(_Symbol, emaTFs[i], 14, 0, MODE_EMA, PRICE_CLOSE);
         if(i == 0) m_hEMA14_W1 = emaHandles[0];
         else if(i == 1) m_hEMA14_D1 = emaHandles[1];
         else if(i == 2) m_hEMA14_H4 = emaHandles[2];
         else if(i == 3) m_hEMA14_H1 = emaHandles[3];
         else if(i == 4) m_hEMA14_M30 = emaHandles[4];
         else if(i == 5) m_hEMA14_M15 = emaHandles[5];
         else if(i == 6) m_hEMA14_M5 = emaHandles[6];
         else if(i == 7) m_hEMA14_M1 = emaHandles[7];
      }

      if(emaHandles[i] != INVALID_HANDLE)
      {
         double buf[1];
         if(CopyBuffer(emaHandles[i], 0, 0, 1, buf) > 0)
            g_MultiTF_EMA14[i].val = buf[0];
      }
   }

   // EMA 200 Update
   if(m_hEMA200_Current == INVALID_HANDLE)
      m_hEMA200_Current = iMA(_Symbol, InpTimeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(m_hEMA200_H1 == INVALID_HANDLE)
      m_hEMA200_H1 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);

   if(m_hEMA200_Current != INVALID_HANDLE)
   {
      double b200[1];
      if(CopyBuffer(m_hEMA200_Current, 0, 0, 1, b200) > 0)
         g_CurrentEMA200 = b200[0];
   }
   if(m_hEMA200_H1 != INVALID_HANDLE)
   {
      double b200H1[1];
      if(CopyBuffer(m_hEMA200_H1, 0, 0, 1, b200H1) > 0)
         g_HTF_EMA200 = b200H1[0];
   }

   // Waterfall Cascade Analysis (H4 -> H1 -> M30 -> M15 -> M5)
   // In downtrend: H4 > H1 > M30 > M15 > M5
   // In uptrend:   H4 < H1 < M30 < M15 < M5
   if(g_MultiTF_EMA14[2].val > 0 && g_MultiTF_EMA14[3].val > 0 && 
      g_MultiTF_EMA14[4].val > 0 && g_MultiTF_EMA14[5].val > 0 && g_MultiTF_EMA14[6].val > 0)
   {
      g_EMA14_CascadeDown = (g_MultiTF_EMA14[2].val > g_MultiTF_EMA14[3].val &&
                             g_MultiTF_EMA14[3].val > g_MultiTF_EMA14[4].val &&
                             g_MultiTF_EMA14[4].val > g_MultiTF_EMA14[5].val &&
                             g_MultiTF_EMA14[5].val > g_MultiTF_EMA14[6].val);

      g_EMA14_CascadeUp   = (g_MultiTF_EMA14[2].val < g_MultiTF_EMA14[3].val &&
                             g_MultiTF_EMA14[3].val < g_MultiTF_EMA14[4].val &&
                             g_MultiTF_EMA14[4].val < g_MultiTF_EMA14[5].val &&
                             g_MultiTF_EMA14[5].val < g_MultiTF_EMA14[6].val);
   }
   else
   {
      g_EMA14_CascadeDown = false;
      g_EMA14_CascadeUp   = false;
   }

   // Near Key EMA 14 Test (Within 35 points of H4, H1, D1, or W1)
   double curPrice = (m_symbol.Ask() + m_symbol.Bid()) / 2.0;
   g_EMA14_NearTest = false;
   for(int i = 0; i < 4; i++) // W1, D1, H4, H1
   {
      if(g_MultiTF_EMA14[i].val > 0 && MathAbs(curPrice - g_MultiTF_EMA14[i].val) <= (35.0 * _Point))
      {
         g_EMA14_NearTest = true;
         break;
      }
   }
}

void RemoveMultiTF_EMA14_Visuals()
{
   ObjectsDeleteAll(0, GUI_PREFIX + "EMA14_");
   ObjectsDeleteAll(0, GUI_PREFIX + "EMA200_");
}

void DrawMultiTF_EMA14_Visuals()
{
   if(!g_ShowVisuals || !g_ShowEMAVisuals)
   {
      RemoveMultiTF_EMA14_Visuals();
      return;
   }

   datetime curTime = TimeCurrent();
   long secPerBar   = PeriodSeconds(InpTimeframe);
   datetime tStart  = curTime - (datetime)(secPerBar * 35);
   datetime tEnd    = curTime + (datetime)(secPerBar * 12);

   // 1. Draw Institutional HTF EMA 14 Levels (W1, D1, H4, H1)
   if(InpShowMultiTF_EMA14)
   {
      for(int i = 0; i < 4; i++) // W1, D1, H4, H1
      {
         double pVal = g_MultiTF_EMA14[i].val;
         if(pVal <= 0) continue;

         string lineName = GUI_PREFIX + "EMA14_LINE_" + g_MultiTF_EMA14[i].tfName;
         if(ObjectFind(0, lineName) < 0)
            ObjectCreate(0, lineName, OBJ_TREND, 0, tStart, pVal, tEnd, pVal);
         else
         {
            ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, tStart);
            ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, pVal);
            ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, tEnd);
            ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, pVal);
         }
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpColorEMA14_Lines);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
         ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);

         // Label (Smart Horizontal & Vertical Staggering to prevent overlap)
         datetime tLbl = tEnd + (datetime)(secPerBar * (3 + (i * 2)));
         string lblName = GUI_PREFIX + "EMA14_LBL_" + g_MultiTF_EMA14[i].tfName;
         if(ObjectFind(0, lblName) < 0)
            ObjectCreate(0, lblName, OBJ_TEXT, 0, tLbl, pVal);
         else
         {
            ObjectSetInteger(0, lblName, OBJPROP_TIME, 0, tLbl);
            ObjectSetDouble(0, lblName, OBJPROP_PRICE, 0, pVal);
         }
         string valStr = (_Digits > 2) ? StringFormat("%.1f", pVal) : StringFormat("%.2f", pVal);
         ObjectSetString(0, lblName, OBJPROP_TEXT, StringFormat(" 🟣 EMA 14 [%s]: %s ", g_MultiTF_EMA14[i].tfName, valStr));
         ObjectSetString(0, lblName, OBJPROP_FONT, "Segoe UI Semibold");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, InpColorEMA14_Lines);
         ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
      }
   }
   else
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "EMA14_");
   }

   // 2. Draw Institutional EMA 200 Level
   if(InpShowEMA200_Line && g_CurrentEMA200 > 0)
   {
      string line200 = GUI_PREFIX + "EMA200_LINE";
      if(ObjectFind(0, line200) < 0)
         ObjectCreate(0, line200, OBJ_TREND, 0, tStart, g_CurrentEMA200, tEnd, g_CurrentEMA200);
      else
      {
         ObjectSetInteger(0, line200, OBJPROP_TIME, 0, tStart);
         ObjectSetDouble(0, line200, OBJPROP_PRICE, 0, g_CurrentEMA200);
         ObjectSetInteger(0, line200, OBJPROP_TIME, 1, tEnd);
         ObjectSetDouble(0, line200, OBJPROP_PRICE, 1, g_CurrentEMA200);
      }
      ObjectSetInteger(0, line200, OBJPROP_COLOR, InpColorEMA200_Line);
      ObjectSetInteger(0, line200, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, line200, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, line200, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line200, OBJPROP_BACK, true);
      ObjectSetInteger(0, line200, OBJPROP_SELECTABLE, false);

      // EMA 200 Label (Staggered ahead of EMA 14 labels)
      datetime tLbl200 = tEnd + (datetime)(secPerBar * 1);
      string lbl200 = GUI_PREFIX + "EMA200_LBL";
      if(ObjectFind(0, lbl200) < 0)
         ObjectCreate(0, lbl200, OBJ_TEXT, 0, tLbl200, g_CurrentEMA200);
      else
      {
         ObjectSetInteger(0, lbl200, OBJPROP_TIME, 0, tLbl200);
         ObjectSetDouble(0, lbl200, OBJPROP_PRICE, 0, g_CurrentEMA200);
      }
      string val200Str = (_Digits > 2) ? StringFormat("%.1f", g_CurrentEMA200) : StringFormat("%.2f", g_CurrentEMA200);
      ObjectSetString(0, lbl200, OBJPROP_TEXT, StringFormat(" 🏛️ EMA 200: %s ", val200Str));
      ObjectSetString(0, lbl200, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, lbl200, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, lbl200, OBJPROP_COLOR, InpColorEMA200_Line);
      ObjectSetInteger(0, lbl200, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, lbl200, OBJPROP_BACK, false);
   }
   else
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "EMA200_");
   }
}

//+------------------------------------------------------------------+
//| SMART STRUCTURAL RE-ENTRY GUARD & ZONE RECOVERY SUITE            |
//+------------------------------------------------------------------+
bool IsPriceInsideDemandZone(double price, double bufferPts = 30.0)
{
   double buf = bufferPts * _Point;

   // 1. Check SMC MTF Demand Zones
   for(int z = 0; z < ArraySize(g_SMC_MTF_Zones); z++)
   {
      if(!g_SMC_MTF_Zones[z].isActive || g_SMC_MTF_Zones[z].direction != 1) continue;
      if(price >= (g_SMC_MTF_Zones[z].bottomPrice - buf) && price <= (g_SMC_MTF_Zones[z].topPrice + buf))
         return true;
   }

   // 2. Check Active Demand Order Block
   if(g_OB_Active && g_ActiveOB.isActive && g_ActiveOB.direction == 1)
   {
      if(price >= (g_ActiveOB.bottomPrice - buf) && price <= (g_ActiveOB.topPrice + buf))
         return true;
   }

   // 3. Check HTF Reversal Zone
   if(g_HTFReversal.isValid && g_HTFReversal.direction == 1)
      return true;

   // 4. Check Fibo Golden Pocket / Discount Zone
   if(g_Fibo.isInsideZone && g_MarketTrend == TREND_BULLISH)
      return true;

   return false;
}

bool IsPriceInsideSupplyZone(double price, double bufferPts = 30.0)
{
   double buf = bufferPts * _Point;

   // 1. Check SMC MTF Supply Zones
   for(int z = 0; z < ArraySize(g_SMC_MTF_Zones); z++)
   {
      if(!g_SMC_MTF_Zones[z].isActive || g_SMC_MTF_Zones[z].direction != -1) continue;
      if(price >= (g_SMC_MTF_Zones[z].bottomPrice - buf) && price <= (g_SMC_MTF_Zones[z].topPrice + buf))
         return true;
   }

   // 2. Check Active Supply Order Block
   if(g_OB_Active && g_ActiveOB.isActive && g_ActiveOB.direction == -1)
   {
      if(price >= (g_ActiveOB.bottomPrice - buf) && price <= (g_ActiveOB.topPrice + buf))
         return true;
   }

   // 3. Check HTF Reversal Zone
   if(g_HTFReversal.isValid && g_HTFReversal.direction == -1)
      return true;

   // 4. Check Fibo Premium Zone
   if(g_Fibo.isInsideZone && g_MarketTrend == TREND_BEARISH)
      return true;

   return false;
}

bool CheckSmartReEntryGuard(ENUM_ORDER_TYPE orderType, double currentPrice, int qualityScore, string &blockReason)
{
   if(!InpEnableSmartReEntryGuard)
      return true;

   // If no previous SL recorded or lock expired (> 15 minutes = 900 seconds)
   if(g_LastStoppedPrice <= 0 || g_LastStoppedTime <= 0)
      return true;

   datetime elapsedSec = TimeCurrent() - g_LastStoppedTime;
   if(elapsedSec >= 900)
   {
      g_LastStoppedPrice = 0.0;
      return true;
   }

   // Check distance from last stopped price
   double distPts = MathAbs(currentPrice - g_LastStoppedPrice) / _Point;
   if(distPts >= InpSamePriceLockBufferPts)
      return true;

   // Price is hovering within buffer of last SL!
   // Check Break-Even protection
   if(InpAllowReEntryOnBE && g_LastStoppedProfit >= 0.0)
   {
      g_ReEntryUnlocked = true;
      g_ReEntryUnlockReason = "BE Protection Active (Risk-Free Re-entry)";
      return true;
   }

   // 🌟 Check THE GOLDEN EXCEPTION:
   // 1. Must be in Demand Zone (for Buy) or Supply Zone (for Sell)
   bool inZone = false;
   if(orderType == ORDER_TYPE_BUY)
      inZone = IsPriceInsideDemandZone(currentPrice);
   else if(orderType == ORDER_TYPE_SELL)
      inZone = IsPriceInsideSupplyZone(currentPrice);

   // 2. Must have Price Action confirmation
   bool hasPA = (g_DetectedPattern != PA_NONE || g_PABuyTrigger || g_PASellTrigger || g_PARejectionType != "" || g_HTFReversal.isValid);

   // 3. Must have Quality Score >= InpReEntryMinScore (70%+)
   bool hasScore = (qualityScore >= InpReEntryMinScore);

   if(inZone && hasPA && hasScore)
   {
      g_ReEntryUnlocked = true;
      g_ReEntryUnlockReason = StringFormat("DZ/SZ Reversal Confluence (Score %d%% >= %d%%)", qualityScore, InpReEntryMinScore);
      Print(">>> 🛡️ [SMART RE-ENTRY UNLOCKED] Price @ ", DoubleToString(currentPrice, _Digits),
            " is inside Zone + PA Confirmed + Score: ", qualityScore, "% >= ", InpReEntryMinScore, "%! Re-entry granted.");
      return true;
   }

   blockReason = StringFormat("Smart Re-Entry Guard: Price (%.2f) within %d pts of Last SL (%.2f) [%ds ago]. Required: Zone (%s) + PA (%s) + Score>=%d%% (Current: %d%%)",
                              currentPrice, InpSamePriceLockBufferPts, g_LastStoppedPrice, (int)elapsedSec,
                              (inZone ? "YES" : "NO"), (hasPA ? "YES" : "NO"), InpReEntryMinScore, qualityScore);
   return false;
}

//+------------------------------------------------------------------+
//| HTF PRECISION TREND GUARD (H1 MIDLINE & FALLING KNIFE SHIELD)    |
//+------------------------------------------------------------------+
bool CheckHTFPrecisionTrendGuard(ENUM_ORDER_TYPE orderType, string &blockReason)
{
   if(!InpUseHTFPrecisionGuard || !g_HTFMacroGuardActive) return true;

   ENUM_TIMEFRAMES activeTF = GetCurrentExecutionTF();
   int activeRank = GetTFRank(activeTF);
   ENUM_TIMEFRAMES htf = (activeRank >= 6) ? PERIOD_D1 : PERIOD_H1;
   int hEMA = (activeRank >= 6) ? m_hEMA_D1 : m_hEMA_H1;

   // 1. Live HTF Falling Knife / Rocket Spike Dump Guard (Adaptive across Gold, Crypto, Forex)
   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   if(CopyRates(_Symbol, htf, 0, 2, htfRates) >= 2)
   {
      double curAsk = m_symbol.Ask();
      double curBid = m_symbol.Bid();
      double htfOpen = htfRates[0].open;
      double effectiveDumpPts = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpH1FallingKnifeDumpPts : MathMax((double)g_AssetProfile.fallbackSL * 0.55, 80.0);

      if(orderType == ORDER_TYPE_BUY)
      {
         double dropPts = (htfOpen - curAsk) / _Point;
         if(dropPts >= effectiveDumpPts)
         {
            blockReason = StringFormat("🛑 HTF FALLING KNIFE (%s ทุบลง -%.0f pts) - มีดกำลังร่วง ห้ามรับมีด 🛡️", EnumToString(htf), dropPts);
            return false;
         }
      }
      else if(orderType == ORDER_TYPE_SELL)
      {
         double risePts = (curBid - htfOpen) / _Point;
         if(risePts >= effectiveDumpPts)
         {
            blockReason = StringFormat("🛑 HTF ROCKET SPIKE (%s พุ่งขึ้น +%.0f pts) - แท่งพุ่งแรง ห้ามดักช็อต 🛡️", EnumToString(htf), risePts);
            return false;
         }
      }
   }

   // 2. Samurai HTF Linear Regression Midline / Channel Floor Cut
   if(InpH1MidlineCheck)
   {
      SLinearRegressionResult htfLRL;
      if(CalculateLinearRegression(htf, InpLRL_ChartBars, htfLRL))
      {
         double curAsk = m_symbol.Ask();
         double curBid = m_symbol.Bid();

         if(orderType == ORDER_TYPE_BUY)
         {
            // If HTF is Bearish or Sideway, strictly block BUY below midline
            if(htfLRL.trend != LRL_TREND_BULLISH && curAsk < htfLRL.medianPrice)
            {
               blockReason = StringFormat("🛑 HTF UNDER MIDLINE (%s: %.2f < เส้นกลาง %.2f) - ฝั่งหมีคุมชาร์ต ห้าม Buy 🛡️", EnumToString(htf), curAsk, htfLRL.medianPrice);
               return false;
            }
            // If HTF is Bullish channel, allow discount dip-buy down to the lower band, but block if breaking below channel floor!
            else if(htfLRL.trend == LRL_TREND_BULLISH && curAsk < (htfLRL.lowerPrice - (20 * _Point)))
            {
               blockReason = StringFormat("🛑 HTF BREAK BELOW CHANNEL (%s: %.2f < ขอบล่าง %.2f) - หลุดกรอบแชนแนลแม่ ห้าม Buy 🛡️", EnumToString(htf), curAsk, htfLRL.lowerPrice);
               return false;
            }
         }
         else if(orderType == ORDER_TYPE_SELL)
         {
            // If HTF is Bullish or Sideway, strictly block SELL above midline
            if(htfLRL.trend != LRL_TREND_BEARISH && curBid > htfLRL.medianPrice)
            {
               blockReason = StringFormat("🛑 HTF ABOVE MIDLINE (%s: %.2f > เส้นกลาง %.2f) - ฝั่งกระทิงคุมชาร์ต ห้าม Sell 🛡️", EnumToString(htf), curBid, htfLRL.medianPrice);
               return false;
            }
            // If HTF is Bearish channel, allow premium rally-sell up to the upper band, but block if breaking above channel ceiling!
            else if(htfLRL.trend == LRL_TREND_BEARISH && curBid > (htfLRL.upperPrice + (20 * _Point)))
            {
               blockReason = StringFormat("🛑 HTF BREAK ABOVE CHANNEL (%s: %.2f > ขอบบน %.2f) - ทะลุกรอบแชนแนลแม่ ห้าม Sell 🛡️", EnumToString(htf), curBid, htfLRL.upperPrice);
               return false;
            }
         }
      }
   }

   // 3. Single-TF HTF EMA Decoupling (Adaptive to H1 or D1 based on active chart)
   if(InpH1SingleBarEMACheck && hEMA != INVALID_HANDLE)
   {
      double ema1[1];
      MqlRates r1[];
      ArraySetAsSeries(r1, true);
      if(CopyRates(_Symbol, htf, 0, 1, r1) > 0 && CopyBuffer(hEMA, 0, 0, 1, ema1) > 0)
      {
         if(orderType == ORDER_TYPE_BUY && r1[0].close < ema1[0])
         {
            blockReason = StringFormat("🛑 %s CLOSED BELOW EMA50 - แท่งเทียน %s หลุดใต้แนวเฉลี่ย ห้าม Buy 🛡️", EnumToString(htf), EnumToString(htf));
            return false;
         }
         else if(orderType == ORDER_TYPE_SELL && r1[0].close > ema1[0])
         {
            blockReason = StringFormat("🛑 %s CLOSED ABOVE EMA50 - แท่งเทียน %s ลอยเหนือแนวเฉลี่ย ห้าม Sell 🛡️", EnumToString(htf), EnumToString(htf));
            return false;
         }
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| 🛡️ IRONCLAD ANTI-PEAK & ANTI-BOTTOM GUARDS (SMC MASTER V7.50)    |
//+------------------------------------------------------------------+
bool CheckAntiPeakGuard(ENUM_ORDER_TYPE orderType, double currentPrice, string &blockReason, bool isSniperSetup=false)
{
   blockReason = "";
   if(orderType != ORDER_TYPE_BUY || currentPrice <= 0)
      return true; // Only guards against buying at market peaks

   // 0. Z-Score Statistical Extreme Guard (Overextended Peak >= +2.0 SD)
   if(InpUseZScoreGuard && g_ZScoreExtremePeak)
   {
      blockReason = StringFormat("🛑 Z-SCORE PEAK GUARD: ราคาเบี่ยงเบนสูง (Z = %+.2f SD)\n↳ เกินกรอบสถิติ +%.1f SD • ห้าม Buy ยอดดอยเด็ดขาด 🛡️", g_LiveZScore, InpZScoreThreshold);
      return false;
   }

   // 0.1 CME Call Wall Ceiling Guard (Tactical, Mega, and Intermediate Walls)
   if(InpUseCMEWallGuard)
   {
      if(g_CME_NearMegaCallWall)
      {
         blockReason = StringFormat("🛑 CME MEGA CALL: ราคา %.2f จ่อเพดานสถาบัน Strike %.2f\n↳ ปริมาณหนาแน่น 10,133 OI • ห้าม Buy ยอดดอยเด็ดขาด 🛡️", currentPrice, InpCME_MegaCallWall);
         return false;
      }
      if(g_CME_NearCallWall && (InpCME_WallCautionEngine || g_TradeMode == TRADE_MODE_SAFE_COPILOT || currentPrice <= (InpCME_CallWall + (50 * _Point))))
      {
         blockReason = StringFormat("ðŸ”´ CME CALL WALL: à¸£à¸²à¸„à¸² %.2f à¸•à¸´à¸”à¹€à¸žà¸”à¸²à¸™à¹€à¸ˆà¹‰à¸²à¸¡à¸·à¸­ Strike %.2f\nâ€¢ à¸ªà¸ à¸²à¸žà¸„à¸¥à¹ˆà¸­à¸‡à¸”à¸±à¸ 2,871 OI â€¢ à¸«à¹‰à¸²à¸¡ Buy à¸”à¸±à¸à¸£à¸­à¸¢à¹ˆà¸­à¸«à¸£à¸·à¸­à¸Šà¹‰à¸­à¸™ Sell", currentPrice, InpCME_CallWall);
         return false;
      }
      if(g_CME_NearIntermedCall && (InpCME_WallCautionEngine || g_TradeMode == TRADE_MODE_SAFE_COPILOT || currentPrice <= (InpCME_IntermediateCall + (50 * _Point))))
      {
         blockReason = StringFormat("🛑 CME INTERMED CALL: ราคา %.2f จ่อแนวต้าน Strike %.2f\n↳ ปริมาณ 1,439 OI • ห้าม Buy ไล่ราคา 🛡️", currentPrice, InpCME_IntermediateCall);
         return false;
      }
   }

   // 3. BSL Liquidity Swept Trap (Price swept BSL and is hovering in the trap zone)
   if(g_LQ_Radar.bslSwept && g_LQ_Radar.bsl.price > 0 && currentPrice >= g_LQ_Radar.bsl.price - (150 * _Point))
   {
      blockReason = StringFormat("🛑 BSL TRAP GUARD: กวาดสภาพคล่องยอดดอย (BSL @ %.2f)\n↳ ติดกับดักเจ้ามือ • ห้าม Buy สวนเด็ดขาด 🛡️", g_LQ_Radar.bsl.price);
      return false;
   }

   // Standard Wave & Dip-Buy Anti-Peak Checks (Relaxed ONLY for Institutional Breakout Snipers)
   if(g_PlanSource != "BREAKOUT")
   {
      double high = g_LastSwingHigh.price;
      double low  = g_LastSwingLow.price;
      double range = high - low;

      // 1. Dynamic Swing Range Extreme Ceiling (Top 20% of Current Wave Range)
      if(range > 100 * _Point && high > 0)
      {
         double peakThreshold = high - (range * 0.20);
         if(currentPrice >= peakThreshold)
         {
            blockReason = StringFormat("🛑 ANTI-PEAK GUARD: ราคา %.2f โซน 20%% ยอดดอย\n↳ ระดับ ≥ %.2f • ห้าม Buy ยอดดอยเด็ดขาด 🛡️", currentPrice, peakThreshold);
            return false;
         }
      }

      // 2. Proximity to Swing High / BSL (Within 250 pts on Gold, or 35% of FallbackSL)
      double peakProximity = MathMax(250.0 * _Point, (double)g_AssetProfile.fallbackSL * 0.35 * _Point);
      if(high > 0 && (high - currentPrice) <= peakProximity && currentPrice <= high + (100 * _Point))
      {
         blockReason = StringFormat("🛑 ANTI-PEAK GUARD: ราคา %.2f จ่อยอด High %.2f\n↳ ห่าง %.0f pts (≤ %.0f) • ห้าม Buy ยอดดอยเด็ดขาด 🛡️", currentPrice, high, (high - currentPrice)/_Point, peakProximity/_Point);
         return false;
      }

      // 4. LRL Channel Upper Band Extreme (Price touching or above the Upper Band)
      if(InpEnableLRLChannel && g_LRL_Chart.upperPrice > 0 && currentPrice >= (g_LRL_Chart.upperPrice - (20 * _Point)))
      {
         blockReason = StringFormat("🛑 LRL UPPER BAND: ราคา %.2f แตะขอบบนแชนแนล\n↳ สุดกรอบ Samurai Wick • ห้าม Buy ปลายขอบบน 🛡️", g_LRL_Chart.upperPrice);
         return false;
      }
   }

   return true;
}

bool CheckAntiBottomGuard(ENUM_ORDER_TYPE orderType, double currentPrice, string &blockReason, bool isSniperSetup=false)
{
   blockReason = "";
   if(orderType != ORDER_TYPE_SELL || currentPrice <= 0)
      return true; // Only guards against selling at market troughs

   // 0. Z-Score Statistical Extreme Guard (Overextended Abyss <= -2.0 SD)
   if(InpUseZScoreGuard && g_ZScoreExtremeValley)
   {
      blockReason = StringFormat("🛑 Z-SCORE ABYSS GUARD: ราคาเทลึกผิดปกติ (Z = %+.2f SD)\n↳ หลุดกรอบสถิติ -%.1f SD • ห้าม Sell ก้นเหวเด็ดขาด 🛡️", g_LiveZScore, InpZScoreThreshold);
      return false;
   }

   // 0.1 CME Put Wall Floor Guard (Tactical, Macro, and Intermediate Walls)
   if(InpUseCMEWallGuard)
   {
      if(g_CME_NearMacroPutWall)
      {
         blockReason = StringFormat("🛑 CME MACRO PUT BASE: ราคา %.2f จ่อฐานใหญ่ Strike %.2f\n↳ ปริมาณหนาแน่น 2,525 OI • ห้าม Sell ก้นเหวเด็ดขาด 🛡️", currentPrice, InpCME_MacroPutWall);
         return false;
      }
      if(g_CME_NearPutWall && (InpCME_WallCautionEngine || g_TradeMode == TRADE_MODE_SAFE_COPILOT || currentPrice >= (InpCME_PutWall - (50 * _Point))))
      {
         blockReason = StringFormat("🛑 CME PUT WALL: ราคา %.2f จ่อพื้นแนวรับ Strike %.2f\n↳ ปริมาณหนาแน่น 3,293 OI • ห้าม Sell ก้นเหวเด็ดขาด 🛡️", currentPrice, InpCME_PutWall);
         return false;
      }
      if(g_CME_NearIntermedPut && (InpCME_WallCautionEngine || g_TradeMode == TRADE_MODE_SAFE_COPILOT || currentPrice >= (InpCME_IntermediatePut - (50 * _Point))))
      {
         blockReason = StringFormat("🛑 CME INTERMED PUT: ราคา %.2f จ่อแนวรับย่อย Strike %.2f\n↳ ปริมาณ 2,466 OI • ห้าม Sell ก้นเหว 🛡️", currentPrice, InpCME_IntermediatePut);
         return false;
      }
   }

   // 3. SSL Liquidity Swept Trap (Price swept SSL and is hovering in the trap zone)
   if(g_LQ_Radar.sslSwept && g_LQ_Radar.ssl.price > 0 && currentPrice <= g_LQ_Radar.ssl.price + (150 * _Point))
   {
      blockReason = StringFormat("🛑 SSL TRAP GUARD: กวาดสภาพคล่องก้นเหว (SSL @ %.2f)\n↳ ติดกับดักเจ้ามือ • ห้าม Sell สวนเด็ดขาด 🛡️", g_LQ_Radar.ssl.price);
      return false;
   }

   // Standard Wave & Rally-Sell Anti-Bottom Checks (Relaxed ONLY for Institutional Breakdown Snipers)
   if(g_PlanSource != "BREAKDOWN")
   {
      double high = g_LastSwingHigh.price;
      double low  = g_LastSwingLow.price;
      double range = high - low;

      // 1. Dynamic Swing Range Extreme Floor (Bottom 20% of Current Wave Range)
      if(range > 100 * _Point && low > 0)
      {
         double valleyThreshold = low + (range * 0.20);
         if(currentPrice <= valleyThreshold)
         {
            blockReason = StringFormat("🛑 ANTI-BOTTOM GUARD: ราคา %.2f โซน 20%% ก้นเหว\n↳ ระดับ ≤ %.2f • ห้าม Sell ก้นเหวเด็ดขาด 🛡️", currentPrice, valleyThreshold);
            return false;
         }
      }

      // 2. Proximity to Swing Low / SSL (Within 250 pts on Gold, or 35% of FallbackSL)
      double bottomProximity = MathMax(250.0 * _Point, (double)g_AssetProfile.fallbackSL * 0.35 * _Point);
      if(low > 0 && (currentPrice - low) <= bottomProximity && currentPrice >= low - (100 * _Point))
      {
         blockReason = StringFormat("🛑 ANTI-BOTTOM GUARD: ราคา %.2f จ่อก้น Low %.2f\n↳ ห่าง %.0f pts (≤ %.0f) • ห้าม Sell ก้นเหวเด็ดขาด 🛡️", currentPrice, low, (currentPrice - low)/_Point, bottomProximity/_Point);
         return false;
      }

      // 4. LRL Channel Lower Band Extreme (Price touching or below the Lower Band)
      if(InpEnableLRLChannel && g_LRL_Chart.lowerPrice > 0 && currentPrice <= (g_LRL_Chart.lowerPrice + (20 * _Point)))
      {
         blockReason = StringFormat("🛑 LRL LOWER BAND: ราคา %.2f แตะขอบล่างแชนแนล\n↳ สุดกรอบ Samurai Wick • ห้าม Sell ปลายขอบล่าง 🛡️", g_LRL_Chart.lowerPrice);
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| 🛡️ CHECK DEMAND ZONE PROXIMITY GUARD (STRICT NO-SELL IN/NEAR DEMAND)
//+------------------------------------------------------------------+
bool CheckDemandZoneProximityGuard(ENUM_ORDER_TYPE orderType, double currentPrice, string &blockReason)
{
   if(orderType != ORDER_TYPE_SELL) return true;
   
   double buffer = MathMax(20.0 * _Point, (double)g_AssetProfile.beLock * 0.5 * _Point);
   double minClearance = MathMax(250.0 * _Point, (double)g_AssetProfile.fallbackSL * 0.35 * _Point);
   
   for(int i = 0; i < ArraySize(g_SMC_MTF_Zones); i++)
   {
      if(!g_SMC_MTF_Zones[i].isActive || g_SMC_MTF_Zones[i].direction != 1) continue;
      
      // 1. If price is inside or touching Demand Zone (Buffer margin)
      if(currentPrice <= (g_SMC_MTF_Zones[i].topPrice + buffer) && currentPrice >= (g_SMC_MTF_Zones[i].bottomPrice - buffer))
      {
         blockReason = StringFormat("🛑 DEMAND ZONE GUARD: ราคา %.2f จ่อในโซน %s\n↳ โซนรับ [%.2f-%.2f] • ห้าม SELL ในแนวรับเด็ดขาด 🛡️", 
                                    currentPrice, g_SMC_MTF_Zones[i].tfName, g_SMC_MTF_Zones[i].bottomPrice, g_SMC_MTF_Zones[i].topPrice);
         return false;
      }

      // 2. If price is above Demand Zone but too close (Insufficient floor headroom)
      if(currentPrice > g_SMC_MTF_Zones[i].topPrice)
      {
         double distToFloor = currentPrice - g_SMC_MTF_Zones[i].topPrice;
         if(distToFloor < minClearance)
         {
            blockReason = StringFormat("🛑 TIGHT DEMAND FLOOR: ห่างพื้นรับ %s เพียง %.0f pts\n↳ โซนรับ [%.2f-%.2f] • ห้าม SELL ยัดแนวรับเด็ดขาด 🛡️", 
                                       g_SMC_MTF_Zones[i].tfName, distToFloor / _Point, g_SMC_MTF_Zones[i].bottomPrice, g_SMC_MTF_Zones[i].topPrice);
            return false;
         }
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| 🛡️ CHECK SUPPLY ZONE PROXIMITY GUARD (STRICT NO-BUY IN/NEAR SUPPLY)
//+------------------------------------------------------------------+
bool CheckSupplyZoneProximityGuard(ENUM_ORDER_TYPE orderType, double currentPrice, string &blockReason)
{
   if(orderType != ORDER_TYPE_BUY) return true;
   
   double buffer = MathMax(20.0 * _Point, (double)g_AssetProfile.beLock * 0.5 * _Point);
   double minClearance = MathMax(250.0 * _Point, (double)g_AssetProfile.fallbackSL * 0.35 * _Point);
   
   for(int i = 0; i < ArraySize(g_SMC_MTF_Zones); i++)
   {
      if(!g_SMC_MTF_Zones[i].isActive || g_SMC_MTF_Zones[i].direction != -1) continue;
      
      // 1. If price is inside or touching Supply Zone (Buffer margin)
      if(currentPrice >= (g_SMC_MTF_Zones[i].bottomPrice - buffer) && currentPrice <= (g_SMC_MTF_Zones[i].topPrice + buffer))
      {
         blockReason = StringFormat("🛑 SUPPLY ZONE GUARD: ราคา %.2f จ่อในโซน %s\n↳ โซนต้าน [%.2f-%.2f] • ห้าม BUY ในแนวต้านเด็ดขาด 🛡️", 
                                    currentPrice, g_SMC_MTF_Zones[i].tfName, g_SMC_MTF_Zones[i].bottomPrice, g_SMC_MTF_Zones[i].topPrice);
         return false;
      }

      // 2. If price is below Supply Zone but too close (Insufficient ceiling headroom)
      if(currentPrice < g_SMC_MTF_Zones[i].bottomPrice)
      {
         double distToCeiling = g_SMC_MTF_Zones[i].bottomPrice - currentPrice;
         if(distToCeiling < minClearance)
         {
            blockReason = StringFormat("🛑 TIGHT SUPPLY CEILING: ห่างเพดานต้าน %s เพียง %.0f pts\n↳ โซนต้าน [%.2f-%.2f] • ห้าม BUY ยัดแนวต้านเด็ดขาด 🛡️", 
                                       g_SMC_MTF_Zones[i].tfName, distToCeiling / _Point, g_SMC_MTF_Zones[i].bottomPrice, g_SMC_MTF_Zones[i].topPrice);
            return false;
         }
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| CHECK EXHAUSTION GUARDS (PREVENT PEAK-BUY & BOTTOM-SELL)         |
//+------------------------------------------------------------------+
bool IsTradeAllowedByExhaustionGuard(ENUM_ORDER_TYPE orderType, string &blockReason, bool isSniperSetup=false)
{
   blockReason = "";

   // 0. Ironclad Anti-Peak & Anti-Bottom Guards (SMC Master Protection)
   if(orderType == ORDER_TYPE_BUY)
   {
      string peakBlock = "";
      if(!CheckAntiPeakGuard(ORDER_TYPE_BUY, m_symbol.Ask(), peakBlock, isSniperSetup))
      {
         blockReason = peakBlock;
         return false;
      }
      string supBlock = "";
      if(!CheckSupplyZoneProximityGuard(ORDER_TYPE_BUY, m_symbol.Ask(), supBlock))
      {
         blockReason = supBlock;
         return false;
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      string btmBlock = "";
      if(!CheckAntiBottomGuard(ORDER_TYPE_SELL, m_symbol.Bid(), btmBlock, isSniperSetup))
      {
         blockReason = btmBlock;
         return false;
      }
      string dmdBlock = "";
      if(!CheckDemandZoneProximityGuard(ORDER_TYPE_SELL, m_symbol.Bid(), dmdBlock))
      {
         blockReason = dmdBlock;
         return false;
      }
   }

   // 1. ATR Impulse Over-Extension Filter (Active in Safe mode, relaxed for sniper setups)
   if(InpUseATRExtensionGuard && m_hATR != INVALID_HANDLE && !isSniperSetup)
   {
      double atrBuf[1];
      if(CopyBuffer(m_hATR, 0, 0, 1, atrBuf) > 0 && atrBuf[0] > 0)
      {
         double currentATR = atrBuf[0] / _Point;
         if(orderType == ORDER_TYPE_SELL && g_LastSwingHigh.price > 0)
         {
            double dropDistance = (g_LastSwingHigh.price - m_symbol.Bid()) / _Point;
            if(dropDistance > (currentATR * InpMaxImpulseATRFactor))
            {
               blockReason = StringFormat("🛑 IMPULSE OVER-EXTENDED (ทุบ %.0f pts > %.1fx ATR) - ห้าม Sell ปลายคลื่น 🛡️", dropDistance, InpMaxImpulseATRFactor);
               return false;
            }
         }
         else if(orderType == ORDER_TYPE_BUY && g_LastSwingLow.price > 0)
         {
            double pumpDistance = (m_symbol.Ask() - g_LastSwingLow.price) / _Point;
            if(pumpDistance > (currentATR * InpMaxImpulseATRFactor))
            {
               blockReason = StringFormat("🛑 IMPULSE OVER-EXTENDED (พุ่ง %.0f pts > %.1fx ATR) - ห้าม Buy ปลายคลื่น 🛡️", pumpDistance, InpMaxImpulseATRFactor);
               return false;
            }
         }
      }
   }

   // 3. HTF Macro Trend Conflict Filter (Adaptive to Active Chart TF)
   if(g_HTFMacroGuardActive && !isSniperSetup)
   {
      ENUM_TIMEFRAMES activeTF = GetCurrentExecutionTF();
      int activeRank = GetTFRank(activeTF);

      ENUM_TIMEFRAMES htf1 = PERIOD_H1;
      ENUM_TIMEFRAMES htf2 = PERIOD_H4;
      int hEMA_1 = m_hEMA_H1;
      int hEMA_2 = m_hEMA_H4;

      if(activeRank >= 7) // D1 or W1
      {
         htf1 = PERIOD_D1; htf2 = PERIOD_W1;
         hEMA_1 = m_hEMA_D1; hEMA_2 = m_hEMA_W1;
      }
      else if(activeRank == 6) // H4
      {
         htf1 = PERIOD_H4; htf2 = PERIOD_D1;
         hEMA_1 = m_hEMA_H4; hEMA_2 = m_hEMA_D1;
      }

      if(orderType == ORDER_TYPE_SELL)
      {
         if(hEMA_1 != INVALID_HANDLE && hEMA_2 != INVALID_HANDLE)
         {
            double ema1[1], ema2[1];
            MqlRates r1[], r2[];
            ArraySetAsSeries(r1, true); ArraySetAsSeries(r2, true);
            if(CopyRates(_Symbol, htf1, 0, 1, r1) > 0 && CopyBuffer(hEMA_1, 0, 0, 1, ema1) > 0 &&
               CopyRates(_Symbol, htf2, 0, 1, r2) > 0 && CopyBuffer(hEMA_2, 0, 0, 1, ema2) > 0)
            {
               if(r1[0].close >= ema1[0] && r2[0].close >= ema2[0])
               {
                  blockReason = StringFormat("🛑 HTF MACRO BULLISH (%s+%s ขาขึ้น) - ห้าม Sell สวนเทรนด์ใหญ่ 🛡️", EnumToString(htf1), EnumToString(htf2));
                  return false;
               }
            }
         }
      }
      else if(orderType == ORDER_TYPE_BUY)
      {
         if(hEMA_1 != INVALID_HANDLE && hEMA_2 != INVALID_HANDLE)
         {
            double ema1[1], ema2[1];
            MqlRates r1[], r2[];
            ArraySetAsSeries(r1, true); ArraySetAsSeries(r2, true);
            if(CopyRates(_Symbol, htf1, 0, 1, r1) > 0 && CopyBuffer(hEMA_1, 0, 0, 1, ema1) > 0 &&
               CopyRates(_Symbol, htf2, 0, 1, r2) > 0 && CopyBuffer(hEMA_2, 0, 0, 1, ema2) > 0)
            {
               if(r1[0].close <= ema1[0] && r2[0].close <= ema2[0])
               {
                  blockReason = StringFormat("🛑 HTF MACRO BEARISH (%s+%s ขาลง) - ห้าม Buy สวนเทรนด์ใหญ่ 🛡️", EnumToString(htf1), EnumToString(htf2));
                  return false;
               }
            }
         }
      }
   }

   // 4. Linear Regression Channel & Dual-Period Hybrid Filter
   if(InpEnableLRLChannel && g_LRLFilterActive && !isSniperSetup)
   {
      // A. Check against Higher TF (200 closed bars) Mother Trend
      if(orderType == ORDER_TYPE_SELL && g_LRL_HTF_Consensus == LRL_TREND_BULLISH)
      {
         blockReason = StringFormat("🛑 LRL HTF BULLISH (200 แท่ง θ=%.1f°) - ห้าม Sell สวนเทรนด์แม่ 🛡️", g_LRL_HTF_AvgAngle);
         return false;
      }
      else if(orderType == ORDER_TYPE_BUY && g_LRL_HTF_Consensus == LRL_TREND_BEARISH)
      {
         blockReason = StringFormat("🛑 LRL HTF BEARISH (200 แท่ง θ=%.1f°) - ห้าม Buy สวนเทรนด์แม่ 🛡️", g_LRL_HTF_AvgAngle);
         return false;
      }

      // B. Anti-Channel Overbought / Oversold Filter (100 closed bars on Chart)
      if(g_LRL_Chart.devUpper > 0 && g_LRL_Chart.devLower > 0)
      {
         if(orderType == ORDER_TYPE_BUY)
         {
            // Only block buy at the upper band if channel is flat/downward, or price has blown far past the top band
            if(m_symbol.Ask() >= (g_LRL_Chart.upperPrice - (20 * _Point)))
            {
               blockReason = "🛑 LRL UPPER BAND (ยอด Channel) - ห้าม Buy ปลายไส้ยอดดอย 🛡️";
               return false;
            }
         }
         else if(orderType == ORDER_TYPE_SELL)
         {
            // Only block sell at the lower band if channel is flat/upward, or price has blown far past the bottom band
            if(m_symbol.Bid() <= (g_LRL_Chart.lowerPrice + (20 * _Point)))
            {
               blockReason = "🛑 LRL LOWER BAND (ก้น Channel) - ห้าม Sell ปลายไส้ก้นเหว 🛡️";
               return false;
            }
         }
      }
   }

   // 5. Fibonacci Premium / Discount Zone Guard (Anti-Peak-Buy & Anti-Bottom-Sell)
   if(g_FiboGuardActive && g_TradeMode == TRADE_MODE_SAFE_COPILOT && !isSniperSetup)
   {
      double zoneTol = MathMax(30 * _Point, g_AssetProfile.beLock * _Point);
      if(orderType == ORDER_TYPE_SELL)
      {
         // In Bearish trend, SELL is valid on pullbacks (>= 23.6% retracement or retesting EMA/FVG).
         // ONLY block SELL if price is breaking out beneath the entire swing low without any pullback!
         double minSellPullbackLevel = (g_Fibo.p500 > 0) ? g_Fibo.p500 : ((g_LastSwingLow.price > 0) ? (g_LastSwingLow.price + zoneTol) : 0);
         if(minSellPullbackLevel > 0 && m_symbol.Bid() < (minSellPullbackLevel - zoneTol))
         {
            blockReason = StringFormat("🛑 FIBO EXTENDED LOW (%.2f < %.2f) - ห้าม Sell ไล่ราคาใต้สวิงโลว์ 🛡️", m_symbol.Bid(), minSellPullbackLevel);
            return false;
         }
      }
      else if(orderType == ORDER_TYPE_BUY)
      {
         // In Bullish trend, BUY is valid on pullbacks (<= 78.6% retracement or dipping to EMA/FVG).
         // ONLY block BUY if price is breaking out above the entire swing high without any pullback!
         double maxBuyPullbackLevel = (g_Fibo.p500 > 0) ? g_Fibo.p500 : ((g_LastSwingHigh.price > 0) ? (g_LastSwingHigh.price - zoneTol) : 0);
         if(maxBuyPullbackLevel > 0 && m_symbol.Ask() > (maxBuyPullbackLevel + zoneTol))
         {
            blockReason = StringFormat("🛑 FIBO EXTENDED HIGH (%.2f > %.2f) - ห้าม Buy ไล่ราคาเหนือสวิงไฮ 🛡️", m_symbol.Ask(), maxBuyPullbackLevel);
            return false;
         }
      }
   }

   // 6. ATH Macro Grid Anti-Peak / Anti-Bottom Guard
   string athBlock = "";
   double checkPrice = (orderType == ORDER_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();
   if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && !isSniperSetup && IsATHPeakGuardBlocked(orderType, checkPrice, athBlock))
   {
      blockReason = athBlock;
      return false;
   }

   // 7. HTF Precision Trend Guard (Samurai H1 Midline, Falling Knife & Single-TF H1 EMA50)
   string htfPrecBlock = "";
   if(!isSniperSetup && !CheckHTFPrecisionTrendGuard(orderType, htfPrecBlock))
   {
      blockReason = htfPrecBlock;
      return false;
   }

   // 8. VPA Volume Climax Guard (Anti-Blowoff Spike / Panic Reversal Shield)
   if(InpUseVPAClimaxGuard && !isSniperSetup)
   {
      MqlRates vRates[];
      ArraySetAsSeries(vRates, true);
      if(CopyRates(_Symbol, InpTimeframe, 0, 22, vRates) >= 22)
      {
         double sumV = 0;
         for(int vi = 1; vi <= 20; vi++)
            sumV += (double)vRates[vi].tick_volume;
         double avgV = sumV / 20.0;
         if(avgV > 0)
         {
            double curRatio  = (double)vRates[0].tick_volume / avgV;
            double prevRatio = (double)vRates[1].tick_volume / avgV;
            double maxRecentRatio = MathMax(curRatio, prevRatio);

            if(maxRecentRatio >= 2.8)
            {
               double climaxBuffer = MathMax(150.0, (double)g_AssetProfile.fallbackSL * 0.20) * _Point;
               if(orderType == ORDER_TYPE_BUY && g_LastSwingHigh.price > 0)
               {
                  if(m_symbol.Ask() >= (g_LastSwingHigh.price - climaxBuffer))
                  {
                     blockReason = StringFormat("🛑 VPA BUYING CLIMAX (Vol %.1fx) - ห้าม Buy ยอดดอยติดกับดักเจ้ามือ 🛡️", maxRecentRatio);
                     return false;
                  }
               }
               else if(orderType == ORDER_TYPE_SELL && g_LastSwingLow.price > 0)
               {
                  if(m_symbol.Bid() <= (g_LastSwingLow.price + climaxBuffer))
                  {
                     blockReason = StringFormat("🛑 VPA SELLING CLIMAX (Vol %.1fx) - ห้าม Sell ก้นเหวติดกับดักเจ้ามือ 🛡️", maxRecentRatio);
                     return false;
                  }
               }
            }
         }
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| 7.5 DIRECTIONAL BIAS & PROBABILITY WEIGHTING ENGINE (ข้อ 10)     |
//+------------------------------------------------------------------+
void CalculateMarketDirectionalBias()
{
   // 1. Dow Structure & Trend (20% max weight with Dynamic Wave Retracement Balancing)
   double buyDow = 0.0, sellDow = 0.0;
   double hVal = g_LastSwingHigh.price;
   double lVal = g_LastSwingLow.price;
   double rngVal = hVal - lVal;
   double cBid = m_symbol.Bid();
   double cAsk = m_symbol.Ask();
   double curPrice = (cBid + cAsk) / 2.0;

   if(g_MarketTrend == TREND_BULLISH)
   {
      // Check if price is at extreme peak of the wave (Impulse Exhaustion / Distribution zone)
      bool isAtPeakExtreme = (hVal > 0 && rngVal > 100 * _Point && (cBid >= hVal - (rngVal * 0.20) || g_LQ_Radar.bslSwept));
      bool isInDiscountZone = (lVal > 0 && rngVal > 100 * _Point && (cBid <= lVal + (rngVal * 0.50)));
      if(isAtPeakExtreme)
      {
         // Extreme Peak / BSL Swept: Buying impulse exhausted! Distribution favors SELL reversal!
         buyDow  = 3.0;
         sellDow = 17.0;
      }
      else if(isInDiscountZone)
      {
         // Deep Discount: Healthy pullback for Bullish continuation!
         buyDow  = 18.0;
         sellDow = 2.0;
      }
      else
      {
         // Upper Retracement: Healthy retracement phase, not yet in deep discount
         buyDow  = 11.0;
         sellDow = 9.0;
      }
   }
   else if(g_MarketTrend == TREND_BEARISH)
   {
      // Check if price is at extreme trough of the wave (Impulse Exhaustion / Accumulation zone)
      bool isAtBottomExtreme = (lVal > 0 && rngVal > 100 * _Point && (cAsk <= lVal + (rngVal * 0.20) || g_LQ_Radar.sslSwept));
      bool isInPremiumZone  = (hVal > 0 && rngVal > 100 * _Point && (cAsk >= hVal - (rngVal * 0.50)));
      if(isAtBottomExtreme)
      {
         // Extreme Bottom / SSL Swept: Selling impulse exhausted! Accumulation favors BUY reversal!
         buyDow  = 17.0;
         sellDow = 3.0;
      }
      else if(isInPremiumZone)
      {
         // Deep Premium: Healthy rebound for Bearish continuation!
         buyDow  = 2.0;
         sellDow = 18.0;
      }
      else
      {
         // Lower Retracement
         buyDow  = 9.0;
         sellDow = 11.0;
      }
   }
   else
   {
      if(g_BOS_Confirmed && g_StructEvent == STRUCT_BULLISH_BOS)
      {
         buyDow  = 16.0;
         sellDow = 4.0;
      }
      else if(g_BOS_Confirmed && g_StructEvent == STRUCT_BEARISH_BOS)
      {
         buyDow  = 4.0;
         sellDow = 16.0;
      }
      else
      {
         buyDow  = 10.0;
         sellDow = 10.0;
      }
   }

   // 2. Intermediate EMA 50/200 Trend Regime & Cross State (15% max weight)
   double buyEMA = 7.5, sellEMA = 7.5;
   if(m_hEMA != INVALID_HANDLE && m_hEMA200 != INVALID_HANDLE)
   {
      double ema50[1], ema200[1];
      if(CopyBuffer(m_hEMA, 0, 0, 1, ema50) > 0 && CopyBuffer(m_hEMA200, 0, 0, 1, ema200) > 0)
      {
         if(ema50[0] > ema200[0]) // Golden Cross Regime
         {
            if(curPrice >= ema50[0])
            {
               buyEMA  = 15.0;
               sellEMA = 0.0;
            }
            else
            {
               buyEMA  = 10.0;
               sellEMA = 5.0;
            }
         }
         else if(ema50[0] < ema200[0]) // Death Cross Regime
         {
            if(curPrice <= ema50[0])
            {
               buyEMA  = 0.0;
               sellEMA = 15.0;
            }
            else
            {
               buyEMA  = 5.0;
               sellEMA = 10.0;
            }
         }
      }
   }

   // 3. Hierarchical Multi-Timeframe Alignment (15% max weight)
   double mtfRatio = (double)g_MTF_BullPct / 100.0;
   if(mtfRatio < 0.0) mtfRatio = 0.5;
   if(mtfRatio > 1.0) mtfRatio = 0.5;
   double buyMTF  = mtfRatio * 15.0;
   double sellMTF = (1.0 - mtfRatio) * 15.0;

   // 4. Smart Money Concepts (SMC) & Liquidity Radar (20% max weight)
   double buySMC = 10.0, sellSMC = 10.0;
   if(InpUseICT_Unicorn && g_Unicorn_Setup.isActive)
   {
      if(g_Unicorn_Setup.state == UNICORN_BULLISH)
      {
         buySMC  = 18.0;
         sellSMC = 2.0;
      }
      else if(g_Unicorn_Setup.state == UNICORN_BEARISH)
      {
         buySMC  = 2.0;
         sellSMC = 18.0;
      }
   }
   else if(InpUseCRT_TurtleSoup && g_CRT_Setup.isActive)
   {
      if(g_CRT_Setup.state == CRT_BULLISH_SWEEP)
      {
         buySMC  = 18.0;
         sellSMC = 2.0;
      }
      else if(g_CRT_Setup.state == CRT_BEARISH_SWEEP)
      {
         buySMC  = 2.0;
         sellSMC = 18.0;
      }
   }
   else if(InpUseAsianRangeJudas && (g_JudasBuyActive || g_JudasSellActive))
   {
      if(g_JudasBuyActive)
      {
         buySMC  = 18.0;
         sellSMC = 2.0;
      }
      else
      {
         buySMC  = 2.0;
         sellSMC = 18.0;
      }
   }
   else if(g_LQ_Radar.sslSwept && !g_LQ_Radar.bslSwept)
   {
      // SSL Swept: Purged buyers' SL below -> Smart Money accumulation!
      buySMC  = 18.0;
      sellSMC = 2.0;
   }
   else if(g_LQ_Radar.bslSwept && !g_LQ_Radar.sslSwept)
   {
      // BSL Swept: Purged sellers' SL above -> Smart Money distribution!
      buySMC  = 2.0;
      sellSMC = 18.0;
   }
   else if(g_LQ_Radar.ssl.isValid && g_LQ_Radar.bsl.isValid)
   {
      double totalDist = g_LQ_Radar.ssl.distancePts + g_LQ_Radar.bsl.distancePts;
      if(totalDist > 0.0)
      {
         // Closer to SSL (discount/demand) -> higher buy score
         double buyRatio = g_LQ_Radar.bsl.distancePts / totalDist;
         buySMC  = buyRatio * 20.0;
         sellSMC = (1.0 - buyRatio) * 20.0;
      }
   }

   // 5. Wyckoff Phase, VPA Volume & Classical Patterns (10% max weight)
   double buyWyckoff = 5.0, sellWyckoff = 5.0;
   if(g_ExhaustionActive && StringFind(g_ExhaustionGuardMsg, "BUYING CLIMAX") >= 0)
   {
      buyWyckoff  = 1.0;
      sellWyckoff = 9.0;
   }
   else if(g_ExhaustionActive && StringFind(g_ExhaustionGuardMsg, "SELLING CLIMAX") >= 0)
   {
      buyWyckoff  = 9.0;
      sellWyckoff = 1.0;
   }
   else if(g_DetectedPattern == PA_BEARISH_PINBAR || g_DetectedPattern == PA_BEARISH_ENGULFING ||
           g_DetectedPattern == PA_EVENING_STAR || g_DetectedPattern == PA_DARK_CLOUD_COVER ||
           g_DetectedPattern == PA_THREE_BLACK_CROWS || g_DetectedPattern == PA_DOUBLE_TOP ||
           g_DetectedPattern == PA_TRIPLE_TOP || g_DetectedPattern == PA_HEAD_SHOULDERS)
   {
      buyWyckoff  = 0.0;
      sellWyckoff = 10.0;
   }
   else if(g_DetectedPattern == PA_BULLISH_PINBAR || g_DetectedPattern == PA_BULLISH_ENGULFING ||
           g_DetectedPattern == PA_MORNING_STAR || g_DetectedPattern == PA_PIERCING_LINE ||
           g_DetectedPattern == PA_THREE_WHITE_SOLDIERS || g_DetectedPattern == PA_DOUBLE_BOTTOM ||
           g_DetectedPattern == PA_TRIPLE_BOTTOM || g_DetectedPattern == PA_INVERTED_HEAD_SHOULDERS)
   {
      buyWyckoff  = 10.0;
      sellWyckoff = 0.0;
   }
   else if(g_PullbackArmed || g_Fibo.isInsideZone)
   {
      if(g_MarketTrend == TREND_BULLISH)
      {
         buyWyckoff  = 8.0;
         sellWyckoff = 2.0;
      }
      else if(g_MarketTrend == TREND_BEARISH)
      {
         buyWyckoff  = 2.0;
         sellWyckoff = 8.0;
      }
   }

   // 6. Samurai Extreme Wick Linear Regression Channel (LRL) (10% max weight)
   double buyLRL = 5.0, sellLRL = 5.0;
   if(InpEnableLRLChannel && g_LRL_Chart.medianPrice > 0)
   {
      double curBid = m_symbol.Bid();
      double halfWidth = MathMax(_Point, (g_LRL_Chart.upperPrice - g_LRL_Chart.lowerPrice) / 2.0);
      double posNorm = (curBid - g_LRL_Chart.medianPrice) / halfWidth;
      posNorm = MathMax(-1.0, MathMin(1.0, posNorm));

      // Check D1 Macro Slope to prevent fighting dominant macro slope
      double macroPenaltyBuy = (g_LRL_HTF_Consensus == LRL_TREND_BEARISH) ? 2.5 : 0.0;
      double macroPenaltySell = (g_LRL_HTF_Consensus == LRL_TREND_BULLISH) ? 2.5 : 0.0;

      if(g_LRL_Chart.angle > 15.0)
      {
         if(posNorm <= 0.0) { buyLRL = 10.0 - macroPenaltyBuy;  sellLRL = 0.0 + macroPenaltyBuy; }
         else               { buyLRL = 7.0 - macroPenaltyBuy;   sellLRL = 3.0 + macroPenaltyBuy; }
      }
      else if(g_LRL_Chart.angle < -15.0)
      {
         if(posNorm >= 0.0) { buyLRL = 0.0 + macroPenaltySell;  sellLRL = 10.0 - macroPenaltySell; }
         else               { buyLRL = 3.0 + macroPenaltySell;  sellLRL = 7.0 - macroPenaltySell;  }
      }
      else
      {
         if(posNorm <= -0.5)      { buyLRL = 8.0 - macroPenaltyBuy;  sellLRL = 2.0 + macroPenaltyBuy; }
         else if(posNorm >= 0.5) { buyLRL = 2.0 + macroPenaltySell; sellLRL = 8.0 - macroPenaltySell; }
         else                    { buyLRL = 5.0 - macroPenaltyBuy + macroPenaltySell; sellLRL = 5.0 + macroPenaltyBuy - macroPenaltySell; }
      }
      buyLRL  = MathMax(0.0, MathMin(10.0, buyLRL));
      sellLRL = MathMax(0.0, MathMin(10.0, sellLRL));
   }

   // 7. Momentum & Candlestick Trigger (Pure Price Action & Rejection Flow) (10% max weight)
   double buyMom = 5.0, sellMom = 5.0;
   if(g_PABuyTrigger && !g_PASellTrigger)
   {
      buyMom  = 10.0;
      sellMom = 0.0;
   }
   else if(g_PASellTrigger && !g_PABuyTrigger)
   {
      buyMom  = 0.0;
      sellMom = 10.0;
   }
   else
   {
      MqlRates bRates[];
      ArraySetAsSeries(bRates, true);
      if(CopyRates(_Symbol, InpTimeframe, 0, 1, bRates) > 0)
      {
         double cRange = bRates[0].high - bRates[0].low;
         if(cRange > 0)
         {
            double buyRatio = (bRates[0].close - bRates[0].low) / cRange;
            buyMom  = buyRatio * 10.0;
            sellMom = (1.0 - buyRatio) * 10.0;
         }
      }
   }

   // Sum and normalize across all 7 institutional pillars to 100%
   double totalBuy   = buyDow + buyEMA + buyMTF + buySMC + buyWyckoff + buyLRL + buyMom;
   double totalSell  = sellDow + sellEMA + sellMTF + sellSMC + sellWyckoff + sellLRL + sellMom;
   double grandTotal = totalBuy + totalSell;

   if(grandTotal > 0.0)
   {
      g_MarketBiasBuyPct = (int)MathRound((totalBuy / grandTotal) * 100.0);
      g_MarketBiasBuyPct = MathMax(0, MathMin(100, g_MarketBiasBuyPct));
      g_MarketBiasSellPct = 100 - g_MarketBiasBuyPct;
   }
   else
   {
      g_MarketBiasBuyPct  = 50;
      g_MarketBiasSellPct = 50;
   }

   // Action Advice Formulation (Unified, Harmonized & Anti-Contradiction)
   if(g_ExhaustionActive)
   {
      if(g_MarketBiasBuyPct >= 55)
      {
         g_MarketBiasAdvice    = "⚠️ ชะลอ BUY • ระวังแรงทุบ รอแท่งกลับตัวคอนเฟิร์ม";
         g_MarketBiasAdviceCol = clrOrange;
      }
      else if(g_MarketBiasSellPct >= 55)
      {
         g_MarketBiasAdvice    = "⚠️ ชะลอ SELL • ระวังแรงดีด รอแท่งกลับตัวคอนเฟิร์ม";
         g_MarketBiasAdviceCol = clrOrange;
      }
      else
      {
         g_MarketBiasAdvice    = "⚠️ พักการเข้าเทรด • สภาวะคลื่นตึงตัว (Exhaustion)";
         g_MarketBiasAdviceCol = clrGold;
      }
   }
   else if(g_MarketBiasBuyPct >= 70)
   {
      g_MarketBiasAdvice    = "🟢 BUY ได้เปรียบสูง (เน้นดักย่อ BUY ในโซน Discount)";
      g_MarketBiasAdviceCol = clrLime;
   }
   else if(g_MarketBiasBuyPct >= 58)
   {
      g_MarketBiasAdvice    = "🟢 BUY ได้เปรียบ (รอจังหวะย่อ BUY)";
      g_MarketBiasAdviceCol = clrPaleGreen;
   }
   else if(g_MarketBiasSellPct >= 70)
   {
      g_MarketBiasAdvice    = "🔴 SELL ได้เปรียบสูง (เน้นดักเด้ง SELL ในโซน Premium)";
      g_MarketBiasAdviceCol = clrTomato;
   }
   else if(g_MarketBiasSellPct >= 58)
   {
      g_MarketBiasAdvice    = "🔴 SELL ได้เปรียบ (รอจังหวะเด้ง SELL)";
      g_MarketBiasAdviceCol = clrLightCoral;
   }
   else
   {
      g_MarketBiasAdvice    = "🟡 ไซด์เวย์ 50:50 (พักมือ • รอเลือกข้าง)";
      g_MarketBiasAdviceCol = clrGold;
   }
}

//+------------------------------------------------------------------+
//| 7.9 BOT STATE FINALIZER (GUARANTEES RISK DISCIPLINE & GATING)   |
//+------------------------------------------------------------------+
void FinalizeBotState(int openCount)
{
   if(g_DailyTargetReached)
      g_BotState = STATE_DAILY_TARGET_HIT;
   else if(g_DailyMaxLossReached)
      g_BotState = STATE_DAILY_LOSS_HIT;
   else if((!g_AllowMultiPos && openCount > 0) || openCount >= InpMaxOpenPos)
      g_BotState = STATE_IN_POSITION;

   UpdateSmartActionCommand(openCount);
}

//+------------------------------------------------------------------+
//| 8. BOT STATE EVALUATION & TRADE PLAN CALCULATION                 |
//+------------------------------------------------------------------+
void EvaluateBotStateAndPlan()
{
   int openCount = CountOpenPositions(InpManageManualTrades);

   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();

   // Anti-Reentry Cooldown: Neutralized in V8.00 per Master Plan (Fluid Trend & Liquidity Reversal Continuation)
   g_PostCloseCooldownRemainSec = 0;

   // 0. Active Position Synchronization Engine (Ensures Card 2 & Chart Lines 100% Match Open Trade)
   if(openCount > 0)
   {
      ulong              activeTicket    = 0;
      ENUM_POSITION_TYPE activeType      = POSITION_TYPE_BUY;
      double             activeOpenPrice = 0;
      double             activeSL        = 0;
      double             activeTP        = 0;
      double             activeVol       = 0;
      double             activeProfit    = 0;
      double             weightedOpenPrice = 0.0;
      double             totalVol = 0.0;

      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong t = PositionGetTicket(i);
         if(t > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            long m = PositionGetInteger(POSITION_MAGIC);
            if(m == InpMagicNumber || (InpManageManualTrades && m == 0))
            {
               if(activeTicket == 0)
               {
                  activeTicket = t;
                  activeType   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                  activeSL     = PositionGetDouble(POSITION_SL);
                  activeTP     = PositionGetDouble(POSITION_TP);
               }
               double v = PositionGetDouble(POSITION_VOLUME);
               double p = PositionGetDouble(POSITION_PRICE_OPEN);
               weightedOpenPrice += (p * v);
               totalVol += v;
            }
         }
      }

      if(totalVol > 0)
         activeOpenPrice = weightedOpenPrice / totalVol;

      if(activeTicket > 0)
      {
         g_PlanDirection = (activeType == POSITION_TYPE_BUY) ? 1 : -1;
         g_PlanSource    = (activeType == POSITION_TYPE_BUY) ? "ACTIVE_BUY" : "ACTIVE_SELL";
         g_PlanEntry     = activeOpenPrice;
         g_PlanSL        = activeSL;

         int tfSLPts = 0, tfTP1Pts = 0, tfTP2Pts = 0, tfTP3Pts = 0;
         GetTimeframeAdaptiveSLTP(InpTimeframe, tfSLPts, tfTP1Pts, tfTP2Pts, tfTP3Pts);

         if(activeType == POSITION_TYPE_BUY)
         {
            g_PlanTP1 = activeOpenPrice + (tfTP1Pts * _Point);
            g_PlanTP2 = activeOpenPrice + (tfTP2Pts * _Point);
            g_PlanTP3 = activeOpenPrice + (tfTP3Pts * _Point);
         }
         else
         {
            g_PlanTP1 = activeOpenPrice - (tfTP1Pts * _Point);
            g_PlanTP2 = activeOpenPrice - (tfTP2Pts * _Point);
            g_PlanTP3 = activeOpenPrice - (tfTP3Pts * _Point);
         }
         g_PlanTP = (activeTP > 0) ? activeTP : g_PlanTP2;

         double riskPts = (activeSL > 0) ? MathAbs(activeOpenPrice - activeSL) / _Point : (double)tfSLPts;
         if(riskPts > 0)
         {
            g_PlanRR1 = MathAbs(g_PlanTP1 - activeOpenPrice) / (_Point * riskPts);
            g_PlanRR2 = MathAbs(g_PlanTP2 - activeOpenPrice) / (_Point * riskPts);
            g_PlanRR3 = MathAbs(g_PlanTP3 - activeOpenPrice) / (_Point * riskPts);
            g_PlanRR  = g_PlanRR2;
         }

         if(!g_AllowMultiPos || openCount >= InpMaxOpenPos)
         {
            g_BotState = STATE_IN_POSITION;
            FinalizeBotState(openCount);
            return;
         }
      }
   }

   g_ReversalArmedPendingConfirm = false;
   g_ReversalPendingDir          = 0;
   g_ReversalPendingReason       = "";

   // 0.1 HTF Zone Candlestick Reversal Signal Priority Trigger (Institutional Setup)
   if((InpEnableHTFReversalSniper || g_AutoSniperActive) && g_HTFReversal.isValid)
   {
      // Invalidation: if price already surged past TP1, do not chase entry!
      if((g_HTFReversal.direction == 1 && ask >= g_HTFReversal.tp1Price) ||
         (g_HTFReversal.direction == -1 && bid <= g_HTFReversal.tp1Price))
      {
         g_HTFReversal.isValid = false;
      }
      else
      {
         g_PlanDirection = g_HTFReversal.direction;
         g_PlanSource    = "HTF_REVERSAL";
         g_PlanEntry = g_HTFReversal.entryPrice;
         g_PlanSL    = g_HTFReversal.slPrice;
         g_PlanTP1   = g_HTFReversal.tp1Price;
         g_PlanTP2   = g_HTFReversal.tp2Price;
         g_PlanTP3   = g_HTFReversal.tp3Price;
         g_PlanTP    = g_HTFReversal.tpPrice;
         double riskPts = MathAbs(g_PlanEntry - g_PlanSL) / _Point;
         if(riskPts > 0)
         {
            g_PlanRR1 = MathAbs(g_PlanTP1 - g_PlanEntry) / (_Point * riskPts);
            g_PlanRR2 = MathAbs(g_PlanTP2 - g_PlanEntry) / (_Point * riskPts);
            g_PlanRR3 = MathAbs(g_PlanTP3 - g_PlanEntry) / (_Point * riskPts);
            g_PlanRR  = g_PlanRR2;
         }
         g_BotState = STATE_TRIGGER_READY;
         FinalizeBotState(openCount);
         return;
      }
   }

   // 0.1 Spike Sniper Priority Trigger for HUD Display & Trade Plan
   bool canUseSpikeAsPlan = false;
   if((InpEnableSpikeSniper || g_AutoSniperActive) && g_SpikeSignal.isValid)
   {
      // Real-time Invalidation: if price breached Pinbar SL or already reached TP, clear signal
      if((g_SpikeSignal.direction == 1 && (bid <= g_SpikeSignal.slPrice || ask >= g_SpikeSignal.tpPrice)) ||
         (g_SpikeSignal.direction == -1 && (ask >= g_SpikeSignal.slPrice || bid <= g_SpikeSignal.tpPrice)))
      {
         g_SpikeSignal.isValid = false;
      }
      else if(openCount == 0)
      {
         if(g_TradeMode == TRADE_MODE_AGGRESSIVE_SNIPER)
         {
            canUseSpikeAsPlan = true;
         }
         else // TRADE_MODE_SAFE_COPILOT
         {
            // In SAFE mode, adopt spike if aligned with market trend, sideway, or at structural reversal extremes (BSL/SSL Swept)
            if((g_SpikeSignal.direction == 1 && (g_MarketTrend == TREND_BULLISH || g_LQ_Radar.sslSwept)) ||
               (g_SpikeSignal.direction == -1 && (g_MarketTrend == TREND_BEARISH || g_LQ_Radar.bslSwept)) ||
               (g_MarketTrend == TREND_SIDEWAY))
            {
               canUseSpikeAsPlan = true;
            }
         }
      }
   }

   if(canUseSpikeAsPlan)
   {
      g_PlanDirection = g_SpikeSignal.direction;
      g_PlanSource    = "SPIKE";
      g_PlanEntry     = g_SpikeSignal.entryPrice;
      g_PlanSL        = g_SpikeSignal.slPrice;
      
      double riskPts = MathAbs(g_PlanEntry - g_PlanSL) / _Point;
      if(riskPts > 0)
      {
         if(g_PlanDirection == 1)
         {
            g_PlanTP1 = g_PlanEntry + (riskPts * 1.0 * _Point);
            g_PlanTP2 = g_PlanEntry + (riskPts * 1.618 * _Point);
            g_PlanTP3 = g_PlanEntry + (riskPts * 2.618 * _Point);
         }
         else
         {
            g_PlanTP1 = g_PlanEntry - (riskPts * 1.0 * _Point);
            g_PlanTP2 = g_PlanEntry - (riskPts * 1.618 * _Point);
            g_PlanTP3 = g_PlanEntry - (riskPts * 2.618 * _Point);
         }
         g_PlanTP  = g_PlanTP2;
         g_PlanRR1 = 1.0;
         g_PlanRR2 = 1.6;
         g_PlanRR3 = 2.6;
         g_PlanRR  = 1.6;
      }
      else
      {
         g_PlanTP  = g_SpikeSignal.tpPrice;
         g_PlanTP1 = g_SpikeSignal.tpPrice;
         g_PlanTP2 = g_SpikeSignal.tpPrice;
         g_PlanTP3 = g_SpikeSignal.tpPrice;
      }
      g_BotState = STATE_TRIGGER_READY;
      FinalizeBotState(openCount);
      return;
   }

   // 0.15 Institutional Peak / Valley Candlestick Reversal Plan (Instant Sell at High / Buy at Low)
   if(openCount == 0 && ((g_LastSwingHigh.price > 0 && g_LastSwingLow.price > 0) || g_ZScoreExtremePeak || g_ZScoreExtremeValley || g_CME_NearCallWall || g_CME_NearMegaCallWall || g_CME_NearIntermedCall || g_CME_NearPutWall || g_CME_NearMacroPutWall || g_CME_NearIntermedPut || g_LQ_Radar.bslSwept || g_LQ_Radar.sslSwept || InpEnableLRLChannel))
   {
      double swingRng = (g_LastSwingHigh.price > g_LastSwingLow.price) ? (g_LastSwingHigh.price - g_LastSwingLow.price) : 0;
      MqlRates revRates[];
      ArraySetAsSeries(revRates, true);
      int copiedRev = CopyRates(_Symbol, InpTimeframe, 0, 5, revRates);

      // A. Peak Reversal SELL Plan: Price near peak, BSL swept, Z >= +2.0 SD, CME Call Wall, Anti-Peak Guard, or LRL Upper Band + Bearish PA rejection
      bool isGoldAsset = (g_AssetProfile.assetType == ASSET_GOLD);
      string peakBlockReason = "";
      bool isAntiPeakBlocked = !CheckAntiPeakGuard(ORDER_TYPE_BUY, ask, peakBlockReason);
      bool isNearLRLUpper = (InpEnableLRLChannel && g_LRL_Chart.upperPrice > 0 && bid >= g_LRL_Chart.upperPrice - (50 * _Point));
      bool isNearCallWall = (isGoldAsset && (g_CME_NearCallWall || g_CME_NearMegaCallWall || g_CME_NearIntermedCall));
      bool isNearPeak = (swingRng > 100 * _Point && bid >= g_LastSwingHigh.price - (swingRng * 0.25)) || 
                        g_LQ_Radar.bslSwept || g_ZScoreExtremePeak || isNearCallWall || isAntiPeakBlocked || isNearLRLUpper;
      
      // In a Bullish Trend, breaking above swing high is an Impulse Breakout / Wave 3 expansion!
      // Strictly do NOT counter-trend fade the breakout unless an actual BSL sweep or HTF Supply rejection is confirmed!
      if(g_MarketTrend == TREND_BULLISH && !g_LQ_Radar.bslSwept && !(g_HTFReversal.isValid && g_HTFReversal.direction == -1) && !isNearCallWall)
      {
         isNearPeak = false;
      }

      bool isBullishPA_Active = (g_DetectedPattern == PA_BULLISH_ENGULFING || 
                                 g_DetectedPattern == PA_BULLISH_PINBAR || 
                                 g_DetectedPattern == PA_MORNING_STAR || 
                                 g_DetectedPattern == PA_PIERCING_LINE || 
                                 g_DetectedPattern == PA_THREE_WHITE_SOLDIERS || 
                                 g_PABuyTrigger);

      bool isBearishPA = (!isBullishPA_Active) && 
                         (g_DetectedPattern == PA_BEARISH_PINBAR || g_DetectedPattern == PA_BEARISH_ENGULFING || 
                          g_DetectedPattern == PA_EVENING_STAR || g_PASellTrigger || g_JudasSellActive ||
                          (g_HTFReversal.isValid && g_HTFReversal.direction == -1));

      if(isNearPeak && isBearishPA && copiedRev >= 3)
      {
         // 🛡️ Safe Mode True Reversal Confirmation Engine
         bool isConfirmedSell = true;
         if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && InpSafeRequireReversalConfirm)
         {
            // 1. Anti-Momentum Spike: Live bar is not expanding aggressively upward into the resistance
            bool isBullExpansion = (revRates[0].close > revRates[0].open && (revRates[0].close - revRates[0].open) >= (50 * _Point));
            
            // 2. Follow-Through Breakdown:
            // Either live price has traded below setup candle's low (break of rejection low),
            // OR live candle is red and trading below setup candle's close with bearish pressure
            bool isFollowThrough = (bid < revRates[1].low) || 
                                   (revRates[0].close < revRates[0].open && bid <= (revRates[1].close - (15 * _Point)));

            // 3. CME Wall Caution Engine:
            if(isNearCallWall && InpCME_WallCautionEngine)
            {
               if(isBullExpansion || !isFollowThrough)
                  isConfirmedSell = false;
            }
            else
            {
               if(isBullExpansion || !isFollowThrough)
                  isConfirmedSell = false;
            }
         }

         if(!isConfirmedSell)
         {
            // Do NOT overwrite g_PlanDirection with -1 while unconfirmed!
            // Only flag pending alert, but keep the underlying trend plan intact on Card 2.
            g_BotState = STATE_PULLBACK_ARMED;
            g_PullbackArmed = true;
            g_ReversalArmedPendingConfirm = true;
            g_ReversalPendingDir = -1;
            if(isNearCallWall)
               g_ReversalPendingReason = "จ่อ CME Call Wall • รอคอนเฟิร์มกลับตัว ⏳";
            else
               g_ReversalPendingReason = StringFormat("ดักยอด Peak Reversal • รอหลุด Low [%.2f] ⏳", revRates[1].low);
            FinalizeBotState(openCount);
            return;
         }

         g_PlanDirection = -1;
         g_PlanSource    = "REVERSAL";
         g_PlanEntry     = bid;
         double atrBuf   = g_AssetProfile.beLock * _Point;
         double effectiveCallWall = (isGoldAsset && InpUseCMEWallGuard && g_CME_NearMegaCallWall && InpCME_MegaCallWall > 0) ? InpCME_MegaCallWall : 
                                    ((isGoldAsset && InpUseCMEWallGuard && g_CME_NearCallWall && InpCME_CallWall > 0) ? InpCME_CallWall : 
                                    ((isGoldAsset && InpUseCMEWallGuard && g_CME_NearIntermedCall && InpCME_IntermediateCall > 0) ? InpCME_IntermediateCall : 0));
         double refHigh  = MathMax(g_LastSwingHigh.price, (isGoldAsset && InpUseCMEWallGuard && effectiveCallWall > 0) ? effectiveCallWall : bid);
         g_PlanSL        = MathMax(refHigh + MathMax(atrBuf, 30 * _Point), bid + (250 * _Point));
         double riskPts  = (g_PlanSL - g_PlanEntry) / _Point;

         double minSafeSLPts = 250.0, maxAllowedSLPts = 777.0;
         GetDynamicSLBounds(minSafeSLPts, maxAllowedSLPts);
         if(riskPts > maxAllowedSLPts) { g_PlanSL = g_PlanEntry + (maxAllowedSLPts * _Point); riskPts = maxAllowedSLPts; }
         else if(riskPts < minSafeSLPts) { g_PlanSL = g_PlanEntry + (minSafeSLPts * _Point); riskPts = minSafeSLPts; }

         double eqLvl = (g_Fibo.p500 > 0 && g_Fibo.p500 < g_PlanEntry) ? g_Fibo.p500 : (g_PlanEntry - (riskPts * 2.5 * _Point));
         g_PlanTP1 = g_PlanEntry - (riskPts * 1.5 * _Point);
         g_PlanTP2 = (eqLvl < g_PlanEntry) ? eqLvl : g_PlanEntry - (riskPts * 2.5 * _Point);
         double effectivePutTarget = (isGoldAsset && InpUseCMEWallGuard && InpCME_IntermediatePut > 0 && InpCME_IntermediatePut < g_PlanEntry) ? InpCME_IntermediatePut : 
                                     ((isGoldAsset && InpUseCMEWallGuard && InpCME_PutWall > 0 && InpCME_PutWall < g_PlanEntry) ? InpCME_PutWall : 
                                     ((isGoldAsset && InpUseCMEWallGuard && InpCME_MacroPutWall > 0 && InpCME_MacroPutWall < g_PlanEntry) ? InpCME_MacroPutWall : 0));
         g_PlanTP3 = (isGoldAsset && InpUseCMEWallGuard && effectivePutTarget > 0) ? effectivePutTarget : ((g_LastSwingLow.price > 0 && g_LastSwingLow.price < g_PlanEntry) ? g_LastSwingLow.price : g_PlanEntry - (riskPts * 4.0 * _Point));
         g_PlanTP  = g_PlanTP2;
         g_PlanRR1 = 1.5; g_PlanRR2 = 2.5; g_PlanRR3 = 4.0; g_PlanRR = 2.5;

         g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
         g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);
         g_PlanTP1   = NormalizeDouble(g_PlanTP1, _Digits);
         g_PlanTP2   = NormalizeDouble(g_PlanTP2, _Digits);
         g_PlanTP3   = NormalizeDouble(g_PlanTP3, _Digits);
         g_PlanTP    = NormalizeDouble(g_PlanTP, _Digits);

         g_ReversalArmedPendingConfirm = false;
         g_ReversalPendingDir = 0;
         g_ReversalPendingReason = "";
         g_BotState = STATE_TRIGGER_READY;
         FinalizeBotState(openCount);
         return;
      }

      // B. Valley Reversal BUY Plan: Price near valley, SSL swept, Z <= -2.0 SD, CME Put Wall, Anti-Bottom Guard, or LRL Lower Band + Bullish PA rejection
      string btmBlockReason = "";
      bool isAntiBottomBlocked = !CheckAntiBottomGuard(ORDER_TYPE_SELL, bid, btmBlockReason);
      bool isNearLRLLower = (InpEnableLRLChannel && g_LRL_Chart.lowerPrice > 0 && ask <= g_LRL_Chart.lowerPrice + (50 * _Point));
      bool isNearPutWall = (isGoldAsset && (g_CME_NearPutWall || g_CME_NearMacroPutWall || g_CME_NearIntermedPut));
      bool isNearValley = (swingRng > 100 * _Point && ask <= g_LastSwingLow.price + (swingRng * 0.25)) || 
                          g_LQ_Radar.sslSwept || g_ZScoreExtremeValley || isNearPutWall || isAntiBottomBlocked || isNearLRLLower;
      
      // In a Bearish Trend, breaking below swing low is an Impulse Dump / Wave 3 expansion!
      // Strictly do NOT counter-trend catch falling knives unless SSL sweep or HTF Demand rejection!
      if(g_MarketTrend == TREND_BEARISH && !g_LQ_Radar.sslSwept && !(g_HTFReversal.isValid && g_HTFReversal.direction == 1) && !isNearPutWall)
      {
         isNearValley = false;
      }

      bool isBearishPA_Active = (g_DetectedPattern == PA_BEARISH_ENGULFING || 
                                 g_DetectedPattern == PA_BEARISH_PINBAR || 
                                 g_DetectedPattern == PA_EVENING_STAR || 
                                 g_DetectedPattern == PA_DARK_CLOUD_COVER || 
                                 g_DetectedPattern == PA_THREE_BLACK_CROWS || 
                                 g_PASellTrigger);

      bool isBullishPA  = (!isBearishPA_Active) && 
                          (g_DetectedPattern == PA_BULLISH_PINBAR || g_DetectedPattern == PA_BULLISH_ENGULFING || 
                           g_DetectedPattern == PA_MORNING_STAR || g_PABuyTrigger || g_JudasBuyActive ||
                           (g_HTFReversal.isValid && g_HTFReversal.direction == 1));

      if(isNearValley && isBullishPA && copiedRev >= 3)
      {
         // 🛡️ Safe Mode True Reversal Confirmation Engine
         bool isConfirmedBuy = true;
         if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && InpSafeRequireReversalConfirm)
         {
            // 1. Anti-Momentum Spike: Live bar is not dumping aggressively downward into the support
            bool isBearExpansion = (revRates[0].close < revRates[0].open && (revRates[0].open - revRates[0].close) >= (50 * _Point));
            
            // 2. Follow-Through Breakdown:
            // Either live price has traded above setup candle's high (break of rejection high),
            // OR live candle is green and trading above setup candle's close with bullish pressure
            bool isFollowThrough = (ask > revRates[1].high) || 
                                   (revRates[0].close > revRates[0].open && ask >= (revRates[1].close + (15 * _Point)));

            // 3. CME Wall Caution Engine:
            if(isNearPutWall && InpCME_WallCautionEngine)
            {
               if(isBearExpansion || !isFollowThrough)
                  isConfirmedBuy = false;
            }
            else
            {
               if(isBearExpansion || !isFollowThrough)
                  isConfirmedBuy = false;
            }
         }

         if(!isConfirmedBuy)
         {
            // Do NOT overwrite g_PlanDirection with 1 while unconfirmed!
            g_BotState = STATE_PULLBACK_ARMED;
            g_PullbackArmed = true;
            g_ReversalArmedPendingConfirm = true;
            g_ReversalPendingDir = 1;
            if(isNearPutWall)
               g_ReversalPendingReason = "จ่อ CME Put Wall • รอคอนเฟิร์มกลับตัว ⏳";
            else
               g_ReversalPendingReason = StringFormat("ดักก้น Valley Reversal • รอเบรก High [%.2f] ⏳", revRates[1].high);
            FinalizeBotState(openCount);
            return;
         }

         g_PlanDirection = 1;
         g_PlanSource    = "REVERSAL";
         g_PlanEntry     = ask;
         double atrBuf   = g_AssetProfile.beLock * _Point;
         double effectivePutWall = (isGoldAsset && InpUseCMEWallGuard && g_CME_NearMacroPutWall && InpCME_MacroPutWall > 0) ? InpCME_MacroPutWall : 
                                   ((isGoldAsset && InpUseCMEWallGuard && g_CME_NearPutWall && InpCME_PutWall > 0) ? InpCME_PutWall : 
                                   ((isGoldAsset && InpUseCMEWallGuard && g_CME_NearIntermedPut && InpCME_IntermediatePut > 0) ? InpCME_IntermediatePut : 0));
         double refLow   = (g_LastSwingLow.price > 0) ? ((isGoldAsset && InpUseCMEWallGuard && effectivePutWall > 0) ? MathMin(g_LastSwingLow.price, effectivePutWall) : g_LastSwingLow.price) : ((isGoldAsset && InpUseCMEWallGuard && effectivePutWall > 0) ? effectivePutWall : ask);
         g_PlanSL        = MathMin(refLow - MathMax(atrBuf, 30 * _Point), ask - (250 * _Point));
         double riskPts  = (g_PlanEntry - g_PlanSL) / _Point;

         double minSafeSLPts = 250.0, maxAllowedSLPts = 777.0;
         GetDynamicSLBounds(minSafeSLPts, maxAllowedSLPts);
         if(riskPts > maxAllowedSLPts) { g_PlanSL = g_PlanEntry - (maxAllowedSLPts * _Point); riskPts = maxAllowedSLPts; }
         else if(riskPts < minSafeSLPts) { g_PlanSL = g_PlanEntry - (minSafeSLPts * _Point); riskPts = minSafeSLPts; }

         double eqLvl = (g_Fibo.p500 > 0 && g_Fibo.p500 > g_PlanEntry) ? g_Fibo.p500 : (g_PlanEntry + (riskPts * 2.5 * _Point));
         g_PlanTP1 = g_PlanEntry + (riskPts * 1.5 * _Point);
         g_PlanTP2 = (eqLvl > g_PlanEntry) ? eqLvl : g_PlanEntry + (riskPts * 2.5 * _Point);
         double effectiveCallTarget = (isGoldAsset && InpUseCMEWallGuard && InpCME_IntermediateCall > 0 && InpCME_IntermediateCall > g_PlanEntry) ? InpCME_IntermediateCall : 
                                      ((isGoldAsset && InpUseCMEWallGuard && InpCME_CallWall > 0 && InpCME_CallWall > g_PlanEntry) ? InpCME_CallWall : 
                                      ((isGoldAsset && InpUseCMEWallGuard && InpCME_MegaCallWall > 0 && InpCME_MegaCallWall > g_PlanEntry) ? InpCME_MegaCallWall : 0));
         g_PlanTP3 = (isGoldAsset && InpUseCMEWallGuard && effectiveCallTarget > 0) ? effectiveCallTarget : ((g_LastSwingHigh.price > 0 && g_LastSwingHigh.price > g_PlanEntry) ? g_LastSwingHigh.price : g_PlanEntry + (riskPts * 4.0 * _Point));
         g_PlanTP  = g_PlanTP2;
         g_PlanRR1 = 1.5; g_PlanRR2 = 2.5; g_PlanRR3 = 4.0; g_PlanRR = 2.5;

         g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
         g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);
         g_PlanTP1   = NormalizeDouble(g_PlanTP1, _Digits);
         g_PlanTP2   = NormalizeDouble(g_PlanTP2, _Digits);
         g_PlanTP3   = NormalizeDouble(g_PlanTP3, _Digits);
         g_PlanTP    = NormalizeDouble(g_PlanTP, _Digits);

         g_ReversalArmedPendingConfirm = false;
         g_ReversalPendingDir = 0;
         g_ReversalPendingReason = "";
         g_BotState = STATE_TRIGGER_READY;
         FinalizeBotState(openCount);
         return;
      }
   }

   // 0.2 ICT Unicorn Model Priority Trigger for HUD Display & Trade Plan
   if(InpUseICT_Unicorn && g_Unicorn_Setup.isActive && openCount == 0)
   {
      g_PlanDirection = (g_Unicorn_Setup.state == UNICORN_BULLISH) ? 1 : -1;
      g_PlanSource    = "UNICORN";

      int tfSLPts = 0, tfTP1Pts = 0, tfTP2Pts = 0, tfTP3Pts = 0;
      GetTimeframeAdaptiveSLTP(InpTimeframe, tfSLPts, tfTP1Pts, tfTP2Pts, tfTP3Pts);
      double atrBuf = g_AssetProfile.beLock * _Point;

      double minSafeSLPts = 250.0, maxAllowedSLPts = 777.0;
      GetDynamicSLBounds(minSafeSLPts, maxAllowedSLPts);
      double maxSniperTol = MathMax(30.0, (double)InpSniperMaxEntryTolerancePts) * _Point;

      if(g_PlanDirection == 1) // BULLISH UNICORN
      {
         g_PlanEntry = (g_Unicorn_Setup.overlapBottom > 0) ? g_Unicorn_Setup.overlapBottom : g_Unicorn_Setup.breakerBottom;
         g_PlanSL    = g_Unicorn_Setup.breakerBottom - MathMax(atrBuf, 30 * _Point);
         double riskPts = (g_PlanEntry - g_PlanSL) / _Point;

         // Hard SL Sanity Ceiling & Floor
         if(riskPts > maxAllowedSLPts) { g_PlanSL = g_PlanEntry - (maxAllowedSLPts * _Point); riskPts = maxAllowedSLPts; }
         else if(riskPts < minSafeSLPts) { g_PlanSL = g_PlanEntry - (minSafeSLPts * _Point); riskPts = minSafeSLPts; }

         // Anchor SL below major structural SSL if nearby and within maxAllowedSLPts
         if(g_LQ_Radar.ssl.price > 0 && g_LQ_Radar.ssl.price < g_PlanEntry && (g_PlanEntry - g_LQ_Radar.ssl.price) <= maxAllowedSLPts * _Point)
         {
            double structSL = g_LQ_Radar.ssl.price - MathMax(atrBuf, 50 * _Point);
            if(structSL < g_PlanSL && (g_PlanEntry - structSL) / _Point <= maxAllowedSLPts)
            {
               g_PlanSL = structSL;
               riskPts = (g_PlanEntry - g_PlanSL) / _Point;
            }
         }

         g_PlanTP1 = g_PlanEntry + (riskPts * 1.5 * _Point);
         g_PlanTP2 = g_PlanEntry + (riskPts * 2.5 * _Point);
         g_PlanTP3 = g_PlanEntry + (riskPts * 4.0 * _Point);
         g_PlanTP  = g_PlanTP2;
         g_PlanRR1 = 1.5; g_PlanRR2 = 2.5; g_PlanRR3 = 4.0; g_PlanRR = 2.5;

         g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
         g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);
         g_PlanTP1   = NormalizeDouble(g_PlanTP1, _Digits);
         g_PlanTP2   = NormalizeDouble(g_PlanTP2, _Digits);
         g_PlanTP3   = NormalizeDouble(g_PlanTP3, _Digits);
         g_PlanTP    = NormalizeDouble(g_PlanTP, _Digits);

         double entryTol = MathMax(30 * _Point, atrBuf * 2.0);
         bool inBreakerZone  = (ask <= g_Unicorn_Setup.breakerTop + (entryTol * 1.5) && ask >= g_Unicorn_Setup.breakerBottom - entryTol);
         bool atSniperEntry   = (ask <= g_PlanEntry + maxSniperTol && ask >= g_PlanSL + (minSafeSLPts * 0.8 * _Point));

         if(inBreakerZone && atSniperEntry)
         {
            string supBlock = "";
            if(!CheckSupplyZoneProximityGuard(ORDER_TYPE_BUY, ask, supBlock))
            {
               g_BotState = STATE_WAIT_PULLBACK;
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = supBlock;
            }
            else
               g_BotState = STATE_TRIGGER_READY;
         }
         else if(inBreakerZone)
            g_BotState = STATE_PULLBACK_ARMED;
         else
            g_BotState = STATE_WAIT_PULLBACK;
      }
      else // BEARISH UNICORN
      {
         g_PlanEntry = (g_Unicorn_Setup.overlapTop > 0) ? g_Unicorn_Setup.overlapTop : g_Unicorn_Setup.breakerTop;
         g_PlanSL    = g_Unicorn_Setup.breakerTop + MathMax(atrBuf, 30 * _Point);
         double riskPts = (g_PlanSL - g_PlanEntry) / _Point;

         // Hard SL Sanity Ceiling & Floor
         if(riskPts > maxAllowedSLPts) { g_PlanSL = g_PlanEntry + (maxAllowedSLPts * _Point); riskPts = maxAllowedSLPts; }
         else if(riskPts < minSafeSLPts) { g_PlanSL = g_PlanEntry + (minSafeSLPts * _Point); riskPts = minSafeSLPts; }

         // Anchor SL above major structural BSL if nearby and within maxAllowedSLPts
         if(g_LQ_Radar.bsl.price > g_PlanEntry && (g_LQ_Radar.bsl.price - g_PlanEntry) <= maxAllowedSLPts * _Point)
         {
            double structSL = g_LQ_Radar.bsl.price + MathMax(atrBuf, 50 * _Point);
            if(structSL > g_PlanSL && (structSL - g_PlanEntry) / _Point <= maxAllowedSLPts)
            {
               g_PlanSL = structSL;
               riskPts = (g_PlanSL - g_PlanEntry) / _Point;
            }
         }

         g_PlanTP1 = g_PlanEntry - (riskPts * 1.5 * _Point);
         g_PlanTP2 = g_PlanEntry - (riskPts * 2.5 * _Point);
         g_PlanTP3 = g_PlanEntry - (riskPts * 4.0 * _Point);
         g_PlanTP  = g_PlanTP2;
         g_PlanRR1 = 1.5; g_PlanRR2 = 2.5; g_PlanRR3 = 4.0; g_PlanRR = 2.5;

         g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
         g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);
         g_PlanTP1   = NormalizeDouble(g_PlanTP1, _Digits);
         g_PlanTP2   = NormalizeDouble(g_PlanTP2, _Digits);
         g_PlanTP3   = NormalizeDouble(g_PlanTP3, _Digits);
         g_PlanTP    = NormalizeDouble(g_PlanTP, _Digits);

         double entryTol = MathMax(30 * _Point, atrBuf * 2.0);
         bool inBreakerZone  = (bid >= g_Unicorn_Setup.breakerBottom - (entryTol * 1.5) && bid <= g_Unicorn_Setup.breakerTop + entryTol);
         bool atSniperEntry   = (bid >= g_PlanEntry - maxSniperTol && bid <= g_PlanSL - (minSafeSLPts * 0.8 * _Point));

         if(inBreakerZone && atSniperEntry)
         {
            string dmdBlock = "";
            if(!CheckDemandZoneProximityGuard(ORDER_TYPE_SELL, bid, dmdBlock))
            {
               g_BotState = STATE_WAIT_PULLBACK;
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = dmdBlock;
            }
            else
               g_BotState = STATE_TRIGGER_READY;
         }
         else if(inBreakerZone)
            g_BotState = STATE_PULLBACK_ARMED;
         else
            g_BotState = STATE_WAIT_PULLBACK;
      }
      FinalizeBotState(openCount);
      return;
   }

   // 0.25 FOREX LAB 50% WICK SNIPER (P'Chanut Top-Down Wick Reversal & 3-Candle Confirmation)
   if(InpUseWickReversalSniper && g_WickSniper_Setup.isActive && openCount == 0)
   {
      g_PlanDirection = (g_WickSniper_Setup.direction == ORDER_TYPE_BUY) ? 1 : -1;
      g_PlanSource    = "WICK_SNIPER";

      double minSafeSLPts = 200.0, maxAllowedSLPts = 600.0;
      GetDynamicSLBounds(minSafeSLPts, maxAllowedSLPts);

      if(g_PlanDirection == 1) // BULLISH 50% WICK SNIPER
      {
         g_PlanEntry = (g_WickSniper_Setup.retestArmed) ? g_WickSniper_Setup.entryPrice : ask;
         g_PlanSL    = g_WickSniper_Setup.stopLoss;
         double riskPts = (g_PlanEntry - g_PlanSL) / _Point;

         if(riskPts > maxAllowedSLPts) { g_PlanSL = g_PlanEntry - (maxAllowedSLPts * _Point); riskPts = maxAllowedSLPts; }
         else if(riskPts < minSafeSLPts) { g_PlanSL = g_PlanEntry - (minSafeSLPts * _Point); riskPts = minSafeSLPts; }

         g_PlanTP1 = NormalizeDouble(g_PlanEntry + (riskPts * 2.0 * _Point), _Digits);
         g_PlanTP2 = NormalizeDouble(g_PlanEntry + (riskPts * 3.5 * _Point), _Digits);
         g_PlanTP3 = NormalizeDouble(g_PlanEntry + (riskPts * 5.0 * _Point), _Digits);
         g_PlanTP  = g_PlanTP2;
         g_PlanRR1 = 2.0; g_PlanRR2 = 3.5; g_PlanRR3 = 5.0; g_PlanRR = 3.5;

         g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
         g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);

         if(g_WickSniper_Setup.candleCloseConfirmed && (g_WickSniper_Setup.retestArmed || !InpWickRequireRetest))
         {
            g_BotState = STATE_TRIGGER_READY;
            g_SmartActionCommand = "🔭 สเต็ป 4 (ลั่นไก): 50% Wick H1 + ย่อ Retest คอนเฟิร์ม";
            g_SmartActionSubtext = "↳ ลั่นไก BUY สอยปลายไส้! กรองไส้หลอก 100% SL ก้นเหว 🎯";
            g_SmartActionColor   = clrLime;
         }
         else
         {
            g_BotState = STATE_PULLBACK_ARMED;
            g_SmartActionCommand = StringFormat("🔭 สเต็ป 3 (แตะโซน): %s", g_WickSniper_Setup.description);
            g_SmartActionSubtext = "↳ รอ 3 แท่งมหาประลัยปิดยืนยัน + ดักย่อ Retest 50% ⏳";
            g_SmartActionColor   = clrAqua;
         }
         FinalizeBotState(openCount);
         return;
      }
      else if(g_PlanDirection == -1) // BEARISH 50% WICK SNIPER
      {
         g_PlanEntry = (g_WickSniper_Setup.retestArmed) ? g_WickSniper_Setup.entryPrice : bid;
         g_PlanSL    = g_WickSniper_Setup.stopLoss;
         double riskPts = (g_PlanSL - g_PlanEntry) / _Point;

         if(riskPts > maxAllowedSLPts) { g_PlanSL = g_PlanEntry + (maxAllowedSLPts * _Point); riskPts = maxAllowedSLPts; }
         else if(riskPts < minSafeSLPts) { g_PlanSL = g_PlanEntry + (minSafeSLPts * _Point); riskPts = minSafeSLPts; }

         g_PlanTP1 = NormalizeDouble(g_PlanEntry - (riskPts * 2.0 * _Point), _Digits);
         g_PlanTP2 = NormalizeDouble(g_PlanEntry - (riskPts * 3.5 * _Point), _Digits);
         g_PlanTP3 = NormalizeDouble(g_PlanEntry - (riskPts * 5.0 * _Point), _Digits);
         g_PlanTP  = g_PlanTP2;
         g_PlanRR1 = 2.0; g_PlanRR2 = 3.5; g_PlanRR3 = 5.0; g_PlanRR = 3.5;

         g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
         g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);

         if(g_WickSniper_Setup.candleCloseConfirmed && (g_WickSniper_Setup.retestArmed || !InpWickRequireRetest))
         {
            g_BotState = STATE_TRIGGER_READY;
            g_SmartActionCommand = "🔭 สเต็ป 4 (ลั่นไก): 50% Wick H1 บน + ย่อ Retest คอนเฟิร์ม";
            g_SmartActionSubtext = "↳ ลั่นไก SELL สอยปลายไส้! กรองไส้หลอก 100% SL ยอดดอย 🎯";
            g_SmartActionColor   = clrCrimson;
         }
         else
         {
            g_BotState = STATE_PULLBACK_ARMED;
            g_SmartActionCommand = StringFormat("🔭 สเต็ป 3 (แตะโซน): %s", g_WickSniper_Setup.description);
            g_SmartActionSubtext = "↳ รอ 3 แท่งมหาประลัยปิดยืนยัน + ดักย่อ Retest 50% ⏳";
            g_SmartActionColor   = clrTomato;
         }
         FinalizeBotState(openCount);
         return;
      }
   }

   // 0.3 Candle Range Theory (CRT Turtle Soup) Priority Trigger
   if(InpUseCRT_TurtleSoup && g_CRT_Setup.isActive && openCount == 0)
   {
      g_PlanDirection = (g_CRT_Setup.state == CRT_BULLISH_SWEEP) ? 1 : -1;
      g_PlanSource    = "CRT";

      int tfSLPts = 0, tfTP1Pts = 0, tfTP2Pts = 0, tfTP3Pts = 0;
      GetTimeframeAdaptiveSLTP(InpTimeframe, tfSLPts, tfTP1Pts, tfTP2Pts, tfTP3Pts);
      double atrBuf = g_AssetProfile.beLock * _Point;

      double minSafeSLPts = 250.0, maxAllowedSLPts = 777.0;
      GetDynamicSLBounds(minSafeSLPts, maxAllowedSLPts);
      double maxSniperTol = MathMax(30.0, (double)InpSniperMaxEntryTolerancePts) * _Point;

      if(g_PlanDirection == 1) // BULLISH CRT SWEEP
      {
         g_PlanEntry = (g_CRT_Setup.retestMidpoint > 0) ? g_CRT_Setup.retestMidpoint : ask;
         g_PlanSL    = g_CRT_Setup.sweepExtreme - MathMax(atrBuf, 25 * _Point);
         double riskPts = (g_PlanEntry - g_PlanSL) / _Point;

         // Hard SL Sanity Ceiling & Floor
         if(riskPts > maxAllowedSLPts) { g_PlanSL = g_PlanEntry - (maxAllowedSLPts * _Point); riskPts = maxAllowedSLPts; }
         else if(riskPts < minSafeSLPts) { g_PlanSL = g_PlanEntry - (minSafeSLPts * _Point); riskPts = minSafeSLPts; }

         // Anchor SL below major structural SSL if nearby and within maxAllowedSLPts
         if(g_LQ_Radar.ssl.price > 0 && g_LQ_Radar.ssl.price < g_PlanEntry && (g_PlanEntry - g_LQ_Radar.ssl.price) <= maxAllowedSLPts * _Point)
         {
            double structSL = g_LQ_Radar.ssl.price - MathMax(atrBuf, 50 * _Point);
            if(structSL < g_PlanSL && (g_PlanEntry - structSL) / _Point <= maxAllowedSLPts)
            {
               g_PlanSL = structSL;
               riskPts = (g_PlanEntry - g_PlanSL) / _Point;
            }
         }

         g_PlanTP1 = (g_LQ_Radar.bsl.price > g_PlanEntry) ? g_LQ_Radar.bsl.price : (g_PlanEntry + (riskPts * 1.5 * _Point));
         g_PlanTP2 = g_PlanEntry + (riskPts * 2.5 * _Point);
         g_PlanTP3 = g_PlanEntry + (riskPts * 4.0 * _Point);
         g_PlanTP  = g_PlanTP2;
         g_PlanRR1 = 1.5; g_PlanRR2 = 2.5; g_PlanRR3 = 4.0; g_PlanRR = 2.5;

         g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
         g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);
         g_PlanTP1   = NormalizeDouble(g_PlanTP1, _Digits);
         g_PlanTP2   = NormalizeDouble(g_PlanTP2, _Digits);
         g_PlanTP3   = NormalizeDouble(g_PlanTP3, _Digits);
         g_PlanTP    = NormalizeDouble(g_PlanTP, _Digits);

         double entryTol = MathMax(30 * _Point, atrBuf * 2.0);
         bool inSweepZone   = (ask >= g_CRT_Setup.sweepExtreme - entryTol && ask <= g_CRT_Setup.refLevel + entryTol);
         bool atSniperEntry = (ask <= g_PlanEntry + maxSniperTol && ask >= g_PlanSL + (minSafeSLPts * 0.8 * _Point));

         // Dynamic Sweep Momentum Trigger: If price has swept SSL and is now actively driving UP with bullish momentum
         double currentRiskPts = (ask - g_PlanSL) / _Point;
         bool isBullMomentum = (ask >= g_CRT_Setup.refLevel - entryTol && currentRiskPts <= maxAllowedSLPts && currentRiskPts >= minSafeSLPts && (g_PlanTP1 - ask) >= (minSafeSLPts * 1.2 * _Point));

         if((inSweepZone && atSniperEntry) || isBullMomentum)
         {
            string supBlock = "";
            if(!CheckSupplyZoneProximityGuard(ORDER_TYPE_BUY, ask, supBlock))
            {
               g_BotState = STATE_WAIT_PULLBACK;
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = supBlock;
            }
            else
            {
               g_BotState = STATE_TRIGGER_READY;
               if(isBullMomentum && ask > g_PlanEntry)
               {
                  g_PlanEntry = NormalizeDouble(ask, _Digits);
                  g_PlanRR = (g_PlanSL < g_PlanEntry) ? (g_PlanTP - g_PlanEntry) / (g_PlanEntry - g_PlanSL) : 2.5;
               }
            }
         }
         else if(inSweepZone)
            g_BotState = STATE_PULLBACK_ARMED;
         else
            g_BotState = STATE_WAIT_PULLBACK;
      }
      else // BEARISH CRT SWEEP
      {
         g_PlanEntry = (g_CRT_Setup.retestMidpoint > 0) ? g_CRT_Setup.retestMidpoint : bid;
         g_PlanSL    = g_CRT_Setup.sweepExtreme + MathMax(atrBuf, 25 * _Point);
         double riskPts = (g_PlanSL - g_PlanEntry) / _Point;

         // Hard SL Sanity Ceiling & Floor
         if(riskPts > maxAllowedSLPts) { g_PlanSL = g_PlanEntry + (maxAllowedSLPts * _Point); riskPts = maxAllowedSLPts; }
         else if(riskPts < minSafeSLPts) { g_PlanSL = g_PlanEntry + (minSafeSLPts * _Point); riskPts = minSafeSLPts; }

         // Anchor SL above major structural BSL if nearby and within maxAllowedSLPts
         if(g_LQ_Radar.bsl.price > g_PlanEntry && (g_LQ_Radar.bsl.price - g_PlanEntry) <= maxAllowedSLPts * _Point)
         {
            double structSL = g_LQ_Radar.bsl.price + MathMax(atrBuf, 50 * _Point);
            if(structSL > g_PlanSL && (structSL - g_PlanEntry) / _Point <= maxAllowedSLPts)
            {
               g_PlanSL = structSL;
               riskPts = (g_PlanSL - g_PlanEntry) / _Point;
            }
         }

         g_PlanTP1 = (g_LQ_Radar.ssl.price > 0 && g_LQ_Radar.ssl.price < g_PlanEntry) ? g_LQ_Radar.ssl.price : (g_PlanEntry - (riskPts * 1.5 * _Point));
         g_PlanTP2 = g_PlanEntry - (riskPts * 2.5 * _Point);
         g_PlanTP3 = g_PlanEntry - (riskPts * 4.0 * _Point);
         g_PlanTP  = g_PlanTP2;
         g_PlanRR1 = 1.5; g_PlanRR2 = 2.5; g_PlanRR3 = 4.0; g_PlanRR = 2.5;

         g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
         g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);
         g_PlanTP1   = NormalizeDouble(g_PlanTP1, _Digits);
         g_PlanTP2   = NormalizeDouble(g_PlanTP2, _Digits);
         g_PlanTP3   = NormalizeDouble(g_PlanTP3, _Digits);
         g_PlanTP    = NormalizeDouble(g_PlanTP, _Digits);

         double entryTol = MathMax(30 * _Point, atrBuf * 2.0);
         bool inSweepZone   = (bid <= g_CRT_Setup.sweepExtreme + entryTol && bid >= g_CRT_Setup.refLevel - entryTol);
         bool atSniperEntry = (bid >= g_PlanEntry - maxSniperTol && bid <= g_PlanSL - (minSafeSLPts * 0.8 * _Point));

         // Dynamic Sweep Momentum Trigger: If price has swept BSL and is now actively driving DOWN with bearish momentum
         double currentRiskPts = (g_PlanSL - bid) / _Point;
         bool isBearMomentum = (bid <= g_CRT_Setup.refLevel + entryTol && currentRiskPts <= maxAllowedSLPts && currentRiskPts >= minSafeSLPts && (bid - g_PlanTP1) >= (minSafeSLPts * 1.2 * _Point));

         if((inSweepZone && atSniperEntry) || isBearMomentum)
         {
            string dmdBlock = "";
            if(!CheckDemandZoneProximityGuard(ORDER_TYPE_SELL, bid, dmdBlock))
            {
               g_BotState = STATE_WAIT_PULLBACK;
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = dmdBlock;
            }
            else
            {
               g_BotState = STATE_TRIGGER_READY;
               if(isBearMomentum && bid < g_PlanEntry)
               {
                  g_PlanEntry = NormalizeDouble(bid, _Digits);
                  g_PlanRR = (g_PlanSL > g_PlanEntry) ? (g_PlanEntry - g_PlanTP) / (g_PlanSL - g_PlanEntry) : 2.5;
               }
            }
         }
         else if(inSweepZone)
            g_BotState = STATE_PULLBACK_ARMED;
         else
            g_BotState = STATE_WAIT_PULLBACK;
      }

      if(g_BotState == STATE_TRIGGER_READY)
      {
         FinalizeBotState(openCount);
         return;
      }
      // Note: If CRT is in waiting state (STATE_WAIT_PULLBACK), allow Section 0.4 Breakdown Engine to evaluate below!
   }

   // 0.4 Institutional Two-Way Structural Breakdown & Momentum Breakout Sniper (Trend-Confirmed & Anti-Fakeout)
   if(InpUseBreakoutSniper && openCount == 0)
   {
      MqlRates mRates[];
      ArraySetAsSeries(mRates, true);
      if(CopyRates(_Symbol, InpTimeframe, 0, 6, mRates) >= 5)
      {
         double curBid = m_symbol.Bid();
         double curAsk = m_symbol.Ask();
         double atrBuf = g_AssetProfile.beLock * _Point;
         double minSafeSLPts = 250.0, maxAllowedSLPts = 777.0;
         GetDynamicSLBounds(minSafeSLPts, maxAllowedSLPts);
         double swingRng = (g_LastSwingHigh.price > g_LastSwingLow.price) ? (g_LastSwingHigh.price - g_LastSwingLow.price) : 0;

         // Dynamic ATR for range comparison
         double atrVal = 100.0 * _Point;
         if(InpUseDynamicATR && m_hATR != INVALID_HANDLE)
         {
            double aBuf[1];
            if(CopyBuffer(m_hATR, 0, 0, 1, aBuf) > 0 && aBuf[0] > 0)
               atrVal = aBuf[0];
         }
         double minBodyPts = MathMax((double)InpBreakoutMinBodyPts * _Point, (g_AssetProfile.assetType == ASSET_GOLD ? 100 * _Point : 25 * _Point));

         // Timeframe-Specific Candle Confirmation Logic:
         // M1/M5: 2 closed candles confirmation (Bar 2 broke, Bar 1 confirmed follow-through)
         // M15: 1 solid candle (Bar 1) with wick ratio <= InpBreakoutWickMaxRatio, or 2 candles if wick is longer
         // M30/H1/H4: 1 solid closed candle (Bar 1)
         bool isShortTF = (InpTimeframe == PERIOD_M1 || InpTimeframe == PERIOD_M5);

         // A. BEARISH BREAKDOWN SELL CONFIRMATION:
         bool isBreakdownConfirmed = false;
         double breakHigh = 0;

         if(isShortTF)
         {
            // Bar 2 closed below Bar 3 low
            bool bar2BrokeDown = (mRates[2].close < mRates[3].low && mRates[2].close < mRates[2].open);
            // Bar 1 confirmed follow-through (closed red and held below Bar 3 low)
            bool bar1Confirmed = (mRates[1].close < mRates[1].open && mRates[1].close <= mRates[3].low);
            double rng2 = mRates[2].high - mRates[2].low;
            double body2 = MathAbs(mRates[2].close - mRates[2].open);
            double lowerWick2 = mRates[2].close - mRates[2].low;
            double wickRatio2 = (rng2 > 0) ? (lowerWick2 / rng2) : 0;

            if(bar2BrokeDown && bar1Confirmed && wickRatio2 <= InpBreakoutWickMaxRatio && body2 >= minBodyPts)
            {
               isBreakdownConfirmed = true;
               breakHigh = MathMax(mRates[1].high, MathMax(mRates[2].high, mRates[3].high));
            }
         }
         else
         {
            // M15, M30, H1+: Bar 1 closed below Bar 2 low
            bool bar1BrokeDown = (mRates[1].close < mRates[2].low && mRates[1].close < mRates[1].open);
            double rng1 = mRates[1].high - mRates[1].low;
            double body1 = MathAbs(mRates[1].close - mRates[1].open);
            double lowerWick1 = mRates[1].close - mRates[1].low;
            double wickRatio1 = (rng1 > 0) ? (lowerWick1 / rng1) : 0;

            // False Breakout Filter: Wick must NOT be longer than InpBreakoutWickMaxRatio (35%)
            if(bar1BrokeDown && wickRatio1 <= InpBreakoutWickMaxRatio && body1 >= minBodyPts)
            {
               isBreakdownConfirmed = true;
               breakHigh = MathMax(mRates[0].high, MathMax(mRates[1].high, mRates[2].high));
            }
         }

         // Trend Alignment Guard: Do NOT breakdown sell if major trend is BULLISH
         bool trendOkSell = (!InpBreakoutRequireTrend || g_MarketTrend == TREND_BEARISH || g_MarketTrend == TREND_SIDEWAY);

         // CME Downward Runway Check (Must have >= 350 pts clearance to next Put Wall):
         double nextPutFloor = 0;
         if(InpCME_IntermediatePut > 0 && curBid > InpCME_IntermediatePut) nextPutFloor = InpCME_IntermediatePut;
         else if(InpCME_PutWall > 0 && curBid > InpCME_PutWall) nextPutFloor = InpCME_PutWall;
         else if(InpCME_MacroPutWall > 0 && curBid > InpCME_MacroPutWall) nextPutFloor = InpCME_MacroPutWall;
         bool cmeDownwardRoom = (nextPutFloor <= 0 || (curBid - nextPutFloor) >= (350.0 * _Point));

         double valleyFloor = (g_LastSwingLow.price > 0) ? g_LastSwingLow.price + (minSafeSLPts * 0.6 * _Point) : 0;
         bool hasDownwardRoom = cmeDownwardRoom && (valleyFloor <= 0 || curBid > valleyFloor);
         bool notAbyss = !g_ZScoreExtremeValley && !g_CME_NearPutWall && !g_CME_NearMacroPutWall && !g_CME_NearIntermedPut;

         // Breakdown Confluence Score Calculation (Target: 55 - 65%)
         int breakdownScore = 0;
         if(g_MarketTrend == TREND_BEARISH) breakdownScore += 25;
         else if(g_MarketTrend == TREND_SIDEWAY) breakdownScore += 10;

         double evalRng = (isShortTF ? (mRates[2].high - mRates[2].low) : (mRates[1].high - mRates[1].low));
         double evalBody = (isShortTF ? MathAbs(mRates[2].close - mRates[2].open) : MathAbs(mRates[1].close - mRates[1].open));
         double bodyRatioSell = (evalRng > 0) ? (evalBody / evalRng) : 0;
         if(bodyRatioSell >= 0.70) breakdownScore += 20;
         else if(bodyRatioSell >= 0.60) breakdownScore += 15;
         else breakdownScore += 10;

         if(evalRng >= atrVal * 1.5) breakdownScore += 15;
         else if(evalRng >= atrVal * 1.0) breakdownScore += 10;

         if(cmeDownwardRoom) breakdownScore += 15;
         if(g_JudasSellActive || (g_LQ_Radar.bsl.isSwept && !g_LQ_Radar.ssl.isSwept)) breakdownScore += 15;
         if(mRates[0].close < mRates[1].close) breakdownScore += 10;

         if(isBreakdownConfirmed && trendOkSell && hasDownwardRoom && notAbyss && breakdownScore >= InpBreakoutMinScore)
         {
            g_PlanDirection = -1;
            g_PlanSource    = "BREAKDOWN";
            g_PlanEntry     = curBid;
            g_PatternScore  = MathMin(100, breakdownScore);
            g_PatternName   = StringFormat("🎯 Breakdown SELL 🔴 (Score: %d%%)", g_PatternScore);

            g_PlanSL = MathMax(breakHigh + MathMax(atrBuf, 30 * _Point), curBid + (minSafeSLPts * _Point));
            double riskPts = (g_PlanSL - g_PlanEntry) / _Point;

            if(riskPts > maxAllowedSLPts) { g_PlanSL = g_PlanEntry + (maxAllowedSLPts * _Point); riskPts = maxAllowedSLPts; }
            else if(riskPts < minSafeSLPts) { g_PlanSL = g_PlanEntry + (minSafeSLPts * _Point); riskPts = minSafeSLPts; }

            double targetLow = (nextPutFloor > 0 && nextPutFloor < g_PlanEntry) ? nextPutFloor : ((g_LastSwingLow.price > 0 && g_LastSwingLow.price < g_PlanEntry) ? g_LastSwingLow.price : (g_PlanEntry - (riskPts * 2.5 * _Point)));
            g_PlanTP1 = g_PlanEntry - (riskPts * 1.5 * _Point);
            g_PlanTP2 = targetLow;
            g_PlanTP3 = (InpCME_PutWall > 0 && InpCME_PutWall < g_PlanEntry) ? InpCME_PutWall : (g_PlanEntry - (riskPts * 4.0 * _Point));
            g_PlanTP  = g_PlanTP2;
            g_PlanRR1 = 1.5; g_PlanRR2 = 2.5; g_PlanRR3 = 4.0; g_PlanRR = 2.5;

            g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
            g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);
            g_PlanTP1   = NormalizeDouble(g_PlanTP1, _Digits);
            g_PlanTP2   = NormalizeDouble(g_PlanTP2, _Digits);
            g_PlanTP3   = NormalizeDouble(g_PlanTP3, _Digits);
            g_PlanTP    = NormalizeDouble(g_PlanTP, _Digits);

            g_BotState = STATE_TRIGGER_READY;
            FinalizeBotState(openCount);
            return;
         }

         // B. BULLISH BREAKOUT BUY CONFIRMATION:
         bool isBreakoutConfirmed = false;
         double breakLow = 0;

         if(isShortTF)
         {
            // Bar 2 closed above Bar 3 high
            bool bar2BrokeUp = (mRates[2].close > mRates[3].high && mRates[2].close > mRates[2].open);
            // Bar 1 confirmed follow-through (closed green and held above Bar 3 high)
            bool bar1Confirmed = (mRates[1].close > mRates[1].open && mRates[1].close >= mRates[3].high);
            double rng2 = mRates[2].high - mRates[2].low;
            double body2 = MathAbs(mRates[2].close - mRates[2].open);
            double upperWick2 = mRates[2].high - mRates[2].close;
            double wickRatio2 = (rng2 > 0) ? (upperWick2 / rng2) : 0;

            if(bar2BrokeUp && bar1Confirmed && wickRatio2 <= InpBreakoutWickMaxRatio && body2 >= minBodyPts)
            {
               isBreakoutConfirmed = true;
               breakLow = MathMin(mRates[1].low, MathMin(mRates[2].low, mRates[3].low));
            }
         }
         else
         {
            // M15, M30, H1+: Bar 1 closed above Bar 2 high
            bool bar1BrokeUp = (mRates[1].close > mRates[2].high && mRates[1].close > mRates[1].open);
            double rng1 = mRates[1].high - mRates[1].low;
            double body1 = MathAbs(mRates[1].close - mRates[1].open);
            double upperWick1 = mRates[1].high - mRates[1].close;
            double wickRatio1 = (rng1 > 0) ? (upperWick1 / rng1) : 0;

            // False Breakout Filter: Upper wick must NOT be longer than InpBreakoutWickMaxRatio (35%)
            if(bar1BrokeUp && wickRatio1 <= InpBreakoutWickMaxRatio && body1 >= minBodyPts)
            {
               isBreakoutConfirmed = true;
               breakLow = MathMin(mRates[0].low, MathMin(mRates[1].low, mRates[2].low));
            }
         }

         // Trend Alignment Guard: Do NOT breakout buy if major trend is BEARISH
         bool trendOkBuy = (!InpBreakoutRequireTrend || g_MarketTrend == TREND_BULLISH || g_MarketTrend == TREND_SIDEWAY);

         // CME Upward Runway Check (Must have >= 350 pts clearance to next Call Wall):
         double nextCallCeil = 0;
         if(InpCME_IntermediateCall > 0 && curAsk < InpCME_IntermediateCall) nextCallCeil = InpCME_IntermediateCall;
         else if(InpCME_CallWall > 0 && curAsk < InpCME_CallWall) nextCallCeil = InpCME_CallWall;
         else if(InpCME_MegaCallWall > 0 && curAsk < InpCME_MegaCallWall) nextCallCeil = InpCME_MegaCallWall;
         bool cmeUpwardRoom = (nextCallCeil <= 0 || (nextCallCeil - curAsk) >= (350.0 * _Point));

         bool hasUpwardRoom = cmeUpwardRoom && (g_LastSwingHigh.price <= curAsk || (g_LastSwingHigh.price - curAsk) >= (minSafeSLPts * 0.8 * _Point));
         bool notPeak = !g_ZScoreExtremePeak && !g_CME_NearCallWall && !g_CME_NearMegaCallWall && !g_CME_NearIntermedCall;

         // Breakout Confluence Score Calculation (Target: 55 - 65%)
         int breakoutScore = 0;
         if(g_MarketTrend == TREND_BULLISH) breakoutScore += 25;
         else if(g_MarketTrend == TREND_SIDEWAY) breakoutScore += 10;

         double evalRngBuy = (isShortTF ? (mRates[2].high - mRates[2].low) : (mRates[1].high - mRates[1].low));
         double evalBodyBuy = (isShortTF ? MathAbs(mRates[2].close - mRates[2].open) : MathAbs(mRates[1].close - mRates[1].open));
         double bodyRatioBuy = (evalRngBuy > 0) ? (evalBodyBuy / evalRngBuy) : 0;
         if(bodyRatioBuy >= 0.70) breakoutScore += 20;
         else if(bodyRatioBuy >= 0.60) breakoutScore += 15;
         else breakoutScore += 10;

         if(evalRngBuy >= atrVal * 1.5) breakoutScore += 15;
         else if(evalRngBuy >= atrVal * 1.0) breakoutScore += 10;

         if(cmeUpwardRoom) breakoutScore += 15;
         if(g_JudasBuyActive || (g_LQ_Radar.ssl.isSwept && !g_LQ_Radar.bsl.isSwept)) breakoutScore += 15;
         if(mRates[0].close > mRates[1].close) breakoutScore += 10;

         if(isBreakoutConfirmed && trendOkBuy && hasUpwardRoom && notPeak && breakoutScore >= InpBreakoutMinScore)
         {
            g_PlanDirection = 1;
            g_PlanSource    = "BREAKOUT";
            g_PlanEntry     = curAsk;
            g_PatternScore  = MathMin(100, breakoutScore);
            g_PatternName   = StringFormat("🚀 Breakout BUY 🟢 (Score: %d%%)", g_PatternScore);

            g_PlanSL = MathMin(breakLow - MathMax(atrBuf, 30 * _Point), curAsk - (minSafeSLPts * _Point));
            double riskPts = (g_PlanEntry - g_PlanSL) / _Point;

            if(riskPts > maxAllowedSLPts) { g_PlanSL = g_PlanEntry - (maxAllowedSLPts * _Point); riskPts = maxAllowedSLPts; }
            else if(riskPts < minSafeSLPts) { g_PlanSL = g_PlanEntry - (minSafeSLPts * _Point); riskPts = minSafeSLPts; }

            double targetHigh = (nextCallCeil > curAsk) ? nextCallCeil : ((g_LastSwingHigh.price > 0 && g_LastSwingHigh.price > g_PlanEntry) ? g_LastSwingHigh.price : (g_PlanEntry + (riskPts * 2.5 * _Point)));
            g_PlanTP1 = g_PlanEntry + (riskPts * 1.5 * _Point);
            g_PlanTP2 = targetHigh;
            g_PlanTP3 = (InpCME_CallWall > curAsk) ? InpCME_CallWall : (g_PlanEntry + (riskPts * 4.0 * _Point));
            g_PlanTP  = g_PlanTP2;
            g_PlanRR1 = 1.5; g_PlanRR2 = 2.5; g_PlanRR3 = 4.0; g_PlanRR = 2.5;

            g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
            g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);
            g_PlanTP1   = NormalizeDouble(g_PlanTP1, _Digits);
            g_PlanTP2   = NormalizeDouble(g_PlanTP2, _Digits);
            g_PlanTP3   = NormalizeDouble(g_PlanTP3, _Digits);
            g_PlanTP    = NormalizeDouble(g_PlanTP, _Digits);

            g_BotState = STATE_TRIGGER_READY;
            FinalizeBotState(openCount);
            return;
         }
      }
   }

   // If CRT Turtle Soup was evaluated and is in waiting state (and Breakdown did not trigger):
   if(InpUseCRT_TurtleSoup && g_CRT_Setup.isActive && openCount == 0)
   {
      FinalizeBotState(openCount);
      return;
   }

   // Sideway Market Check: Only clear trend wave when there is genuinely no directional structure
   if(g_MarketTrend == TREND_SIDEWAY)
   {
      g_BotState = (openCount > 0) ? STATE_IN_POSITION : STATE_WAIT_STRUCTURE;
      if(openCount == 0)
      {
         g_PlanEntry = 0; g_PlanSL = 0; g_PlanTP = 0; g_PlanRR = 0;
         g_PlanDirection = 0; g_PlanSource = "";
         g_PullbackArmed = false;
         g_ExhaustionActive = false;
         g_ExhaustionGuardMsg = "";
      }
      FinalizeBotState(openCount);
      return;
   }

   // Dynamic Structural ATR Volatility Buffer Calculation
   double atrBuffer = g_AssetProfile.beLock * _Point;
   if(InpUseDynamicATR && m_hATR != INVALID_HANDLE)
   {
      double atrVal[1];
      if(CopyBuffer(m_hATR, 0, 0, 1, atrVal) > 0)
      {
         atrBuffer = atrVal[0] * 0.35;
      }
   }

   // Dynamic Timeframe-Adaptive SL and TP Calibration
   int tfSLPts = 0, tfTP1Pts = 0, tfTP2Pts = 0, tfTP3Pts = 0;
   GetTimeframeAdaptiveSLTP(InpTimeframe, tfSLPts, tfTP1Pts, tfTP2Pts, tfTP3Pts);

   if(g_MarketTrend == TREND_BULLISH)
   {
      g_PlanDirection = 1;
      g_PlanSource    = "WAVE";
      double optimalEntry = (g_Fibo.p618 > 0) ? g_Fibo.p618 : ((g_Fibo.zoneHigh > 0) ? g_Fibo.zoneHigh : ask);
      g_PlanEntry = optimalEntry;

      if(InpUseFiboTarget && g_Fibo.p100 > 0)
      {
         g_PlanSL  = g_Fibo.p100 - atrBuffer;
         g_PlanTP1 = (g_Fibo.p0 > 0) ? g_Fibo.p0 : (optimalEntry + (tfTP1Pts * _Point));
         g_PlanTP2 = (g_Fibo.p1618 > 0) ? g_Fibo.p1618 : (optimalEntry + (tfTP2Pts * _Point));
         g_PlanTP3 = (g_Fibo.p2618 > 0) ? g_Fibo.p2618 : (optimalEntry + (tfTP3Pts * _Point));
      }
      else
      {
         g_PlanSL  = g_PlanEntry - MathMax(tfSLPts * _Point, atrBuffer * 2.0);
         g_PlanTP1 = g_PlanEntry + (tfTP1Pts * _Point);
         g_PlanTP2 = g_PlanEntry + (tfTP2Pts * _Point);
         g_PlanTP3 = g_PlanEntry + (tfTP3Pts * _Point);
      }

      double minAllowedSLPts = 250.0, maxAllowedSLPts = 777.0;
      GetDynamicSLBounds(minAllowedSLPts, maxAllowedSLPts);
      double riskPts = (g_PlanEntry - g_PlanSL) / _Point;
      if(riskPts > maxAllowedSLPts)
      {
         g_PlanSL = g_PlanEntry - (maxAllowedSLPts * _Point);
         riskPts = maxAllowedSLPts;
      }
      else if(riskPts < minAllowedSLPts)
      {
         g_PlanSL = g_PlanEntry - (minAllowedSLPts * _Point);
         riskPts = minAllowedSLPts;
      }

      double maxAllowedTP1Pts = MathMax((double)tfTP1Pts * 1.5, 500.0);
      double maxAllowedTP2Pts = MathMax((double)tfTP2Pts * 1.5, 1000.0);
      double maxAllowedTP3Pts = MathMax((double)tfTP3Pts * 1.5, 1500.0);

      double rewardPts1 = (g_PlanTP1 - g_PlanEntry) / _Point;
      double rewardPts2 = (g_PlanTP2 - g_PlanEntry) / _Point;
      double rewardPts3 = (g_PlanTP3 - g_PlanEntry) / _Point;

      if(rewardPts1 > maxAllowedTP1Pts || rewardPts1 <= 0) { g_PlanTP1 = g_PlanEntry + (tfTP1Pts * _Point);  rewardPts1 = tfTP1Pts; }
      if(rewardPts2 > maxAllowedTP2Pts || rewardPts2 <= 0) { g_PlanTP2 = g_PlanEntry + (tfTP2Pts * _Point); rewardPts2 = tfTP2Pts; }
      if(rewardPts3 > maxAllowedTP3Pts || rewardPts3 <= 0) { g_PlanTP3 = g_PlanEntry + (tfTP3Pts * _Point); rewardPts3 = tfTP3Pts; }

      // ATH Front-Running Adjustment (Shave TP slightly below ATH resistance)
      if(InpUseATHGrid && InpUseATHFrontRunning)
      {
         double athSup = 0, athRes = 0;
         GetNearestATHLevels(g_PlanEntry, athSup, athRes);
         g_PlanTP1 = AdjustTPForATHFrontRunning(ORDER_TYPE_BUY, g_PlanEntry, g_PlanTP1, athSup, athRes);
         g_PlanTP2 = AdjustTPForATHFrontRunning(ORDER_TYPE_BUY, g_PlanEntry, g_PlanTP2, athSup, athRes);
         g_PlanTP3 = AdjustTPForATHFrontRunning(ORDER_TYPE_BUY, g_PlanEntry, g_PlanTP3, athSup, athRes);
      }

      // Strict TP Tier Separation Guard (TP1 < TP2 < TP3)
      double minStepDist = MathMax(150.0, (double)tfTP1Pts * 0.35) * _Point;
      if(g_PlanTP2 <= (g_PlanTP1 + minStepDist)) g_PlanTP2 = g_PlanTP1 + (MathMax(tfTP2Pts - tfTP1Pts, (int)(tfTP1Pts * 0.5)) * _Point);
      if(g_PlanTP3 <= (g_PlanTP2 + minStepDist)) g_PlanTP3 = g_PlanTP2 + (MathMax(tfTP3Pts - tfTP2Pts, (int)(tfTP1Pts * 0.5)) * _Point);

      rewardPts1 = (g_PlanTP1 - g_PlanEntry) / _Point;
      rewardPts2 = (g_PlanTP2 - g_PlanEntry) / _Point;
      rewardPts3 = (g_PlanTP3 - g_PlanEntry) / _Point;

      g_PlanRR1 = (riskPts > 0) ? (rewardPts1 / riskPts) : 0;
      g_PlanRR2 = (riskPts > 0) ? (rewardPts2 / riskPts) : 0;
      g_PlanRR3 = (riskPts > 0) ? (rewardPts3 / riskPts) : 0;

      // Dynamic Target Selection: ADX Momentum Turbo Gate
      if(InpUseADXTurboGate)
      {
         if(g_ADXMode == ADX_MODE_TURBO)
         {
            g_PlanTP = (g_PlanTP3 > 0) ? g_PlanTP3 : g_PlanTP2;
            g_PlanRR = (g_PlanRR3 > 0) ? g_PlanRR3 : g_PlanRR2;
         }
         else if(g_ADXMode == ADX_MODE_RANGE)
         {
            g_PlanTP = (g_PlanTP1 > 0) ? g_PlanTP1 : g_PlanTP2;
            g_PlanRR = (g_PlanRR1 > 0) ? g_PlanRR1 : g_PlanRR2;
         }
         else
         {
            g_PlanTP = g_PlanTP2;
            g_PlanRR = g_PlanRR2;
         }
      }
      else
      {
         g_PlanTP = g_PlanTP2;
         g_PlanRR = g_PlanRR2;
      }

      g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
      g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);
      g_PlanTP1   = NormalizeDouble(g_PlanTP1, _Digits);
      g_PlanTP2   = NormalizeDouble(g_PlanTP2, _Digits);
      g_PlanTP3   = NormalizeDouble(g_PlanTP3, _Digits);
      g_PlanTP    = NormalizeDouble(g_PlanTP, _Digits);

      // Invalidation Guard: Dynamic sanity floor & temporary SL breach protection
      if(g_PlanEntry <= g_PlanSL)
      {
         g_PlanSL = g_PlanEntry - (minAllowedSLPts * _Point);
      }
      if(bid < g_PlanSL)
      {
         // Price breached SL temporarily: preserve technical roadmap on Card 2, hold execution safely
         g_PullbackArmed = false;
         g_ExhaustionActive = true;
         g_ExhaustionGuardMsg = "🛡️ ราคาย่อทดสอบแนว SL • รอแรง Rejection ยืนยัน ⏳";
         g_BotState = STATE_WAIT_PULLBACK;
      }
      else if(g_PullbackArmed)
      {
         string blockMsg = "";
         if(!IsTradeAllowedByExhaustionGuard(ORDER_TYPE_BUY, blockMsg))
         {
            g_ExhaustionActive = true;
            g_ExhaustionGuardMsg = blockMsg;
            g_BotState = STATE_PULLBACK_ARMED;
         }
         else
         {
            g_ExhaustionActive = false;
            g_ExhaustionGuardMsg = "";
            if(g_PABuyTrigger)
            {
               // Anti-Falling-Knife Filter: If price is actively crashing in a red candle, delay BUY
               MqlRates chkRates[];
               ArraySetAsSeries(chkRates, true);
               bool isDumpingKnife = false;
               if(CopyRates(_Symbol, InpTimeframe, 0, 2, chkRates) >= 2)
               {
                  double curRange = chkRates[0].high - chkRates[0].low;
                  double curBody  = chkRates[0].open - chkRates[0].close;
                  if(curBody > 0 && curRange > (50 * _Point) && ((chkRates[0].close - chkRates[0].low) / curRange) < 0.25)
                     isDumpingKnife = true;
               }

               if(isDumpingKnife)
               {
                  g_ExhaustionActive = true;
                  g_ExhaustionGuardMsg = "🛡️ ชะลอ BUY • แท่งแดงทุบแรง รอแท่ง Rejection ยืนยัน ⏳";
                  g_BotState = STATE_PULLBACK_ARMED;
               }
               else if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && g_MarketBiasBuyPct < 45)
               {
                  g_ExhaustionActive = true;
                  g_ExhaustionGuardMsg = StringFormat("🛡️ ชะลอ BUY (น้ำหนัก BUY แค่ %d%% < 45%% - เสี่ยงกับดัก 🛡️)", g_MarketBiasBuyPct);
                  g_BotState = STATE_PULLBACK_ARMED;
               }
               else if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && g_LiveADX_Val < 20.0)
               {
                  g_ExhaustionActive = true;
                  g_ExhaustionGuardMsg = StringFormat("🛡️ รอวอลุ่มยืนยัน (ADX %.1f < 20 ⏳)", g_LiveADX_Val);
                  g_BotState = STATE_PULLBACK_ARMED;
               }
               else if(g_PostCloseCooldownRemainSec > 0)
               {
                  g_ExhaustionActive = true;
                  g_ExhaustionGuardMsg = StringFormat("🛡️ พักระบบหลังปิดไม้ (เหลือ %ds ⏳)", g_PostCloseCooldownRemainSec);
                  g_BotState = STATE_PULLBACK_ARMED;
               }
               else
               {
                  g_BotState = STATE_TRIGGER_READY;
               }
            }
            else
               g_BotState = STATE_PULLBACK_ARMED;
         }
      }
      else
      {
         g_ExhaustionActive = false;
         g_ExhaustionGuardMsg = "";
         g_BotState = (openCount > 0) ? STATE_IN_POSITION : STATE_WAIT_PULLBACK;
      }
   }
   else if(g_MarketTrend == TREND_BEARISH)
   {
      g_PlanDirection = -1;
      g_PlanSource    = "WAVE";
      double optimalEntry = (g_Fibo.p618 > 0) ? g_Fibo.p618 : ((g_Fibo.zoneLow > 0) ? g_Fibo.zoneLow : bid);
      g_PlanEntry = optimalEntry;

      if(InpUseFiboTarget && g_Fibo.p100 > 0)
      {
         g_PlanSL  = g_Fibo.p100 + atrBuffer;
         g_PlanTP1 = (g_Fibo.p0 > 0) ? g_Fibo.p0 : (optimalEntry - (tfTP1Pts * _Point));
         g_PlanTP2 = (g_Fibo.p1618 > 0) ? g_Fibo.p1618 : (optimalEntry - (tfTP2Pts * _Point));
         g_PlanTP3 = (g_Fibo.p2618 > 0) ? g_Fibo.p2618 : (optimalEntry - (tfTP3Pts * _Point));
      }
      else
      {
         g_PlanSL  = g_PlanEntry + MathMax(tfSLPts * _Point, atrBuffer * 2.0);
         g_PlanTP1 = g_PlanEntry - (tfTP1Pts * _Point);
         g_PlanTP2 = g_PlanEntry - (tfTP2Pts * _Point);
         g_PlanTP3 = g_PlanEntry - (tfTP3Pts * _Point);
      }

      double minAllowedSLPts = 250.0, maxAllowedSLPts = 777.0;
      GetDynamicSLBounds(minAllowedSLPts, maxAllowedSLPts);
      double riskPts = (g_PlanSL - g_PlanEntry) / _Point;
      if(riskPts > maxAllowedSLPts)
      {
         g_PlanSL = g_PlanEntry + (maxAllowedSLPts * _Point);
         riskPts = maxAllowedSLPts;
      }
      else if(riskPts < minAllowedSLPts)
      {
         g_PlanSL = g_PlanEntry + (minAllowedSLPts * _Point);
         riskPts = minAllowedSLPts;
      }

      double maxAllowedTP1Pts = MathMax((double)tfTP1Pts * 1.5, 500.0);
      double maxAllowedTP2Pts = MathMax((double)tfTP2Pts * 1.5, 1000.0);
      double maxAllowedTP3Pts = MathMax((double)tfTP3Pts * 1.5, 1500.0);

      double rewardPts1 = (g_PlanEntry - g_PlanTP1) / _Point;
      double rewardPts2 = (g_PlanEntry - g_PlanTP2) / _Point;
      double rewardPts3 = (g_PlanEntry - g_PlanTP3) / _Point;

      if(rewardPts1 > maxAllowedTP1Pts || rewardPts1 <= 0) { g_PlanTP1 = g_PlanEntry - (tfTP1Pts * _Point);  rewardPts1 = tfTP1Pts; }
      if(rewardPts2 > maxAllowedTP2Pts || rewardPts2 <= 0) { g_PlanTP2 = g_PlanEntry - (tfTP2Pts * _Point); rewardPts2 = tfTP2Pts; }
      if(rewardPts3 > maxAllowedTP3Pts || rewardPts3 <= 0) { g_PlanTP3 = g_PlanEntry - (tfTP3Pts * _Point); rewardPts3 = tfTP3Pts; }

      // ATH Front-Running Adjustment (Shave TP slightly above ATH support)
      if(InpUseATHGrid && InpUseATHFrontRunning)
      {
         double athSup = 0, athRes = 0;
         GetNearestATHLevels(g_PlanEntry, athSup, athRes);
         g_PlanTP1 = AdjustTPForATHFrontRunning(ORDER_TYPE_SELL, g_PlanEntry, g_PlanTP1, athSup, athRes);
         g_PlanTP2 = AdjustTPForATHFrontRunning(ORDER_TYPE_SELL, g_PlanEntry, g_PlanTP2, athSup, athRes);
         g_PlanTP3 = AdjustTPForATHFrontRunning(ORDER_TYPE_SELL, g_PlanEntry, g_PlanTP3, athSup, athRes);
      }

      // Strict TP Tier Separation Guard (TP1 > TP2 > TP3 for SELL)
      double minStepDist = MathMax(150.0, (double)tfTP1Pts * 0.35) * _Point;
      if(g_PlanTP2 >= (g_PlanTP1 - minStepDist)) g_PlanTP2 = g_PlanTP1 - (MathMax(tfTP2Pts - tfTP1Pts, (int)(tfTP1Pts * 0.5)) * _Point);
      if(g_PlanTP3 >= (g_PlanTP2 - minStepDist)) g_PlanTP3 = g_PlanTP2 - (MathMax(tfTP3Pts - tfTP2Pts, (int)(tfTP1Pts * 0.5)) * _Point);

      rewardPts1 = (g_PlanEntry - g_PlanTP1) / _Point;
      rewardPts2 = (g_PlanEntry - g_PlanTP2) / _Point;
      rewardPts3 = (g_PlanEntry - g_PlanTP3) / _Point;

      g_PlanRR1 = (riskPts > 0) ? (rewardPts1 / riskPts) : 0;
      g_PlanRR2 = (riskPts > 0) ? (rewardPts2 / riskPts) : 0;
      g_PlanRR3 = (riskPts > 0) ? (rewardPts3 / riskPts) : 0;

      // Dynamic Target Selection: ADX Momentum Turbo Gate
      if(InpUseADXTurboGate)
      {
         if(g_ADXMode == ADX_MODE_TURBO)
         {
            g_PlanTP = (g_PlanTP3 > 0) ? g_PlanTP3 : g_PlanTP2;
            g_PlanRR = (g_PlanRR3 > 0) ? g_PlanRR3 : g_PlanRR2;
         }
         else if(g_ADXMode == ADX_MODE_RANGE)
         {
            g_PlanTP = (g_PlanTP1 > 0) ? g_PlanTP1 : g_PlanTP2;
            g_PlanRR = (g_PlanRR1 > 0) ? g_PlanRR1 : g_PlanRR2;
         }
         else
         {
            g_PlanTP = g_PlanTP2;
            g_PlanRR = g_PlanRR2;
         }
      }
      else
      {
         g_PlanTP = g_PlanTP2;
         g_PlanRR = g_PlanRR2;
      }

      g_PlanEntry = NormalizeDouble(g_PlanEntry, _Digits);
      g_PlanSL    = NormalizeDouble(g_PlanSL, _Digits);
      g_PlanTP1   = NormalizeDouble(g_PlanTP1, _Digits);
      g_PlanTP2   = NormalizeDouble(g_PlanTP2, _Digits);
      g_PlanTP3   = NormalizeDouble(g_PlanTP3, _Digits);
      g_PlanTP    = NormalizeDouble(g_PlanTP, _Digits);

      // Invalidation Guard: Dynamic sanity ceiling & temporary SL breach protection
      if(g_PlanEntry >= g_PlanSL)
      {
         g_PlanSL = g_PlanEntry + (minAllowedSLPts * _Point);
      }
      if(ask > g_PlanSL)
      {
         // Price breached SL temporarily: preserve technical roadmap on Card 2, hold execution safely
         g_PullbackArmed = false;
         g_ExhaustionActive = true;
         g_ExhaustionGuardMsg = "🛡️ ราคาเด้งทดสอบแนว SL • รอแท่ง Rejection ยืนยัน ⏳";
         g_BotState = STATE_WAIT_PULLBACK;
      }
      else if(g_PullbackArmed)
      {
         string blockMsg = "";
         if(!IsTradeAllowedByExhaustionGuard(ORDER_TYPE_SELL, blockMsg))
         {
            g_ExhaustionActive = true;
            g_ExhaustionGuardMsg = blockMsg;
            g_BotState = STATE_PULLBACK_ARMED;
         }
         else
         {
            g_ExhaustionActive = false;
            g_ExhaustionGuardMsg = "";
            if(g_PASellTrigger)
            {
               // Anti-Rocket-Launch Filter: If price is actively pumping in a green candle, delay SELL
               MqlRates chkRates[];
               ArraySetAsSeries(chkRates, true);
               bool isPumpingRocket = false;
               if(CopyRates(_Symbol, InpTimeframe, 0, 2, chkRates) >= 2)
               {
                  double curRange = chkRates[0].high - chkRates[0].low;
                  double curBody  = chkRates[0].close - chkRates[0].open;
                  if(curBody > 0 && curRange > (50 * _Point) && ((chkRates[0].high - chkRates[0].close) / curRange) < 0.25)
                     isPumpingRocket = true;
               }

               if(isPumpingRocket)
               {
                  g_ExhaustionActive = true;
                  g_ExhaustionGuardMsg = "🛡️ ชะลอ SELL • แท่งเขียวพุ่งแรง รอแท่ง Rejection ยืนยัน ⏳";
                  g_BotState = STATE_PULLBACK_ARMED;
               }
               else if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && g_MarketBiasSellPct < 45)
               {
                  g_ExhaustionActive = true;
                  g_ExhaustionGuardMsg = StringFormat("🛡️ ชะลอ SELL (น้ำหนัก SELL แค่ %d%% < 45%% - เสี่ยงกับดัก 🛡️)", g_MarketBiasSellPct);
                  g_BotState = STATE_PULLBACK_ARMED;
               }
               else if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && g_LiveADX_Val < 20.0)
               {
                  g_ExhaustionActive = true;
                  g_ExhaustionGuardMsg = StringFormat("🛡️ รอวอลุ่มยืนยัน (ADX %.1f < 20 ⏳)", g_LiveADX_Val);
                  g_BotState = STATE_PULLBACK_ARMED;
               }
               else if(g_PostCloseCooldownRemainSec > 0)
               {
                  g_ExhaustionActive = true;
                  g_ExhaustionGuardMsg = StringFormat("🛡️ พักระบบหลังปิดไม้ (เหลือ %ds ⏳)", g_PostCloseCooldownRemainSec);
                  g_BotState = STATE_PULLBACK_ARMED;
               }
               else
               {
                  g_BotState = STATE_TRIGGER_READY;
               }
            }
            else
               g_BotState = STATE_PULLBACK_ARMED;
         }
      }
      else
      {
         g_ExhaustionActive = false;
         g_ExhaustionGuardMsg = "";
         g_BotState = (openCount > 0) ? STATE_IN_POSITION : STATE_WAIT_PULLBACK;
      }
   }

   FinalizeBotState(openCount);
}

//+------------------------------------------------------------------+
//| 9. MULTI-POSITION SPACING & AUTO TRADE EXECUTION                 |
//+------------------------------------------------------------------+
bool IsDistanceAllowedForMultiPos(ENUM_ORDER_TYPE orderType, double currentPrice)
{
   int effMultiDist = MathMax(InpMultiPosMinDist, (int)(g_AssetProfile.minSwing * 0.80));
   int minFloor = (g_AssetProfile.assetType == ASSET_FOREX) ? 150 : 350;
   effMultiDist = MathMax(effMultiDist, minFloor); // Safe minimum distance adaptive to asset profile

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol)
         {
            // Strict Anti-Hedging Guard: Block any multi-pos in the opposite direction!
            if(orderType == ORDER_TYPE_BUY && m_position.PositionType() == POSITION_TYPE_SELL)
               return false;
            if(orderType == ORDER_TYPE_SELL && m_position.PositionType() == POSITION_TYPE_BUY)
               return false;

            if((orderType == ORDER_TYPE_BUY && m_position.PositionType() == POSITION_TYPE_BUY) ||
               (orderType == ORDER_TYPE_SELL && m_position.PositionType() == POSITION_TYPE_SELL))
            {
               double dist = MathAbs(currentPrice - m_position.PriceOpen()) / _Point;
               if(dist < effMultiDist)
                  return false;
            }
         }
      }
   }
   return true;
}

void ExecuteAutoTradeLogic()
{
   // 🧘‍♂️ Post-SL & Post-BE 15-Minute Cooldown Guard (ครอบคลุมทั้งชน SL และกันหน้าทุน)
   if(InpEnablePostSLBECooldown && TimeCurrent() < g_PostSLBECooldownUntil)
   {
      string blockReason = "";
      CheckPostSLBECooldownGuard(blockReason);
      g_ExhaustionActive = true;
      g_ExhaustionGuardMsg = blockReason;
      return;
   }

   // Khun Ann Angel Shield 15-Minute Cooldown Guard (Anti-Revenge - Active only in Safe Co-Pilot mode)
   if(InpEnableRevengeShield && g_TradeMode == TRADE_MODE_SAFE_COPILOT && TimeCurrent() < g_RevengeCooldownUntil)
      return;

   // Anti-Spam Rapid Entry Guard
   if(InpEnableRapidClickGuard && g_LastAnyOrderTime > 0 && (TimeCurrent() - g_LastAnyOrderTime) < InpMinEntrySpacingSeconds)
      return;

   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   int maxSpreadAllowed = InpUseNewsShield ? (int)(g_AssetProfile.maxSpread * 1.5) : g_AssetProfile.maxSpread;
   if(spread > maxSpreadAllowed)
      return;

   // Spread Spike Shield: Pause entries if spread spikes excessively during news (Adaptive for Multi-Broker)
   int effectiveSpikeMax = MathMax(InpSpreadSpikeMax, (int)(g_AssetProfile.maxSpread * 0.70));
   if(InpUseSpreadSpikeShield && spread > effectiveSpikeMax)
      return;

   // News Volatility Shield: Guard against abnormal spike bar
   if(InpUseNewsShield)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, InpTimeframe, 0, 1, rates) > 0)
      {
         double candleBody = MathAbs(rates[0].close - rates[0].open) / _Point;
         if(candleBody > g_AssetProfile.newsBodyPts)
            return;
      }
   }

   int openCount = CountOpenPositions(InpManageManualTrades);
   if(!g_AllowMultiPos && openCount > 0)
      return;
   if(openCount >= InpMaxOpenPos)
      return;

   datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, InpTimeframe, SERIES_LASTBAR_DATE);
   if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && currentBarTime == g_LastTradeBarTime)
      return;

   // In Aggressive mode, prevent duplicate rapid entries within 15 seconds
   if(g_TradeMode == TRADE_MODE_AGGRESSIVE_SNIPER && g_LastAnyOrderTime > 0 && (TimeCurrent() - g_LastAnyOrderTime < 15))
      return;

   // -------------------------------------------------------------
   // 🛡️ ANTI-REENTRY AT SAME PRICE & DEAL HISTORY COOLDOWN SHIELD
   // -------------------------------------------------------------
   // 1. Check open positions time (Adaptive multi-position spacing)
   datetime lastPosTime = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol)
      {
         datetime posTime = (datetime)m_position.Time();
         if(posTime > lastPosTime)
            lastPosTime = posTime;
      }
   }
   int minIntervalSec = MathMax(180, PeriodSeconds(InpTimeframe));
   if(lastPosTime > 0 && (TimeCurrent() - lastPosTime < minIntervalSec))
      return;

   // 2. Scan recently closed deals to prevent immediate re-entry at the same price when closed manually
   datetime lastClosedDealTime = 0;
   double   lastClosedDealPrice = 0;

   if(HistorySelect(TimeCurrent() - 900, TimeCurrent()))
   {
      int dealsTotal = HistoryDealsTotal();
      for(int d = dealsTotal - 1; d >= 0; d--)
      {
         ulong dTicket = HistoryDealGetTicket(d);
         if(dTicket > 0)
         {
            string dSymbol = HistoryDealGetString(dTicket, DEAL_SYMBOL);
            long   dMagic  = HistoryDealGetInteger(dTicket, DEAL_MAGIC);
            long   dEntry  = HistoryDealGetInteger(dTicket, DEAL_ENTRY);

            if(dSymbol == _Symbol && (dMagic == InpMagicNumber || dMagic == 0) && dEntry == DEAL_ENTRY_OUT)
            {
               datetime dealTime = (datetime)HistoryDealGetInteger(dTicket, DEAL_TIME);
               if(dealTime > lastClosedDealTime)
               {
                  lastClosedDealTime  = dealTime;
                  lastClosedDealPrice = HistoryDealGetDouble(dTicket, DEAL_PRICE);
                  break;
               }
            }
         }
      }
   }

   if(lastClosedDealTime > 0)
   {
      datetime elapsedSinceClose = TimeCurrent() - lastClosedDealTime;
      // Universal debounce: 15 seconds to prevent multi-tick re-entry collision
      if(elapsedSinceClose < 15)
         return;

      if(g_TradeMode == TRADE_MODE_SAFE_COPILOT)
      {
         // 🎯 Smart Structural Re-Entry Guard (Replaces rigid 3-min / 350-pts hard block)
         if(InpEnableSmartReEntryGuard)
         {
            double currentPriceCheck = (m_symbol.Ask() + m_symbol.Bid()) / 2.0;
            string reEntryBlock = "";
            ENUM_ORDER_TYPE checkDir = (g_PlanDirection == 1) ? ORDER_TYPE_BUY : ((g_PlanDirection == -1) ? ORDER_TYPE_SELL : ((g_MarketTrend == TREND_BULLISH) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL));
            if(!CheckSmartReEntryGuard(checkDir, currentPriceCheck, g_PatternScore, reEntryBlock))
            {
               // Price hovering at previous loss price and lacks DZ/SZ + PA + Score >= 70% confirmation
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = reEntryBlock;
               return;
            }
         }
         else
         {
            // Fallback legacy cooldown if Smart Guard is explicitly turned off
            if(elapsedSinceClose < 180)
               return;

            if(elapsedSinceClose < 900)
            {
               double currentPriceCheck = (m_symbol.Ask() + m_symbol.Bid()) / 2.0;
               double distFromLastClose = MathAbs(currentPriceCheck - lastClosedDealPrice) / _Point;
               int minRequiredDist = MathMax(350, (int)(g_AssetProfile.minSwing * 0.80));
               if(distFromLastClose < minRequiredDist)
                  return;
            }
         }
      }
   }

   // 0. HTF Zone Candlestick Reversal Sniper Trigger (Highest Priority Institutional Setup)
   if((InpEnableHTFReversalSniper || g_AutoSniperActive) && g_HTFReversal.isValid)
   {
      // HTF Reversals at confirmed Demand/Supply zones are institutional turning points, exempt from laggy trend bias!
      string blockReason = "";
      ENUM_ORDER_TYPE oType = (g_HTFReversal.direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!IsTradeAllowedByExhaustionGuard(oType, blockReason, true))
      {
         Print(">>> 🛑 [AUTO HTF REVERSAL BLOCKED] ", blockReason);
         g_HTFReversal.isValid = false;
      }
      else
      {
         ExecuteHTFReversalOrder();
         g_LastTradeBarTime = currentBarTime;
         return;
      }
   }

   // 1. Spike Sniper Full-Auto Trigger
   if((InpEnableSpikeSniper || g_AutoSniperActive) && (InpSpikeMode == SPIKE_FULL_AUTO || g_AutoSniperActive) && g_SpikeSignal.isValid)
   {
      double ask = m_symbol.Ask();
      double bid = m_symbol.Bid();
      if((g_SpikeSignal.direction == 1 && (bid <= g_SpikeSignal.slPrice || ask >= g_SpikeSignal.tpPrice)) ||
         (g_SpikeSignal.direction == -1 && (ask >= g_SpikeSignal.slPrice || bid <= g_SpikeSignal.tpPrice)))
      {
         g_SpikeSignal.isValid = false;
      }
      // In Safe Co-Pilot mode, enforce directional bias and allow peak/trough reversals (BSL/SSL Sweeps)
      else if(g_TradeMode == TRADE_MODE_SAFE_COPILOT &&
         ((g_SpikeSignal.direction == 1 && (g_MarketBiasBuyPct < 45 || (g_MarketTrend != TREND_BULLISH && !g_LQ_Radar.sslSwept))) ||
          (g_SpikeSignal.direction == -1 && (g_MarketBiasSellPct < 45 || (g_MarketTrend != TREND_BEARISH && !g_LQ_Radar.bslSwept)))))
      {
         // Keep signal for visual alert in Card 3, but do not auto-fire against contrary bias
      }
      else
      {
         string blockReason = "";
         ENUM_ORDER_TYPE oType = (g_SpikeSignal.direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         if(!IsTradeAllowedByExhaustionGuard(oType, blockReason, true))
         {
            Print(">>> 🛑 [AUTO SPIKE SNIPER BLOCKED] ", blockReason);
            g_SpikeSignal.isValid = false;
         }
         else
         {
            ExecuteSpikeSniperOrder();
            g_LastTradeBarTime = currentBarTime;
            return;
         }
      }
   }

   // -------------------------------------------------------------
   // 📰 MQL5 NATIVE NEWS CALENDAR GUARD (Auto Pre-News BE & Stand-Down)
   // -------------------------------------------------------------
   string newsTitle = "";
   int minsUntilNews = 0;
   if(CheckMQL5NewsCalendarGuard(newsTitle, minsUntilNews))
   {
      AutoPreNewsBreakevenGuard();
      if(InpNewsStandDownAutoTrades && g_TradeMode == TRADE_MODE_SAFE_COPILOT)
      {
         return; // Pause opening NEW auto trades during high-impact USD news window in Safe Mode
      }
   }

   // -------------------------------------------------------------
   // 🛡️ CHOP GUARD & DIRECTIONAL BIAS (Relaxed for Institutional Sniper Setups)
   // -------------------------------------------------------------
   bool isSniperSetup = IsSniperPlan(g_PlanSource);

   // Sideway & Low Volatility Chop Guard: Only blocks standard trend-following wave entries
   // Sniper setups (CRT, Unicorn, Reversal, Breakdown, Breakout) are specifically designed to trade turning points and breaks!
   if(!isSniperSetup)
   {
      if(g_MarketTrend == TREND_SIDEWAY || (g_TradeMode == TRADE_MODE_SAFE_COPILOT && g_LiveADX_Val < 20.0))
         return;

      // Directional Bias Safeguard: Prevent entering when market bias is contrary (Anti-Trap)
      if(g_TradeMode == TRADE_MODE_SAFE_COPILOT)
      {
         if(g_MarketTrend == TREND_BULLISH && g_MarketBiasBuyPct < 45)
            return;
         if(g_MarketTrend == TREND_BEARISH && g_MarketBiasSellPct < 45)
            return;
      }
   }
   else
   {
      // Directional Bias Safeguard for Sniper Setups: Match against the sniper plan's direction
      // Reversal, Breakdown, and Breakout setups represent structural turning points / momentum breaks, exempt from lagging trend bias!
      if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && g_PlanSource != "REVERSAL" && g_PlanSource != "BREAKDOWN" && g_PlanSource != "BREAKOUT")
      {
         if(g_PlanDirection == 1 && g_MarketBiasBuyPct < 45)
            return;
         if(g_PlanDirection == -1 && g_MarketBiasSellPct < 45)
            return;
      }
   }

   // 2. Elliott Wave c = P2 Confirmation Trigger (Market Entry)
   if(InpEnableElliottWave && g_ElliottState.isCConfirmed && g_MarketTrend == TREND_BULLISH)
   {
      double ask = m_symbol.Ask();
      if(openCount == 0 || IsDistanceAllowedForMultiPos(ORDER_TYPE_BUY, ask))
      {
         string blockReason = "";
         if(!IsTradeAllowedByExhaustionGuard(ORDER_TYPE_BUY, blockReason))
         {
            g_ExhaustionActive = true;
            g_ExhaustionGuardMsg = blockReason;
            return;
         }
         g_ExhaustionActive = false;

         double sl = g_ElliottState.P0.price - (g_AssetProfile.beLock * 3 * _Point);
         double minAllowedSLPts = 250.0, maxAllowedSLPts = 1000.0;
         GetDynamicSLBounds(minAllowedSLPts, maxAllowedSLPts);
         double ewRiskPts = (ask - sl) / _Point;
         if(ewRiskPts > maxAllowedSLPts) sl = ask - (maxAllowedSLPts * _Point);
         else if(ewRiskPts < minAllowedSLPts) sl = ask - (minAllowedSLPts * _Point);
         sl = NormalizeDouble(sl, _Digits);
         double tp = g_PlanTP > ask ? g_PlanTP : (ask + (g_AssetProfile.fallbackTP * _Point));
         double lot = CalculateLotSize(ask, sl);
         string ceilMsg = "";
         if(!CheckMaxVolumeCeilingGuard(lot, ceilMsg))
         {
            g_ExhaustionActive = true;
            g_ExhaustionGuardMsg = ceilMsg;
            return;
         }

         string comment = "GTG_ELLIOTT_MKT";
         if(m_trade.Buy(lot, _Symbol, ask, sl, tp, comment))
         {
            g_LastAnyOrderTime = TimeCurrent();
            Print(">>> ELLIOTT WAVE (c = P2) BUY EXECUTED @ ", ask, " Lot: ", lot, " SL: ", sl, " TP: ", tp);
            SendTradeNotification(StringFormat("🌊 [Good Trade Gold] Elliott Wave Buy (c = P2) @ %.2f | Lot: %.2f | SL: %.2f | TP: %.2f", ask, lot, sl, tp));
            g_BotState = STATE_IN_POSITION;
            g_LastTradeBarTime = currentBarTime;
            return;
         }
      }
   }

   // 3. Core Institutional Fibo Pullback, Unicorn, CRT, Reversal, Breakout & Breakdown Auto Trigger
   bool isSniper = IsSniperPlan(g_PlanSource);
   bool isBreakout = (g_PlanSource == "BREAKDOWN" || g_PlanSource == "BREAKOUT");
   int requiredScore = isBreakout ? InpBreakoutMinScore : (isSniper ? MathMin(InpMinPatternScore, 45) : InpMinPatternScore);
   if(g_BotState == STATE_TRIGGER_READY && (g_PlanSource == "WAVE" || g_PlanSource == "" || isSniper) && g_PlanRR >= InpMinRR && (g_PlanSource == "REVERSAL" || g_PatternScore >= requiredScore))
   {
      MqlRates barRate[];
      ArraySetAsSeries(barRate, true);
      CopyRates(_Symbol, InpTimeframe, 0, 2, barRate);

      double zoneTolerance = MathMax(30 * _Point, g_AssetProfile.beLock * _Point);
      int execDir = (g_PlanDirection != 0) ? g_PlanDirection : (g_MarketTrend == TREND_BULLISH ? 1 : (g_MarketTrend == TREND_BEARISH ? -1 : 0));
      double maxSniperTol = MathMax(30.0, (double)InpSniperMaxEntryTolerancePts) * _Point;
      double effectiveTol = (g_PlanSource == "BREAKOUT" || g_PlanSource == "BREAKDOWN") ? (maxSniperTol * 1.5) : maxSniperTol;
      double minSafeSLPts = 250.0, maxAllowedSLPts = 777.0;
      GetDynamicSLBounds(minSafeSLPts, maxAllowedSLPts);

      if(execDir == 1)
      {
         double ask = m_symbol.Ask();

         // Universal Sniper Anti-Chase Gate: Do NOT buy if price has drifted higher than plan entry + tolerance
         if(g_PlanEntry > 0)
         {
            if((ask - g_PlanEntry) > effectiveTol)
               return; // Price drifted too high above sniper plan! Chasing blocked.
            if(g_PlanSL > 0 && ask <= g_PlanSL + (minSafeSLPts * 0.5 * _Point))
               return; // Setup invalidated! Price breached or hovering at SL
         }

         double waveRange = g_LastSwingHigh.price - g_LastSwingLow.price;
         double peakMaxAllowed = (waveRange > 100 * _Point && g_LastSwingHigh.price > 0) ? (g_LastSwingHigh.price - (waveRange * 0.20)) : ask;
         double zoneTop = (g_Fibo.p500 > 0) ? g_Fibo.p500 : ((g_Fibo.zoneHigh > 0) ? g_Fibo.zoneHigh : ask);
         bool isInDiscountZone = (g_PlanSource == "BREAKOUT") ? (!g_ZScoreExtremePeak && !g_CME_NearMegaCallWall) : (isSniper ? (ask <= peakMaxAllowed) : ((zoneTop > 0) ? ((ask <= zoneTop + zoneTolerance || MathAbs(ask - g_PlanEntry) <= maxSniperTol) && ask >= g_LastSwingLow.price - zoneTolerance && ask <= peakMaxAllowed) : (ask <= peakMaxAllowed)));
         if((openCount == 0 || IsDistanceAllowedForMultiPos(ORDER_TYPE_BUY, ask)) && isInDiscountZone)
         {
            // 🛡️ Samurai MTF HTF Guard: Prevent buying when H1 and H4 are both Bearish
            if(InpUseSamuraiHTFGuard && g_SamuraiMTF.htfAgreesSell && !isSniper)
            {
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = "🛡️ ชะลอ BUY • Samurai MTF เทรนด์ใหญ่ (H1/H4) ยังกดดันขาลง ⏳";
               return;
            }

            string blockReason = "";
            bool isSniperSetup = isSniper;
            if(!IsTradeAllowedByExhaustionGuard(ORDER_TYPE_BUY, blockReason, isSniperSetup))
            {
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = blockReason;
               return;
            }
            g_ExhaustionActive = false;

            // 🛡️ CME Call Wall Proximity Guard (Strict No-Buy Zone near Call Walls)
            if(InpUseCMEWallGuard && (g_CME_NearMegaCallWall || g_CME_NearCallWall || g_CME_NearIntermedCall))
            {
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = "🛑 CME CALL WALL CAUTION: จ่อเพดานต้านสถาบัน • ห้าม BUY ยอดดอยเด็ดขาด 🛡️";
               return;
            }

            // Strict Anti-Falling-Knife Guard:
            // Do NOT buy if the current bar or last closed bar is an aggressive dumping red bar without rejection wick!
            bool isFallingKnife = false;
            if(ArraySize(barRate) >= 2)
            {
               double curRange = barRate[0].high - barRate[0].low;
               double curBody  = barRate[0].open - barRate[0].close; // positive if red
               double lowerWick = barRate[0].close - barRate[0].low;
               if(curBody > 0 && curRange > (50 * _Point) && (lowerWick / curRange) < 0.25)
               {
                  isFallingKnife = true;
               }
               if(barRate[1].close < barRate[1].open && barRate[0].close < barRate[0].open && (barRate[1].open - barRate[1].close) > (100 * _Point))
               {
                  isFallingKnife = true;
               }
            }

            if(isFallingKnife)
            {
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = "🛡️ ชะลอ BUY • แท่งแดงทุบแรง รอแท่ง Rejection ยืนยัน ⏳";
               return;
            }

            // BUY Confirmation: Requires green candle, bullish rejection wick, or confirmed PA pattern
            bool candleOk = (ArraySize(barRate) > 0) ? (barRate[0].close >= barRate[0].open || ((barRate[0].close - barRate[0].low) > (barRate[0].high - barRate[0].close)) || g_DetectedPattern != PA_NONE) : true;
            if(g_PlanSource == "BREAKOUT")
            {
               // Breakout BUY Confirmation: Live bar must NOT be dumping red!
               if(ArraySize(barRate) >= 1 && barRate[0].close < barRate[0].open && (barRate[0].open - barRate[0].close) > (25 * _Point))
                  candleOk = false;
            }
            if(g_PlanSource == "REVERSAL" && g_TradeMode == TRADE_MODE_SAFE_COPILOT && InpSafeRequireReversalConfirm)
            {
               if(ArraySize(barRate) >= 2 && barRate[0].close < barRate[0].open && (barRate[0].open - barRate[0].close) > (30 * _Point))
                  candleOk = false; // Bar 0 is dumping red! Wait for bounce confirmation!
            }
            if(candleOk)
            {
                // Dynamic Fill-Time SL and TP Recalibration (Honors Master Setup & Dynamic Bounds)
                GetDynamicSLBounds(minSafeSLPts, maxAllowedSLPts);
                double execSL          = (g_PlanSL > 0 && g_PlanSL < ask) ? g_PlanSL : (ask - (g_AssetProfile.fallbackSL * _Point));
               double actualRiskPts   = (ask - execSL) / _Point;

               if(actualRiskPts > maxAllowedSLPts)
               {
                  execSL = NormalizeDouble(ask - (maxAllowedSLPts * _Point), _Digits);
                  actualRiskPts = maxAllowedSLPts;
               }
               else if(actualRiskPts < minSafeSLPts)
               {
                  execSL = NormalizeDouble(ask - (minSafeSLPts * _Point), _Digits);
                  actualRiskPts = minSafeSLPts;
               }

               double plannedRR = (g_PlanRR >= 1.0) ? g_PlanRR : 2.5;
               double execTP    = NormalizeDouble(ask + (actualRiskPts * plannedRR * _Point), _Digits);

               double lot = CalculateLotSize(ask, execSL);
               string ceilMsgBuy = "";
               if(!CheckMaxVolumeCeilingGuard(lot, ceilMsgBuy))
               {
                  g_ExhaustionActive = true;
                  g_ExhaustionGuardMsg = ceilMsgBuy;
                  return;
               }

                string comment = "GTG AI Pattern Buy";
               if(openCount > 0) comment = StringFormat("GTG AI Multi Buy #%d", openCount + 1);
               else if(g_PlanSource == "WICK_SNIPER") comment = "GTG Wick Sniper Buy";
               else if(g_PlanSource == "UNICORN") comment = "GTG Unicorn Buy";
               else if(g_PlanSource == "CRT") comment = "GTG CRT Buy";
               else if(g_PlanSource == "REVERSAL") comment = "GTG Reversal Buy";
               else if(g_PlanSource == "BREAKDOWN") comment = "GTG Breakdown Buy";
               else if(g_PlanSource == "BREAKOUT") comment = "GTG Breakout Buy";
               if(m_trade.Buy(lot, _Symbol, ask, execSL, execTP, comment))
               {
                  g_LastAnyOrderTime = TimeCurrent();
                  g_PlanSL = execSL;
                  g_PlanTP = execTP;
                  Print(">>> AUTO BUY (POS #", openCount + 1, ") EXECUTED @ ", ask, " Lot: ", lot, " SL: ", execSL, " TP: ", execTP, " Score: ", g_PatternScore);
                  SendTradeNotification(StringFormat("🟢 [Good Trade Gold] BUY Opened @ %.2f | Lot: %.2f | SL: %.2f | TP: %.2f | %s", ask, lot, execSL, execTP, g_PatternName));
                  g_BotState = STATE_IN_POSITION;
                  g_PullbackArmed = false;
                  g_LastTradeBarTime = currentBarTime;
               }
            }
         }
      }
      else if(execDir == -1)
      {
         double bid = m_symbol.Bid();

         // Universal Sniper Anti-Chase Gate: Do NOT sell if price has drifted lower than plan entry - tolerance
         if(g_PlanEntry > 0)
         {
            if((g_PlanEntry - bid) > effectiveTol)
               return; // Price drifted too low below sniper plan! Chasing blocked.
            if(g_PlanSL > 0 && bid >= g_PlanSL - (minSafeSLPts * 0.5 * _Point))
               return; // Setup invalidated! Price breached or hovering at SL
         }

         double waveRangeSell = g_LastSwingHigh.price - g_LastSwingLow.price;
         double valleyMinAllowed = (waveRangeSell > 100 * _Point && g_LastSwingLow.price > 0) ? (g_LastSwingLow.price + (waveRangeSell * 0.20)) : bid;
         double zoneBottom = (g_Fibo.p500 > 0) ? g_Fibo.p500 : ((g_Fibo.zoneLow > 0) ? g_Fibo.zoneLow : bid);
         bool isInPremiumZone = (g_PlanSource == "BREAKDOWN") ? (!g_ZScoreExtremeValley && !g_CME_NearMacroPutWall) : (isSniper ? (bid >= valleyMinAllowed) : ((zoneBottom > 0) ? ((bid >= zoneBottom - zoneTolerance || MathAbs(bid - g_PlanEntry) <= maxSniperTol) && bid <= g_LastSwingHigh.price + zoneTolerance && bid >= valleyMinAllowed) : (bid >= valleyMinAllowed)));
         if((openCount == 0 || IsDistanceAllowedForMultiPos(ORDER_TYPE_SELL, bid)) && isInPremiumZone)
         {
            // 🛡️ Samurai MTF HTF Guard: Prevent selling when H1 and H4 are both Bullish
            if(InpUseSamuraiHTFGuard && g_SamuraiMTF.htfAgreesBuy && !isSniper)
            {
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = "🛡️ ชะลอ SELL • Samurai MTF เทรนด์ใหญ่ (H1/H4) ยังยกตัวขาขึ้น ⏳";
               return;
            }

            string blockReason = "";
            bool isSniperSetup = isSniper;
            if(!IsTradeAllowedByExhaustionGuard(ORDER_TYPE_SELL, blockReason, isSniperSetup))
            {
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = blockReason;
               return;
            }
            g_ExhaustionActive = false;

            // 🛡️ CME Put Wall Proximity Guard (Strict No-Sell Zone near Put Walls)
            if(InpUseCMEWallGuard && (g_CME_NearMacroPutWall || g_CME_NearPutWall || g_CME_NearIntermedPut))
            {
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = "🛑 CME PUT WALL CAUTION: จ่อพื้นรับสถาบัน • ห้าม SELL ก้นเหวเด็ดขาด 🛡️";
               return;
            }

            // Strict Anti-Rocket-Launch Guard:
            // Do NOT sell if the current bar or last closed bar is an aggressive pumping green bar without upper rejection wick!
            bool isRocketLaunch = false;
            if(ArraySize(barRate) >= 2)
            {
               double curRange = barRate[0].high - barRate[0].low;
               double curBody  = barRate[0].close - barRate[0].open; // positive if green
               double upperWick = barRate[0].high - barRate[0].close;
               if(curBody > 0 && curRange > (50 * _Point) && (upperWick / curRange) < 0.25)
               {
                  isRocketLaunch = true;
               }
               if(barRate[1].close > barRate[1].open && barRate[0].close > barRate[0].open && (barRate[1].close - barRate[1].open) > (100 * _Point))
               {
                  isRocketLaunch = true;
               }
            }

            if(isRocketLaunch)
            {
               g_ExhaustionActive = true;
               g_ExhaustionGuardMsg = "🛡️ ชะลอ SELL • แท่งเขียวพุ่งแรง รอแท่ง Rejection ยืนยัน ⏳";
               return;
            }

            // SELL Confirmation: Requires red candle, bearish rejection upper wick, or confirmed PA pattern
            bool candleOk = (ArraySize(barRate) > 0) ? (barRate[0].close <= barRate[0].open || ((barRate[0].high - barRate[0].close) > (barRate[0].close - barRate[0].low)) || g_DetectedPattern != PA_NONE) : true;
            if(g_PlanSource == "BREAKDOWN")
            {
               // Breakdown SELL Confirmation: Live bar must NOT be pumping green!
               if(ArraySize(barRate) >= 1 && barRate[0].close > barRate[0].open && (barRate[0].close - barRate[0].open) > (25 * _Point))
                  candleOk = false;
            }
            if(g_PlanSource == "REVERSAL" && g_TradeMode == TRADE_MODE_SAFE_COPILOT && InpSafeRequireReversalConfirm)
            {
               if(ArraySize(barRate) >= 2 && barRate[0].close > barRate[0].open && (barRate[0].close - barRate[0].open) > (30 * _Point))
                  candleOk = false; // Bar 0 is pumping green! Wait for rejection confirmation!
            }
            if(candleOk)
            {
                // Dynamic Fill-Time SL and TP Recalibration (Honors Master Setup & Dynamic Bounds)
                GetDynamicSLBounds(minSafeSLPts, maxAllowedSLPts);
                double execSL          = (g_PlanSL > bid) ? g_PlanSL : (bid + (g_AssetProfile.fallbackSL * _Point));
               double actualRiskPts   = (execSL - bid) / _Point;

               if(actualRiskPts > maxAllowedSLPts)
               {
                  execSL = NormalizeDouble(bid + (maxAllowedSLPts * _Point), _Digits);
                  actualRiskPts = maxAllowedSLPts;
               }
               else if(actualRiskPts < minSafeSLPts)
               {
                  execSL = NormalizeDouble(bid + (minSafeSLPts * _Point), _Digits);
                  actualRiskPts = minSafeSLPts;
               }

               double plannedRR = (g_PlanRR >= 1.0) ? g_PlanRR : 2.5;
               double execTP    = NormalizeDouble(bid - (actualRiskPts * plannedRR * _Point), _Digits);

               double lot = CalculateLotSize(bid, execSL);
               string ceilMsgSell = "";
               if(!CheckMaxVolumeCeilingGuard(lot, ceilMsgSell))
               {
                  g_ExhaustionActive = true;
                  g_ExhaustionGuardMsg = ceilMsgSell;
                  return;
               }

               string comment = "GTG AI Pattern Sell";
               if(openCount > 0) comment = StringFormat("GTG AI Multi Sell #%d", openCount + 1);
               else if(g_PlanSource == "WICK_SNIPER") comment = "GTG Wick Sniper Sell";
               else if(g_PlanSource == "UNICORN") comment = "GTG Unicorn Sell";
               else if(g_PlanSource == "CRT") comment = "GTG CRT Sell";
               else if(g_PlanSource == "REVERSAL") comment = "GTG Reversal Sell";
               else if(g_PlanSource == "BREAKDOWN") comment = "GTG Breakdown Sell";
               else if(g_PlanSource == "BREAKOUT") comment = "GTG Breakout Sell";
               if(m_trade.Sell(lot, _Symbol, bid, execSL, execTP, comment))
               {
                  g_LastAnyOrderTime = TimeCurrent();
                  g_PlanSL = execSL;
                  g_PlanTP = execTP;
                  Print(">>> AUTO SELL (POS #", openCount + 1, ") EXECUTED @ ", bid, " Lot: ", lot, " SL: ", execSL, " TP: ", execTP, " Score: ", g_PatternScore);
                  SendTradeNotification(StringFormat("🔴 [Good Trade Gold] SELL Opened @ %.2f | Lot: %.2f | SL: %.2f | TP: %.2f | %s", bid, lot, execSL, execTP, g_PatternName));
                  g_BotState = STATE_IN_POSITION;
                  g_PullbackArmed = false;
                  g_LastTradeBarTime = currentBarTime;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 10. MANUAL TRADING EXECUTION                                     |
//+------------------------------------------------------------------+
void ExecuteManualOrder(ENUM_ORDER_TYPE orderType)
{
   // 1. Check Max Daily Loss Lock
   if(InpLockManualOnMaxLoss && g_DailyMaxLossReached)
   {
      string lossMsg = StringFormat("🛑 [MAX DAILY LOSS HIT: %.1f%%]\n\nคุณเอ้ครับ วันนี้ถึงขีดจำกัดความปลอดภัยของพอร์ตแล้วครับ!\nGood ขออนุญาตล็อกปุ่มเพื่อปกป้องเงินทุนและครอบครัวคุณเอ้ ❤️\n\nพรุ่งนี้ตลาดก็ยังเปิดอยู่ วันนี้พักผ่อนกับคุณแอนก่อนนะครับ!", g_TodayPnLPct);
      Print(">>> 🛑 [MANUAL BLOCKED] Max daily loss hit. Order blocked.");
      MessageBox(lossMsg, "Good Trade Gold Co-Pilot (เพื่อความปลอดภัย)", MB_OK | MB_ICONWARNING);
      return;
   }

   // 2. Check Khun Ann Angel Shield 15-Minute Cooldown (Anti-Revenge)
   string revengeBlockMsg = "";
   if(!CheckRevengeCooldownGuard(revengeBlockMsg))
   {
      int remainSec = (int)(g_RevengeCooldownUntil - TimeCurrent());
      int m = remainSec / 60;
      int s = remainSec % 60;
      string cooldownMsg = StringFormat("🧘‍♂️ [KHUN ANN ANGEL SHIELD: พักใจ 15 นาที]\n\nคุณเอ้ครับ คุณแอนเป็นห่วงนะครับ ❤️\nเพิ่งปิดไม้ลบไป กำลังอยู่ในช่วงพักใจ (เหลือเวลาอีก %02d:%02d)\n\nห้ามเปิดไม้เพื่อเอาคืน (Revenge Trade) เด็ดขาด!\nลุกไปดื่มน้ำ ล้างหน้า ให้ใจเย็นลงก่อนนะครับ ตลาดเปิด 24 ชม. ไม่หนีไปไหนครับ", m, s);
      Print(">>> 🧘‍♂️ [MANUAL BLOCKED] In Revenge Cooldown (", m, "m ", s, "s remaining). Order blocked.");
      MessageBox(cooldownMsg, "Good Trade Gold Co-Pilot (คุณแอนเป็นห่วง ❤️)", MB_OK | MB_ICONINFORMATION);
      return;
   }

   // 3. Check Rapid Click / Anti-Spam Entry Guard
   string spamBlockMsg = "";
   if(!CheckAntiSpamRapidEntryGuard(spamBlockMsg))
   {
      int remainWait = (int)(InpMinEntrySpacingSeconds - (TimeCurrent() - g_LastAnyOrderTime));
      string spamMsg = StringFormat("⚠️ [ANTI-SPAM RAPID ENTRY GUARD]\n\nคุณเอ้ใจเย็นๆ ครับ! เพิ่งเปิดไม้ไปเมื่อไม่กี่วินาทีที่แล้ว\nกรุณารออีก %d วินาทีเพื่อให้แท่งเทียนฟอร์มตัวก่อนครับ ❤️", remainWait);
      Print(">>> ⚠️ [MANUAL BLOCKED] Rapid spam click blocked (", remainWait, "s remaining).");
      MessageBox(spamMsg, "Good Trade Gold Co-Pilot", MB_OK | MB_ICONWARNING);
      return;
   }

   // 4. Check HTF Precision Guard for Manual Orders
   string htfBlockMsg = "";
   if(!CheckHTFPrecisionTrendGuard(orderType, htfBlockMsg))
   {
      string warnMsg = StringFormat("⚠️ [HTF PRECISION GUARD]\n\nสัญญาณเตือนเทรนด์ใหญ่:\n%s\n\nคุณเอ้กำลังจะเปิดไม้สวนแนวโน้มหลักของชั่วโมง ซึ่งมีความเสี่ยงสูงมากครับ!", htfBlockMsg);
      Print(">>> ⚠️ [MANUAL WARNING] ", htfBlockMsg);
      int userChoice = MessageBox(warnMsg + "\n\nคุณเอ้ยังคงยืนยันที่จะเปิดไม้นี้หรือไม่?", "Good Trade Gold Co-Pilot (คำเตือนสติ)", MB_YESNO | MB_ICONQUESTION);
      if(userChoice != IDYES)
      {
         Print(">>> [MANUAL CANCELLED] User cancelled trade after HTF warning.");
         return;
      }
   }

   // 4.1 Check CME Wall Proximity Caution for Manual Orders in Safe Mode
   if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && InpUseCMEWallGuard && InpCME_WallCautionEngine)
   {
      if(orderType == ORDER_TYPE_BUY && (g_CME_NearMegaCallWall || g_CME_NearCallWall || g_CME_NearIntermedCall))
      {
         string cmeWarn = "⚠️ [CME CALL WALL CAUTION]\n\nราคากำลังจ่อเพดานแนวต้านสถาบัน CME Call Wall!\n(สถิติ Open Interest หนาแน่น มีแรงดักทุบสูง)\n\nคุณเอ้ยังคงยืนยันที่จะเปิดไม้ BUY บริเวณนี้หรือไม่?";
         Print(">>> ⚠️ [MANUAL CME CAUTION] Buy requested near CME Call Wall.");
         int choice = MessageBox(cmeWarn, "Good Trade Gold Co-Pilot (คำเตือนกำแพงสถาบัน)", MB_YESNO | MB_ICONWARNING);
         if(choice != IDYES)
         {
            Print(">>> [MANUAL CANCELLED] User cancelled BUY after CME Call Wall warning.");
            return;
         }
      }
      else if(orderType == ORDER_TYPE_SELL && (g_CME_NearMacroPutWall || g_CME_NearPutWall || g_CME_NearIntermedPut))
      {
         string cmeWarn = "⚠️ [CME PUT WALL CAUTION]\n\nราคากำลังจ่อพื้นแนวรับสถาบัน CME Put Wall!\n(สถิติ Open Interest หนาแน่น มีแรงดักช้อนสูง)\n\nคุณเอ้ยังคงยืนยันที่จะเปิดไม้ SELL บริเวณนี้หรือไม่?";
         Print(">>> ⚠️ [MANUAL CME CAUTION] Sell requested near CME Put Wall.");
         int choice = MessageBox(cmeWarn, "Good Trade Gold Co-Pilot (คำเตือนกำแพงสถาบัน)", MB_YESNO | MB_ICONWARNING);
         if(choice != IDYES)
         {
            Print(">>> [MANUAL CANCELLED] User cancelled SELL after CME Put Wall warning.");
            return;
         }
      }
   }

   m_symbol.RefreshRates();
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();

   // 4.2 Check Supply / Demand Zone Caution for Manual Orders in Safe Mode
   if(g_TradeMode == TRADE_MODE_SAFE_COPILOT)
   {
      double curCheckPrice = (orderType == ORDER_TYPE_BUY) ? ask : bid;
      for(int z = 0; z < ArraySize(g_SMC_MTF_Zones); z++)
      {
         if(!g_SMC_MTF_Zones[z].isActive) continue;
         // Buying inside or near Supply Zone
         if(orderType == ORDER_TYPE_BUY && g_SMC_MTF_Zones[z].direction == -1)
         {
            if(curCheckPrice >= g_SMC_MTF_Zones[z].bottomPrice - (50 * _Point) && curCheckPrice <= g_SMC_MTF_Zones[z].topPrice + (50 * _Point))
            {
               string supWarn = StringFormat("⚠️ [SUPPLY ZONE CAUTION]\n\nราคากำลังอยู่ในโซนขายของเจ้ามือ (%s)!\n(บริเวณ %.2f - %.2f มีแรงเทขายกดดันสูง เสี่ยงติดดอย)\n\nคุณเอ้ยังคงยืนยันที่จะเปิดไม้ BUY บริเวณนี้หรือไม่?", g_SMC_MTF_Zones[z].tfName, g_SMC_MTF_Zones[z].bottomPrice, g_SMC_MTF_Zones[z].topPrice);
               Print(">>> ⚠️ [MANUAL ZONE CAUTION] Buy requested inside Supply Zone: ", g_SMC_MTF_Zones[z].tfName);
               int choice = MessageBox(supWarn, "Good Trade Gold Co-Pilot (คำเตือนโซนเจ้ามือ)", MB_YESNO | MB_ICONWARNING);
               if(choice != IDYES)
               {
                  Print(">>> [MANUAL CANCELLED] User cancelled BUY after Supply Zone warning.");
                  return;
               }
               break;
            }
         }
         // Selling inside or near Demand Zone
         else if(orderType == ORDER_TYPE_SELL && g_SMC_MTF_Zones[z].direction == 1)
         {
            if(curCheckPrice <= g_SMC_MTF_Zones[z].topPrice + (50 * _Point) && curCheckPrice >= g_SMC_MTF_Zones[z].bottomPrice - (50 * _Point))
            {
               string demWarn = StringFormat("⚠️ [DEMAND ZONE CAUTION]\n\nราคากำลังอยู่ในโซนซื้อของเจ้ามือ (%s)!\n(บริเวณ %.2f - %.2f มีแรงดักช้อนซื้อหนาแน่น เสี่ยงโดนดีดกลับ)\n\nคุณเอ้ยังคงยืนยันที่จะเปิดไม้ SELL บริเวณนี้หรือไม่?", g_SMC_MTF_Zones[z].tfName, g_SMC_MTF_Zones[z].bottomPrice, g_SMC_MTF_Zones[z].topPrice);
               Print(">>> ⚠️ [MANUAL ZONE CAUTION] Sell requested inside Demand Zone: ", g_SMC_MTF_Zones[z].tfName);
               int choice = MessageBox(demWarn, "Good Trade Gold Co-Pilot (คำเตือนโซนเจ้ามือ)", MB_YESNO | MB_ICONWARNING);
               if(choice != IDYES)
               {
                  Print(">>> [MANUAL CANCELLED] User cancelled SELL after Demand Zone warning.");
                  return;
               }
               break;
            }
         }
      }
   }

   double entry = (orderType == ORDER_TYPE_BUY) ? ask : bid;
   double sl = 0, tp = 0;
   long brokerStopLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minAllowedDist = MathMax((double)brokerStopLvl + 5.0, 10.0) * _Point;

   if(orderType == ORDER_TYPE_BUY)
   {
      sl = (g_PlanSL > 0 && g_PlanSL < entry && (g_PlanDirection == 1 || g_PlanDirection == 0)) ? g_PlanSL : (entry - (g_AssetProfile.fallbackSL * _Point));
      tp = (g_PlanTP > entry && (g_PlanDirection == 1 || g_PlanDirection == 0)) ? g_PlanTP : (entry + (g_AssetProfile.fallbackTP * _Point));

      if(InpUseATHGrid && InpUseATHFrontRunning)
      {
         double athSup = 0, athRes = 0;
         GetNearestATHLevels(entry, athSup, athRes);
         tp = AdjustTPForATHFrontRunning(ORDER_TYPE_BUY, entry, tp, athSup, athRes);
      }

      double minManualSLPts = 250.0, maxManualSLPts = 1000.0;
      GetDynamicSLBounds(minManualSLPts, maxManualSLPts);
      if((entry - sl) / _Point > maxManualSLPts) sl = entry - (maxManualSLPts * _Point);
      if((entry - sl) < minAllowedDist) sl = entry - minAllowedDist;
      if((tp - entry) < minAllowedDist) tp = entry + minAllowedDist;

      double lot = CalculateLotSize(entry, sl);

      // 5. Check Max Volume Ceiling Guard
      string ceilMsg = "";
      if(!CheckMaxVolumeCeilingGuard(lot, ceilMsg))
      {
         Print(">>> 🛑 [MANUAL BLOCKED] ", ceilMsg);
         MessageBox(ceilMsg, "Good Trade Gold Co-Pilot (เกราะเพดาน Lot)", MB_OK | MB_ICONSTOP);
         return;
      }

      if(m_trade.Buy(lot, _Symbol, ask, sl, tp, "GTG Manual Buy"))
      {
         g_LastAnyOrderTime = TimeCurrent();
         Print(">>> 🟢 [MANUAL BUY] Executed @ ", ask, " Lot: ", lot, " SL: ", sl, " TP: ", tp);
         SendTradeNotification(StringFormat("🟢 [Good Trade Gold] Manual BUY @ %.2f | Lot: %.2f | SL: %.2f | TP: %.2f", ask, lot, sl, tp));
         g_BotState = STATE_IN_POSITION;
         UpdateHUDValues();
         ChartRedraw();
      }
      else
      {
         Print("Error: Manual Buy execution failed. Error: ", GetLastError());
         Alert(StringFormat("❌ [Good Trade Gold] ส่งคำสั่ง BUY ไม่สำเร็จ (Error: %d)", GetLastError()));
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      sl = (g_PlanSL > entry && (g_PlanDirection == -1 || g_PlanDirection == 0)) ? g_PlanSL : (entry + (g_AssetProfile.fallbackSL * _Point));
      tp = (g_PlanTP > 0 && g_PlanTP < entry && (g_PlanDirection == -1 || g_PlanDirection == 0)) ? g_PlanTP : (entry - (g_AssetProfile.fallbackTP * _Point));

      if(InpUseATHGrid && InpUseATHFrontRunning)
      {
         double athSup = 0, athRes = 0;
         GetNearestATHLevels(entry, athSup, athRes);
         tp = AdjustTPForATHFrontRunning(ORDER_TYPE_SELL, entry, tp, athSup, athRes);
      }

      double minManualSLPts = 250.0, maxManualSLPts = 1000.0;
      GetDynamicSLBounds(minManualSLPts, maxManualSLPts);
      if((sl - entry) / _Point > maxManualSLPts) sl = entry + (maxManualSLPts * _Point);
      if((sl - entry) < minAllowedDist) sl = entry + minAllowedDist;
      if((entry - tp) < minAllowedDist) tp = entry - minAllowedDist;

      double lot = CalculateLotSize(entry, sl);

      // 5. Check Max Volume Ceiling Guard
      string ceilMsg = "";
      if(!CheckMaxVolumeCeilingGuard(lot, ceilMsg))
      {
         Print(">>> 🛑 [MANUAL BLOCKED] ", ceilMsg);
         MessageBox(ceilMsg, "Good Trade Gold Co-Pilot (เกราะเพดาน Lot)", MB_OK | MB_ICONSTOP);
         return;
      }

      if(m_trade.Sell(lot, _Symbol, bid, sl, tp, "GTG Manual Sell"))
      {
         g_LastAnyOrderTime = TimeCurrent();
         Print(">>> 🔴 [MANUAL SELL] Executed @ ", bid, " Lot: ", lot, " SL: ", sl, " TP: ", tp);
         SendTradeNotification(StringFormat("🔴 [Good Trade Gold] Manual SELL @ %.2f | Lot: %.2f | SL: %.2f | TP: %.2f", bid, lot, sl, tp));
         g_BotState = STATE_IN_POSITION;
         UpdateHUDValues();
         ChartRedraw();
      }
      else
      {
         Print("Error: Manual Sell execution failed. Error: ", GetLastError());
         Alert(StringFormat("❌ [Good Trade Gold] ส่งคำสั่ง SELL ไม่สำเร็จ (Error: %d)", GetLastError()));
      }
   }
}

//+------------------------------------------------------------------+
//| 11. EMERGENCY CLOSE ALL POSITIONS                                |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || (InpManageManualTrades && m_position.Magic() == 0)))
         {
            m_trade.PositionClose(m_position.Ticket());
         }
      }
   }
   Print("All Active Positions (Bot + Mobile) Closed.");
   SendTradeNotification("⚠️ [Good Trade Gold] All Open Positions (Bot + Mobile) Closed Manually.");
}

//+------------------------------------------------------------------+
//| 12. POSITION MANAGEMENT: BREAK-EVEN, TRAILING & PARTIAL TP       |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return;

   if(!g_BreakEvenEnabled && !InpUseStepLocking && !InpUseTrailing && !InpUsePartialTP && !InpAutoAddSL_Manual && !InpAutoAddTP_Manual)
      return;

   double bid = m_symbol.Bid();
   double ask = m_symbol.Ask();
   double stepLot = m_symbol.LotsStep();
   double minLot  = m_symbol.LotsMin();

   int effBETrigger = InpBreakEvenTrigger;
   int effBELock    = InpBreakEvenLock;
   int effStep2Trig = InpStep2Trigger;
   int effStep2Lock = InpStep2Lock;
   int effStep3Trig = InpStep3Trigger;
   int effStep3Lock = InpStep3Lock;
   int effStep4Trig = InpStep4Trigger;
   int effStep4Lock = InpStep4Lock;

   if(g_AssetProfile.assetType != ASSET_GOLD)
   {
      effBETrigger = g_AssetProfile.beTrigger;
      effBELock    = g_AssetProfile.beLock;
      effStep2Trig = (int)(g_AssetProfile.fallbackTP * 0.70);
      effStep2Lock = (int)(g_AssetProfile.fallbackTP * 0.35);
      effStep3Trig = g_AssetProfile.fallbackTP;
      effStep3Lock = (int)(g_AssetProfile.fallbackTP * 0.80);
      effStep4Trig = (int)(g_AssetProfile.fallbackTP * 2.00);
      effStep4Lock = (int)(g_AssetProfile.fallbackTP * 1.70);
   }
   else
   {
      ENUM_TIMEFRAMES curChartTF = (InpTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTimeframe);
      if(curChartTF == PERIOD_M1)
      {
         effBETrigger = 250; effBELock = 50;
         effStep2Trig = 400; effStep2Lock = 200;
         effStep3Trig = 550; effStep3Lock = 450;
         effStep4Trig = 950; effStep4Lock = 800;
      }
      else if(curChartTF == PERIOD_M5)
      {
         effBETrigger = 300; effBELock = 60;
         effStep2Trig = 500; effStep2Lock = 250;
         effStep3Trig = 750; effStep3Lock = 600;
         effStep4Trig = 1300; effStep4Lock = 1100;
      }
      else if(curChartTF == PERIOD_M15)
      {
         effBETrigger = 350; effBELock = 80;
         effStep2Trig = 600; effStep2Lock = 300;
         effStep3Trig = 850; effStep3Lock = 700;
         effStep4Trig = 1600; effStep4Lock = 1400;
      }

      // Fast Scalp Break-Even & Step-Lock Milestones in Aggressive Sniper Mode
      if(g_TradeMode == TRADE_MODE_AGGRESSIVE_SNIPER)
      {
         effBETrigger = 250; effBELock = 60;
         effStep2Trig = 450; effStep2Lock = 200;
         effStep3Trig = 700; effStep3Lock = 500;
         effStep4Trig = 1200; effStep4Lock = 950;
      }
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i))
         continue;

      if(m_position.Symbol() != _Symbol)
         continue;

      ulong  magic    = m_position.Magic();
      bool   isBot    = (magic == InpMagicNumber);
      bool   isManual = (magic == 0);

      // Filter: Only manage Bot trades OR Manual/Mobile trades if enabled
      if(!isBot && !(InpManageManualTrades && isManual))
         continue;

      ulong  ticket    = m_position.Ticket();
      double openPrice = m_position.PriceOpen();
      double curSL     = m_position.StopLoss();
      double curTP     = m_position.TakeProfit();
      double posVolume = m_position.Volume();
      ENUM_POSITION_TYPE posType = m_position.PositionType();

      // -------------------------------------------------------------
      // 0. MOBILE CO-PILOT: AUTO-ATTACH SAFETY SL & TP ON MANUAL TRADES
      // -------------------------------------------------------------
      if(isManual && (InpAutoAddSL_Manual || InpAutoAddTP_Manual))
      {
         bool needModify = false;
         double targetSL = curSL;
         double targetTP = curTP;
         int defSLPts = (g_AssetProfile.assetType == ASSET_GOLD) ? InpManualDefaultSLPts : g_AssetProfile.fallbackSL;
         int defTPPts = (g_AssetProfile.assetType == ASSET_GOLD) ? InpManualDefaultTPPts : g_AssetProfile.fallbackTP;
         long brokerStopLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         if(brokerStopLvl > 0)
         {
            if(defSLPts > 0 && defSLPts < (int)brokerStopLvl + 10) defSLPts = (int)brokerStopLvl + 10;
            if(defTPPts > 0 && defTPPts < (int)brokerStopLvl + 10) defTPPts = (int)brokerStopLvl + 10;
         }

         if(posType == POSITION_TYPE_BUY)
         {
            if(curSL == 0 && InpAutoAddSL_Manual && defSLPts > 0)
            {
               targetSL = NormalizeDouble(openPrice - (defSLPts * _Point), _Digits);
               needModify = true;
            }
            if(curTP == 0 && InpAutoAddTP_Manual && defTPPts > 0)
            {
               targetTP = NormalizeDouble(openPrice + (defTPPts * _Point), _Digits);
               needModify = true;
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            if(curSL == 0 && InpAutoAddSL_Manual && defSLPts > 0)
            {
               targetSL = NormalizeDouble(openPrice + (defSLPts * _Point), _Digits);
               needModify = true;
            }
            if(curTP == 0 && InpAutoAddTP_Manual && defTPPts > 0)
            {
               targetTP = NormalizeDouble(openPrice - (defTPPts * _Point), _Digits);
               needModify = true;
            }
         }

         if(needModify)
         {
            if(m_trade.PositionModify(ticket, targetSL, targetTP))
            {
               curSL = targetSL;
               curTP = targetTP;
               Print(">>> 📱 [MOBILE CO-PILOT] Attached Auto SL/TP on Manual #", ticket, " SL: ", targetSL, " TP: ", targetTP);
               SendTradeNotification(StringFormat("📱 [Mobile Co-Pilot] Attached on Manual Trade #%I64u (SL: %.2f, TP: %.2f)", ticket, targetSL, targetTP));
            }
         }
      }

      // If manual trade trailing sync is disabled, skip trailing/BE for manual orders
      if(isManual && !InpManualTrailingSync)
         continue;

      // ⚔️ Samurai MTF Mobile Co-Pilot Adaptive Harmony
      int posBETrigger = effBETrigger;
      int posBELock    = effBELock;
      if(isManual && g_BreakEvenEnabled && InpUseSamuraiMTFConfluence)
      {
         // If mobile trade opposes Samurai MTF, protect capital with tighter BE trigger (e.g. 450 -> 300 pts)
         if((posType == POSITION_TYPE_BUY && g_SamuraiMTF.consensusDir == -1) ||
            (posType == POSITION_TYPE_SELL && g_SamuraiMTF.consensusDir == 1))
         {
            posBETrigger = MathMax(250, effBETrigger - 150);
         }
      }

      // BUY MANAGEMENT
      if(posType == POSITION_TYPE_BUY)
      {
         double profitPts = (bid - openPrice) / _Point;
         long brokerStopLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double minAllowedDist = MathMax((double)brokerStopLvl + 5.0, 10.0) * _Point;

         // A. Partial Take-Profit (80% closed once at Milestone 1: +450 pts)
         if(InpUsePartialTP && !IsPartialTP_Executed(ticket))
         {
            double targetPts = (double)effBETrigger;

            if(profitPts >= targetPts && profitPts > 0)
            {
               int lotDigits = (stepLot <= 0.001) ? 3 : ((stepLot <= 0.01) ? 2 : ((stepLot <= 0.1) ? 1 : 0));
               double closeLot = NormalizeDouble(MathRound((posVolume * (InpPartialClosePct / 100.0)) / stepLot) * stepLot, lotDigits);
               double remainLot = NormalizeDouble(posVolume - closeLot, lotDigits);

               // Adaptive Cent Account Volume Clamp: If remainLot is below broker minimum, adjust closeLot
               if(closeLot >= minLot && remainLot < minLot && (posVolume - minLot) >= minLot)
               {
                  closeLot = NormalizeDouble(posVolume - minLot, lotDigits);
                  remainLot = minLot;
               }

               if(closeLot >= minLot && remainLot >= minLot)
               {
                  if(m_trade.PositionClosePartial(ticket, closeLot))
                  {
                     MarkPartialTP_Executed(ticket);
                     Print(">>> 💰 PARTIAL TP ", DoubleToString(InpPartialClosePct, 0), "% EXECUTED on #", ticket, (isManual ? " (Mobile)" : ""), " Closed: ", closeLot, " Remaining: ", remainLot);
                     SendTradeNotification(StringFormat("💰 [Good Trade Gold] Partial TP %.0f%% Hit on #%I64u%s | Closed: %.2f Lot | SL Moved to BE!", InpPartialClosePct, ticket, (isManual ? " (Mobile)" : ""), closeLot));
                     double beSL = NormalizeDouble(openPrice + (effBELock * _Point), _Digits);
                     if(curSL < beSL && (bid - beSL) >= minAllowedDist)
                        m_trade.PositionModify(ticket, beSL, curTP);
                     continue;
                  }
                  else
                  {
                     Print(">>> ⚠️ [PARTIAL TP FAILED] Ticket #", ticket, " CloseLot: ", closeLot, " Retcode: ", m_trade.ResultRetcode(), " (", m_trade.ResultRetcodeDescription(), ")");
                     double beSL = NormalizeDouble(openPrice + (effBELock * _Point), _Digits);
                     if(curSL < beSL && (bid - beSL) >= minAllowedDist)
                        m_trade.PositionModify(ticket, beSL, curTP);
                  }
               }
               else
               {
                  // Volume cannot be split (e.g. single minimum lot 0.10) - Move SL to BE directly!
                  double beSL = NormalizeDouble(openPrice + (effBELock * _Point), _Digits);
                  if(curSL < beSL && (bid - beSL) >= minAllowedDist)
                  {
                     if(m_trade.PositionModify(ticket, beSL, curTP))
                     {
                        MarkPartialTP_Executed(ticket);
                        Print(">>> 🛡️ [BE MOVED - SINGLE LOT] Position #", ticket, " SL -> ", beSL);
                        SendTradeNotification(StringFormat("🛡️ [Good Trade Gold] SL Moved to BE (+%d pts) on Single Lot #%I64u @ %.2f", effBELock, ticket, beSL));
                        continue;
                     }
                  }
               }
            }
         }

         // -------------------------------------------------------------
         // B. 🎯 MILESTONE STEP-LOCKING & BREAK-EVEN ENGINE (BUY)
         // -------------------------------------------------------------
         if(g_BreakEvenEnabled || InpUseStepLocking)
         {
            double targetStepSL = 0;
            string lockMsg = "";

            // Step 4: Profit >= 1900 pts (TP2) -> Lock +1650 pts
            if(InpUseStepLocking && profitPts >= effStep4Trig)
            {
               targetStepSL = NormalizeDouble(openPrice + (effStep4Lock * _Point), _Digits);
               lockMsg = StringFormat("Step 4 (TP2 Lock +%d pts)", InpStep4Lock);
            }
            // Step 3: Profit >= 950 pts (TP1) -> Lock +800 pts
            else if(InpUseStepLocking && profitPts >= effStep3Trig)
            {
               targetStepSL = NormalizeDouble(openPrice + (effStep3Lock * _Point), _Digits);
               lockMsg = StringFormat("Step 3 (TP1 Lock +%d pts)", InpStep3Lock);
            }
            // Step 2: Profit >= 700 pts -> Lock +350 pts
            else if(InpUseStepLocking && profitPts >= effStep2Trig)
            {
               targetStepSL = NormalizeDouble(openPrice + (effStep2Lock * _Point), _Digits);
               lockMsg = StringFormat("Step 2 (Lock +%d pts)", InpStep2Lock);
            }
            // Step 1: Profit >= 450 pts (Break-Even) -> Lock +80 pts
            else if(g_BreakEvenEnabled && profitPts >= posBETrigger)
            {
               targetStepSL = NormalizeDouble(openPrice + (posBELock * _Point), _Digits);
               lockMsg = StringFormat("Break-Even (Lock +%d pts)", posBELock);
            }

            if(targetStepSL > 0 && targetStepSL > curSL && (bid - targetStepSL) >= minAllowedDist)
            {
               if(m_trade.PositionModify(ticket, targetStepSL, curTP))
               {
                  Print(">>> 🛡️ [STEP-LOCKING BUY] Position #", ticket, (isManual ? " (Mobile)" : ""), " ", lockMsg, " SL -> ", targetStepSL);
                  SendTradeNotification(StringFormat("🛡️ [Good Trade Gold] %s on #%I64u%s @ %.2f", lockMsg, ticket, (isManual ? " (Mobile)" : ""), targetStepSL));
                  continue;
               }
            }
         }

         // -------------------------------------------------------------
         // C. TRAILING STOP (Adaptive Runner & Sniper Fast Trail)
         // -------------------------------------------------------------
         bool isSweepTrade = (StringFind(m_position.Comment(), "Sweep") >= 0 || StringFind(m_position.Comment(), "SNIPER") >= 0);
         double effectiveTrailStart = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpTrailingStart : (double)g_AssetProfile.trailStart;
         double effectiveTrailDist  = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpTrailingDist  : (double)g_AssetProfile.trailDist;
         double effectiveTrailStep  = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpTrailingStep  : (double)g_AssetProfile.trailStep;
         string trailModeStr = isManual ? "Mobile Co-Pilot Trail" : "Standard";

         if(isSweepTrade && InpUseSweepFastTrail)
         {
            effectiveTrailStart = (double)InpSweepTrailStart;
            effectiveTrailDist  = (double)InpSweepTrailStep;
            effectiveTrailStep  = (double)InpSweepTrailStep;
            trailModeStr        = "Sniper Fast Trail";
         }
         else if(InpUseAdaptiveTrailing)
         {
            CalculateAdaptiveTrailingDistance(ticket, effectiveTrailDist, effectiveTrailStep, trailModeStr);
         }

         if((InpUseTrailing || (isSweepTrade && InpUseSweepFastTrail)) && profitPts >= effectiveTrailStart)
         {
            double newSL = NormalizeDouble(bid - (effectiveTrailDist * _Point), _Digits);
            if(newSL > curSL + (effectiveTrailStep * _Point) && (bid - newSL) >= minAllowedDist)
            {
               m_trade.PositionModify(ticket, newSL, curTP);
               Print("Position #", ticket, (isManual ? " (Mobile)" : ""), " (", trailModeStr, ") updated to ", newSL);
            }
         }
      }
      // SELL MANAGEMENT
      else if(posType == POSITION_TYPE_SELL)
      {
         double profitPts = (openPrice - ask) / _Point;
         long brokerStopLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double minAllowedDist = MathMax((double)brokerStopLvl + 5.0, 10.0) * _Point;

         // A. Partial Take-Profit (80% closed once at Milestone 1: +450 pts)
         if(InpUsePartialTP && !IsPartialTP_Executed(ticket))
         {
            double targetPts = (double)effBETrigger;

            if(profitPts >= targetPts && profitPts > 0)
            {
               int lotDigits = (stepLot <= 0.001) ? 3 : ((stepLot <= 0.01) ? 2 : ((stepLot <= 0.1) ? 1 : 0));
               double closeLot = NormalizeDouble(MathRound((posVolume * (InpPartialClosePct / 100.0)) / stepLot) * stepLot, lotDigits);
               double remainLot = NormalizeDouble(posVolume - closeLot, lotDigits);

               // Adaptive Cent Account Volume Clamp: If remainLot is below broker minimum, adjust closeLot
               if(closeLot >= minLot && remainLot < minLot && (posVolume - minLot) >= minLot)
               {
                  closeLot = NormalizeDouble(posVolume - minLot, lotDigits);
                  remainLot = minLot;
               }

               if(closeLot >= minLot && remainLot >= minLot)
               {
                  if(m_trade.PositionClosePartial(ticket, closeLot))
                  {
                     MarkPartialTP_Executed(ticket);
                     Print(">>> 💰 PARTIAL TP ", DoubleToString(InpPartialClosePct, 0), "% EXECUTED on #", ticket, (isManual ? " (Mobile)" : ""), " Closed: ", closeLot, " Remaining: ", remainLot);
                     SendTradeNotification(StringFormat("💰 [Good Trade Gold] Partial TP %.0f%% Hit on #%I64u%s | Closed: %.2f Lot | SL Moved to BE!", InpPartialClosePct, ticket, (isManual ? " (Mobile)" : ""), closeLot));
                     double beSL = NormalizeDouble(openPrice - (effBELock * _Point), _Digits);
                     if((curSL == 0 || curSL > beSL) && (beSL - ask) >= minAllowedDist)
                        m_trade.PositionModify(ticket, beSL, curTP);
                     continue;
                  }
               }
            }
         }

         // -------------------------------------------------------------
         // B. 🎯 MILESTONE STEP-LOCKING & BREAK-EVEN ENGINE (SELL)
         // -------------------------------------------------------------
         if(g_BreakEvenEnabled || InpUseStepLocking)
         {
            double targetStepSL = 0;
            string lockMsg = "";

            // Step 4: Profit >= 1900 pts (TP2) -> Lock +1650 pts
            if(InpUseStepLocking && profitPts >= effStep4Trig)
            {
               targetStepSL = NormalizeDouble(openPrice - (effStep4Lock * _Point), _Digits);
               lockMsg = StringFormat("Step 4 (TP2 Lock +%d pts)", InpStep4Lock);
            }
            // Step 3: Profit >= 950 pts (TP1) -> Lock +800 pts
            else if(InpUseStepLocking && profitPts >= effStep3Trig)
            {
               targetStepSL = NormalizeDouble(openPrice - (effStep3Lock * _Point), _Digits);
               lockMsg = StringFormat("Step 3 (TP1 Lock +%d pts)", InpStep3Lock);
            }
            // Step 2: Profit >= 700 pts -> Lock +350 pts
            else if(InpUseStepLocking && profitPts >= effStep2Trig)
            {
               targetStepSL = NormalizeDouble(openPrice - (effStep2Lock * _Point), _Digits);
               lockMsg = StringFormat("Step 2 (Lock +%d pts)", InpStep2Lock);
            }
            // Step 1: Profit >= 450 pts (Break-Even) -> Lock +80 pts
            else if(g_BreakEvenEnabled && profitPts >= posBETrigger)
            {
               targetStepSL = NormalizeDouble(openPrice - (posBELock * _Point), _Digits);
               lockMsg = StringFormat("Break-Even (Lock +%d pts)", posBELock);
            }

            if(targetStepSL > 0 && (curSL == 0 || targetStepSL < curSL) && (targetStepSL - ask) >= minAllowedDist)
            {
               if(m_trade.PositionModify(ticket, targetStepSL, curTP))
               {
                  Print(">>> 🛡️ [STEP-LOCKING SELL] Position #", ticket, (isManual ? " (Mobile)" : ""), " ", lockMsg, " SL -> ", targetStepSL);
                  SendTradeNotification(StringFormat("🛡️ [Good Trade Gold] %s on #%I64u%s @ %.2f", lockMsg, ticket, (isManual ? " (Mobile)" : ""), targetStepSL));
                  continue;
               }
            }
         }

         // -------------------------------------------------------------
         // C. TRAILING STOP (Adaptive Runner & Sniper Fast Trail)
         // -------------------------------------------------------------
         bool isSweepTrade = (StringFind(m_position.Comment(), "Sweep") >= 0 || StringFind(m_position.Comment(), "SNIPER") >= 0);
         double effectiveTrailStart = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpTrailingStart : (double)g_AssetProfile.trailStart;
         double effectiveTrailDist  = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpTrailingDist  : (double)g_AssetProfile.trailDist;
         double effectiveTrailStep  = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpTrailingStep  : (double)g_AssetProfile.trailStep;
         string trailModeStr = isManual ? "Mobile Co-Pilot Trail" : "Standard";

         if(isSweepTrade && InpUseSweepFastTrail)
         {
            effectiveTrailStart = (double)InpSweepTrailStart;
            effectiveTrailDist  = (double)InpSweepTrailStep;
            effectiveTrailStep  = (double)InpSweepTrailStep;
            trailModeStr        = "Sniper Fast Trail";
         }
         else if(InpUseAdaptiveTrailing)
         {
            CalculateAdaptiveTrailingDistance(ticket, effectiveTrailDist, effectiveTrailStep, trailModeStr);
         }

         if((InpUseTrailing || (isSweepTrade && InpUseSweepFastTrail)) && profitPts >= effectiveTrailStart)
         {
            double newSL = NormalizeDouble(ask + (effectiveTrailDist * _Point), _Digits);
            if((curSL == 0 || newSL < curSL - (effectiveTrailStep * _Point)) && (newSL - ask) >= minAllowedDist)
            {
               m_trade.PositionModify(ticket, newSL, curTP);
               Print("Position #", ticket, (isManual ? " (Mobile)" : ""), " (", trailModeStr, ") updated to ", newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 13. LOT SIZE & STATS CALCULATION HELPERS                         |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLoss)
{
   double step = m_symbol.LotsStep();
   if(step <= 0) step = 0.01;
   double minLot = m_symbol.LotsMin();
   if(minLot <= 0) minLot = 0.01;
   double maxLot = m_symbol.LotsMax();
   if(maxLot <= 0) maxLot = 100.0;
   int lotDigits = (step <= 0.001) ? 3 : ((step <= 0.01) ? 2 : ((step <= 0.1) ? 1 : 0));

   if(g_LotMode == LOT_FIXED)
   {
      double lot = NormalizeDouble(MathRound(g_CurrentLot / step) * step, lotDigits);
      return MathMax(minLot, MathMin(maxLot, lot));
   }

   double balance = m_account.Balance();
   double riskMoney = balance * (g_RiskPercent / 100.0);
   double slPoints = MathAbs(entryPrice - stopLoss) / _Point;

   if(slPoints <= 0)
      slPoints = g_AssetProfile.fallbackSL;

   double tickValue = m_symbol.TickValue();
   double tickSize  = m_symbol.TickSize();
   double pointVal  = (tickSize > 0 && tickValue > 0) ? (tickValue * (_Point / tickSize)) : 1.0;
   if(pointVal <= 0) pointVal = 1.0;

   double calculatedLot = riskMoney / (slPoints * pointVal);
   if(InpEnableMaxVolumeCeiling && InpMaxTotalVolumeCap > 0 && calculatedLot > InpMaxTotalVolumeCap)
      calculatedLot = InpMaxTotalVolumeCap;
   calculatedLot = NormalizeDouble(MathFloor((calculatedLot + (step * 0.01)) / step) * step, lotDigits);

   return MathMax(minLot, MathMin(maxLot, calculatedLot));
}

void AdjustLot(double delta)
{
   if(g_LotMode == LOT_FIXED)
   {
      double step = m_symbol.LotsStep();
      double minLot = m_symbol.LotsMin();
      double maxLot = m_symbol.LotsMax();
      if(InpEnableMaxVolumeCeiling && InpMaxTotalVolumeCap > 0 && maxLot > InpMaxTotalVolumeCap)
         maxLot = InpMaxTotalVolumeCap;
      g_CurrentLot = MathMax(minLot, MathMin(maxLot, NormalizeDouble(g_CurrentLot + delta, 2)));
      ObjectSetString(0, GUI_PREFIX + "EDIT_LOT", OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
   }
   else
   {
      g_RiskPercent = MathMax(0.1, MathMin(10.0, NormalizeDouble(g_RiskPercent + (delta * 10), 1)));
      ObjectSetString(0, GUI_PREFIX + "EDIT_LOT", OBJPROP_TEXT, DoubleToString(g_RiskPercent, 1) + "%");
   }
   SavePersistentGUIState();
   ChartRedraw();
}

int CountOpenPositions(bool includeManual=false)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol)
         {
            if(m_position.Magic() == InpMagicNumber || (includeManual && InpManageManualTrades && m_position.Magic() == 0))
               count++;
         }
      }
   }
   return count;
}

double CalculateTotalProfit()
{
   double profit = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || (InpManageManualTrades && m_position.Magic() == 0)))
            profit += m_position.Profit() + m_position.Swap();
      }
   }
   return profit;
}

void GetClosedTradeStats(int &total, int &wins, int &losses, double &netPnl, double &winRate)
{
   total = 0;
   wins = 0;
   losses = 0;
   netPnl = 0.0;
   winRate = 0.0;

   if(!HistorySelect(0, TimeCurrent()))
      return;

   int dealsTotal = HistoryDealsTotal();
   for(int i = 0; i < dealsTotal; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

         if(magic == InpMagicNumber && symbol == _Symbol && entryType == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) 
                          + HistoryDealGetDouble(dealTicket, DEAL_SWAP) 
                          + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

            total++;
            netPnl += profit;
            if(profit >= 0.0)
               wins++;
            else
               losses++;
         }
      }
   }

   if(total > 0)
      winRate = ((double)wins / (double)total) * 100.0;
}

void GetTodayClosedTradeStats(int &todayTotal, int &todayWins, int &todayLosses, double &todayNetPnl, double &todayWinRate,
                              int &manTotal, int &manWins, int &manLosses, double &manNetPnl)
{
   todayTotal = 0; todayWins = 0; todayLosses = 0; todayNetPnl = 0.0; todayWinRate = 0.0;
   manTotal = 0; manWins = 0; manLosses = 0; manNetPnl = 0.0;

   datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0);
   if(startOfDay <= 0)
   {
      datetime tc = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(tc, dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      startOfDay = StructToTime(dt);
   }
   if(startOfDay <= 0 || !HistorySelect(startOfDay, TimeCurrent()))
      return;

   int dealsTotal = HistoryDealsTotal();
   for(int i = 0; i < dealsTotal; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         if(dealTime < startOfDay) continue;

         long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;

         long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

         if(symbol == _Symbol && (entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT || entryType == DEAL_ENTRY_OUT_BY))
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) 
                          + HistoryDealGetDouble(dealTicket, DEAL_SWAP) 
                          + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

            if(magic == InpMagicNumber)
            {
               todayTotal++;
               todayNetPnl += profit;
               if(profit >= 0.0) todayWins++; else todayLosses++;
            }
            else if(magic == 0 || magic == 888999)
            {
               manTotal++;
               manNetPnl += profit;
               if(profit >= 0.0) manWins++; else manLosses++;
            }
         }
      }
   }

   if(todayTotal > 0)
      todayWinRate = ((double)todayWins / (double)todayTotal) * 100.0;
}

string GetGVKey(string tag)
{
   return StringFormat("GTG_%s_%d_%s", _Symbol, (int)InpMagicNumber, tag);
}

void ApplyTradeMode(ENUM_TRADE_MODE mode)
{
   g_TradeMode = mode;
   if(g_TradeMode == TRADE_MODE_SAFE_COPILOT)
   {
      g_HTFMacroGuardActive = InpUseHTFMacroGuard;
      g_LRLFilterActive     = InpLRL_FilterEntries;
      g_AutoSniperActive    = false;
      g_FiboGuardActive     = InpUseFiboZoneGuard;
   }
   else // TRADE_MODE_AGGRESSIVE_SNIPER
   {
      g_HTFMacroGuardActive = false;
      g_LRLFilterActive     = false;
      g_AutoSniperActive    = true;
      g_FiboGuardActive     = false;
      // ปลดล็อกเกราะพักใจ 15 นาที (Khun Ann Angel Shield) ทันทีในโหมดสไนเปอร์
      g_RevengeCooldownUntil = 0;
      GlobalVariableSet(GetGVKey("REVENGE_UNTIL"), 0.0);
   }
}

void SavePersistentGUIState()
{
   GlobalVariableSet(GetGVKey("INIT"), 1.0);
   GlobalVariableSet(GetGVKey("TRADEMODE"), (double)g_TradeMode);
   GlobalVariableSet(GetGVKey("AUTO"), g_AutoTradeEnabled ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("MULTI"), g_AllowMultiPos ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("LOTMODE"), (double)g_LotMode);
   GlobalVariableSet(GetGVKey("LOT"), g_CurrentLot);
   GlobalVariableSet(GetGVKey("RISK"), g_RiskPercent);
   GlobalVariableSet(GetGVKey("BE"), g_BreakEvenEnabled ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("DRAW"), g_ShowVisuals ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("DASH"), g_ShowDashboard ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("CTRL"), g_ShowControls ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("C1_EXP"), g_Card1_Expanded ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("C2_EXP"), g_Card2_Expanded ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("C3_EXP"), g_Card3_Expanded ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("C4_EXP"), g_Card4_Expanded ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("CTRL_EXP"), g_Ctrl_Expanded ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("MTF_SHOW"), g_ShowMTFStrip ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("ATH_SHOW"), g_ShowATHGrid ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("LRL_SHOW"), g_ShowLRLChannel ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("ABCD_SHOW"), g_ShowABCDWave ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("EMA_SHOW"), g_ShowEMAVisuals ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("REVENGE_UNTIL"), (double)g_RevengeCooldownUntil);
   GlobalVariableSet(GetGVKey("POST_SLBE_UNTIL"), (double)g_PostSLBECooldownUntil);
   GlobalVariableSet(GetGVKey("GUARD_UNLOCKED"), g_DailyGuardManualUnlocked ? 1.0 : 0.0);
   GlobalVariableSet(GetGVKey("GUARD_BASE_PNL"), g_DailyGuardBaselinePnL);
   GlobalVariableSet(GetGVKey("GUARD_RESET_DAY"), (double)g_DailyGuardResetDay);
}

void LoadPersistentGUIState()
{
   if(GlobalVariableCheck(GetGVKey("INIT")))
   {
      if(GlobalVariableCheck(GetGVKey("TRADEMODE")))
         ApplyTradeMode((ENUM_TRADE_MODE)(int)GlobalVariableGet(GetGVKey("TRADEMODE")));
      else
         ApplyTradeMode(InpStartTradeMode);

      g_AutoTradeEnabled = (GlobalVariableGet(GetGVKey("AUTO")) > 0.5);
      g_AllowMultiPos    = (GlobalVariableGet(GetGVKey("MULTI")) > 0.5);
      g_LotMode          = (ENUM_LOT_MODE)(int)GlobalVariableGet(GetGVKey("LOTMODE"));
      g_CurrentLot       = GlobalVariableGet(GetGVKey("LOT"));
      g_RiskPercent      = GlobalVariableGet(GetGVKey("RISK"));
      g_BreakEvenEnabled = (GlobalVariableGet(GetGVKey("BE")) > 0.5);
      g_ShowVisuals      = (GlobalVariableGet(GetGVKey("DRAW")) > 0.5);
      g_ShowDashboard    = (GlobalVariableGet(GetGVKey("DASH")) > 0.5);
      g_ShowControls     = (GlobalVariableGet(GetGVKey("CTRL")) > 0.5);
      g_Card1_Expanded   = GlobalVariableCheck(GetGVKey("C1_EXP")) ? (GlobalVariableGet(GetGVKey("C1_EXP")) > 0.5) : true;
      g_Card2_Expanded   = GlobalVariableCheck(GetGVKey("C2_EXP")) ? (GlobalVariableGet(GetGVKey("C2_EXP")) > 0.5) : true;
      g_Card3_Expanded   = GlobalVariableCheck(GetGVKey("C3_EXP")) ? (GlobalVariableGet(GetGVKey("C3_EXP")) > 0.5) : true;
      g_Card4_Expanded   = GlobalVariableCheck(GetGVKey("C4_EXP")) ? (GlobalVariableGet(GetGVKey("C4_EXP")) > 0.5) : true;
      g_Ctrl_Expanded    = (GlobalVariableGet(GetGVKey("CTRL_EXP")) > 0.5);
      g_ShowMTFStrip     = InpUseSamuraiMTFStrip;
      g_ShowATHGrid      = GlobalVariableCheck(GetGVKey("ATH_SHOW")) ? (GlobalVariableGet(GetGVKey("ATH_SHOW")) > 0.5) : InpDrawATHLines;
      g_ShowLRLChannel   = GlobalVariableCheck(GetGVKey("LRL_SHOW")) ? (GlobalVariableGet(GetGVKey("LRL_SHOW")) > 0.5) : InpEnableLRLChannel;
      g_ShowABCDWave     = GlobalVariableCheck(GetGVKey("ABCD_SHOW")) ? (GlobalVariableGet(GetGVKey("ABCD_SHOW")) > 0.5) : true;
      g_ShowEMAVisuals   = GlobalVariableCheck(GetGVKey("EMA_SHOW")) ? (GlobalVariableGet(GetGVKey("EMA_SHOW")) > 0.5) : (InpShowMultiTF_EMA14 || InpShowEMA200_Line);
      if(GlobalVariableCheck(GetGVKey("REVENGE_UNTIL")))
         g_RevengeCooldownUntil = (datetime)(ulong)GlobalVariableGet(GetGVKey("REVENGE_UNTIL"));
      if(GlobalVariableCheck(GetGVKey("POST_SLBE_UNTIL")))
         g_PostSLBECooldownUntil = (datetime)(ulong)GlobalVariableGet(GetGVKey("POST_SLBE_UNTIL"));

      datetime curStartOfDay = iTime(_Symbol, PERIOD_D1, 0);
      if(curStartOfDay <= 0)
      {
         datetime tc = TimeCurrent();
         MqlDateTime dt;
         TimeToStruct(tc, dt);
         dt.hour = 0; dt.min = 0; dt.sec = 0;
         curStartOfDay = StructToTime(dt);
      }
      if(GlobalVariableCheck(GetGVKey("GUARD_RESET_DAY")))
      {
         datetime savedResetDay = (datetime)(ulong)GlobalVariableGet(GetGVKey("GUARD_RESET_DAY"));
         if(savedResetDay == curStartOfDay)
         {
            if(GlobalVariableCheck(GetGVKey("GUARD_UNLOCKED")))
               g_DailyGuardManualUnlocked = (GlobalVariableGet(GetGVKey("GUARD_UNLOCKED")) > 0.5);
            if(GlobalVariableCheck(GetGVKey("GUARD_BASE_PNL")))
               g_DailyGuardBaselinePnL = GlobalVariableGet(GetGVKey("GUARD_BASE_PNL"));
            g_DailyGuardResetDay = savedResetDay;
         }
         else
         {
            GlobalVariableDel(GetGVKey("GUARD_UNLOCKED"));
            GlobalVariableDel(GetGVKey("GUARD_BASE_PNL"));
            GlobalVariableDel(GetGVKey("GUARD_RESET_DAY"));
            g_DailyGuardManualUnlocked = false;
            g_DailyGuardBaselinePnL = 0.0;
            g_DailyGuardResetDay = 0;
         }
      }
      Print(">>> 💾 [PERSISTENT GUI MEMORY] Restored GUI interactive settings & Trade Mode (", (g_TradeMode == TRADE_MODE_SAFE_COPILOT ? "SAFE" : "AGGRESSIVE"), ") from GlobalVariables.");
   }
   else
   {
      ApplyTradeMode(InpStartTradeMode);
      g_AutoTradeEnabled = InpStartAutoTrade;
      g_AllowMultiPos    = InpAllowMultiPos;
      g_LotMode          = InpStartLotMode;
      g_CurrentLot       = InpStartFixedLot;
      g_RiskPercent      = InpStartRiskPercent;
      g_BreakEvenEnabled = InpUseBreakEven;
      g_ShowVisuals      = InpShowVisuals;
      g_ShowDashboard    = InpShowDashboardGUI;
      g_ShowControls     = InpShowControlsGUI;
      g_Card1_Expanded   = true;
      g_Card2_Expanded   = true;
      g_Card3_Expanded   = true;
      g_Card4_Expanded   = true;
      g_Ctrl_Expanded    = true;
      g_ShowMTFStrip     = InpUseSamuraiMTFStrip;
      g_ShowATHGrid      = InpDrawATHLines;
      g_ShowLRLChannel   = InpEnableLRLChannel;
      g_ShowABCDWave     = true;
      g_ShowEMAVisuals   = (InpShowMultiTF_EMA14 || InpShowEMA200_Line);
      g_RevengeCooldownUntil = 0;
      SavePersistentGUIState();
   }
}

bool IsPartialTP_Executed(ulong ticket)
{
   if(GlobalVariableCheck(GetGVKey(StringFormat("PTP_%I64u", ticket))))
      return true;

   for(int i = 0; i < ArraySize(g_PartialTP_Tickets); i++)
   {
      if(g_PartialTP_Tickets[i] == ticket)
         return true;
   }
   return false;
}

void MarkPartialTP_Executed(ulong ticket)
{
   if(IsPartialTP_Executed(ticket))
      return;
   GlobalVariableSet(GetGVKey(StringFormat("PTP_%I64u", ticket)), 1.0);
   int sz = ArraySize(g_PartialTP_Tickets);
   ArrayResize(g_PartialTP_Tickets, sz + 1);
   g_PartialTP_Tickets[sz] = ticket;
}

void SendTradeNotification(string msg)
{
   if(InpUseMobileAlerts)
   {
      SendNotification(msg);
   }
}

bool IsCentAccount()
{
   string curr = AccountInfoString(ACCOUNT_CURRENCY);
   StringToUpper(curr);
   string sym = _Symbol;
   StringToUpper(sym);
   
   if(StringFind(curr, "USC") >= 0 || StringFind(curr, "CENT") >= 0 || StringFind(curr, "EUX") >= 0 || 
      StringFind(curr, "GBC") >= 0 || StringFind(curr, "EURC") >= 0 || StringFind(curr, "GBPC") >= 0 ||
      StringFind(curr, "UST") >= 0 || StringFind(curr, "PROCENT") >= 0 || StringFind(curr, "CUSD") >= 0 ||
      StringFind(curr, "USDC") >= 0)
      return true;

   if(StringFind(sym, ".SC") >= 0 || StringFind(sym, "_C") >= 0 || StringFind(sym, "-C") >= 0 ||
      StringFind(sym, ".C") >= 0 || StringFind(sym, "CENT") >= 0 || StringFind(sym, "MICRO") >= 0 ||
      StringFind(sym, ".MIC") >= 0 || (StringLen(sym) > 1 && StringSubstr(sym, StringLen(sym)-1, 1) == "C"))
      return true;
      
   return false;
}

string FormatMoney(double amount, bool showSign=false)
{
   string sign = (showSign && amount >= 0) ? "+" : "";
   if(IsCentAccount())
   {
      return StringFormat("%s%.2f Cent", sign, amount);
   }
   else
   {
      string curr = AccountInfoString(ACCOUNT_CURRENCY);
      if(curr == "USD" || curr == "")
         return StringFormat("%s$%.2f", sign, amount);
      else
         return StringFormat("%s%.2f %s", sign, amount, curr);
   }
}

//+------------------------------------------------------------------+
//| 14. GRAPHICAL USER INTERFACE (GUI DASHBOARD & CONTROLS)          |
//+------------------------------------------------------------------+
void CreateFullGUI()
{
   DestroyGUI();

   int panelLeftX = 15;
   int topBarY    = 8;
   int panelTopY  = 35;
   int hudWidth   = 485;

   // -------------------------------------------------------------
   // 0. TOP QUICK ACCESS NAVIGATION BAR (ALWAYS ACCESSIBLE)
   // -------------------------------------------------------------
   int navH = 22;
   int curNavX = panelLeftX;
   int w1 = 58;
   int w2 = 58;
   int w3 = 60;
   int w4 = 58;
   int w5 = 58;
   int w6 = 58;
   int w7 = 60;
   int w8 = 60;

   CreateButton("NAV_TOGGLE_HUD", curNavX, topBarY, w1, navH, 
                g_ShowDashboard ? "📊 HUD" : "📊 แสดง", 
                g_ShowDashboard ? C'20,40,60' : C'40,40,50', clrAqua);
   curNavX += w1 + 2;

   CreateButton("NAV_TOGGLE_CTRL", curNavX, topBarY, w2, navH, 
                g_ShowControls ? "🎛️ ควบคุม" : "🎛️ ปุ่มกด", 
                g_ShowControls ? C'20,40,60' : C'40,40,50', clrGold);
   curNavX += w2 + 2;

   CreateButton("NAV_TOGGLE_DRAW", curNavX, topBarY, w3, navH, 
                g_ShowVisuals ? "📈 กราฟ: ON" : "📈 กราฟ: OFF", 
                g_ShowVisuals ? C'20,60,40' : C'60,30,30', clrLime);
   curNavX += w3 + 2;

   CreateButton("NAV_TOGGLE_MTF", curNavX, topBarY, w4, navH, 
                g_ShowMTFStrip ? "🕯️ MTF: ON" : "🕯️ MTF: OFF", 
                g_ShowMTFStrip ? C'20,50,70' : C'40,40,50', clrCyan);
   curNavX += w4 + 2;

   CreateButton("NAV_TOGGLE_ATH", curNavX, topBarY, w5, navH, 
                g_ShowATHGrid ? "🧭 ATH: ON" : "🧭 ATH: OFF", 
                g_ShowATHGrid ? C'60,45,15' : C'40,40,50', clrGold);
   curNavX += w5 + 2;

   CreateButton("NAV_TOGGLE_LRL", curNavX, topBarY, w6, navH, 
                g_ShowLRLChannel ? "📐 LRL: ON" : "📐 LRL: OFF", 
                g_ShowLRLChannel ? C'25,55,50' : C'40,40,50', clrSpringGreen);
   curNavX += w6 + 2;

   CreateButton("NAV_TOGGLE_ABCD", curNavX, topBarY, w7, navH, 
                g_ShowABCDWave ? "🌊 ABCD: ON" : "🌊 ABCD: OFF", 
                g_ShowABCDWave ? C'20,50,65' : C'40,40,50', clrDeepSkyBlue);
   curNavX += w7 + 2;

   CreateButton("NAV_TOGGLE_EMA", curNavX, topBarY, w8, navH, 
                g_ShowEMAVisuals ? "🟣 EMA: ON" : "🟣 EMA: OFF", 
                g_ShowEMAVisuals ? C'50,20,70' : C'40,40,50', C'210,130,255');

   // -------------------------------------------------------------
   // A. LEFT PANEL (STATUS & 4-CARD MODULAR HUD WITH ACCORDION)
   // -------------------------------------------------------------
   int hudHeight = 545;
   if(g_ShowDashboard)
   {
      // Calculate dynamic positions & height based on which cards are expanded
      int cardLeftX  = panelLeftX + 12;
      int cardW      = hudWidth - 24; // 461 px
      int labelLeftX = cardLeftX + 8;
      int valLeftX   = cardLeftX + 138; // Calibrated for maximum value breathing room (323 px)

      int currentY   = panelTopY + 90; // Upgraded: 44 + 40 (2-line box) + 6px gap = 90 (was 74)

      // Card 1
      int y1     = currentY;
      int cardH1 = g_Card1_Expanded ? 268 : 24;
      currentY  += cardH1 + 6;

      // Card 2
      int y2     = currentY;
      int cardH2 = g_Card2_Expanded ? 152 : 24;
      currentY  += cardH2 + 6;

      // Card 3
      int y3     = currentY;
      int cardH3 = g_Card3_Expanded ? 166 : 24;
      currentY  += cardH3 + 6;

      // Card 4
      int y4     = currentY;
      int cardH4 = g_Card4_Expanded ? 110 : 24;
      currentY  += cardH4 + 8;

      hudHeight = currentY - panelTopY;

      // Background Panel
      CreateRectLabel("HUD_BG", panelLeftX, panelTopY, hudWidth, hudHeight, C'10,18,26', C'25,40,55', 2);

      // Title Header, Auto-Update Button & Minimize Button
      CreateLabel("HUD_TITLE", panelLeftX + 12, panelTopY + 10, "GOOD TRADE GOLD PRO 💎", "Segoe UI Black", 11, clrAqua);
      CreateLabel("HUD_SUBTITLE", panelLeftX + 12, panelTopY + 26, "DOW WAVE + FIBO + AI PATTERN + FVG + PROP GUARD", "Segoe UI Semibold", 8, clrDarkGray);

      // In-EA Auto-Updater Button (In Header Red Box)
      int updateBtnW = 125;
      int updateBtnH = 22;
      int updateBtnX = panelLeftX + hudWidth - 28 - updateBtnW - 8;
      int updateBtnY = panelTopY + 9;
      color btnBg    = g_UpdateAvailable ? C'0,140,65' : C'18,32,46';
      color btnTx    = g_UpdateAvailable ? clrWhite : clrAqua;
      CreateButton("HUD_BTN_UPDATE", updateBtnX, updateBtnY, updateBtnW, updateBtnH, g_UpdateStatusText, btnBg, btnTx);

      CreateButton("HUD_BTN_MIN", panelLeftX + hudWidth - 28, panelTopY + 10, 20, 18, "—", C'30,45,60', clrSilver);

      // State Badge Box (2-Line Stacked Display: 40px Height)
      CreateRectLabel("HUD_STATE_BOX", cardLeftX, panelTopY + 44, cardW, 40, C'15,28,40', C'40,70,100', 1);
      CreateLabel("HUD_STATE_TXT", cardLeftX + 10, panelTopY + 47, "INITIALIZING...", "Segoe UI Bold", 9, clrYellow);
      CreateLabel("HUD_STATE_TXT_L2", cardLeftX + 10, panelTopY + 64, "", "Segoe UI Semibold", 8, clrKhaki);

      // ----------------------------------------------------------
      // CARD 1: สภาวะตลาด & เทรนด์ (MARKET ANALYSIS)
      // ----------------------------------------------------------
      CreateRectLabel("HUD_CARD_MKT_BG", cardLeftX, y1, cardW, cardH1, C'12,22,34', C'25,48,70', 1);
      CreateLabel("HUD_CARD_MKT_TITLE", labelLeftX, y1 + 5, "🌐 1. สภาวะตลาด & เทรนด์ (MARKET ANALYSIS)", "Segoe UI Bold", 8, clrLightSkyBlue);
      CreateButton("HUD_BTN_MIN_C1", cardLeftX + cardW - 22, y1 + 3, 18, 18, (g_Card1_Expanded ? "—" : "+"), C'30,45,60', clrSilver);

      if(g_Card1_Expanded)
      {
         // Row 1: Directional Bias Engine Live Gauge (BUY % vs SELL %)
         int yBias = y1 + 22;
         CreateRectLabel("HUD_BAR_ROW_MKT_BIAS", labelLeftX, yBias + 2, 3, 12, clrGold, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_MKT_BIAS", labelLeftX + 8, yBias, "⚖️ น้ำหนักตลาด", "Segoe UI", 8, clrGold);
         CreateLabel("HUD_VAL_BIAS_BUY", valLeftX, yBias, "🟢 BUY 50%", "Segoe UI Black", 8, C'50,225,130');
         CreateLabel("HUD_VAL_BIAS_SEP", valLeftX + 80, yBias, "|", "Segoe UI", 8, clrDarkGray);
         CreateLabel("HUD_VAL_BIAS_SELL", valLeftX + 90, yBias, "🔴 SELL 50%", "Segoe UI Black", 8, C'255,100,120');

         // Row 2: Quasimodo / SMC Smart Action Command (2-Line Stacked Display)
         int yAdv  = y1 + 40;
         int yAdv2 = y1 + 58;
         CreateRectLabel("HUD_BAR_ROW_MKT_ADVICE", labelLeftX, yAdv + 2, 3, 30, clrDeepSkyBlue, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_MKT_ADVICE", labelLeftX + 8, yAdv, "🎯 สไนเปอร์ แอ็กชัน", "Segoe UI", 8, clrGold);
         CreateLabel("HUD_VAL_MKT_ADVICE", valLeftX, yAdv, "⏸️ ตลาด SIDEWAY (นั่งทับมือก่อน ⏳)", "Segoe UI Bold", 8, clrGold);
         CreateLabel("HUD_VAL_MKT_ADVICE_L2", labelLeftX + 14, yAdv2, "↳ ยังไม่เกิด ChoCH / BOS ➔ ห้ามออกไม้เด็ดขาด (รอฟอร์มคลื่น)!", "Segoe UI Semibold", 8, C'255,215,0');

         // Row 3: Asset & Session
         int yAsset = y1 + 78;
         CreateRectLabel("HUD_BAR_ROW_MKT_ASSET", labelLeftX, yAsset + 2, 3, 12, clrSteelBlue, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_MKT_ASSET", labelLeftX + 8, yAsset, "", "Segoe UI", 8, clrSilver);
         CreateLabel("HUD_VAL_ROW_MKT_ASSET", valLeftX, yAsset, "", "Segoe UI Semibold", 8, clrWhite);

         // Row 4: Spread
         int ySpread = y1 + 96;
         CreateRectLabel("HUD_BAR_ROW_MKT_SPREAD", labelLeftX, ySpread + 2, 3, 12, clrSteelBlue, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_MKT_SPREAD", labelLeftX + 8, ySpread, "", "Segoe UI", 8, clrSilver);
         CreateLabel("HUD_VAL_ROW_MKT_SPREAD", valLeftX, ySpread, "", "Segoe UI Semibold", 8, clrWhite);

         // Row 5: MTF ABCD Structure (2-Line Stacked Display)
         int yTrend  = y1 + 114;
         int yTrend2 = y1 + 130;
         CreateRectLabel("HUD_BAR_ROW_MKT_TREND", labelLeftX, yTrend + 2, 3, 26, clrSteelBlue, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_MKT_TREND", labelLeftX + 8, yTrend, "📈 MTF ABCD (สั้น)", "Segoe UI", 8, clrSilver);
         CreateLabel("HUD_VAL_ROW_MKT_TREND", valLeftX, yTrend, "", "Segoe UI Semibold", 8, clrWhite);
         CreateLabel("HUD_VAL_ROW_MKT_TREND_L2", labelLeftX + 14, yTrend2, "", "Segoe UI Semibold", 8, C'175,225,255');

         // Row 6: EMA Cross & Multi-TF EMA 14 Status (2-Line Stacked Display)
         int yCross  = y1 + 150;
         int yCross2 = y1 + 166;
         CreateRectLabel("HUD_BAR_ROW_MKT_CROSS", labelLeftX, yCross + 2, 3, 26, clrSteelBlue, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_MKT_CROSS", labelLeftX + 8, yCross, "👑 สัญญาณ EMA Cross", "Segoe UI", 8, clrSilver);
         CreateLabel("HUD_VAL_ROW_MKT_CROSS", valLeftX, yCross, "", "Segoe UI Semibold", 8, clrWhite);
         CreateLabel("HUD_VAL_ROW_MKT_CROSS_L2", labelLeftX + 14, yCross2, "", "Segoe UI Semibold", 8, clrGold);

         // Rows 7 - 9: ABCD Wave, PA Signal, ADX (1-Line Display)
         string card1Tags[] = {"ROW_MKT_WAVE", "ROW_MKT_SIGNAL", "ROW_MKT_ADX"};
         int card1Y[] = {y1 + 186, y1 + 204, y1 + 222};
         for(int i = 0; i < 3; i++)
         {
            CreateRectLabel("HUD_BAR_" + card1Tags[i], labelLeftX, card1Y[i] + 2, 3, 12, clrSteelBlue, clrNONE, 0);
            CreateLabel("HUD_TITLE_" + card1Tags[i], labelLeftX + 8, card1Y[i], "", "Segoe UI", 8, clrSilver);
            CreateLabel("HUD_VAL_" + card1Tags[i], valLeftX, card1Y[i], "", "Segoe UI Semibold", 8, clrWhite);
         }

         // Row 10: SMC Liquidity Radar with Dual Colored Labels (Red SL Sell / Green SL Buy)
         int yLQ = y1 + 242;
         CreateRectLabel("HUD_BAR_ROW_MKT_LQ", labelLeftX, yLQ + 2, 3, 12, clrDarkGoldenrod, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_MKT_LQ", labelLeftX + 8, yLQ, "🎯 SMC LQ Radar", "Segoe UI", 8, clrKhaki);
         CreateLabel("HUD_VAL_LQ_BSL", valLeftX, yLQ, "", "Segoe UI Semibold", 8, C'255,100,120'); // Red / Coral (SL Sell)
         CreateLabel("HUD_VAL_LQ_SEP", valLeftX + 138, yLQ, "|", "Segoe UI", 8, clrDarkGray);
         CreateLabel("HUD_VAL_LQ_SSL", valLeftX + 148, yLQ, "", "Segoe UI Semibold", 8, C'50,225,130'); // Green / SpringGreen (SL Buy)
      }

      // ----------------------------------------------------------
      // CARD 2: แผนเข้าสไนเปอร์ (SNIPER TRADE SETUP)
      // ----------------------------------------------------------
      CreateRectLabel("HUD_CARD_PLAN_BG", cardLeftX, y2, cardW, cardH2, C'10,26,20', C'20,60,40', 1);
      CreateLabel("HUD_CARD_PLAN_TITLE", labelLeftX, y2 + 5, "🎯 2. แผนเข้าสไนเปอร์ (SNIPER TRADE SETUP)", "Segoe UI Bold", 8, clrAqua);
      CreateButton("HUD_BTN_MIN_C2", cardLeftX + cardW - 22, y2 + 3, 18, 18, (g_Card2_Expanded ? "—" : "+"), C'30,45,60', clrSilver);

      if(g_Card2_Expanded)
      {
         // Row 1: Sniper Trade Setup Entry (Up to 3-Line Stacked Display: Zero Overflow!)
         int yEntry  = y2 + 22;
         int yEntry2 = y2 + 38;
         int yEntry3 = y2 + 54;
         CreateRectLabel("HUD_BAR_ROW_PLAN_ENTRY", labelLeftX, yEntry + 2, 3, 44, clrLime, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_PLAN_ENTRY", labelLeftX + 8, yEntry, "⚡ จุดเข้าสไนเปอร์", "Segoe UI", 8, clrSilver);
         CreateLabel("HUD_VAL_ROW_PLAN_ENTRY", valLeftX, yEntry, "", "Segoe UI Semibold", 8, clrWhite);
         CreateLabel("HUD_VAL_ROW_PLAN_ENTRY_L2", labelLeftX + 14, yEntry2, "", "Segoe UI Semibold", 8, C'255,215,0');
         CreateLabel("HUD_VAL_ROW_PLAN_ENTRY_L3", labelLeftX + 22, yEntry3, "", "Segoe UI Semibold", 8, C'255,230,120');

         // Rows 2 - 5: SL, TP1, TP2, TP3
         string card2Tags[] = {"ROW_PLAN_SL", "ROW_PLAN_TP1", "ROW_PLAN_TP2", "ROW_PLAN_TP3"};
         int card2Y[] = {y2 + 72, y2 + 90, y2 + 108, y2 + 126};
         for(int i = 0; i < 4; i++)
         {
            CreateRectLabel("HUD_BAR_" + card2Tags[i], labelLeftX, card2Y[i] + 2, 3, 12, (i == 0 ? clrCrimson : clrAqua), clrNONE, 0);
            CreateLabel("HUD_TITLE_" + card2Tags[i], labelLeftX + 8, card2Y[i], "", "Segoe UI", 8, clrSilver);
            CreateLabel("HUD_VAL_" + card2Tags[i], valLeftX, card2Y[i], "", "Segoe UI Semibold", 8, clrWhite);
         }
      }

      // ----------------------------------------------------------
      // CARD 3: พอร์ตกองทุน & ออเดอร์ (PROP GUARD & ORDERS)
      // ----------------------------------------------------------
      CreateRectLabel("HUD_CARD_PROP_BG", cardLeftX, y3, cardW, cardH3, C'16,20,32', C'35,45,65', 1);
      CreateLabel("HUD_CARD_PROP_TITLE", labelLeftX, y3 + 5, "🛡️ 3. พอร์ตกองทุน & ออเดอร์ (PROP GUARD)", "Segoe UI Bold", 8, clrSlateBlue);
      CreateButton("HUD_BTN_RESET_GUARD", cardLeftX + cardW - 85, y3 + 3, 58, 18, "🔄 รีเซ็ต", C'30,45,60', clrSilver);
      CreateButton("HUD_BTN_MIN_C3", cardLeftX + cardW - 22, y3 + 3, 18, 18, (g_Card3_Expanded ? "—" : "+"), C'30,45,60', clrSilver);

      if(g_Card3_Expanded)
      {
         // Row 1: Open Positions & Risk Management Mode (2-Line Stacked Display)
         int yPos1 = y3 + 22;
         int yPos2 = y3 + 38;
         CreateRectLabel("HUD_BAR_ROW_PROP_POS", labelLeftX, yPos1 + 2, 3, 26, clrRoyalBlue, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_PROP_POS", labelLeftX + 8, yPos1, "📦 ไม้ที่ถืออยู่", "Segoe UI", 8, clrSilver);
         CreateLabel("HUD_VAL_ROW_PROP_POS", valLeftX, yPos1, "", "Segoe UI Semibold", 8, clrWhite);
         CreateLabel("HUD_VAL_ROW_PROP_POS_L2", labelLeftX + 14, yPos2, "", "Segoe UI Semibold", 8, clrLightSkyBlue);

         // Row 2: Daily Profit Target (1-Line Display)
         int yGoal = y3 + 56;
         CreateRectLabel("HUD_BAR_ROW_PROP_GOAL", labelLeftX, yGoal + 2, 3, 12, clrSpringGreen, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_PROP_GOAL", labelLeftX + 8, yGoal, "🎯 เป้ากำไรรายวัน", "Segoe UI", 8, clrSilver);
         CreateLabel("HUD_VAL_ROW_PROP_GOAL", valLeftX, yGoal, "", "Segoe UI Semibold", 8, clrWhite);

         // Row 3: Smart Re-Entry Guard (Up to 3-Line Stacked Display: Zero Overflow!)
         int yReEntry1 = y3 + 74;
         int yReEntry2 = y3 + 90;
         int yReEntry3 = y3 + 106;
         CreateRectLabel("HUD_BAR_ROW_PROP_REENTRY", labelLeftX, yReEntry1 + 2, 3, 44, clrMediumSlateBlue, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_PROP_REENTRY", labelLeftX + 8, yReEntry1, "🛡️ ล็อกไม้ซ้ำ (Re-Entry)", "Segoe UI", 8, clrSilver);
         CreateLabel("HUD_VAL_ROW_PROP_REENTRY", valLeftX, yReEntry1, "", "Segoe UI Semibold", 8, clrWhite);
         CreateLabel("HUD_VAL_ROW_PROP_REENTRY_L2", labelLeftX + 14, yReEntry2, "", "Segoe UI Semibold", 8, clrKhaki);
         CreateLabel("HUD_VAL_ROW_PROP_REENTRY_L3", labelLeftX + 22, yReEntry3, "", "Segoe UI Semibold", 8, C'240,230,170');

         // Row 4: Spike Sniper Signal (2-Line Stacked Display)
         int ySpike1 = y3 + 126;
         int ySpike2 = y3 + 142;
         CreateRectLabel("HUD_BAR_ROW_PROP_SPIKE", labelLeftX, ySpike1 + 2, 3, 26, clrRoyalBlue, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_PROP_SPIKE", labelLeftX + 8, ySpike1, "⚡ สไนเปอร์ Spike", "Segoe UI", 8, clrSilver);
         CreateLabel("HUD_VAL_ROW_PROP_SPIKE", valLeftX, ySpike1, "", "Segoe UI Semibold", 8, clrWhite);
         CreateLabel("HUD_VAL_ROW_PROP_SPIKE_L2", labelLeftX + 14, ySpike2, "", "Segoe UI Semibold", 8, clrGold);
      }

      // ----------------------------------------------------------
      // CARD 4: สุขภาพพอร์ต & ผลงานรวม (PORTFOLIO HEALTH)
      // ----------------------------------------------------------
      CreateRectLabel("HUD_CARD_STATS_BG", cardLeftX, y4, cardW, cardH4, C'24,20,12', C'60,50,20', 1);
      CreateLabel("HUD_CARD_STATS_TITLE", labelLeftX, y4 + 5, "💰 4. สุขภาพพอร์ต & ผลงานรวม (PORTFOLIO HEALTH)", "Segoe UI Bold", 8, clrGold);
      CreateButton("HUD_BTN_MIN_C4", cardLeftX + cardW - 22, y4 + 3, 18, 18, (g_Card4_Expanded ? "—" : "+"), C'30,45,60', clrSilver);

      if(g_Card4_Expanded)
      {
         // Row 1: Account Balance & Equity (1-Line Display)
         int yBal = y4 + 22;
         CreateRectLabel("HUD_BAR_ROW_STATS_BAL", labelLeftX, yBal + 2, 3, 12, clrGold, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_STATS_BAL", labelLeftX + 8, yBal, "💳 บัญชี (Bal/Eq)", "Segoe UI", 8, clrLemonChiffon);
         CreateLabel("HUD_VAL_ROW_STATS_BAL", valLeftX, yBal, "", "Segoe UI Semibold", 8, clrGold);

         // Row 2: Today Closed Trades (Up to 3-Line Display: EA Line 1, Co-Pilot Line 2, Extra Line 3)
         int yWin1 = y4 + 40;
         int yWin2 = y4 + 56;
         int yWin3 = y4 + 72;
         CreateRectLabel("HUD_BAR_ROW_STATS_WIN", labelLeftX, yWin1 + 2, 3, 44, clrGold, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_STATS_WIN", labelLeftX + 8, yWin1, "🏆 ผลงานวันนี้ (Today)", "Segoe UI", 8, clrLemonChiffon);
         CreateLabel("HUD_VAL_ROW_STATS_WIN", valLeftX, yWin1, "", "Segoe UI Semibold", 8, clrGold);
         CreateLabel("HUD_VAL_ROW_STATS_WIN_L2", labelLeftX + 14, yWin2, "", "Segoe UI Semibold", 8, clrKhaki);
         CreateLabel("HUD_VAL_ROW_STATS_WIN_L3", labelLeftX + 22, yWin3, "", "Segoe UI Semibold", 8, C'230,225,180');

         // Row 3: Cumulative Overall Profit (1-Line Display)
         int yPnL = y4 + 90;
         CreateRectLabel("HUD_BAR_ROW_STATS_PNL", labelLeftX, yPnL + 2, 3, 12, clrGold, clrNONE, 0);
         CreateLabel("HUD_TITLE_ROW_STATS_PNL", labelLeftX + 8, yPnL, "💵 กำไรสะสมรวม", "Segoe UI", 8, clrLemonChiffon);
         CreateLabel("HUD_VAL_ROW_STATS_PNL", valLeftX, yPnL, "", "Segoe UI Semibold", 8, clrGold);
      }
   }

   // -------------------------------------------------------------
   // B. BOTTOM CONTROL PANEL (WITH SMART SIDE-BY-SIDE DOCKING)
   // -------------------------------------------------------------
   if(g_ShowControls)
   {
      int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      int chartWidth  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);

      int ctrlLeftX  = panelLeftX;
      int ctrlTopY   = panelTopY;
      int ctrlWidth  = hudWidth; // 475 px (Exact match to Dashboard width)
      int ctrlHeight = g_Ctrl_Expanded ? 195 : 28;

      if(g_ShowDashboard)
      {
         // Smart Adaptive Docking: If vertical space is tight (< 750px) and width allows, dock on the RIGHT side!
         if(chartHeight > 0 && chartHeight < (panelTopY + hudHeight + ctrlHeight + 35) && chartWidth >= (panelLeftX + (hudWidth * 2) + 15))
         {
            ctrlLeftX = panelLeftX + hudWidth + 10;
            ctrlTopY  = panelTopY;
         }
         else
         {
            ctrlTopY  = panelTopY + hudHeight + 8;
         }
      }

      CreateRectLabel("CTRL_BG", ctrlLeftX, ctrlTopY, ctrlWidth, ctrlHeight, C'10,18,26', C'25,40,55', 2);
      CreateLabel("CTRL_TITLE", ctrlLeftX + 12, ctrlTopY + 10, "🎛️ แผงควบคุม / สั่งด้วยมือ (MANUAL CONTROLLER)", "Segoe UI Bold", 9, clrGold);
      CreateButton("CTRL_BTN_MIN", ctrlLeftX + ctrlWidth - 28, ctrlTopY + 8, 20, 18, (g_Ctrl_Expanded ? "—" : "+"), C'30,45,60', clrSilver);

      if(g_Ctrl_Expanded)
      {
         int ctrlInnerX = ctrlLeftX + 12;
         int ctrlInnerW = ctrlWidth - 24; // 451 px

         // Row 1: 5 Toggle Switches (Grid layout: 87px each)
         int btnY = ctrlTopY + 34;
         int btnH = 24;
         int numToggles = 5;
         int gap = 4;
         int toggleW = (ctrlInnerW - ((numToggles - 1) * gap)) / numToggles; // (451 - 16) / 5 = 87 px

         // 1. Auto Trade Button
         CreateButton("BTN_AUTO", ctrlInnerX + (0 * (toggleW + gap)), btnY, toggleW, btnH, 
                      g_AutoTradeEnabled ? "ออโต้ ● ON" : "ออโต้ ● OFF", 
                      g_AutoTradeEnabled ? clrSeaGreen : clrDimGray, clrWhite);

         // 2. Multi Position Button
         CreateButton("BTN_MULTI", ctrlInnerX + (1 * (toggleW + gap)), btnY, toggleW, btnH, 
                      g_AllowMultiPos ? "หลายไม้ ● ON" : "หลายไม้ ● OFF", 
                      g_AllowMultiPos ? clrDodgerBlue : clrDimGray, clrWhite);

         // 3. Lot Mode Button
         CreateButton("BTN_LOTMODE", ctrlInnerX + (2 * (toggleW + gap)), btnY, toggleW, btnH, 
                      g_LotMode == LOT_FIXED ? "โหมด: Lot" : "โหมด: % ทุน", 
                      g_LotMode == LOT_FIXED ? clrOrange : clrDarkCyan, clrWhite);

         // 4. Break Even / Trailing Button
         CreateButton("BTN_BE", ctrlInnerX + (3 * (toggleW + gap)), btnY, toggleW, btnH, 
                      g_BreakEvenEnabled ? "กันทุน ● ON" : "กันทุน ● OFF", 
                      g_BreakEvenEnabled ? clrMediumSlateBlue : clrDimGray, clrWhite);

         // 5. Visual on Chart Button
         CreateButton("BTN_VISUAL", ctrlInnerX + (4 * (toggleW + gap)), btnY, toggleW, btnH, 
                      g_ShowVisuals ? "กราฟิก ● ON" : "กราฟิก ● OFF", 
                      g_ShowVisuals ? clrTeal : clrDimGray, clrWhite);

         // Row 2: Lot Sizing & Risk Controls
         btnY += 30;
         CreateLabel("CTRL_LBL_LOT", ctrlInnerX, btnY + 3, "ขนาด Lot / % Risk ต่อไม้:", "Segoe UI Semibold", 8, clrSilver);

         int stepW = 44;
         int editW = 75;
         int lotStartX = ctrlInnerX + 175;
         CreateButton("BTN_LOT_MINUS10", lotStartX, btnY, stepW, 22, "-0.10", C'25,35,45', clrSilver);
         CreateButton("BTN_LOT_MINUS1",  lotStartX + stepW + 3, btnY, stepW, 22, "-0.01", C'25,35,45', clrSilver);
         
         CreateEdit("EDIT_LOT", lotStartX + (stepW * 2) + 6, btnY, editW, 22, 
                    (g_LotMode == LOT_FIXED ? DoubleToString(g_CurrentLot, 2) : DoubleToString(g_RiskPercent, 1) + "%"), 
                    C'15,25,35', clrLime);

         CreateButton("BTN_LOT_PLUS1",  lotStartX + (stepW * 2) + editW + 9, btnY, stepW, 22, "+0.01", C'25,35,45', clrSilver);
         CreateButton("BTN_LOT_PLUS10", lotStartX + (stepW * 3) + editW + 12, btnY, stepW, 22, "+0.10", C'25,35,45', clrSilver);

         // Row 3: Manual Direct Action Buttons (🟢 BUY & 🔴 SELL)
         btnY += 28;
         int actionW = (ctrlInnerW - 8) / 2; // (451 - 8) / 2 = 221 px
         CreateButton("BTN_MANUAL_BUY", ctrlInnerX, btnY, actionW, 30, "🟢 BUY MARKET", C'20,100,45', clrWhite);
         CreateButton("BTN_MANUAL_SELL", ctrlInnerX + actionW + 8, btnY, actionW, 30, "🔴 SELL MARKET", C'140,30,30', clrWhite);

         // Row 4: Trade Mode Switch & Emergency Close All
         btnY += 36;
         string modeBtnText = (g_TradeMode == TRADE_MODE_SAFE_COPILOT) ? "🛡️ SAFE: ยิงมือ Co-Pilot" : "⚡ AGGRESSIVE: สไนเปอร์ AUTO";
         color modeBtnBg = (g_TradeMode == TRADE_MODE_SAFE_COPILOT) ? C'18,90,55' : C'195,80,15';
         CreateButton("BTN_TRADE_MODE", ctrlInnerX, btnY, actionW, 28, modeBtnText, modeBtnBg, clrWhite);
         CreateButton("BTN_CLOSE_ALL", ctrlInnerX + actionW + 8, btnY, actionW, 28, "⚠️ ปิดฉุกเฉิน (CLOSE ALL)", C'160,20,20', clrWhite);

         // Footer Info Label
         btnY += 32;
         string footerInfo = "MAGIC: " + IntegerToString(InpMagicNumber) + " • " + (g_TradeMode == TRADE_MODE_SAFE_COPILOT ? "🛡️ SAFE (HTF GUARD ON)" : "⚡ AGGRESSIVE (AUTO SNIPER)") + (InpManageManualTrades ? " • 📱 CO-PILOT: ON" : "");
         CreateLabel("CTRL_INFO", ctrlInnerX, btnY, footerInfo, "Segoe UI", 7, clrDarkGray);
      }
   }

   // C. CLEAN LEGACY IN-CHART MTF OBJECTS IF ANY
   ObjectsDeleteAll(0, GUI_PREFIX + "MTF_");
}

//+------------------------------------------------------------------+
//| FORMAT DISTANCE (POINTS VS DOLLARS) FOR ASSET-AWARE DISPLAY      |
//+------------------------------------------------------------------+
string FormatPlanDistStr(double pts, bool isLoss)
{
   string prefix = isLoss ? "-" : "+";
   if(g_AssetProfile.assetType == ASSET_CRYPTO || (pts * _Point) >= 100.0)
   {
      double dollarVal = pts * _Point;
      if(dollarVal >= 100.0)
         return StringFormat("%s$%.0f", prefix, dollarVal);
      else
         return StringFormat("%s$%.2f", prefix, dollarVal);
   }
   return StringFormat("%s%.0f pts", prefix, pts);
}

//+------------------------------------------------------------------+
//| 2-LINE STACKED STATE BANNER FORMATTER & INTELLIGENT AUTO-WRAP    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| SMART TEXT AUTO-WRAPPER (PREVENTS ANY OVERFLOW IN HUD CARDS)     |
//+------------------------------------------------------------------+
void SmartWrapText(const string rawText, int maxCharsLine1, string &line1, string &line2)
{
   line1 = rawText;
   line2 = "";
   StringTrimLeft(line1);
   StringTrimRight(line1);
   if(line1 == "") return;

   int nPos = StringFind(line1, "\n");
   if(nPos >= 0)
   {
      line2 = StringSubstr(line1, nPos + 1);
      line1 = StringSubstr(line1, 0, nPos);
      StringTrimLeft(line2);
      StringTrimRight(line2);
      StringTrimLeft(line1);
      StringTrimRight(line1);
      return;
   }

   int len = StringLen(line1);
   if(len <= maxCharsLine1) return;

   int splitPos = -1;
   int sepLen   = 0;

   // Priority A: check for logical separators
   string seps[] = {" • ", " | ", " - ", " : ", " •", " |", " -"};
   int sepLens[] = {3, 3, 3, 3, 2, 2, 2};
   for(int s = 0; s < 7; s++)
   {
      int pos = StringFind(line1, seps[s], 18);
      if(pos > 18 && pos <= maxCharsLine1)
      {
         if(pos > splitPos)
         {
            splitPos = pos;
            sepLen   = sepLens[s];
         }
      }
   }

   // Priority B: check for " (", " ["
   if(splitPos < 0)
   {
      int pPos = StringFind(line1, " (", 20);
      if(pPos > 20 && pPos <= maxCharsLine1)
      {
         splitPos = pPos;
         sepLen   = 1;
      }
      else
      {
         int bPos = StringFind(line1, " [", 20);
         if(bPos > 20 && bPos <= maxCharsLine1)
         {
            splitPos = bPos;
            sepLen   = 1;
         }
      }
   }

   // Priority C: check space near maxCharsLine1
   if(splitPos < 0)
   {
      for(int i = MathMin(maxCharsLine1, len - 3); i >= 18; i--)
      {
         ushort ch = StringGetCharacter(line1, i);
         if(ch == ' ' || ch == ',' || ch == ';')
         {
            splitPos = i;
            sepLen   = 1;
            break;
         }
      }
   }

   if(splitPos < 0)
   {
      splitPos = maxCharsLine1;
      sepLen   = 0;
   }

   line2 = StringSubstr(line1, splitPos + sepLen);
   line1 = StringSubstr(line1, 0, splitPos);
   StringTrimLeft(line2);
   StringTrimRight(line2);
   StringTrimLeft(line1);
   StringTrimRight(line1);

   if(line2 != "" && StringFind(line2, "↳") < 0 && StringFind(line2, "•") < 0 && StringFind(line2, "(") != 0)
      line2 = "↳ " + line2;
}

void SmartWrapText3(const string rawText, int maxCharsLine1, int maxCharsLine2, string &line1, string &line2, string &line3)
{
   line1 = rawText;
   line2 = "";
   line3 = "";

   SmartWrapText(rawText, maxCharsLine1, line1, line2);
   if(line2 != "" && StringLen(line2) > maxCharsLine2)
   {
      string tempL2 = line2;
      string tempL3 = "";
      SmartWrapText(tempL2, maxCharsLine2, tempL2, tempL3);
      line2 = tempL2;
      line3 = tempL3;
      if(line3 != "" && StringFind(line3, "↳") < 0)
         line3 = "   ↳ " + line3;
   }
}

void FormatStateBannerLines(const string rawState, color stateCol, string &line1, string &line2, color &col1, color &col2)
{
   line1 = rawState;
   line2 = "";
   col1  = stateCol;

   // Soft, readable contrast colors for Line 2
   if(stateCol == clrOrangeRed || stateCol == clrTomato || stateCol == clrCrimson || stateCol == clrRed)
      col2 = C'255,195,195';
   else if(stateCol == clrGold || stateCol == clrYellow || stateCol == C'255,165,0' || stateCol == C'255,185,50' || stateCol == clrOrange)
      col2 = C'255,230,170';
   else if(stateCol == clrLime || stateCol == clrSpringGreen)
      col2 = C'190,255,210';
   else if(stateCol == clrDeepSkyBlue || stateCol == clrAqua)
      col2 = C'190,230,255';
   else
      col2 = clrSilver;

   if(rawState == "") return;

   // 1. Explicit Newline Split (\n)
   int nPos = StringFind(rawState, "\n");
   if(nPos >= 0)
   {
      line1 = StringSubstr(rawState, 0, nPos);
      line2 = StringSubstr(rawState, nPos + 1);
      StringTrimLeft(line2);
      StringTrimRight(line2);
      return;
   }

   // 2. If short enough (<= 40 chars), check if known state has rich context, else 1-line
   int len = StringLen(rawState);
   if(len <= 40)
   {
      if(rawState == "WAIT_STRUCTURE (รอฟอร์มคลื่น High/Low)")
      {
         line1 = "🔍 WAITING FOR MARKET STRUCTURE";
         line2 = "↳ รอสแกน High/Low สวิงล่าสุด และ Dow BOS ⏳";
         return;
      }
      return;
   }

   // 3. Intelligent Splitter for Strings > 44 Chars
   int splitPos = -1;
   int sepLen   = 0;

   // Priority A: Check for " • " between 18 and 48
   int dotPos = StringFind(rawState, " • ", 18);
   if(dotPos > 18 && dotPos <= 48)
   {
      splitPos = dotPos;
      sepLen   = 3;
   }

   // Priority B: Check for " - " between 18 and 48
   if(splitPos < 0)
   {
      int dashPos = StringFind(rawState, " - ", 18);
      if(dashPos > 18 && dashPos <= 48)
      {
         splitPos = dashPos;
         sepLen   = 3;
      }
   }

   // Priority C: Check for " (" between 22 and 48
   if(splitPos < 0)
   {
      int parenPos = StringFind(rawState, " (", 22);
      if(parenPos > 22 && parenPos <= 48)
      {
         splitPos = parenPos;
         sepLen   = 1;
      }
   }

   // Priority D: Fallback to space nearest to index 40
   if(splitPos < 0)
   {
      for(int i = MathMin(45, len - 5); i >= 20; i--)
      {
         ushort ch = StringGetCharacter(rawState, i);
         if(ch == ' ' || ch == ',' || ch == ';')
         {
            splitPos = i;
            sepLen   = 1;
            break;
         }
      }
   }

   if(splitPos > 0)
   {
      line1 = StringSubstr(rawState, 0, splitPos);
      line2 = StringSubstr(rawState, splitPos + sepLen);
      StringTrimLeft(line2);
      StringTrimRight(line2);
      if(StringFind(line2, "↳") < 0 && StringFind(line2, "•") < 0 && StringFind(line2, "(") != 0)
         line2 = "↳ " + line2;
   }
}

//+------------------------------------------------------------------+
//| UPDATE HUD VALUES REAL-TIME (4-CARD MODULAR ENGINE)              |
//+------------------------------------------------------------------+
void UpdateHUDValues()
{
   if(!g_ShowDashboard)
      return;

   string stateText = "WAITING FOR MARKET DATA";
   color  stateColor = clrYellow;

   int openCount = CountOpenPositions(InpManageManualTrades);
   double netPnl = CalculateTotalProfit();
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();

   if(openCount == 0 && g_HTFReversal.isValid)
   {
      stateText = StringFormat("⚡ %s ⚡\n↳ สัญญาณกลับตัวแท่งเทียน: %s", (g_HTFReversal.direction == 1 ? "HTF DEMAND DIP-BUY SIGNAL" : "HTF SUPPLY DIP-SELL SIGNAL"), g_HTFReversal.reason);
      stateColor = (g_HTFReversal.direction == 1 ? clrLime : clrTomato);
   }
   else if(openCount == 0 && g_ExhaustionActive && g_ExhaustionGuardMsg != "")
   {
      stateText = g_ExhaustionGuardMsg;
      stateColor = clrOrangeRed;
   }
   else if(openCount == 0 && InpUseNewsCalendarGuard && g_NewsStandDownActive)
   {
      string newsTimeStr = (g_NewsMinutesUntil >= 0) ? StringFormat("อีก %d นาที", g_NewsMinutesUntil) : StringFormat("ผ่านไป %d นาที (รอตลาดนิ่งอีก %d นาที)", MathAbs(g_NewsMinutesUntil), MathMax(0, InpNewsPostMinutes - MathAbs(g_NewsMinutesUntil)));
      stateText = StringFormat("⏰ ข่าวแดง USD (%s) • %s\n↳ ช่วงผันผวนสูง • พักระบบออโต้เทรดชั่วคราว 🛡️", g_NewsEventTitle, newsTimeStr);
      stateColor = C'255,165,0';
   }
   else if(g_DailyTargetReached)
   {
      stateText = StringFormat("🏆 DAILY TARGET REACHED (%s) • สำเร็จตามเป้า 👑\n↳ บรรลุเป้าหมายรายวันแล้ว • พักพอร์ตตามแผนสถาบัน 🛡️", FormatMoney(g_TodayPnL, true));
      stateColor = clrGold;
   }
   else if(g_DailyMaxLossReached)
   {
      stateText = StringFormat("🛑 MAX LOSS REACHED (%.1f%%) • ตัดขาดทุนรักษาทุน 🛡️\n↳ ล็อกพอร์ตตามกฎความเสี่ยง [กดรีเซ็ตที่ Card 3 🔄]", g_TodayPnLPct);
      stateColor = clrCrimson;
   }
   else if(InpEnablePostSLBECooldown && TimeCurrent() < g_PostSLBECooldownUntil)
   {
      int remainSec = (int)(g_PostSLBECooldownUntil - TimeCurrent());
      int m = remainSec / 60;
      int s = remainSec % 60;
      stateText = StringFormat("🧘‍♂️ [พักระบบ 15 นาที: %02d:%02d ⏳] หลังชน %s 🛡️\n↳ ตลาดกำลังซึมซับความผันผวน ป้องกันการโดนเบรกหลอกซ้ำ", m, s, (g_PostSLBECooldownReason != "" ? g_PostSLBECooldownReason : "SL/BE"));
      stateColor = C'255,185,50';
   }
   else if(InpEnableRevengeShield && g_TradeMode == TRADE_MODE_SAFE_COPILOT && TimeCurrent() < g_RevengeCooldownUntil)
   {
      int remainSec = (int)(g_RevengeCooldownUntil - TimeCurrent());
      int m = remainSec / 60;
      int s = remainSec % 60;
      stateText = StringFormat("🧘‍♂️ [พักใจ %d นาที: %02d:%02d] คุณแอนเป็นห่วง ❤️\n↳ ลุกไปดื่มน้ำ ผ่อนคลายสายตา ปล่อยให้ระบบดูแลพอร์ตครับ!", InpRevengeCooldownMinutes, m, s);
      stateColor = C'255,185,50';
   }
   else if(openCount > 0)
   {
      string dirBadge = (g_PlanDirection == 1) ? "🟢 BUY" : (g_PlanDirection == -1 ? "🔴 SELL" : "🎯");
      if(openCount >= InpMaxOpenPos || !g_AllowMultiPos)
      {
         stateText = StringFormat("IN_POSITION (ถือ %s %d ไม้ • %s)\n↳ แผนบริหารออเดอร์ • รัน %s 🛡️", dirBadge, openCount, FormatMoney(netPnl, true), g_AdaptiveTrailModeStr);
         stateColor = (netPnl >= 0) ? clrSpringGreen : clrGold;
      }
      else
      {
         if(g_BotState == STATE_TRIGGER_READY)
         {
            stateText = StringFormat("⚡ PYRAMIDING %s SIGNAL (ไม้ที่ %d/%d) ⚡\n↳ เงื่อนไขตามเทรนด์ครบถ้วน • พร้อมเปิดไม้เสริมพอร์ต 🚀", dirBadge, openCount + 1, InpMaxOpenPos);
            stateColor = clrLime;
         }
         else
         {
            stateText = StringFormat("IN_POSITION (ถือ %s %d/%d ไม้ • %s)\n↳ แผนบริหารออเดอร์ • รัน %s 🚀", dirBadge, openCount, InpMaxOpenPos, FormatMoney(netPnl, true), g_AdaptiveTrailModeStr);
            stateColor = (netPnl >= 0) ? clrSpringGreen : clrGold;
         }
      }
   }
   else
   {
      switch(g_BotState)
      {
         case STATE_WAIT_STRUCTURE:
            stateText = "WAIT_STRUCTURE (รอฟอร์มคลื่น High/Low)\n↳ กำลังสแกนหาจุดสวิง และตรวจจับ Bullish/Bearish BOS ⏳";
            stateColor = clrOrange;
            break;
         case STATE_WAIT_PULLBACK:
            stateText = (g_MarketTrend == TREND_BULLISH ? "BULLISH BOS - รอราคาย่อตัว Wave 2\n↳ รอราคาย่อเข้าสู่โซน Discount Fibo (50.0% - 78.6%) ⏳" 
                                                        : "BEARISH BOS - รอราคาเด้งตัว Wave 2\n↳ รอราคาเด้งเข้าสู่โซน Premium Fibo (50.0% - 78.6%) ⏳");
            stateColor = clrDeepSkyBlue;
            break;
         case STATE_PULLBACK_ARMED:
            if(g_ReversalArmedPendingConfirm)
            {
               stateText = StringFormat("🏛️ REVERSAL ARMED • รอคอนเฟิร์มกลับตัว\n↳ %s", g_ReversalPendingReason);
               stateColor = clrGold;
            }
            else if(g_PlanSource == "WICK_SNIPER")
            {
               stateText = (g_PlanDirection == 1) ? StringFormat("🔭 50%% WICK SNIPER BUY ARMED\n↳ %s", g_WickSniper_Setup.description)
                                                  : StringFormat("🔭 50%% WICK SNIPER SELL ARMED\n↳ %s", g_WickSniper_Setup.description);
               stateColor = (g_PlanDirection == 1) ? clrDeepSkyBlue : clrHotPink;
            }
      else if(g_PlanSource == "UNICORN")
            {
               stateText = (g_PlanDirection == 1) ? "🦄 UNICORN BUY ARMED • แตะโซน Breaker/FVG\n↳ รอแท่งเทียน Bullish Rejection สับไกยิงไม้สไนเปอร์ 🟢" 
                                                  : "🦄 UNICORN SELL ARMED • แตะโซน Breaker/FVG\n↳ รอแท่งเทียน Bearish Rejection สับไกยิงไม้สไนเปอร์ 🔴";
            }
            else if(g_PlanSource == "CRT")
            {
               stateText = (g_PlanDirection == 1) ? "🐢 CRT BUY ARMED • กวาดสภาพคล่อง SSL\n↳ รอราคาทิ้งไส้ Rejection เด้งกลับเข้ากรอบ 🟢" 
                                                  : "🐢 CRT SELL ARMED • กวาดสภาพคล่อง BSL\n↳ รอราคาทิ้งไส้ Rejection ทุบกลับเข้ากรอบ 🔴";
            }
            else
            {
               stateText = "🎯 WAVE 2 ARMED (แตะโซน Fibo สำเร็จ)\n↳ รอสัญญาณแท่งเทียน Pure PA Rejection ยืนยันสับไก 🚀";
            }
            stateColor = clrGold;
            break;
         case STATE_TRIGGER_READY:
            if(g_PlanSource == "WICK_SNIPER")
            {
               stateText = (g_PlanDirection == 1) ? "🔭 BUY SNIPER (50%% WICK + 3-CANDLE) 🟢\n↳ ยืนยัน 3 แท่งมหาประลัย + ดักย่อ Retest 50%% ครบถ้วน 🎯" 
                                                  : "🔭 SELL SNIPER (50%% WICK + 3-CANDLE) 🔴\n↳ ยืนยัน 3 แท่งมหาประลัย + ดักย่อ Retest 50%% ครบถ้วน 🎯";
               stateColor = (g_PlanDirection == 1) ? clrLime : clrTomato;
            }
            else if(g_PlanSource == "UNICORN")
            {
               stateText = (g_PlanDirection == 1) ? "🦄 BUY SNIPER (ICT UNICORN) 🟢\n↳ สัญญาณ Unicorn ครบถ้วน • พร้อมเปิด Buy สไนเปอร์ 🚀" 
                                                  : "🦄 SELL SNIPER (ICT UNICORN) 🔴\n↳ สัญญาณ Unicorn ครบถ้วน • พร้อมเปิด Sell สไนเปอร์ 🚀";
               stateColor = (g_PlanDirection == 1) ? clrLime : clrTomato;
            }
            else if(g_PlanSource == "CRT")
            {
               stateText = (g_PlanDirection == 1) ? "🐢 BUY SNIPER (CRT TURTLE SOUP) 🟢\n↳ กวาด SSL สมบูรณ์ • พร้อมเปิด Buy ดักตีกินการ Sweep 🚀" 
                                                  : "🐢 SELL SNIPER (CRT TURTLE SOUP) 🔴\n↳ กวาด BSL สมบูรณ์ • พร้อมเปิด Sell ดักตีกินการ Sweep 🚀";
               stateColor = (g_PlanDirection == 1) ? clrLime : clrTomato;
            }
            else if(g_PlanSource == "SPIKE")
            {
               stateText = (g_PlanDirection == 1) ? "⚡ BUY SNIPER (SPIKE PINBAR) ⚡\n↳ สัญญาณ Spike คมกริบ • พร้อมเปิด Buy จังหวะเด้ง 🚀" 
                                                  : "⚡ SELL SNIPER (SPIKE PINBAR) ⚡\n↳ สัญญาณ Spike คมกริบ • พร้อมเปิด Sell จังหวะทุบ 🚀";
               stateColor = (g_PlanDirection == 1) ? clrLime : clrTomato;
            }
            else if(g_PlanSource == "HTF_REVERSAL")
            {
               stateText = (g_PlanDirection == 1) ? "🎯 BUY REVERSAL (HTF DEMAND) 🎯\n↳ แตะแนวรับใหญ่ระดับชาร์ตแม่ • พร้อมเปิด Buy กลับตัว 🚀" 
                                                  : "🎯 SELL REVERSAL (HTF SUPPLY) 🎯\n↳ แตะแนวต้านใหญ่ระดับชาร์ตแม่ • พร้อมเปิด Sell กลับตัว 🚀";
               stateColor = (g_PlanDirection == 1) ? clrLime : clrTomato;
            }
            else if(g_PlanSource == "REVERSAL")
            {
               string revTag = g_CME_NearMegaCallWall ? "Mega Call Wall" : (g_CME_NearCallWall ? "Call Wall" : (g_CME_NearIntermedCall ? "Intermed Call" : (g_CME_NearMacroPutWall ? "Macro Put Base" : (g_CME_NearPutWall ? "Put Wall" : (g_CME_NearIntermedPut ? "Intermed Put" : (g_ZScoreExtremePeak ? "+2.0 SD" : (g_ZScoreExtremeValley ? "-2.0 SD" : "Peak/Valley")))))));
               stateText = (g_PlanDirection == 1) ? StringFormat("🛡️ CONFIRMED BUY REVERSAL (%s) 🟢\n↳ คอนเฟิร์มกลับตัวฐานล่าง • พร้อมเปิด Buy สไนเปอร์ 🚀", revTag) 
                                                  : StringFormat("🎯 CONFIRMED SELL REVERSAL (%s) 🔴\n↳ คอนเฟิร์มกลับตัวยอดบน • พร้อมเปิด Sell สไนเปอร์ 🚀", revTag);
               stateColor = (g_PlanDirection == 1) ? clrLime : clrTomato;
            }
            else if(g_PlanSource == "BREAKDOWN" || g_PlanSource == "BREAKOUT")
            {
               stateText = (g_PlanDirection == 1) ? "🚀 BUY BREAKOUT (MOMENTUM SURGE) 🟢\n↳ ทะลุแนวต้านพร้อมแรงขับเคลื่อน • พร้อมเปิด Buy ตามเทรนด์ 🚀" 
                                                  : "🎯 SELL BREAKDOWN (SUPPORT BREACH) 🔴\n↳ หลุดแนวรับสำคัญ • พร้อมเปิด Sell ตามเทรนด์ขาลง 🚀";
               stateColor = (g_PlanDirection == 1) ? clrLime : clrTomato;
            }
            else
            {
               stateText = (g_PlanDirection == 1 || (g_PlanDirection == 0 && g_MarketTrend == TREND_BULLISH))
                           ? "⚡ BUY SIGNAL (WAVE 3 IMPULSE) ⚡\n↳ สัญญาณคลื่น Wave 3 สมบูรณ์ • พร้อมเปิด Buy รันกำไร 🚀" 
                           : "⚡ SELL SIGNAL (WAVE 3 IMPULSE) ⚡\n↳ สัญญาณคลื่น Wave 3 สมบูรณ์ • พร้อมเปิด Sell รันกำไร 🚀";
               stateColor = (g_PlanDirection == 1 || (g_PlanDirection == 0 && g_MarketTrend == TREND_BULLISH)) ? clrLime : clrTomato;
            }
            break;
         case STATE_IN_POSITION:
            stateText = "IN_POSITION (กำลังรันเทรนด์ Wave 3)\n↳ ดูแลความเสี่ยงด้วย Adaptive Trailing & Partial TP 🛡️";
            stateColor = clrSpringGreen;
            break;
      }
   }
   if(g_PostCloseCooldownRemainSec > 0 && openCount == 0)
   {
      stateText = StringFormat("🛡️ COOLDOWN (พักระบบหลังปิดไม้ 180s: เหลือ %ds ⏳)\n↳ รอให้ตลาดซึมซับสภาพคล่อง ป้องกันอารมณ์ Overtrade 🧘", g_PostCloseCooldownRemainSec);
      stateColor = clrGold;
   }

   string stateLine1 = "", stateLine2 = "";
   color stateCol1 = stateColor, stateCol2 = clrSilver;
   FormatStateBannerLines(stateText, stateColor, stateLine1, stateLine2, stateCol1, stateCol2);

   ObjectSetString(0, GUI_PREFIX + "HUD_STATE_TXT", OBJPROP_TEXT, stateLine1);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_TXT", OBJPROP_COLOR, stateCol1);
   ObjectSetString(0, GUI_PREFIX + "HUD_STATE_TXT_L2", OBJPROP_TEXT, stateLine2);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_TXT_L2", OBJPROP_COLOR, stateCol2);

   // Align Line 1 vertically: centered if 1 line, top aligned if 2 lines
   int boxY = (int)ObjectGetInteger(0, GUI_PREFIX + "HUD_STATE_BOX", OBJPROP_YDISTANCE);
   if(boxY <= 0) boxY = 79;
   int line1_Y = (stateLine2 != "") ? (boxY + 3) : (boxY + 11);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_TXT", OBJPROP_YDISTANCE, line1_Y);

   // Dynamic Alert Accent on State Box
   if(stateColor == clrOrangeRed || stateColor == clrTomato || stateColor == clrCrimson || stateColor == clrRed)
   {
      ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_BOX", OBJPROP_BGCOLOR, C'32,14,20');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_BOX", OBJPROP_COLOR, C'180,45,60');
   }
   else if(stateColor == clrGold || stateColor == clrYellow || stateColor == C'255,165,0')
   {
      ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_BOX", OBJPROP_BGCOLOR, C'28,24,14');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_BOX", OBJPROP_COLOR, C'160,130,40');
   }
   else if(stateColor == clrLime || stateColor == clrSpringGreen)
   {
      ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_BOX", OBJPROP_BGCOLOR, C'12,28,20');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_BOX", OBJPROP_COLOR, C'35,140,75');
   }
   else
   {
      ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_BOX", OBJPROP_BGCOLOR, C'15,28,40');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_STATE_BOX", OBJPROP_COLOR, C'40,70,100');
   }

   // -------------------------------------------------------------
   // 1. CARD 1: MARKET ANALYSIS & SCANNER (DYNAMIC COLOR ROWS)
   // -------------------------------------------------------------
   // Directional Bias Engine Live Update
   string buyStr  = StringFormat("🟢 BUY %d%%", g_MarketBiasBuyPct);
   string sellStr = StringFormat("🔴 SELL %d%%", g_MarketBiasSellPct);
   color buyCol   = (g_MarketBiasBuyPct >= 65) ? clrLime : (g_MarketBiasBuyPct >= 50 ? C'50,225,130' : clrGray);
   color sellCol  = (g_MarketBiasSellPct >= 65) ? clrTomato : (g_MarketBiasSellPct >= 50 ? C'255,100,120' : clrGray);

   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_BIAS_BUY", OBJPROP_TEXT, buyStr);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_BIAS_BUY", OBJPROP_COLOR, buyCol);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_BIAS_SELL", OBJPROP_TEXT, sellStr);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_BIAS_SELL", OBJPROP_COLOR, sellCol);

   string adviceToShow   = (g_SmartActionCommand != "") ? g_SmartActionCommand : g_MarketBiasAdvice;
   string subtextToShow  = (g_SmartActionSubtext != "") ? g_SmartActionSubtext : "";
   color  adviceColToShow = (g_SmartActionCommand != "") ? g_SmartActionColor : g_MarketBiasAdviceCol;

   string advL1 = adviceToShow, advL2 = "";
   SmartWrapText(adviceToShow, 42, advL1, advL2);
   if(advL2 != "")
   {
      ObjectSetString(0, GUI_PREFIX + "HUD_VAL_MKT_ADVICE", OBJPROP_TEXT, advL1);
      string l2Text = (subtextToShow != "") ? (advL2 + " • " + subtextToShow) : advL2;
      if(StringLen(l2Text) > 48) l2Text = advL2; // Avoid right margin clipping
      ObjectSetString(0, GUI_PREFIX + "HUD_VAL_MKT_ADVICE_L2", OBJPROP_TEXT, l2Text);
   }
   else
   {
      string subL1 = subtextToShow, subL2 = "";
      SmartWrapText(subtextToShow, 50, subL1, subL2);
      ObjectSetString(0, GUI_PREFIX + "HUD_VAL_MKT_ADVICE", OBJPROP_TEXT, adviceToShow);
      ObjectSetString(0, GUI_PREFIX + "HUD_VAL_MKT_ADVICE_L2", OBJPROP_TEXT, subL1);
   }
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_MKT_ADVICE", OBJPROP_COLOR, adviceColToShow);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_MKT_ADVICE_L2", OBJPROP_COLOR, adviceColToShow);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_BAR_ROW_MKT_ADVICE", OBJPROP_BGCOLOR, adviceColToShow);

   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   string sessShort = g_SessionName;
   StringReplace(sessShort, " (High Volatility)", "");
   StringReplace(sessShort, " (Normal)", "");
   
   string cmeDTEInfo = "";
   if(InpUseCMEWallGuard && g_AssetProfile.assetType == ASSET_GOLD)
   {
      if(g_CME_ExpirationAlert)
         cmeDTEInfo = StringFormat(" • 🚨 CME: %dD (Pinning!)", (int)g_CME_LiveDTE);
      else
         cmeDTEInfo = StringFormat(" • ⏳ CME: %dD", (int)g_CME_LiveDTE);
   }

   string assetVal = StringFormat("%s %s • %s%s", g_AssetProfile.iconStr, g_AssetProfile.categoryName, sessShort, cmeDTEInfo);
   if(InpUseNewsCalendarGuard && g_NewsStandDownActive)
   {
      string newsTimeStr = (g_NewsMinutesUntil >= 0) ? StringFormat("อีก %dm", g_NewsMinutesUntil) : StringFormat("ผ่าน %dm (พักอีก %dm)", MathAbs(g_NewsMinutesUntil), MathMax(0, InpNewsPostMinutes - MathAbs(g_NewsMinutesUntil)));
      string shortNews = g_NewsEventTitle;
      if(StringLen(shortNews) > 22) shortNews = StringSubstr(shortNews, 0, 20) + "..";
      assetVal = StringFormat("⏰ ข่าว USD: %s (%s) [พัก]%s", shortNews, newsTimeStr, cmeDTEInfo);
      SetRow("ROW_MKT_ASSET", "📰 ข่าวเศรษฐกิจ USD", assetVal, C'255,165,0', clrDarkOrange, C'255,200,100');
   }
   else
   {
      SetRow("ROW_MKT_ASSET", "🏷️ สินทรัพย์ & เซสชัน", assetVal, clrAqua, clrDeepSkyBlue, clrDeepSkyBlue);
   }

   string spreadVal = StringFormat("%d pts (%s)", spread, (spread <= g_AssetProfile.maxSpread ? "ปกติ (OK) 🟢" : "สเปรดสูง (HIGH) 🔴"));
   color  spreadCol = (spread <= g_AssetProfile.maxSpread) ? clrLime : clrTomato;
   color  spreadTitleCol = (spread <= g_AssetProfile.maxSpread) ? clrPaleGreen : clrLightCoral;
   SetRow("ROW_MKT_SPREAD", "📊 ค่า Spread ปัจจุบัน", spreadVal, spreadCol, (spread <= g_AssetProfile.maxSpread ? clrSeaGreen : clrCrimson), spreadTitleCol);

   string trendTitle = "⚔️ MTF Samurai";
   string trendVal   = StringFormat("%s (%d%% %s)", g_SamuraiMTF.summaryStr, 
                                     (int)MathRound(g_SamuraiMTF.consensusDir >= 0 ? g_SamuraiMTF.bullScore : (100.0 - g_SamuraiMTF.bullScore)),
                                     (g_SamuraiMTF.consensusDir == 1 ? "BUY" : (g_SamuraiMTF.consensusDir == -1 ? "SELL" : "NEUTRAL")));
   color trendValCol = (g_SamuraiMTF.consensusDir == 1 ? clrLime : (g_SamuraiMTF.consensusDir == -1 ? clrCrimson : clrGold));
   color trendTitleCol = (g_SamuraiMTF.consensusDir == 1 ? clrPaleGreen : (g_SamuraiMTF.consensusDir == -1 ? clrLightCoral : clrKhaki));
   SetRow("ROW_MKT_TREND", trendTitle, trendVal, trendValCol, (g_SamuraiMTF.consensusDir == 1 ? clrSeaGreen : (g_SamuraiMTF.consensusDir == -1 ? clrRed : clrGoldenrod)), trendTitleCol);

   string macroTrendStr = StringFormat("H1:%s  H4:%s • %s", 
                                        (g_SamuraiMTF.isBullish[4] ? "BULL 🟢" : (g_SamuraiMTF.isBearish[4] ? "BEAR 🔴" : "SIDE 🟡")),
                                        (g_SamuraiMTF.isBullish[5] ? "BULL 🟢" : (g_SamuraiMTF.isBearish[5] ? "BEAR 🔴" : "SIDE 🟡")),
                                        g_SamuraiMTF.gradeStr);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_ROW_MKT_TREND_L2", OBJPROP_TEXT, "↳ Samurai Macro: " + macroTrendStr);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_ROW_MKT_TREND_L2", OBJPROP_COLOR, (g_SamuraiMTF.consensusDir == 1 ? C'175,255,200' : (g_SamuraiMTF.consensusDir == -1 ? C'255,185,185' : C'255,235,175')));

   SetRow("ROW_MKT_CROSS", "👑 สัญญาณ EMA Cross", g_EMACrossStatusStr, g_EMACrossValCol, g_EMACrossBarCol, g_EMACrossTitleCol);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_ROW_MKT_CROSS_L2", OBJPROP_TEXT, g_EMA14_StatusText);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_ROW_MKT_CROSS_L2", OBJPROP_COLOR, g_EMA14_StatusCol);

   SABCDWaveData waveActive = CalculateABCDWave(InpTimeframe);
   string waveVal = "";
   if(waveActive.priceA > 0 && waveActive.priceB > 0)
   {
      string oteStr = "";
      string targetStr = "";
      if(_Digits > 2)
      {
         oteStr    = StringFormat("%.1f-%.1f", waveActive.oteLow, waveActive.oteHigh);
         targetStr = StringFormat("%.1f", waveActive.priceD);
      }
      else if(waveActive.priceA >= 1000.0)
      {
         oteStr    = StringFormat("%.0f-%.0f", waveActive.oteLow, waveActive.oteHigh);
         targetStr = StringFormat("%.0f", waveActive.priceD);
      }
      else
      {
         oteStr    = StringFormat("%.2f-%.2f", waveActive.oteLow, waveActive.oteHigh);
         targetStr = StringFormat("%.2f", waveActive.priceD);
      }
      waveVal = StringFormat("[%s] OTE:%s • เป้า D:%s", waveActive.legName, oteStr, targetStr);
   }
   else if(g_Fibo.p0 > 0 || g_Fibo.zoneHigh > 0)
   {
      if(g_Fibo.zoneLow >= 1000.0)
         waveVal = StringFormat("%s [%.0f - %.0f]", g_WaveStatusStr, g_Fibo.zoneLow, g_Fibo.zoneHigh);
      else
         waveVal = StringFormat("%s [%.2f - %.2f]", g_WaveStatusStr, g_Fibo.zoneLow, g_Fibo.zoneHigh);
   }
   else
      waveVal = g_WaveStatusStr;

   color waveValCol = (g_MarketTrend == TREND_BULLISH ? clrLime : (g_MarketTrend == TREND_BEARISH ? clrTomato : clrGold));
   color waveTitleCol = (g_MarketTrend == TREND_BULLISH ? clrPaleGreen : (g_MarketTrend == TREND_BEARISH ? clrLightCoral : clrKhaki));
   color waveBarCol = (g_MarketTrend == TREND_BULLISH ? clrSeaGreen : (g_MarketTrend == TREND_BEARISH ? clrRed : clrGoldenrod));
   SetRow("ROW_MKT_WAVE", "🌊 คลื่น ABCD ชาร์ตแม่", waveVal, waveValCol, waveBarCol, waveTitleCol);

   color paValCol = (g_PatternScore >= 70 ? clrGold : (g_MarketTrend == TREND_BULLISH ? clrLime : (g_MarketTrend == TREND_BEARISH ? clrTomato : clrSilver)));
   color paTitleCol = (g_PatternScore >= 70 ? clrKhaki : (g_MarketTrend == TREND_BULLISH ? clrPaleGreen : (g_MarketTrend == TREND_BEARISH ? clrLightCoral : clrLightGray)));
   color paBarCol = (g_PatternScore >= 70 ? clrDarkGoldenrod : (g_MarketTrend == TREND_BULLISH ? clrSeaGreen : clrCrimson));
   string paDisplay = g_PatternName;
   StringReplace(paDisplay, "แท่งเทียนตันขึ้นตามเทรนด์", "ตันขึ้นตามเทรนด์");
   StringReplace(paDisplay, "แท่งเทียนตันลงตามเทรนด์", "ตันลงตามเทรนด์");
   StringReplace(paDisplay, "Turtle Soup", "Soup");
   StringReplace(paDisplay, "Inverted Head & Shoulders", "Inv. H&S");
   StringReplace(paDisplay, "Pin Bar / Hammer", "Pin Bar");
   StringReplace(paDisplay, "Double Bottom (W-Pattern)", "Double Bottom (W)");
   StringReplace(paDisplay, "Double Top (M-Pattern)", "Double Top (M)");
   StringReplace(paDisplay, "Three White Soldiers", "3 White Soldiers");
   StringReplace(paDisplay, "Three Black Crows", "3 Black Crows");
   StringReplace(paDisplay, " + VPA ⏳", " (VPA ⏳)");
   StringReplace(paDisplay, " + VPA 🔥", " (VPA 🔥)");
   StringReplace(paDisplay, " + VPA ✏️", " (VPA ✏️)");
   StringReplace(paDisplay, " + CRT 🐢", " • CRT 🐢");
   StringReplace(paDisplay, " (เมฆดำคลุม 50%)", "");
   StringReplace(paDisplay, " (แทงทะลุ 50%)", "");
   StringReplace(paDisplay, " (คนท้องขาขึ้น)", "");
   StringReplace(paDisplay, " (คนท้องขาลง)", "");
   StringReplace(paDisplay, " (โดจิหางยาวล่าง)", "");
   StringReplace(paDisplay, " (โดจิหางยาวบน)", "");
   StringReplace(paDisplay, " (กลืนกินขาขึ้น)", "");
   StringReplace(paDisplay, " (กลืนกินขาลง)", "");
   StringReplace(paDisplay, " (กลับตัวขึ้น 3 แท่ง)", "");
   StringReplace(paDisplay, " (กลับตัวลง 3 แท่ง)", "");
   if(StringLen(paDisplay) > 42)
   {
      paDisplay = StringSubstr(paDisplay, 0, 39);
      while(StringLen(paDisplay) > 0 && (StringSubstr(paDisplay, StringLen(paDisplay)-1, 1) == "+" || StringSubstr(paDisplay, StringLen(paDisplay)-1, 1) == " "))
         paDisplay = StringSubstr(paDisplay, 0, StringLen(paDisplay)-1);
      paDisplay += "...";
   }
   SetRow("ROW_MKT_SIGNAL", "🕯️ แท่งเทียน (PA)", paDisplay, paValCol, paBarCol, paTitleCol);
   
   color adxValCol = (g_ADXMode == ADX_MODE_TURBO ? clrAqua : (g_ADXMode == ADX_MODE_RANGE ? clrGold : clrLime));
   color adxTitleCol = (g_ADXMode == ADX_MODE_TURBO ? clrTurquoise : (g_ADXMode == ADX_MODE_RANGE ? clrKhaki : clrPaleGreen));
   string adxDisplay = g_ADXStatusStr;
   if(InpUseZScoreGuard && g_LiveZScore != 0)
   {
      string adxTag = (g_ADXMode == ADX_MODE_TURBO ? "TURBO 🔥" : (g_ADXMode == ADX_MODE_RANGE ? "RANGE 🎯" : "NORMAL ⚖️"));
      adxDisplay = StringFormat("%s (%.1f) | %s", adxTag, g_LiveADX_Val, g_ZScoreStatusStr);
      if(g_ZScoreExtremePeak) adxValCol = clrTomato;
      else if(g_ZScoreExtremeValley) adxValCol = clrLime;
   }
   SetRow("ROW_MKT_ADX", "🚀 ADX & Z-Score", adxDisplay, adxValCol, clrDarkCyan, adxTitleCol);

   // Row 10: SMC Liquidity Radar with Dual Colored Labels (Red SL Sell / Green SL Buy)
   string bslPart = "BSL: —";
   string sslPart = "SSL: —";
   string sepPart = "|";
   color  bslCol  = C'255,100,120'; // Red / Coral (SL Sell)
   color  sslCol  = C'50,225,130';  // Green / SpringGreen (SL Buy)

   if(InpUseICT_Unicorn && g_Unicorn_Setup.isActive)
   {
      double uPrice = (g_Unicorn_Setup.state == UNICORN_BULLISH) ? 
                      ((g_Unicorn_Setup.overlapBottom > 0) ? g_Unicorn_Setup.overlapBottom : g_Unicorn_Setup.breakerBottom) :
                      ((g_Unicorn_Setup.overlapTop > 0) ? g_Unicorn_Setup.overlapTop : g_Unicorn_Setup.breakerTop);
      string uPriceStr = (_Digits > 2) ? StringFormat("%.1f", uPrice) : StringFormat("%.2f", uPrice);
      bslPart = StringFormat("🦄 UNICORN [%s]", uPriceStr);
      sepPart = "•";
      if(g_Unicorn_Setup.state == UNICORN_BULLISH)
      {
         sslPart = "ดัก BUY 🟢";
         bslCol  = clrGold;
         sslCol  = clrLime;
      }
      else
      {
         sslPart = "ดัก SELL 🔴";
         bslCol  = clrGold;
         sslCol  = clrTomato;
      }
   }
   else if(InpUseCRT_TurtleSoup && g_CRT_Setup.isActive)
   {
      double crtPrice = (g_CRT_Setup.retestMidpoint > 0) ? g_CRT_Setup.retestMidpoint : g_CRT_Setup.refLevel;
      string crtPriceStr = (_Digits > 2) ? StringFormat("%.1f", crtPrice) : StringFormat("%.2f", crtPrice);
      sepPart = "•";
      if(g_CRT_Setup.state == CRT_BULLISH_SWEEP)
      {
         bslPart = (g_JudasBuyActive ? StringFormat("🎯 Judas+CRT [%s]", crtPriceStr) : StringFormat("🎯 กวาด SSL [%s]", crtPriceStr));
         sslPart = "ดัก BUY 🟢";
         bslCol  = clrGold;
         sslCol  = clrLime;
      }
      else
      {
         bslPart = (g_JudasSellActive ? StringFormat("🎯 Judas+CRT [%s]", crtPriceStr) : StringFormat("🎯 กวาด BSL [%s]", crtPriceStr));
         sslPart = "ดัก SELL 🔴";
         bslCol  = clrGold;
         sslCol  = clrTomato;
      }
   }
   else if(InpUseAsianRangeJudas && (g_JudasBuyActive || g_JudasSellActive))
   {
      sepPart = "•";
      if(g_JudasBuyActive)
      {
         string alStr = (_Digits > 2) ? StringFormat("%.1f", g_AsianRangeLow) : StringFormat("%.2f", g_AsianRangeLow);
         bslPart = StringFormat("🎯 Judas Sweep AL [%s]", alStr);
         sslPart = "ช้อน BUY 🟢";
         bslCol  = clrGold;
         sslCol  = clrLime;
      }
      else
      {
         string ahStr = (_Digits > 2) ? StringFormat("%.1f", g_AsianRangeHigh) : StringFormat("%.2f", g_AsianRangeHigh);
         bslPart = StringFormat("🎯 Judas Sweep AH [%s]", ahStr);
         sslPart = "ดัก SELL 🔴";
         bslCol  = clrGold;
         sslCol  = clrTomato;
      }
   }
   else if(g_DetectedPattern == PA_MOTHER_BAR_BUY || g_DetectedPattern == PA_MOTHER_BAR_SELL)
   {
      sepPart = "•";
      if(g_DetectedPattern == PA_MOTHER_BAR_BUY)
      {
         bslPart = "🐟 Sig ค้ำ Sig";
         sslPart = "ดัก BUY 🟢";
         bslCol  = clrGold;
         sslCol  = clrLime;
      }
      else
      {
         bslPart = "🐟 Sig ค้ำ Sig";
         sslPart = "ดัก SELL 🔴";
         bslCol  = clrGold;
         sslCol  = clrTomato;
      }
   }
   else if(g_LQ_Radar.sslSwept)
   {
      bslPart = "🎯 กวาด LQ ล่าง!";
      sslPart = "ดัก BUY 🟢";
      sepPart = "•";
      bslCol  = clrGold;
      sslCol  = clrLime;
   }
   else if(g_LQ_Radar.bslSwept)
   {
      bslPart = "🎯 กวาด LQ บน!";
      sslPart = "ดัก SELL 🔴";
      sepPart = "•";
      bslCol  = clrGold;
      sslCol  = clrTomato;
   }
   else
   {
      if(g_LQ_Radar.bsl.isValid && g_LQ_Radar.bsl.price > 0)
         bslPart = StringFormat("BSL %.2f (%s)", g_LQ_Radar.bsl.price, FormatLQDistance(g_LQ_Radar.bsl.distancePts, g_AssetProfile.assetType, _Point));
      if(g_LQ_Radar.ssl.isValid && g_LQ_Radar.ssl.price > 0)
         sslPart = StringFormat("SSL %.2f (%s)", g_LQ_Radar.ssl.price, FormatLQDistance(g_LQ_Radar.ssl.distancePts, g_AssetProfile.assetType, _Point));
      sepPart = "|";
   }

   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_LQ_BSL", OBJPROP_TEXT, bslPart);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_LQ_BSL", OBJPROP_COLOR, bslCol);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_LQ_SEP", OBJPROP_TEXT, sepPart);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_LQ_SSL", OBJPROP_TEXT, sslPart);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_LQ_SSL", OBJPROP_COLOR, sslCol);

   // -------------------------------------------------------------
   // 2. CARD 2: SNIPER TRADE SETUP & TARGETS (5 DYNAMIC COLOR ROWS)
   // -------------------------------------------------------------
   bool isBullPlan = (g_PlanDirection != 0) ? (g_PlanDirection == 1) : (g_MarketTrend == TREND_BULLISH);
   bool isBearPlan = (g_PlanDirection != 0) ? (g_PlanDirection == -1) : (g_MarketTrend == TREND_BEARISH);

   bool isSuperConfluence = false;
   if(InpUseATHGrid && g_PlanEntry > 0)
   {
      double athSup = 0, athRes = 0;
      GetNearestATHLevels(g_PlanEntry, athSup, athRes);
      if(isBullPlan && athSup > 0 && MathAbs(g_PlanEntry - athSup) <= (80 * _Point))
         isSuperConfluence = true;
      else if(isBearPlan && athRes > 0 && MathAbs(g_PlanEntry - athRes) <= (80 * _Point))
         isSuperConfluence = true;
   }

   if(isBullPlan)
   {
      ObjectSetInteger(0, GUI_PREFIX + "HUD_CARD_PLAN_BG", OBJPROP_BGCOLOR, C'10,26,20');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_CARD_PLAN_BG", OBJPROP_COLOR, C'20,80,50');
   }
   else if(isBearPlan)
   {
      ObjectSetInteger(0, GUI_PREFIX + "HUD_CARD_PLAN_BG", OBJPROP_BGCOLOR, C'28,12,14');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_CARD_PLAN_BG", OBJPROP_COLOR, C'80,30,35');
   }
   else
   {
      ObjectSetInteger(0, GUI_PREFIX + "HUD_CARD_PLAN_BG", OBJPROP_BGCOLOR, C'20,20,24');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_CARD_PLAN_BG", OBJPROP_COLOR, C'40,45,60');
   }

   // Live Directional Bias Conviction Badge on Card 2 Header
   string card2Header = "🎯 2. แผนเข้าสไนเปอร์ (SNIPER SETUP)";
   if(openCount > 0 || g_BotState == STATE_IN_POSITION)
   {
      card2Header = StringFormat("🎯 2. สถานะไม้ที่ถืออยู่ (ACTIVE POSITION) • %s", (isBullPlan ? "🟢 BUY" : "🔴 SELL"));
   }
   else if(isBullPlan && g_MarketBiasBuyPct >= 50)
      card2Header = StringFormat("🎯 2. แผนเข้าสไนเปอร์ • 🟢 BUY %d%%", g_MarketBiasBuyPct);
   else if(isBearPlan && g_MarketBiasSellPct >= 50)
      card2Header = StringFormat("🎯 2. แผนเข้าสไนเปอร์ • 🔴 SELL %d%%", g_MarketBiasSellPct);
   ObjectSetString(0, GUI_PREFIX + "HUD_CARD_PLAN_TITLE", OBJPROP_TEXT, card2Header);

   string planTitle = "";
   if(openCount > 0 || g_BotState == STATE_IN_POSITION)
   {
      planTitle = (isBullPlan ? "🟢 ไม้ BUY กำลังรัน" : "🔴 ไม้ SELL กำลังรัน");
   }
   else if(g_PlanSource == "UNICORN")
   {
      planTitle = (g_PlanDirection == 1 ? "🦄 Unicorn BUY" : "🦄 Unicorn SELL");
   }
   else if(g_PlanSource == "CRT")
   {
      planTitle = (g_PlanDirection == 1 ? "🐢 CRT BUY" : "🐢 CRT SELL");
   }
   else if(g_PlanSource == "SPIKE")
   {
      planTitle = (g_PlanDirection == 1 ? "🟢 สไนเปอร์ BUY" : "🔴 สไนเปอร์ SELL");
   }
   else if(g_PlanSource == "REVERSAL")
   {
      planTitle = (g_PlanDirection == 1 ? "🎯 Reversal BUY" : "⚡ Reversal SELL");
   }
   else if(g_PlanSource == "BREAKDOWN" || g_PlanSource == "BREAKOUT")
   {
      planTitle = (g_PlanDirection == 1 ? "🚀 Breakout BUY" : "🎯 Breakdown SELL");
   }
   else if(g_PlanSource == "HTF_REVERSAL" || g_HTFReversal.isValid)
   {
      planTitle = (g_PlanDirection == 1 ? "🟢 ช้อน BUY" : "🔴 ดัก SELL");
   }
   else
   {
      if(isBullPlan)
         planTitle = "🟢 แผนเข้า BUY";
      else if(isBearPlan)
         planTitle = "🔴 แผนเข้า SELL";
      else
         planTitle = "🟡 แผนออกไม้";
   }

   string entryStr    = "-";
   string entryStr_L2 = "";
   color  entryL2Col  = C'255,215,0'; // Default Gold

   if(g_PlanEntry > 0)
   {
      string planEntryValStr = DoubleToString(g_PlanEntry, _Digits);
      if(openCount > 0 || g_BotState == STATE_IN_POSITION)
      {
         double curPrice = isBullPlan ? bid : ask;
         double diffPts = isBullPlan ? (curPrice - g_PlanEntry) / _Point : (g_PlanEntry - curPrice) / _Point;
         string ptSign = (diffPts >= 0) ? "+" : "";
         entryStr    = StringFormat("%s  (กำไร %s [%s%.0f pts] 🎯)", planEntryValStr, FormatMoney(netPnl, true), ptSign, diffPts);
         entryStr_L2 = StringFormat("↳ ถือสถานะ %d ไม้ • ระบบรันเทรนด์ & ล็อกทุนทำงาน 🛡️ [%s]", openCount, g_AdaptiveTrailModeStr);
         entryL2Col  = (netPnl >= 0) ? clrSpringGreen : clrTomato;
      }
      else if(InpEnablePostSLBECooldown && TimeCurrent() < g_PostSLBECooldownUntil)
      {
         int remainSec = (int)(g_PostSLBECooldownUntil - TimeCurrent());
         entryStr    = StringFormat("%s  [พักระบบหลัง %s ⏳]", planEntryValStr, (g_PostSLBECooldownReason != "" ? g_PostSLBECooldownReason : "SL/BE"));
         entryStr_L2 = StringFormat("↳ รอเวลาพักระบบความปลอดภัย เหลืออีก %02d:%02d ⏳🛡️", remainSec / 60, remainSec % 60);
         entryL2Col  = C'255,185,50';
      }

      else if(InpUseNewsCalendarGuard && InpNewsStandDownAutoTrades && g_NewsStandDownActive && g_TradeMode == TRADE_MODE_SAFE_COPILOT)
      {
         int minsLeft = (g_NewsMinutesUntil >= 0) ? g_NewsMinutesUntil : MathMax(0, InpNewsPostMinutes - MathAbs(g_NewsMinutesUntil));
         string timeTag = (g_NewsMinutesUntil >= 0) ? StringFormat("อีก %dm", minsLeft) : StringFormat("รอตลาดนิ่งอีก %dm", minsLeft);
         string actBtn = isBullPlan ? "ปุ่มเขียว BUY" : "ปุ่มแดง SELL";
         entryStr    = StringFormat("%s  [พักออโต้ช่วงข่าว 🛡️]", planEntryValStr);
         entryStr_L2 = StringFormat("↳ ข่าวแรง: %s (%s) • ผู้เทรดยังยิงมือได้ที่ %s", g_NewsEventTitle, timeTag, actBtn);
         entryL2Col  = C'255,200,100';
      }
      else if(g_PlanSource == "WICK_SNIPER")
      {
         entryStr = StringFormat("%s  [50%% Wick Sniper 🔭]", planEntryValStr);
         if(g_BotState == STATE_TRIGGER_READY)
         {
            entryStr_L2 = "↳ ยืนยัน 3 แท่งมหาประลัย + ดักย่อ Retest 🎯";
            entryL2Col  = clrLime;
         }
         else
         {
            entryStr_L2 = "↳ แตะโซน 50% Wick • รอแท่งปิดยืนยัน ⏳";
            entryL2Col  = clrKhaki;
         }
      }
      else if(g_PlanSource == "UNICORN")
      {
         entryStr = StringFormat("%s  [Unicorn Breaker 🦄]", planEntryValStr);
         if(g_BotState == STATE_TRIGGER_READY)
         {
            entryStr_L2 = "↳ คอนเฟิร์มสมบูรณ์ ⚡ ลั่นไกสไนเปอร์ Breaker + FVG 🎯";
            entryL2Col  = clrLime;
         }
         else
         {
            entryStr_L2 = "↳ รอราคาย่อทดสอบ Breaker Block & FVG คอนเฟิร์ม ⏳";
            entryL2Col  = clrAqua;
         }
      }
      else if(g_PlanSource == "CRT")
      {
         entryStr = StringFormat("%s  [CRT Turtle Soup 🐢]", planEntryValStr);
         if(g_BotState == STATE_TRIGGER_READY)
         {
            entryStr_L2 = "↳ คอนเฟิร์มสมบูรณ์ ⚡ ลั่นไกสไนเปอร์ Sweep Rejection 🎯";
            entryL2Col  = clrLime;
         }
         else
         {
            entryStr_L2 = "↳ รอราคา Sweep สภาพคล่องทะลุกรอบก่อนดึงกลับ ⏳";
            entryL2Col  = clrAqua;
         }
      }
      else if(g_PlanSource == "SPIKE")
      {
         entryStr    = StringFormat("%s  [Spike Reversal ⚡]", planEntryValStr);
         entryStr_L2 = "↳ แท่งเทียน Pinbar รูดไส้ปฏิเสธราคาชัดเจน 🎯";
         entryL2Col  = clrLime;
      }
      else if(g_PlanSource == "REVERSAL")
      {
         string revTag = g_CME_NearMegaCallWall ? "Mega Call Wall" : (g_CME_NearCallWall ? "Call Wall" : (g_CME_NearIntermedCall ? "Intermed Call" : (g_CME_NearMacroPutWall ? "Macro Put Base" : (g_CME_NearPutWall ? "Put Wall" : (g_CME_NearIntermedPut ? "Intermed Put" : (g_ZScoreExtremePeak ? "+2.0 SD" : (g_ZScoreExtremeValley ? "-2.0 SD" : "Peak/Valley")))))));
         entryStr = StringFormat("%s  [%s]", planEntryValStr, revTag);
         if(g_BotState == STATE_TRIGGER_READY)
         {
            entryStr_L2 = StringFormat("↳ คอนเฟิร์มกลับตัวสมบูรณ์ ⚡ %s", (g_PatternName != "" ? g_PatternName : "PA Rejection"));
            entryL2Col  = clrLime;
         }
         else
         {
            entryStr_L2 = StringFormat("↳ รอแท่งยืนยันกลับตัว ⏳ • %s", (g_ReversalPendingReason != "" ? g_ReversalPendingReason : "ป้องกันการออกไม้ผิดฝั่ง"));
            entryL2Col  = C'255,215,0';
         }
      }
      else if(g_PlanSource == "BREAKDOWN" || g_PlanSource == "BREAKOUT")
      {
         string breakTag = (g_PlanDirection == 1) ? "ทะลุต้านย่อย" : "หลุดรับย่อย/ทุบจาก Supply";
         entryStr    = StringFormat("%s  [Breakout 🚀]", planEntryValStr);
         entryStr_L2 = StringFormat("↳ จุดยิงสไนเปอร์ ⚡ โมเมนตัม %s คอนเฟิร์ม", breakTag);
         entryL2Col  = clrAqua;
      }
      else if(g_PlanSource == "HTF_REVERSAL" || g_HTFReversal.isValid)
      {
         entryStr    = StringFormat("%s  [HTF Reversal 🎯]", planEntryValStr);
         entryStr_L2 = StringFormat("↳ ช้อนโซนใหญ่ 🎯 %s", g_HTFReversal.patternName);
         entryL2Col  = clrAqua;
      }
      else if(openCount > 0)
      {
         entryStr    = StringFormat("%s  [ไม้สะสม #%d ⚡]", planEntryValStr, openCount + 1);
         entryStr_L2 = "↳ รอจังหวะย่อตัวสวยเข้าตามรอบคลื่น 🎯";
         entryL2Col  = clrGold;
      }
      else if(g_BotState == STATE_TRIGGER_READY)
      {
         entryStr    = StringFormat("%s  [พร้อมยิงสไนเปอร์ ⚡%s]", planEntryValStr, (isSuperConfluence ? " 🔥" : ""));
         entryStr_L2 = "↳ คอนเฟิร์มครบทุกระบบ • พร้อมลั่นไกทันที 🎯";
         entryL2Col  = clrLime;
      }
      else if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && g_LiveADX_Val < 20.0)
      {
         entryStr    = StringFormat("%s  [รอ Fibo 61.8%% ⏳]", planEntryValStr);
         entryStr_L2 = StringFormat("↳ วอลุ่ม ADX %.1f < 20 (ตลาดพักตัว รอเบรกเอาท์ ⏳)", g_LiveADX_Val);
         entryL2Col  = clrKhaki;
      }
      else if(g_PullbackArmed)
      {
         entryStr    = StringFormat("%s  [รอย่อ PA Rejection 🎯%s]", planEntryValStr, (isSuperConfluence ? " 🔥" : ""));
         entryStr_L2 = "↳ แตะโซนได้เปรียบแล้ว • รอแท่งเทียนทิ้งไส้กลับตัว ⏳";
         entryL2Col  = clrAqua;
      }
      else
      {
         string retraceAction = isBearPlan ? "เด้งอีก" : "ย่ออีก";
         entryStr    = StringFormat("%s  [รอ Fibo 61.8%% ⏳]", planEntryValStr);
         entryStr_L2 = StringFormat("↳ %s %s เข้า Golden Zone ได้เปรียบ%s ⏳", retraceAction, FormatPlanDistStr(g_Fibo.distanceToZone, false), (isSuperConfluence ? " 🔥" : ""));
         entryL2Col  = clrGold;
      }
   }
   if(g_PlanEntry <= 0)
   {
      entryStr = "— (ไม่มีออเดอร์)";
      if(g_PostCloseCooldownRemainSec > 0)
      {
         entryStr_L2 = StringFormat("↳ พักระบบความปลอดภัยหลังปิดไม้ (เหลือ %ds ⏳🛡️)", g_PostCloseCooldownRemainSec);
         entryL2Col  = clrKhaki;
      }
      else if(g_MarketTrend == TREND_SIDEWAY)
      {
         if(g_LastSwingHigh.price > 0 && g_LastSwingLow.price > 0)
            entryStr_L2 = StringFormat("↳ ตลาด Sideway [%.0f - %.0f] • นั่งทับมือตามวินัย ⏳", g_LastSwingLow.price, g_LastSwingHigh.price);
         else
            entryStr_L2 = "↳ ตลาด Sideway • นั่งทับมือนิ่งๆ รอฟอร์มคลื่นใหม่ ⏳";
         entryL2Col  = clrGold;
      }
      else
      {
         entryStr_L2 = "↳ กำลังสแกนหาจุดยิงสไนเปอร์และโซนได้เปรียบ ⏳";
         entryL2Col  = clrKhaki;
      }
   }
   color planValCol = isBullPlan ? clrLime : (isBearPlan ? clrTomato : clrGold);
   color planTitleCol = isBullPlan ? clrPaleGreen : (isBearPlan ? clrLightCoral : clrKhaki);
   SetRow("ROW_PLAN_ENTRY", planTitle, entryStr, planValCol, (isBullPlan ? clrSeaGreen : clrCrimson), planTitleCol);

   string planL2 = entryStr_L2, planL3 = "";
   SmartWrapText(entryStr_L2, 48, planL2, planL3);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_ROW_PLAN_ENTRY_L2", OBJPROP_TEXT, planL2);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_ROW_PLAN_ENTRY_L2", OBJPROP_COLOR, entryL2Col);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_ROW_PLAN_ENTRY_L3", OBJPROP_TEXT, planL3);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_ROW_PLAN_ENTRY_L3", OBJPROP_COLOR, entryL2Col);

   double riskPts = (g_PlanEntry > 0 && g_PlanSL > 0) ? MathAbs(g_PlanEntry - g_PlanSL) / _Point : 0;
   double liveRR1 = (riskPts > 0 && g_PlanTP1 > 0) ? (MathAbs(g_PlanTP1 - g_PlanEntry) / _Point) / riskPts : g_PlanRR1;
   double liveRR2 = (riskPts > 0 && g_PlanTP2 > 0) ? (MathAbs(g_PlanTP2 - g_PlanEntry) / _Point) / riskPts : g_PlanRR2;
   double liveRR3 = (riskPts > 0 && g_PlanTP3 > 0) ? (MathAbs(g_PlanTP3 - g_PlanEntry) / _Point) / riskPts : g_PlanRR3;

   string slStr = "-";
   if(g_PlanSL > 0)
   {
      double slPts = MathAbs(g_PlanEntry - g_PlanSL) / _Point;
      if(openCount > 0 || g_BotState == STATE_IN_POSITION)
      {
         double curPrice = isBullPlan ? bid : ask;
         double distToSL = isBullPlan ? (curPrice - g_PlanSL) / _Point : (g_PlanSL - curPrice) / _Point;
         string slTag = "";
         if((isBullPlan && g_PlanSL >= g_PlanEntry + (80 * _Point)) || (!isBullPlan && g_PlanSL <= g_PlanEntry - (80 * _Point)))
            slTag = " [ล็อกกำไร 🔒]";
         else if((isBullPlan && g_PlanSL >= g_PlanEntry) || (!isBullPlan && g_PlanSL <= g_PlanEntry))
            slTag = " [กันทุน BE 🛡️]";
         else
            slTag = StringFormat(" [ห่าง %.0f pts]", distToSL);
         slStr = StringFormat("%s (%s%s)", DoubleToString(g_PlanSL, _Digits), FormatPlanDistStr(slPts, true), slTag);
      }
      else
      {
         slStr = StringFormat("%s (%s)", DoubleToString(g_PlanSL, _Digits), FormatPlanDistStr(slPts, true));
      }
   }
   SetRow("ROW_PLAN_SL", "🔴 จุดตัดขาดทุน SL", slStr, clrOrangeRed, clrCrimson, clrLightCoral);

   string tp1Str = "-";
   if(g_PlanEntry > 0 && g_PlanTP1 > 0)
   {
      double pts1 = MathAbs(g_PlanTP1 - g_PlanEntry) / _Point;
      string tpNote = (openCount > 0 || g_BotState == STATE_IN_POSITION) ? "ล็อกกำไร +800 pts" : ((g_PlanSource == "SPIKE") ? "1.0x" : "50% BE");
      tp1Str = StringFormat("%s (%s | RR 1:%.1f | %s)", DoubleToString(g_PlanTP1, _Digits), FormatPlanDistStr(pts1, false), liveRR1, tpNote);
   }
   SetRow("ROW_PLAN_TP1", "💧 เป้า 1 (TP1)", tp1Str, clrAqua, clrSteelBlue, clrSkyBlue);

   string tp2Str = "-";
   if(g_PlanEntry > 0 && g_PlanTP2 > 0)
   {
      double pts2 = MathAbs(g_PlanTP2 - g_PlanEntry) / _Point;
      string tpNote = (openCount > 0 || g_BotState == STATE_IN_POSITION) ? "ล็อกกำไร +1650 pts" : ((g_PlanSource == "SPIKE") ? "1.6x" : "Wave 3");
      tp2Str = StringFormat("%s (%s | RR 1:%.1f | %s)", DoubleToString(g_PlanTP2, _Digits), FormatPlanDistStr(pts2, false), liveRR2, tpNote);
   }
   SetRow("ROW_PLAN_TP2", "🚀 เป้า 2 (TP2)", tp2Str, clrLimeGreen, clrSeaGreen, clrPaleGreen);

   string tp3Str = "-";
   if(g_PlanEntry > 0 && g_PlanTP3 > 0)
   {
      double pts3 = MathAbs(g_PlanTP3 - g_PlanEntry) / _Point;
      string tpNote = (openCount > 0 || g_BotState == STATE_IN_POSITION) ? "Trailing รันเทรนด์" : ((g_PlanSource == "SPIKE") ? "2.6x" : "Runner");
      tp3Str = StringFormat("%s (%s | RR 1:%.1f | %s)", DoubleToString(g_PlanTP3, _Digits), FormatPlanDistStr(pts3, false), liveRR3, tpNote);
   }
   SetRow("ROW_PLAN_TP3", "👑 เป้า 3 (TP3)", tp3Str, clrGold, clrDarkGoldenrod, clrKhaki);

   // -------------------------------------------------------------
   // 3. CARD 3: PROP GUARD & OPEN POSITIONS (2-LINE STACKED ROWS)
   // -------------------------------------------------------------
   int botCount   = CountOpenPositions(false);
   int totalCount = CountOpenPositions(true);

   string posStr    = "";
   string posStr_L2 = "";
   color  posL2Col  = clrLightSkyBlue;

   if(totalCount == 0)
   {
      posStr    = StringFormat("0/%d ไม้ (No Pos) • +0.00 Cent", InpMaxOpenPos);
      posStr_L2 = "↳ โหมดบริหารความเสี่ยง: สแตนด์บายพร้อมคุม Trailing & BE 🛡️";
      posL2Col  = clrLightSkyBlue;
   }
   else if(totalCount > botCount && botCount > 0)
   {
      posStr    = StringFormat("%d ไม้ (บอท: %d, มือถือ: %d) • %s", totalCount, botCount, totalCount - botCount, FormatMoney(netPnl, true));
      posStr_L2 = StringFormat("↳ การบริหารออเดอร์: %s 🛡️", g_AdaptiveTrailModeStr);
      posL2Col  = (netPnl >= 0) ? clrSpringGreen : clrGold;
   }
   else if(totalCount > 0 && botCount == 0)
   {
      posStr    = StringFormat("%d ไม้ (📱 มือถือ: %d) • %s", totalCount, totalCount, FormatMoney(netPnl, true));
      posStr_L2 = StringFormat("↳ การบริหารออเดอร์มือถือ: %s 🛡️", g_AdaptiveTrailModeStr);
      posL2Col  = (netPnl >= 0) ? clrSpringGreen : clrGold;
   }
   else
   {
      posStr    = StringFormat("%d/%d ไม้ (%s) • %s", totalCount, InpMaxOpenPos, (totalCount==1 ? "Single" : "Multi"), FormatMoney(netPnl, true));
      posStr_L2 = StringFormat("↳ การบริหารออเดอร์บอท: %s 🛡️", g_AdaptiveTrailModeStr);
      posL2Col  = (netPnl >= 0) ? clrSpringGreen : clrGold;
   }

   color  posCol = (totalCount > 0) ? ((netPnl >= 0) ? clrLime : clrOrangeRed) : clrLightSkyBlue;
   color  posTitleCol = (totalCount > 0) ? ((netPnl >= 0) ? clrPaleGreen : clrLightCoral) : clrDeepSkyBlue;
   color  posBarCol = (totalCount > 0) ? ((netPnl >= 0) ? clrSeaGreen : clrCrimson) : clrSteelBlue;
   SetRow("ROW_PROP_POS", "📦 ไม้ที่ถืออยู่", posStr, posCol, posBarCol, posTitleCol);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_ROW_PROP_POS_L2", OBJPROP_TEXT, posStr_L2);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_ROW_PROP_POS_L2", OBJPROP_COLOR, posL2Col);

   string statusTag = g_DailyTargetReached ? "🏆 TARGET HIT" : (g_DailyMaxLossReached ? "🛑 MAX LOSS" : (g_DailyGuardManualUnlocked ? "ACTIVE (ปลดล็อก 🔓)" : "ACTIVE 🟢"));
   double effDailyTarget = InpDailyProfitTarget;
   if(!IsCentAccount() && InpDailyProfitTarget >= 500.0)
      effDailyTarget = InpDailyProfitTarget / 100.0;
   string dailyStr = StringFormat("%s / %s (%s)", FormatMoney(g_TodayPnL, true), FormatMoney(effDailyTarget), statusTag);
   color  dailyCol = g_DailyTargetReached ? clrGold : (g_DailyMaxLossReached ? clrCrimson : ((g_TodayPnL >= 0) ? clrSpringGreen : clrOrange));
   SetRow("ROW_PROP_GOAL", "🎯 เป้ากำไรรายวัน", dailyStr, dailyCol, clrSpringGreen, dailyCol);

   // Row 3: Smart Structural Re-Entry Guard (Up to 3-Line Stacked Display: Zero Overflow!)
   string reEntryStr    = "";
   string reEntryStr_L2 = "";
   string reEntryStr_L3 = "";
   color  reEntryCol = clrLightSkyBlue;
   color  reEntryL2Col = clrKhaki;
   color  reEntryBarCol = clrSteelBlue;
   color  reEntryTitleCol = clrDeepSkyBlue;

   if(!InpEnableSmartReEntryGuard)
   {
      reEntryStr    = "ปิดใช้งาน (Off)";
      reEntryStr_L2 = "↳ ปิดระบบป้องกัน Re-Entry";
      reEntryStr_L3 = "   ↳ โปรดระวังการออกไม้ซ้ำจุดเดิม 🛡️";
      reEntryCol    = clrSilver;
      reEntryL2Col  = clrSilver;
   }
   else if(g_LastStoppedPrice > 0 && g_LastStoppedTime > 0 && (TimeCurrent() - g_LastStoppedTime) < 900)
   {
      int elapsedSec = (int)(TimeCurrent() - g_LastStoppedTime);
      int remainSec  = 900 - elapsedSec;
      if(g_ReEntryUnlocked)
      {
         reEntryStr    = "🔓 ปลดล็อกที่โซนสำเร็จ";
         SmartWrapText(StringFormat("↳ ปลดล็อกแล้ว: %s 🚀", g_ReEntryUnlockReason), 48, reEntryStr_L2, reEntryStr_L3);
         reEntryCol    = clrLime;
         reEntryL2Col  = clrLime;
         reEntryBarCol = clrSeaGreen;
         reEntryTitleCol = clrPaleGreen;
      }
      else
      {
         reEntryStr    = StringFormat("🔒 ล็อกจุดเดิม (เหลือ %02d:%02d ⏳)", remainSec / 60, remainSec % 60);
         reEntryStr_L2 = "↳ ป้องกันชน SL ซ้ำที่เดิม (ระยะ +-350 pts)";
         reEntryStr_L3 = "   ↳ รอราคาแตะ Demand/Supply หรือ 50% Wick 🎯";
         reEntryCol    = clrGold;
         reEntryL2Col  = clrGold;
         reEntryBarCol = clrDarkGoldenrod;
         reEntryTitleCol = clrKhaki;
      }
   }
   else if(g_DailyMaxLossReached)
   {
      reEntryStr    = "🛑 หยุดเทรดรายวัน (Max Loss)";
      reEntryStr_L2 = "↳ แตะขีดจำกัดขาดทุนรายวัน";
      reEntryStr_L3 = "   ↳ ตัดขาดทุนเพื่อรักษาเงินทุน 🛡️";
      reEntryCol    = clrCrimson;
      reEntryL2Col  = clrLightCoral;
      reEntryBarCol = clrCrimson;
      reEntryTitleCol = clrLightCoral;
   }
   else
   {
      reEntryStr    = "🟢 สแตนด์บาย (พร้อมรับ Setup)";
      reEntryStr_L2 = "↳ ป้องกันการเข้าซ้ำ 350 pts ทุกการชน SL";
      reEntryStr_L3 = "   ↳ ปลดล็อกทันทีเมื่อแตะโซนใหม่ + Confluence 70%+ 🛡️";
      reEntryCol    = clrPaleGreen;
      reEntryL2Col  = C'175,225,255';
      reEntryBarCol = clrSeaGreen;
      reEntryTitleCol = clrLightSkyBlue;
   }
   SetRow("ROW_PROP_REENTRY", "🛡️ ล็อกไม้ซ้ำ (Re-Entry)", reEntryStr, reEntryCol, reEntryBarCol, reEntryTitleCol);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_ROW_PROP_REENTRY_L2", OBJPROP_TEXT, reEntryStr_L2);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_ROW_PROP_REENTRY_L2", OBJPROP_COLOR, reEntryL2Col);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_ROW_PROP_REENTRY_L3", OBJPROP_TEXT, reEntryStr_L3);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_ROW_PROP_REENTRY_L3", OBJPROP_COLOR, reEntryL2Col);

   // Update Card 3 Reset Guard Button
   if(g_DailyMaxLossReached)
   {
      UpdateButtonState("HUD_BTN_RESET_GUARD", "🔓 ปลดล็อก", C'180,30,40');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_BTN_RESET_GUARD", OBJPROP_COLOR, clrWhite);
   }
   else if(g_DailyTargetReached)
   {
      UpdateButtonState("HUD_BTN_RESET_GUARD", "🔓 ปลดล็อก", C'180,130,0');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_BTN_RESET_GUARD", OBJPROP_COLOR, clrWhite);
   }
   else if(g_DailyGuardManualUnlocked)
   {
      UpdateButtonState("HUD_BTN_RESET_GUARD", "🔓 ปลดล็อกแล้ว", C'25,90,75');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_BTN_RESET_GUARD", OBJPROP_COLOR, clrWhite);
   }
   else
   {
      UpdateButtonState("HUD_BTN_RESET_GUARD", "🔄 รีเซ็ต", C'30,45,60');
      ObjectSetInteger(0, GUI_PREFIX + "HUD_BTN_RESET_GUARD", OBJPROP_COLOR, clrSilver);
   }

   string spikeStr    = "สแตนด์บายสแกนหาแท่งกระชาก ⏳";
   string spikeStr_L2 = "↳ ตรวจจับแท่ง Spike ผิดปกติ & ปฏิเสธราคา (Pinbar Rejection) 🛡️";
   color  spikeCol = clrKhaki;
   color  spikeL2Col = clrKhaki;
   color  spikeTitleCol = clrGold;
   color  spikeBarCol = clrGoldenrod;
   if(g_SpikeSignal.isValid)
   {
      spikeStr    = StringFormat("พร้อมยิง %s สไนเปอร์ ⚡", (g_SpikeSignal.direction == 1 ? "BUY" : "SELL"));
      spikeStr_L2 = StringFormat("↳ สัญญาณ: %s 🎯", g_SpikeSignal.reason);
      spikeCol    = (g_SpikeSignal.direction == 1) ? clrLime : clrTomato;
      spikeL2Col  = (g_SpikeSignal.direction == 1) ? clrLime : clrTomato;
      spikeTitleCol = (g_SpikeSignal.direction == 1) ? clrPaleGreen : clrLightCoral;
      spikeBarCol = (g_SpikeSignal.direction == 1) ? clrSeaGreen : clrCrimson;
   }
   SetRow("ROW_PROP_SPIKE", "⚡ สไนเปอร์ Spike", spikeStr, spikeCol, spikeBarCol, spikeTitleCol);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_ROW_PROP_SPIKE_L2", OBJPROP_TEXT, spikeStr_L2);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_ROW_PROP_SPIKE_L2", OBJPROP_COLOR, spikeL2Col);

   // -------------------------------------------------------------
   // 4. CARD 4: PORTFOLIO HEALTH & STATS (2-LINE STACKED WIN ROW)
   // -------------------------------------------------------------
   string accTypeStr = IsCentAccount() ? "[CENT 🪙]" : "[USD 💵]";
   string balStr = StringFormat("%s Bal: %s | Eq: %s", accTypeStr, FormatMoney(m_account.Balance()), FormatMoney(m_account.Equity()));
   SetRow("ROW_STATS_BAL", "💳 บัญชี (Bal/Eq)", balStr, clrLemonChiffon, clrGold, clrLemonChiffon);

   int todayTotal = 0, todayWins = 0, todayLosses = 0;
   double todayNetPnl = 0.0, todayWinRate = 0.0;
   int manTotal = 0, manWins = 0, manLosses = 0;
   double manNetPnl = 0.0;
   GetTodayClosedTradeStats(todayTotal, todayWins, todayLosses, todayNetPnl, todayWinRate, manTotal, manWins, manLosses, manNetPnl);

   string botWinRateStr = (todayTotal > 0) ? StringFormat("%.0f%%", todayWinRate) : "0%";
   string botStatsStr   = StringFormat("🤖 บอท: %d ไม้ (W:%d | L:%d) • Win %s • %s", todayTotal, todayWins, todayLosses, botWinRateStr, FormatMoney(todayNetPnl, true));

   string manStatsStr   = "";
   color  manCol        = clrKhaki;
   if(manTotal > 0)
   {
      double manWinRate = ((double)manWins / (double)manTotal) * 100.0;
      manStatsStr = StringFormat("↳ 📱 ไม้มือถือ (Co-Pilot): %d ไม้ (W:%d | L:%d) • Win %.0f%% • %s", manTotal, manWins, manLosses, manWinRate, FormatMoney(manNetPnl, true));
      manCol      = (manNetPnl >= 0) ? clrLime : clrTomato;
   }
   else
   {
      manStatsStr = "↳ 📱 ไม้มือถือ (Co-Pilot): 0 ไม้ • พร้อมดูแลกันทุน/รันกำไรอัตโนมัติ 🛡️";
      manCol      = clrKhaki;
   }

   double netDisplayPnl = (InpDailyGuardScope == GUARD_SCOPE_BOT_ONLY) ? todayNetPnl : (todayNetPnl + manNetPnl);
   color  todayCol      = (netDisplayPnl >= 0) ? clrLime : clrTomato;
   color  todayTitleCol = (netDisplayPnl >= 0) ? clrPaleGreen : clrLightCoral;
   color  todayBarCol   = (netDisplayPnl >= 0) ? clrSeaGreen : clrCrimson;

   string manL2 = manStatsStr, manL3 = "";
   SmartWrapText(manStatsStr, 48, manL2, manL3);

   SetRow("ROW_STATS_WIN", "🏆 ผลงานวันนี้ (Today)", botStatsStr, todayCol, todayBarCol, todayTitleCol);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_ROW_STATS_WIN_L2", OBJPROP_TEXT, manL2);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_ROW_STATS_WIN_L2", OBJPROP_COLOR, manCol);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_ROW_STATS_WIN_L3", OBJPROP_TEXT, manL3);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_ROW_STATS_WIN_L3", OBJPROP_COLOR, manCol);

   int closedTotal = 0, closedWins = 0, closedLosses = 0;
   double closedNetPnl = 0.0, closedWinRate = 0.0;
   GetClosedTradeStats(closedTotal, closedWins, closedLosses, closedNetPnl, closedWinRate);

   string statsPnlStr = StringFormat("%s (รวม: %d ไม้ | Win: %.1f%%)", FormatMoney(closedNetPnl, true), closedTotal, closedWinRate);
   color  pnlCol = (closedNetPnl >= 0) ? clrGold : clrOrangeRed;
   color  pnlTitleCol = (closedNetPnl >= 0) ? clrKhaki : clrLightCoral;
   SetRow("ROW_STATS_PNL", "💵 กำไรสะสมรวม", statsPnlStr, pnlCol, clrGoldenrod, pnlTitleCol);

   // Update Trade Mode Button on Control Panel if open
   if(g_ShowControls)
   {
      string modeBtnText = (g_TradeMode == TRADE_MODE_SAFE_COPILOT) ? "🛡️ SAFE: ยิงมือ Co-Pilot" : "⚡ AGGRESSIVE: สไนเปอร์ AUTO";
      color modeBtnBg = (g_TradeMode == TRADE_MODE_SAFE_COPILOT) ? C'18,90,55' : C'195,80,15';
      UpdateButtonState("BTN_TRADE_MODE", modeBtnText, modeBtnBg);
   }
}

void SetRow(string rowTag, string title, string val, color valCol=clrWhite, color barCol=clrSteelBlue, color titleCol=clrSilver)
{
   ObjectSetString(0, GUI_PREFIX + "HUD_TITLE_" + rowTag, OBJPROP_TEXT, title);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_TITLE_" + rowTag, OBJPROP_COLOR, titleCol);
   ObjectSetString(0, GUI_PREFIX + "HUD_VAL_" + rowTag, OBJPROP_TEXT, val);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_VAL_" + rowTag, OBJPROP_COLOR, valCol);
   ObjectSetInteger(0, GUI_PREFIX + "HUD_BAR_" + rowTag, OBJPROP_BGCOLOR, barCol);
}

//+------------------------------------------------------------------+
//| 14.1 NATIVE MULTI-TF CANDLESTICK STRIP & COUNTDOWN FUSION ENGINE  |
//+------------------------------------------------------------------+
void CreateOrUpdateRectLabel(string name, int subwin, int x, int y, int w, int h, color bgCol)
{
   int curWin = ObjectFind(0, name);
   if(curWin >= 0 && curWin != subwin)
   {
      ObjectDelete(0, name);
      curWin = -1;
   }
   if(curWin < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, subwin, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgCol);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bgCol);
}

void CreateOrUpdateTextLabel(string name, int subwin, int x, int y, string text, string font, int fontSize, color col, ENUM_ANCHOR_POINT anchor)
{
   int curWin = ObjectFind(0, name);
   if(curWin >= 0 && curWin != subwin)
   {
      ObjectDelete(0, name);
      curWin = -1;
   }
   if(curWin < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, subwin, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
}

//+------------------------------------------------------------------+
//| 14.0 SAMURAI-EA MTF STRIP & REAL-TIME COUNTDOWN FUSION ENGINE    |
//| Multi-TF 9 Timeframes: M1, M5, M15, M30, H1, H4, D1, W1, MN      |
//| License Key: Z8EJM5-GCK8JR-2WLFE6-1UBDAZ                         |
//+------------------------------------------------------------------+
void SyncSamuraiMTFIndicator(bool enable)
{
   const string tfNames[9] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN"};
   
   if(!enable)
   {
      for(int i = 0; i < 9; i++)
      {
         for(int b = 0; b < 4; b++)
         {
            ObjectDelete(0, GUI_PREFIX + "MTF_W_" + tfNames[i] + "_" + IntegerToString(b));
            ObjectDelete(0, GUI_PREFIX + "MTF_B_" + tfNames[i] + "_" + IntegerToString(b));
         }
         ObjectDelete(0, GUI_PREFIX + "MTF_BID_"  + tfNames[i]);
         ObjectDelete(0, GUI_PREFIX + "MTF_BASE_" + tfNames[i]);
         ObjectDelete(0, GUI_PREFIX + "MTF_L_"    + tfNames[i]);
         ObjectDelete(0, GUI_PREFIX + "MTF_T_"    + tfNames[i]);
      }
      ObjectDelete(0, GUI_PREFIX + "MTF_PA");
      ObjectsDeleteAll(0, GUI_PREFIX + "MTF_");
      ObjectsDeleteAll(0, "Samurai_Sep_");
      
      int totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
      if(totalWindows > 1)
         ChartSetInteger(0, CHART_HEIGHT_IN_PIXELS, 1, 20);
         
      ChartRedraw(0);
      return;
   }
   
   // Set handshake GlobalVariables for external indicator compatibility
   GlobalVariableSet("GV_SAMURAI_TF_STATUS", 1.0);
   GlobalVariableSet("GV_SAMURAI_TF_STATUS" + _Symbol, 1.0);
   GlobalVariableSet("GV_SAMURAI_TF_STATUS" + _Symbol + (string)ChartID(), 1.0);
   
   int totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   
   // Check if Subwindow 1 exists; if not, open Subwindow 1
   if(totalWindows < 2)
   {
      int hInd = iCustom(_Symbol, _Period, "Samurai-Indicator\\Samurai-Multi-TF",
                         "",                   // 0. header
                         0,                    // 1. License_type
                         false,                // 2. show_count_down_candle
                         500,                  // 3. interval
                         10,                   // 4. Inp_Candle_Width
                         100,                  // 5. Inp_TF_Spacing
                         100,                  // 6. Inp_C_Height_Px
                         C'0,220,120',         // 7. Inp_UpColor (Bright Green)
                         C'255,60,80',         // 8. Inp_DnColor (Bright Red)
                         8,                    // 9. font_size
                         (color)6908265,       // 10. font_color
                         "Arial Bold",         // 11. font_name
                         clrAqua,              // 12. Inp_BidColor
                         1,                    // 13. Inp_BidWidth
                         7,                    // 14. time_font_size
                         (color)9470064        // 15. time_color
                        );
      if(hInd != INVALID_HANDLE)
      {
         ChartIndicatorAdd(0, 1, hInd);
      }
      else
      {
         int hFallback = iATR(_Symbol, _Period, 14);
         if(hFallback != INVALID_HANDLE)
            ChartIndicatorAdd(0, 1, hFallback);
      }
   }
   
   // Ensure subwindow 1 has comfortable viewing height (160px)
   totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   if(totalWindows > 1)
   {
      ChartSetInteger(0, CHART_HEIGHT_IN_PIXELS, 1, 160);
   }
   
   // Immediate render of all 9 timeframes
   UpdateSamuraiMTFGoldenAlert();
   ChartRedraw(0);
}

void UpdateSamuraiMTFGoldenAlert()
{
   if(!g_ShowMTFStrip)
      return;
      
   // Refresh handshake GlobalVariables
   GlobalVariableSet("GV_SAMURAI_TF_STATUS", 1.0);
   GlobalVariableSet("GV_SAMURAI_TF_STATUS" + _Symbol, 1.0);
   GlobalVariableSet("GV_SAMURAI_TF_STATUS" + _Symbol + (string)ChartID(), 1.0);
      
   int totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   int targetWin    = (totalWindows >= 2) ? 1 : 0;
   
   // Enforce subwindow 1 height to 160 px so full 4-candle groups and labels are never clipped
   if(targetWin > 0)
   {
      int winCheckH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, targetWin);
      if(winCheckH < 140)
      {
         ChartSetInteger(0, CHART_HEIGHT_IN_PIXELS, targetWin, 160);
      }
   }
   
   // Silky smooth 200ms polling: Guarantees active countdown & color sync even between ticks
   static ulong lastAlertTickMs = 0;
   ulong curMs = GetTickCount64();
   if(curMs - lastAlertTickMs < 200)
      return;
   lastAlertTickMs = curMs;
      
   datetime curTime = TimeCurrent();
   
   // Full 9 Timeframes of Samurai-EA: M1, M5, M15, M30, H1, H4, D1, W1, MN
   const ENUM_TIMEFRAMES tfs[9] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
   const string tfNames[9]      = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN"};
   
   // Dynamic Subwindow Width & Height Protection
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   if(chartW <= 0) chartW = 1200;
   
   int curH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, targetWin);
   if(curH <= 0) curH = 160;
   int winH = (curH < 65) ? 160 : curH;
   
   int yTop        = 14;
   int yBaseLine   = winH - 46;
   int candleAreaH = yBaseLine - yTop - 6;
   if(candleAreaH < 30) candleAreaH = 30;
   int yTfLabel    = yBaseLine + 5;
   int yCountdown  = yBaseLine + 22;
   
   int cBodyW    = 10;
   int cGap      = 4;
   int groupW    = 4 * cBodyW + 3 * cGap; // 52 px
   int baseLineW = groupW + 12;           // 64 px
   
   // Evenly distribute 9 timeframes across the subwindow
   int colSpacing = (chartW - 60) / 9;
   if(colSpacing < 68)  colSpacing = 68;
   if(colSpacing > 185) colSpacing = 185;
   int totalSpan = 9 * colSpacing;
   int startX = (chartW > totalSpan) ? (chartW - totalSpan) / 2 + colSpacing / 2 : 30 + colSpacing / 2;
   
   double liveBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Top-left PA subwindow badge (Matching Samurai original badge)
   string objPABg = GUI_PREFIX + "MTF_PA_BG";
   CreateOrUpdateRectLabel(objPABg, targetWin, 15, 8, 28, 16, C'30,70,130');
   string objPA = GUI_PREFIX + "MTF_PA";
   CreateOrUpdateTextLabel(objPA, targetWin, 29, 16, "PA", "Arial Bold", 8, clrWhite, ANCHOR_CENTER);
   
   // Render all 9 Timeframes (M1, M5, M15, M30, H1, H4, D1, W1, MN)
   for(int i = 0; i < 9; i++)
   {
      int colX = startX + i * colSpacing;
      
      MqlRates rates[4];
      int copied = CopyRates(_Symbol, tfs[i], 0, 4, rates);
      if(copied < 1)
      {
         // Try copying 1 bar
         copied = CopyRates(_Symbol, tfs[i], 0, 1, rates);
      }
      if(copied < 1)
      {
         // Fallback via iTime / iOpen / iHigh / iLow / iClose
         datetime bTime = iTime(_Symbol, tfs[i], 0);
         double bOpen   = iOpen(_Symbol, tfs[i], 0);
         double bHigh   = iHigh(_Symbol, tfs[i], 0);
         double bLow    = iLow(_Symbol, tfs[i], 0);
         double bClose  = iClose(_Symbol, tfs[i], 0);
         if(bTime > 0 && bHigh > 0 && bLow > 0)
         {
            rates[0].time  = bTime;
            rates[0].open  = bOpen;
            rates[0].high  = bHigh;
            rates[0].low   = bLow;
            rates[0].close = bClose;
            copied = 1;
         }
         else
         {
            // Synthetic single bar using live price so column is NEVER skipped
            double refP = (liveBid > 0) ? liveBid : 4150.0;
            rates[0].time  = curTime;
            rates[0].open  = refP;
            rates[0].high  = refP + 15 * _Point;
            rates[0].low   = refP - 15 * _Point;
            rates[0].close = refP;
            copied = 1;
         }
      }
          
      // Inject live Bid into current bar
      if(liveBid > 0 && copied > 0)
      {
         rates[copied - 1].close = liveBid;
         if(liveBid > rates[copied - 1].high) rates[copied - 1].high = liveBid;
         if(liveBid < rates[copied - 1].low)  rates[copied - 1].low  = liveBid;
      }
      
      // Calculate high/low extreme of the copied bars
      double maxH = rates[0].high;
      double minL = rates[0].low;
      for(int b = 1; b < copied; b++)
      {
         if(rates[b].high > maxH) maxH = rates[b].high;
         if(rates[b].low  < minL) minL = rates[b].low;
      }
      double priceRange = maxH - minL;
      if(priceRange < _Point) priceRange = _Point;
      
      // Render mini candles (historical on left, current active bar on right)
      for(int b = 0; b < copied; b++)
      {
         int candleCenterX = colX - groupW / 2 + b * (cBodyW + cGap) + cBodyW / 2;
         
         int yH = yTop + (int)MathRound((maxH - rates[b].high)  / priceRange * candleAreaH);
         int yL = yTop + (int)MathRound((maxH - rates[b].low)   / priceRange * candleAreaH);
         int yO = yTop + (int)MathRound((maxH - rates[b].open)  / priceRange * candleAreaH);
         int yC = yTop + (int)MathRound((maxH - rates[b].close) / priceRange * candleAreaH);
         
         yH = MathMin(MathMax(yH, yTop), yTop + candleAreaH);
         yL = MathMin(MathMax(yL, yTop), yTop + candleAreaH);
         if(yL < yH + 4) yL = yH + 4;
         
         yO = MathMin(MathMax(yO, yTop), yTop + candleAreaH);
         yC = MathMin(MathMax(yC, yTop), yTop + candleAreaH);
         
         int bodyTop = MathMin(yO, yC);
         int bodyH   = MathMax(MathAbs(yC - yO), 3);
         
         bool isBull = (rates[b].close >= rates[b].open);
         color candleCol = isBull ? C'0,220,120' : C'255,60,80'; // Bright Green / Bright Red
         color wickCol   = isBull ? C'0,190,90'  : C'220,40,60';
         
         // 1. Wick (vertical line)
         string objWick = GUI_PREFIX + "MTF_W_" + tfNames[i] + "_" + IntegerToString(b);
         CreateOrUpdateRectLabel(objWick, targetWin, candleCenterX - 1, yH, 2, yL - yH, wickCol);
         
         // 2. Body (rectangle)
         string objBody = GUI_PREFIX + "MTF_B_" + tfNames[i] + "_" + IntegerToString(b);
         CreateOrUpdateRectLabel(objBody, targetWin, candleCenterX - cBodyW / 2, bodyTop, cBodyW, bodyH, candleCol);
      }
      
      // Clean up unused bar slots if copied < 4
      for(int b = copied; b < 4; b++)
      {
         ObjectDelete(0, GUI_PREFIX + "MTF_W_" + tfNames[i] + "_" + IntegerToString(b));
         ObjectDelete(0, GUI_PREFIX + "MTF_B_" + tfNames[i] + "_" + IntegerToString(b));
      }
      
      // 3. Horizontal Aqua Live Bid Line across Candle 0 (current active bar)
      if(liveBid > 0 && copied > 0)
      {
         int yBid = yTop + (int)MathRound((maxH - liveBid) / priceRange * candleAreaH);
         yBid = MathMin(MathMax(yBid, yTop), yTop + candleAreaH);
         int rightCandleCenterX = colX - groupW / 2 + (copied - 1) * (cBodyW + cGap) + cBodyW / 2;
         int bidLineW = 26;
         int bidLineX = rightCandleCenterX - (bidLineW / 2);
         string objBid = GUI_PREFIX + "MTF_BID_" + tfNames[i];
         CreateOrUpdateRectLabel(objBid, targetWin, bidLineX, yBid, bidLineW, 2, C'0,240,255');
      }
      
      // 4. Horizontal Base Separator Line under the candles
      bool isCurrentTF = (_Period == tfs[i]);
      color baseCol = isCurrentTF ? clrGold : C'30,90,160'; // Gold for active chart TF, Steel Blue for others
      string objBase = GUI_PREFIX + "MTF_BASE_" + tfNames[i];
      CreateOrUpdateRectLabel(objBase, targetWin, colX - baseLineW / 2, yBaseLine, baseLineW, 2, baseCol);
      
      // 5. Timeframe Label
      MqlDateTime dt;
      TimeToStruct(curTime, dt);
      long remaining = 0;
      
      if(tfs[i] <= PERIOD_H1)
      {
         int pSecs = PeriodSeconds(tfs[i]);
         datetime barTime = rates[copied - 1].time;
         if(barTime > 0) remaining = (long)((barTime + pSecs) - curTime);
         if(remaining < 0) remaining = 0;
      }
      else if(tfs[i] == PERIOD_H4)
      {
         int curHour = dt.hour;
         int nextH4Hour = ((curHour / 4) + 1) * 4;
         int diffHours = nextH4Hour - curHour - 1;
         int diffMins  = 59 - dt.min;
         int diffSecs  = 60 - dt.sec;
         remaining = diffHours * 3600 + diffMins * 60 + diffSecs;
         if(remaining < 0) remaining = 0;
      }
      else if(tfs[i] == PERIOD_D1)
      {
         remaining = 86400 - (dt.hour * 3600 + dt.min * 60 + dt.sec);
         if(remaining < 0) remaining = 0;
      }
      else if(tfs[i] == PERIOD_W1)
      {
         int daysUntilFri = 5 - dt.day_of_week;
         if(daysUntilFri < 0) daysUntilFri += 7;
         remaining = daysUntilFri * 86400 + (86400 - (dt.hour * 3600 + dt.min * 60 + dt.sec));
         if(remaining < 0) remaining = 0;
      }
      else // PERIOD_MN1
      {
         int daysInMonth = 30;
         if(dt.mon == 1 || dt.mon == 3 || dt.mon == 5 || dt.mon == 7 || dt.mon == 8 || dt.mon == 10 || dt.mon == 12) daysInMonth = 31;
         else if(dt.mon == 2) daysInMonth = 28;
         int remDays = daysInMonth - dt.day;
         if(remDays < 0) remDays = 0;
         remaining = remDays * 86400 + (86400 - (dt.hour * 3600 + dt.min * 60 + dt.sec));
         if(remaining < 0) remaining = 0;
      }
      
      bool isAlert = (InpSamuraiGoldenAlert && remaining <= 15 && PeriodSeconds(tfs[i]) <= 3600);
      color lblCol = isAlert ? clrGold : (isCurrentTF ? clrGold : (color)10526880);
      
      string objLbl = GUI_PREFIX + "MTF_L_" + tfNames[i];
      CreateOrUpdateTextLabel(objLbl, targetWin, colX, yTfLabel, tfNames[i], "Arial Black", 9, lblCol, ANCHOR_CENTER);
      
      // 6. Real-Time Countdown Timer
      string objTime = GUI_PREFIX + "MTF_T_" + tfNames[i];
      string timeStr;
      if(tfs[i] <= PERIOD_H1)
         timeStr = StringFormat("%d:%02d", remaining / 60, remaining % 60);
      else if(tfs[i] == PERIOD_H4 || tfs[i] == PERIOD_D1)
         timeStr = StringFormat("%dh %02dm", remaining / 3600, (remaining % 3600) / 60);
      else
         timeStr = StringFormat("%dd %dh", remaining / 86400, (remaining % 86400) / 3600);
         
      color timeCol = isAlert ? clrGold : (isCurrentTF ? clrYellow : (color)9470064);
      CreateOrUpdateTextLabel(objTime, targetWin, colX, yCountdown, timeStr, "Arial", 8, timeCol, ANCHOR_CENTER);
   }
   
   // Periodic live screenshot to MQL5\Files for instant visual verification
   static ulong lastShotMs = 0;
   if(curMs - lastShotMs > 3000)
   {
      lastShotMs = curMs;
      ChartScreenShot(0, "live_chart_view.png", 1920, 1080, ALIGN_RIGHT);
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 14.1 ATH SMART CONFLUENCE & MACRO GPS ENGINE (กรอบราคา ATH)       |
//+------------------------------------------------------------------+
const double g_athLevels[] = {
   3357.73, 3405.92, 3500.03, 3549.59, 3578.42, 3622.49, 3659.29, 3674.52,
   3699.44, 3728.31, 3791.08, 3831.36, 3871.70, 3895.35, 3949.64, 3977.47,
   4049.66, 4085.32, 4179.74, 4218.24, 4247.73, 4380.07, 4420.34, 4497.83,
   4525.96, 4550.18, 4601.22, 4629.84, 4639.89, 4690.70, 4737.42, 4888.49,
   4967.53, 5111.14, 5311.54, 5595.34
};

void GetNearestATHLevels(double currentPrice, double &nearestSupport, double &nearestResistance)
{
   nearestSupport = 0;
   nearestResistance = 0;
   if(g_AssetProfile.assetType != ASSET_GOLD || currentPrice < 2000.0 || currentPrice > 6000.0) return;
   int size = ArraySize(g_athLevels);
   if(size == 0 || currentPrice <= 0) return;

   for(int i = 0; i < size; i++)
   {
      if(g_athLevels[i] <= currentPrice)
      {
         if(nearestSupport == 0 || g_athLevels[i] > nearestSupport)
            nearestSupport = g_athLevels[i];
      }
      if(g_athLevels[i] >= currentPrice)
      {
         if(nearestResistance == 0 || g_athLevels[i] < nearestResistance)
            nearestResistance = g_athLevels[i];
      }
   }
}

double AdjustTPForATHFrontRunning(ENUM_ORDER_TYPE orderType, double entryPrice, double standardTP, double nearestSup, double nearestRes)
{
   if(!InpUseATHGrid || !InpUseATHFrontRunning || entryPrice <= 0 || standardTP <= 0) return standardTP;
   double offset = InpATHFrontRunOffset * _Point;
   long brokerStopLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minAllowedDist = MathMax((double)brokerStopLvl + 5.0, 10.0) * _Point;

   // Target-specific ATH evaluation: find ATH levels around the target itself!
   double tpSup = 0, tpRes = 0;
   GetNearestATHLevels(standardTP, tpSup, tpRes);

   if(orderType == ORDER_TYPE_BUY)
   {
      // Target is approaching an ATH resistance level above entry
      if(tpRes > 0 && tpRes > entryPrice)
      {
         // Front-run if standardTP is within 150 pts of resistance
         if(standardTP >= (tpRes - (150 * _Point)) && standardTP <= (tpRes + (50 * _Point)))
         {
            double adjustedTP = tpRes - offset;
            if((adjustedTP - entryPrice) >= minAllowedDist)
               return adjustedTP;
         }
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Target is approaching an ATH support level below entry
      if(tpSup > 0 && tpSup < entryPrice)
      {
         // Front-run if standardTP is within 150 pts of support
         if(standardTP <= (tpSup + (150 * _Point)) && standardTP >= (tpSup - (50 * _Point)))
         {
            double adjustedTP = tpSup + offset;
            if((entryPrice - adjustedTP) >= minAllowedDist)
               return adjustedTP;
         }
      }
   }
   return standardTP;
}

bool IsATHPeakGuardBlocked(ENUM_ORDER_TYPE orderType, double currentPrice, string &blockReason)
{
   if(!InpUseATHGrid || !InpUseATRAntiPeakGuard || currentPrice <= 0) return false;
   double nearestSup = 0, nearestRes = 0;
   GetNearestATHLevels(currentPrice, nearestSup, nearestRes);
   double prox = InpATHProximityPts * _Point;

   if(orderType == ORDER_TYPE_BUY)
   {
      if(nearestRes > 0 && (nearestRes - currentPrice) <= prox && currentPrice < nearestRes)
      {
         blockReason = StringFormat("🛑 ATH RESISTANCE (%.2f ห่าง %.0f pts ≤ %d pts) - ห้าม Buy จ่อแนวต้าน ATH 🛡️", nearestRes, (nearestRes - currentPrice)/_Point, InpATHProximityPts);
         return true;
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(nearestSup > 0 && (currentPrice - nearestSup) <= prox && currentPrice > nearestSup)
      {
         blockReason = StringFormat("🛑 ATH SUPPORT (%.2f ห่าง %.0f pts ≤ %d pts) - ห้าม Sell จ่อแนวรับ ATH 🛡️", nearestSup, (currentPrice - nearestSup)/_Point, InpATHProximityPts);
         return true;
      }
   }
   return false;
}

void UpdateATHGridLines(double currentPrice)
{
   string nameRes = GUI_PREFIX + "ATH_RES_LINE";
   string nameSup = GUI_PREFIX + "ATH_SUP_LINE";

   if(!InpUseATHGrid || !InpDrawATHLines || !g_ShowATHGrid || !g_ShowVisuals || currentPrice <= 0 ||
      g_AssetProfile.assetType != ASSET_GOLD || currentPrice < 2000.0 || currentPrice > 6000.0)
   {
      ObjectDelete(0, nameRes);
      ObjectDelete(0, nameSup);
      return;
   }

   double nearestSup = 0, nearestRes = 0;
   GetNearestATHLevels(currentPrice, nearestSup, nearestRes);

   datetime t1 = iTime(_Symbol, _Period, 30);
   datetime t2 = iTime(_Symbol, _Period, 0) + (PeriodSeconds(_Period) * 20);
   if(t1 <= 0) t1 = TimeCurrent() - 3600;
   if(t2 <= 0) t2 = TimeCurrent() + 3600;

   if(nearestRes > 0)
   {
      if(ObjectFind(0, nameRes) < 0)
      {
         ObjectCreate(0, nameRes, OBJ_TREND, 0, t1, nearestRes, t2, nearestRes);
         ObjectSetInteger(0, nameRes, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, nameRes, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetInteger(0, nameRes, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, nameRes, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, nameRes, OBJPROP_BACK, true);
         ObjectSetInteger(0, nameRes, OBJPROP_SELECTABLE, false);
      }
      else
      {
         ObjectSetDouble(0, nameRes, OBJPROP_PRICE, 0, nearestRes);
         ObjectSetDouble(0, nameRes, OBJPROP_PRICE, 1, nearestRes);
         ObjectSetInteger(0, nameRes, OBJPROP_TIME, 0, t1);
         ObjectSetInteger(0, nameRes, OBJPROP_TIME, 1, t2);
      }
      string textRes = StringFormat("🧭 ATH Resistance: %.2f (+%.0f pts)", nearestRes, (nearestRes - currentPrice) / _Point);
      ObjectSetString(0, nameRes, OBJPROP_TEXT, textRes);
   }
   else
   {
      ObjectDelete(0, nameRes);
   }

   if(nearestSup > 0)
   {
      if(ObjectFind(0, nameSup) < 0)
      {
         ObjectCreate(0, nameSup, OBJ_TREND, 0, t1, nearestSup, t2, nearestSup);
         ObjectSetInteger(0, nameSup, OBJPROP_COLOR, clrDeepSkyBlue);
         ObjectSetInteger(0, nameSup, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetInteger(0, nameSup, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, nameSup, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, nameSup, OBJPROP_BACK, true);
         ObjectSetInteger(0, nameSup, OBJPROP_SELECTABLE, false);
      }
      else
      {
         ObjectSetDouble(0, nameSup, OBJPROP_PRICE, 0, nearestSup);
         ObjectSetDouble(0, nameSup, OBJPROP_PRICE, 1, nearestSup);
         ObjectSetInteger(0, nameSup, OBJPROP_TIME, 0, t1);
         ObjectSetInteger(0, nameSup, OBJPROP_TIME, 1, t2);
      }
      string textSup = StringFormat("🧭 ATH Support: %.2f (-%.0f pts)", nearestSup, (currentPrice - nearestSup) / _Point);
      ObjectSetString(0, nameSup, OBJPROP_TEXT, textSup);
   }
   else
   {
      ObjectDelete(0, nameSup);
   }
}

//+------------------------------------------------------------------+
//| INSTITUTIONAL Z-SCORE MEAN REVERSION & CME WALL CALCULATION      |
//+------------------------------------------------------------------+
void UpdateZScoreEngine()
{
   g_LiveZScore = 0.0;
   g_ZScoreExtremePeak = false;
   g_ZScoreExtremeValley = false;
   g_ZScoreStatusStr = "Z: 0.00 SD";

   if(!InpUseZScoreGuard)
      return;

   int period = MathMax(10, InpZScorePeriod);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpTimeframe, 0, period, rates) < period)
      return;

   double sum = 0.0;
   for(int i = 0; i < period; i++)
      sum += rates[i].close;
   double mean = sum / period;

   double sumSqDiff = 0.0;
   for(int i = 0; i < period; i++)
   {
      double diff = rates[i].close - mean;
      sumSqDiff += (diff * diff);
   }
   double variance = sumSqDiff / period;
   double stdDev = (variance > 0) ? MathSqrt(variance) : 0.0;

   if(stdDev > 0)
   {
      double curPrice = (m_symbol.Ask() + m_symbol.Bid()) / 2.0;
      g_LiveZScore = (curPrice - mean) / stdDev;
      
      if(g_LiveZScore >= InpZScoreThreshold)
      {
         g_ZScoreExtremePeak = true;
         g_ZScoreStatusStr = StringFormat("Z: +%.2f SD (PEAK ⚠️)", g_LiveZScore);
      }
      else if(g_LiveZScore <= -InpZScoreThreshold)
      {
         g_ZScoreExtremeValley = true;
         g_ZScoreStatusStr = StringFormat("Z: %.2f SD (ABYSS ⚠️)", g_LiveZScore);
      }
      else
      {
         g_ZScoreStatusStr = StringFormat("Z: %+.2f SD (OK)", g_LiveZScore);
      }
   }
}

void UpdateCMEWallEngine()
{
   g_CME_NearCallWall     = false;
   g_CME_NearMegaCallWall = false;
   g_CME_NearIntermedCall = false;
   g_CME_NearPutWall      = false;
   g_CME_NearMacroPutWall = false;
   g_CME_NearIntermedPut  = false;
   g_CME_ExpirationAlert  = false;

   if(!InpUseCMEWallGuard || g_AssetProfile.assetType != ASSET_GOLD)
      return;

   // Expiration DTE Tracking (Gamma Pinning Zone: DTE <= 3 days)
   int liveDTE = InpCME_DTE;
   if(InpCME_ExpiryDate > 0)
   {
      datetime now = TimeCurrent();
      if(InpCME_ExpiryDate > now)
         liveDTE = (int)((InpCME_ExpiryDate - now) / 86400);
      else
         liveDTE = 0;
   }
   if(liveDTE <= 3)
      g_CME_ExpirationAlert = true;
   g_CME_LiveDTE = liveDTE;

   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();

   // Proximity calculation with dynamic expiration buffer (+150 pts when DTE <= 3)
   double baseProxPts = (double)InpCME_ProximityPts;
   if(g_CME_ExpirationAlert)
      baseProxPts += 150.0;
   double prox = MathMax(50.0, baseProxPts) * _Point;

   // Intermediate proximity (.50 strikes) with dynamic expiration buffer (+100 pts when DTE <= 3)
   double interProxPts = (double)InpCME_IntermedProxPts;
   if(g_CME_ExpirationAlert)
      interProxPts += 100.0;
   double interProx = MathMax(30.0, interProxPts) * _Point;

   // 1. Mega Institutional Call Wall (4500.0) - Ultimate Ceiling
   if(InpCME_MegaCallWall > 0 && ask >= (InpCME_MegaCallWall - prox))
      g_CME_NearMegaCallWall = true;

   // 2. Tactical Call Wall (4400.0) - Active Defense Zone [4394.00 - 4406.00]
   if(InpCME_CallWall > 0 && ask >= (InpCME_CallWall - prox) && (InpCME_MegaCallWall <= 0 || ask <= (InpCME_CallWall + prox)))
      g_CME_NearCallWall = true;

   // 3. Intermediate Call Resistance (4350.0) - Speedbump Zone [4347.00 - 4353.00]
   if(InpCME_IntermediateCall > 0 && ask >= (InpCME_IntermediateCall - interProx) && ask <= (InpCME_IntermediateCall + interProx))
      g_CME_NearIntermedCall = true;

   // 4. Intermediate Put Support (4250.0) - Speedbump Zone [4247.00 - 4253.00]
   if(InpCME_IntermediatePut > 0 && bid <= (InpCME_IntermediatePut + interProx) && bid >= (InpCME_IntermediatePut - interProx))
      g_CME_NearIntermedPut = true;

   // 5. Tactical Put Wall (4300.0) - Active Defense Zone [4294.00 - 4306.00]
   if(InpCME_PutWall > 0 && bid <= (InpCME_PutWall + prox) && (InpCME_IntermediatePut <= 0 || bid >= (InpCME_PutWall - prox)))
      g_CME_NearPutWall = true;

   // 6. Macro Put Base (4200.0) - Ultimate Macro Floor
   if(InpCME_MacroPutWall > 0 && bid <= (InpCME_MacroPutWall + prox) && bid >= (InpCME_MacroPutWall - prox))
      g_CME_NearMacroPutWall = true;
}

void DrawCMEWallVisuals()
{
   string callLineName        = GUI_PREFIX + "CME_CALL_LINE";
   string callLblName         = GUI_PREFIX + "CME_CALL_LBL";
   string megaCallLineName    = GUI_PREFIX + "CME_MEGACALL_LINE";
   string megaCallLblName     = GUI_PREFIX + "CME_MEGACALL_LBL";
   string intermedCallLineName = GUI_PREFIX + "CME_INTCALL_LINE";
   string intermedCallLblName  = GUI_PREFIX + "CME_INTCALL_LBL";
   string putLineName         = GUI_PREFIX + "CME_PUT_LINE";
   string putLblName          = GUI_PREFIX + "CME_PUT_LBL";
   string intermedPutLineName = GUI_PREFIX + "CME_INTPUT_LINE";
   string intermedPutLblName  = GUI_PREFIX + "CME_INTPUT_LBL";
   string macroPutLineName    = GUI_PREFIX + "CME_MACROPUT_LINE";
   string macroPutLblName     = GUI_PREFIX + "CME_MACROPUT_LBL";

   if(!InpDrawCMEWalls || !InpUseCMEWallGuard || !g_ShowVisuals || g_AssetProfile.assetType != ASSET_GOLD)
   {
      ObjectDelete(0, callLineName);
      ObjectDelete(0, callLblName);
      ObjectDelete(0, megaCallLineName);
      ObjectDelete(0, megaCallLblName);
      ObjectDelete(0, intermedCallLineName);
      ObjectDelete(0, intermedCallLblName);
      ObjectDelete(0, putLineName);
      ObjectDelete(0, putLblName);
      ObjectDelete(0, intermedPutLineName);
      ObjectDelete(0, intermedPutLblName);
      ObjectDelete(0, macroPutLineName);
      ObjectDelete(0, macroPutLblName);
      return;
   }

   datetime t1 = iTime(_Symbol, InpTimeframe, MathMin(80, iBars(_Symbol, InpTimeframe) - 1));
   datetime tLineEnd = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 15);
   datetime tCME     = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 24);
   if(t1 <= 0) t1 = TimeCurrent() - 3600;
   if(tLineEnd <= 0) tLineEnd = TimeCurrent() + 3600;
   if(tCME <= 0) tCME = TimeCurrent() + 7200;

   // 1. Tactical Call Wall Line & Label (4400.0)
   if(InpCME_CallWall > 0)
   {
      if(ObjectFind(0, callLineName) < 0)
         ObjectCreate(0, callLineName, OBJ_TREND, 0, t1, InpCME_CallWall, tLineEnd, InpCME_CallWall);
      else
      {
         ObjectSetInteger(0, callLineName, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, callLineName, OBJPROP_PRICE, 0, InpCME_CallWall);
         ObjectSetInteger(0, callLineName, OBJPROP_TIME, 1, tLineEnd);
         ObjectSetDouble(0, callLineName, OBJPROP_PRICE, 1, InpCME_CallWall);
      }
      ObjectSetInteger(0, callLineName, OBJPROP_COLOR, C'255,80,100'); // Coral Red
      ObjectSetInteger(0, callLineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, callLineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, callLineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, callLineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, callLineName, OBJPROP_SELECTABLE, false);

      if(ObjectFind(0, callLblName) < 0)
         ObjectCreate(0, callLblName, OBJ_TEXT, 0, tCME, InpCME_CallWall);
      else
      {
         ObjectSetInteger(0, callLblName, OBJPROP_TIME, tCME);
         ObjectSetDouble(0, callLblName, OBJPROP_PRICE, InpCME_CallWall);
      }
      ObjectSetString(0, callLblName, OBJPROP_TEXT, StringFormat("  ðŸ”´ CME Call Wall [%.2f] (2,890 OI â€¢ à¹€à¸žà¸”à¸²à¸™à¸”à¸±à¸à¸—à¸¸à¸š Sell)", InpCME_CallWall));
      ObjectSetInteger(0, callLblName, OBJPROP_COLOR, C'255,100,120');
      ObjectSetString(0, callLblName, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, callLblName, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, callLblName, OBJPROP_BACK, false);
      ObjectSetInteger(0, callLblName, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectDelete(0, callLineName);
      ObjectDelete(0, callLblName);
   }

   // 2. Mega Institutional Call Wall Line & Label (4500.0)
   if(InpCME_MegaCallWall > 0)
   {
      if(ObjectFind(0, megaCallLineName) < 0)
         ObjectCreate(0, megaCallLineName, OBJ_TREND, 0, t1, InpCME_MegaCallWall, tLineEnd, InpCME_MegaCallWall);
      else
      {
         ObjectSetInteger(0, megaCallLineName, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, megaCallLineName, OBJPROP_PRICE, 0, InpCME_MegaCallWall);
         ObjectSetInteger(0, megaCallLineName, OBJPROP_TIME, 1, tLineEnd);
         ObjectSetDouble(0, megaCallLineName, OBJPROP_PRICE, 1, InpCME_MegaCallWall);
      }
      ObjectSetInteger(0, megaCallLineName, OBJPROP_COLOR, C'255,40,80'); // Crimson Red
      ObjectSetInteger(0, megaCallLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, megaCallLineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, megaCallLineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, megaCallLineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, megaCallLineName, OBJPROP_SELECTABLE, false);

      if(ObjectFind(0, megaCallLblName) < 0)
         ObjectCreate(0, megaCallLblName, OBJ_TEXT, 0, tCME, InpCME_MegaCallWall);
      else
      {
         ObjectSetInteger(0, megaCallLblName, OBJPROP_TIME, tCME);
         ObjectSetDouble(0, megaCallLblName, OBJPROP_PRICE, InpCME_MegaCallWall);
      }
      ObjectSetString(0, megaCallLblName, OBJPROP_TEXT, StringFormat("  ðŸš¨ CME MEGA Call Wall [%.2f] (10,618 OI â€¢ à¸‹à¸¹à¹€à¸›à¸­à¸£à¹Œà¹€à¸žà¸”à¸²à¸™à¸ªà¸–à¸²à¸šà¸±à¸™)", InpCME_MegaCallWall));
      ObjectSetInteger(0, megaCallLblName, OBJPROP_COLOR, C'255,60,100');
      ObjectSetString(0, megaCallLblName, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, megaCallLblName, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, megaCallLblName, OBJPROP_BACK, false);
      ObjectSetInteger(0, megaCallLblName, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectDelete(0, megaCallLineName);
      ObjectDelete(0, megaCallLblName);
   }

   // 2.5 Intermediate Call Resistance Line & Label (4350.0)
   if(InpCME_IntermediateCall > 0)
   {
      if(ObjectFind(0, intermedCallLineName) < 0)
         ObjectCreate(0, intermedCallLineName, OBJ_TREND, 0, t1, InpCME_IntermediateCall, tLineEnd, InpCME_IntermediateCall);
      else
      {
         ObjectSetInteger(0, intermedCallLineName, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, intermedCallLineName, OBJPROP_PRICE, 0, InpCME_IntermediateCall);
         ObjectSetInteger(0, intermedCallLineName, OBJPROP_TIME, 1, tLineEnd);
         ObjectSetDouble(0, intermedCallLineName, OBJPROP_PRICE, 1, InpCME_IntermediateCall);
      }
      ObjectSetInteger(0, intermedCallLineName, OBJPROP_COLOR, C'255,160,50'); // Amber Orange
      ObjectSetInteger(0, intermedCallLineName, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, intermedCallLineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, intermedCallLineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, intermedCallLineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, intermedCallLineName, OBJPROP_SELECTABLE, false);

      if(ObjectFind(0, intermedCallLblName) < 0)
         ObjectCreate(0, intermedCallLblName, OBJ_TEXT, 0, tCME, InpCME_IntermediateCall);
      else
      {
         ObjectSetInteger(0, intermedCallLblName, OBJPROP_TIME, tCME);
         ObjectSetDouble(0, intermedCallLblName, OBJPROP_PRICE, InpCME_IntermediateCall);
      }

      // Anti-Collision with Fibo 50% Equilibrium:
      ENUM_ANCHOR_POINT intCallAnchor = ANCHOR_LEFT_LOWER;
      if(g_Fibo.p500 > 0 && MathAbs(InpCME_IntermediateCall - g_Fibo.p500) < (250 * _Point))
         intCallAnchor = (InpCME_IntermediateCall < g_Fibo.p500) ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER;
      ObjectSetInteger(0, intermedCallLblName, OBJPROP_ANCHOR, intCallAnchor);

      ObjectSetString(0, intermedCallLblName, OBJPROP_TEXT, StringFormat("  ðŸ”¶ CME Intermed Call [%.2f] (1,433 OI â€¢ à¸•à¹‰à¸²à¸™à¸¢à¹ˆà¸­à¸¢ .50)", InpCME_IntermediateCall));
      ObjectSetInteger(0, intermedCallLblName, OBJPROP_COLOR, C'255,180,70');
      ObjectSetString(0, intermedCallLblName, OBJPROP_FONT, "Segoe UI Semibold");
      ObjectSetInteger(0, intermedCallLblName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, intermedCallLblName, OBJPROP_BACK, false);
      ObjectSetInteger(0, intermedCallLblName, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectDelete(0, intermedCallLineName);
      ObjectDelete(0, intermedCallLblName);
   }

   // 3. Tactical Put Wall Line & Label (4300.0)
   if(InpCME_PutWall > 0)
   {
      if(ObjectFind(0, putLineName) < 0)
         ObjectCreate(0, putLineName, OBJ_TREND, 0, t1, InpCME_PutWall, tLineEnd, InpCME_PutWall);
      else
      {
         ObjectSetInteger(0, putLineName, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, putLineName, OBJPROP_PRICE, 0, InpCME_PutWall);
         ObjectSetInteger(0, putLineName, OBJPROP_TIME, 1, tLineEnd);
         ObjectSetDouble(0, putLineName, OBJPROP_PRICE, 1, InpCME_PutWall);
      }
      ObjectSetInteger(0, putLineName, OBJPROP_COLOR, C'50,225,130'); // Spring Green
      ObjectSetInteger(0, putLineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, putLineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, putLineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, putLineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, putLineName, OBJPROP_SELECTABLE, false);

      if(ObjectFind(0, putLblName) < 0)
         ObjectCreate(0, putLblName, OBJ_TEXT, 0, tCME, InpCME_PutWall);
      else
      {
         ObjectSetInteger(0, putLblName, OBJPROP_TIME, tCME);
         ObjectSetDouble(0, putLblName, OBJPROP_PRICE, InpCME_PutWall);
      }
      ObjectSetString(0, putLblName, OBJPROP_TEXT, StringFormat("  ðŸŸ¢ CME Put Wall [%.2f] (3,296 OI â€¢ à¸žà¸·à¹‰à¸™à¸”à¸±à¸à¸Šà¹‰à¸­à¸™ Buy)", InpCME_PutWall));
      ObjectSetInteger(0, putLblName, OBJPROP_COLOR, C'80,250,160');
      ObjectSetString(0, putLblName, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, putLblName, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, putLblName, OBJPROP_BACK, false);
      ObjectSetInteger(0, putLblName, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectDelete(0, putLineName);
      ObjectDelete(0, putLblName);
   }

   // 3.5 Intermediate Put Support Line & Label (4250.0)
   if(InpCME_IntermediatePut > 0)
   {
      if(ObjectFind(0, intermedPutLineName) < 0)
         ObjectCreate(0, intermedPutLineName, OBJ_TREND, 0, t1, InpCME_IntermediatePut, tLineEnd, InpCME_IntermediatePut);
      else
      {
         ObjectSetInteger(0, intermedPutLineName, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, intermedPutLineName, OBJPROP_PRICE, 0, InpCME_IntermediatePut);
         ObjectSetInteger(0, intermedPutLineName, OBJPROP_TIME, 1, tLineEnd);
         ObjectSetDouble(0, intermedPutLineName, OBJPROP_PRICE, 1, InpCME_IntermediatePut);
      }
      ObjectSetInteger(0, intermedPutLineName, OBJPROP_COLOR, C'70,180,255'); // Dodger Cyan
      ObjectSetInteger(0, intermedPutLineName, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, intermedPutLineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, intermedPutLineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, intermedPutLineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, intermedPutLineName, OBJPROP_SELECTABLE, false);

      if(ObjectFind(0, intermedPutLblName) < 0)
         ObjectCreate(0, intermedPutLblName, OBJ_TEXT, 0, tCME, InpCME_IntermediatePut);
      else
      {
         ObjectSetInteger(0, intermedPutLblName, OBJPROP_TIME, tCME);
         ObjectSetDouble(0, intermedPutLblName, OBJPROP_PRICE, InpCME_IntermediatePut);
      }

      // Anti-Collision with Fibo 50% Equilibrium:
      ENUM_ANCHOR_POINT intPutAnchor = ANCHOR_LEFT_LOWER;
      if(g_Fibo.p500 > 0 && MathAbs(InpCME_IntermediatePut - g_Fibo.p500) < (250 * _Point))
         intPutAnchor = (InpCME_IntermediatePut < g_Fibo.p500) ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER;
      ObjectSetInteger(0, intermedPutLblName, OBJPROP_ANCHOR, intPutAnchor);

      ObjectSetString(0, intermedPutLblName, OBJPROP_TEXT, StringFormat("  ðŸ”· CME Intermed Put [%.2f] (2,468 OI â€¢ à¸£à¸±à¸šà¸¢à¹ˆà¸­à¸¢ .50)", InpCME_IntermediatePut));
      ObjectSetInteger(0, intermedPutLblName, OBJPROP_COLOR, C'100,200,255');
      ObjectSetString(0, intermedPutLblName, OBJPROP_FONT, "Segoe UI Semibold");
      ObjectSetInteger(0, intermedPutLblName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, intermedPutLblName, OBJPROP_BACK, false);
      ObjectSetInteger(0, intermedPutLblName, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectDelete(0, intermedPutLineName);
      ObjectDelete(0, intermedPutLblName);
   }

   // 4. Macro Put Base Line & Label (4200.0)
   if(InpCME_MacroPutWall > 0)
   {
      if(ObjectFind(0, macroPutLineName) < 0)
         ObjectCreate(0, macroPutLineName, OBJ_TREND, 0, t1, InpCME_MacroPutWall, tLineEnd, InpCME_MacroPutWall);
      else
      {
         ObjectSetInteger(0, macroPutLineName, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, macroPutLineName, OBJPROP_PRICE, 0, InpCME_MacroPutWall);
         ObjectSetInteger(0, macroPutLineName, OBJPROP_TIME, 1, tLineEnd);
         ObjectSetDouble(0, macroPutLineName, OBJPROP_PRICE, 1, InpCME_MacroPutWall);
      }
      ObjectSetInteger(0, macroPutLineName, OBJPROP_COLOR, C'30,200,160'); // Deep Emerald Mint
      ObjectSetInteger(0, macroPutLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, macroPutLineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, macroPutLineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, macroPutLineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, macroPutLineName, OBJPROP_SELECTABLE, false);

      if(ObjectFind(0, macroPutLblName) < 0)
         ObjectCreate(0, macroPutLblName, OBJ_TEXT, 0, tCME, InpCME_MacroPutWall);
      else
      {
         ObjectSetInteger(0, macroPutLblName, OBJPROP_TIME, tCME);
         ObjectSetDouble(0, macroPutLblName, OBJPROP_PRICE, InpCME_MacroPutWall);
      }
      ObjectSetString(0, macroPutLblName, OBJPROP_TEXT, StringFormat("  🛡️ CME Macro Put Base [%.2f] (2,525 OI • ฐานรับใหญ่สถาบัน)", InpCME_MacroPutWall));
      ObjectSetInteger(0, macroPutLblName, OBJPROP_COLOR, C'50,240,190');
      ObjectSetString(0, macroPutLblName, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, macroPutLblName, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, macroPutLblName, OBJPROP_BACK, false);
      ObjectSetInteger(0, macroPutLblName, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectDelete(0, macroPutLineName);
      ObjectDelete(0, macroPutLblName);
   }
}

//+------------------------------------------------------------------+
//| 15. CHART VISUAL DRAWINGS (FIBO, SWINGS, BOS & FVG)              |
//+------------------------------------------------------------------+
void DrawChartVisuals()
{
   if(!g_ShowVisuals)
      return;

   // 1. Draw Swing Points on Chart (HH, HL, LH, LL with integrated Institutional tags)
   if(g_LastSwingHigh.price > 0 && g_LastSwingHigh.time > 0)
   {
      string hText = g_LastSwingHigh.labelStr;
      if(InpShowSMC_StrongWeak)
         hText = (g_LastSwingHigh.labelType == SWING_HH) ? "HH • Weak High" : "LH • Strong High";
      DrawSwingText("SW_LAST_H", g_LastSwingHigh.time, g_LastSwingHigh.price, hText, (g_LastSwingHigh.labelType == SWING_HH ? clrLime : clrTomato));
   }

   if(g_LastSwingLow.price > 0 && g_LastSwingLow.time > 0)
   {
      string lText = g_LastSwingLow.labelStr;
      if(InpShowSMC_StrongWeak)
         lText = (g_LastSwingLow.labelType == SWING_HL) ? "HL • Strong Low" : "LL • Weak Low";
      DrawSwingText("SW_LAST_L", g_LastSwingLow.time, g_LastSwingLow.price, lText, (g_LastSwingLow.labelType == SWING_HL ? clrLime : clrTomato));
   }

   // 2. Draw Golden Zone Box
   if(g_Fibo.p0 > 0 || g_Fibo.zoneHigh > 0)
   {
      string zoneBox = GUI_PREFIX + "VIS_ZONE_BOX";
      datetime time1 = TimeCurrent() - (PeriodSeconds(InpTimeframe) * 50);
      datetime time2 = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 20);

      if(ObjectFind(0, zoneBox) < 0)
         ObjectCreate(0, zoneBox, OBJ_RECTANGLE, 0, time1, g_Fibo.zoneHigh, time2, g_Fibo.zoneLow);
      else
      {
         ObjectSetInteger(0, zoneBox, OBJPROP_TIME, 0, time1);
         ObjectSetDouble(0, zoneBox, OBJPROP_PRICE, 0, g_Fibo.zoneHigh);
         ObjectSetInteger(0, zoneBox, OBJPROP_TIME, 1, time2);
         ObjectSetDouble(0, zoneBox, OBJPROP_PRICE, 1, g_Fibo.zoneLow);
      }
      ObjectSetInteger(0, zoneBox, OBJPROP_COLOR, InpColorFiboZone);
      ObjectSetInteger(0, zoneBox, OBJPROP_FILL, true);
      ObjectSetInteger(0, zoneBox, OBJPROP_BACK, true);

      // Pure Fibonacci Structure Levels
      if(g_Fibo.p0 > 0)
         DrawFiboLine("LINE_0", StringFormat("0.0%% Peak • %.2f", g_Fibo.p0), g_Fibo.p0, clrDeepSkyBlue, STYLE_DOT, 1);
      else
         ObjectDelete(0, GUI_PREFIX + "VIS_LINE_0");

      if(g_Fibo.p236 > 0)
         DrawFiboLine("LINE_236", StringFormat("23.6%% • %.2f", g_Fibo.p236), g_Fibo.p236, clrMediumTurquoise, STYLE_DOT, 1);
      else
         ObjectDelete(0, GUI_PREFIX + "VIS_LINE_236");

      if(g_Fibo.p382 > 0)
         DrawFiboLine("LINE_382", StringFormat("38.2%% Shallow Retracement • %.2f", g_Fibo.p382), g_Fibo.p382, clrSandyBrown, STYLE_SOLID, 1);
      else
         ObjectDelete(0, GUI_PREFIX + "VIS_LINE_382");

      if(g_Fibo.p500 > 0)
         DrawFiboLine("LINE_500", StringFormat("50.0%% Equilibrium • %.2f", g_Fibo.p500), g_Fibo.p500, clrOrange, STYLE_SOLID, 1);
      else
         ObjectDelete(0, GUI_PREFIX + "VIS_LINE_500");

      if(g_Fibo.p618 > 0)
         DrawFiboLine("LINE_618", StringFormat("61.8%% Golden Pocket • %.2f", g_Fibo.p618), g_Fibo.p618, clrGold, STYLE_SOLID, 2);
      else
         ObjectDelete(0, GUI_PREFIX + "VIS_LINE_618");

      if(g_Fibo.p786 > 0)
         DrawFiboLine("LINE_786", StringFormat("78.6%% Deep Zone • %.2f", g_Fibo.p786), g_Fibo.p786, clrTomato, STYLE_DASH, 1);
      else
         ObjectDelete(0, GUI_PREFIX + "VIS_LINE_786");

      if(g_Fibo.p100 > 0 && MathAbs(g_Fibo.p100 - g_PlanSL) > (g_AssetProfile.minSwing * 0.10 * _Point))
         DrawFiboLine("LINE_100", StringFormat("100.0%% Base • %.2f", g_Fibo.p100), g_Fibo.p100, clrCrimson, STYLE_DOT, 1);
      else
         ObjectDelete(0, GUI_PREFIX + "VIS_LINE_100");

      if(g_Fibo.p1272 > 0)
         DrawFiboLine("LINE_1272", StringFormat("127.2%% Target 1 • %.2f", g_Fibo.p1272), g_Fibo.p1272, clrMediumSpringGreen, STYLE_DASH, 1);
      else
         ObjectDelete(0, GUI_PREFIX + "VIS_LINE_1272");

      if(g_Fibo.p1618 > 0)
         DrawFiboLine("LINE_1618", StringFormat("161.8%% Wave 3 Target • %.2f", g_Fibo.p1618), g_Fibo.p1618, clrLime, STYLE_DASH, 1);
      else
         ObjectDelete(0, GUI_PREFIX + "VIS_LINE_1618");

      if(g_Fibo.p2618 > 0)
         DrawFiboLine("LINE_2618", StringFormat("261.8%% Runner Target • %.2f", g_Fibo.p2618), g_Fibo.p2618, clrGold, STYLE_DASH, 1);
      else
         ObjectDelete(0, GUI_PREFIX + "VIS_LINE_2618");
   }

   // 2.1 Dedicated Active Plan Execution Lines (Matching Card 2 to the exact cent & pip 100%)
   bool hasActivePlan = (g_PlanEntry > 0 && (g_BotState == STATE_TRIGGER_READY || g_BotState == STATE_PULLBACK_ARMED || g_BotState == STATE_IN_POSITION));
   if(hasActivePlan)
   {
      bool isBullPlan = (g_PlanDirection != 0) ? (g_PlanDirection == 1) : (g_MarketTrend == TREND_BULLISH);
      double riskPts = (g_PlanEntry > 0 && g_PlanSL > 0) ? MathAbs(g_PlanEntry - g_PlanSL) / _Point : 0;
      double liveRR1 = (riskPts > 0 && g_PlanTP1 > 0) ? (MathAbs(g_PlanTP1 - g_PlanEntry) / _Point) / riskPts : g_PlanRR1;
      double liveRR2 = (riskPts > 0 && g_PlanTP2 > 0) ? (MathAbs(g_PlanTP2 - g_PlanEntry) / _Point) / riskPts : g_PlanRR2;
      double liveRR3 = (riskPts > 0 && g_PlanTP3 > 0) ? (MathAbs(g_PlanTP3 - g_PlanEntry) / _Point) / riskPts : g_PlanRR3;

      // 50% Wick Equilibrium Level Visual (Forex Lab Sniper)
      if(g_WickSniper_Setup.isActive && g_WickSniper_Setup.wickEquilibrium > 0)
      {
         string wickLineName = GUI_PREFIX + "VIS_WICK_50_LINE";
         string wickTxtName  = GUI_PREFIX + "VIS_WICK_50_TXT";
         color wickCol = (g_WickSniper_Setup.direction == ORDER_TYPE_BUY) ? clrMediumSpringGreen : clrHotPink;
         datetime tStart = iTime(_Symbol, _Period, MathMin(30, iBars(_Symbol, _Period) - 1));
         datetime tEnd   = iTime(_Symbol, _Period, 0) + (PeriodSeconds(_Period) * 12);

         if(ObjectFind(0, wickLineName) < 0)
            ObjectCreate(0, wickLineName, OBJ_TREND, 0, tStart, g_WickSniper_Setup.wickEquilibrium, tEnd, g_WickSniper_Setup.wickEquilibrium);
         else
         {
            ObjectSetInteger(0, wickLineName, OBJPROP_TIME, 0, tStart);
            ObjectSetDouble(0, wickLineName, OBJPROP_PRICE, 0, g_WickSniper_Setup.wickEquilibrium);
            ObjectSetInteger(0, wickLineName, OBJPROP_TIME, 1, tEnd);
            ObjectSetDouble(0, wickLineName, OBJPROP_PRICE, 1, g_WickSniper_Setup.wickEquilibrium);
         }
         ObjectSetInteger(0, wickLineName, OBJPROP_COLOR, wickCol);
         ObjectSetInteger(0, wickLineName, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetInteger(0, wickLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, wickLineName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, wickLineName, OBJPROP_BACK, true);

         if(ObjectFind(0, wickTxtName) < 0)
            ObjectCreate(0, wickTxtName, OBJ_TEXT, 0, tEnd, g_WickSniper_Setup.wickEquilibrium);
         else
         {
            ObjectSetInteger(0, wickTxtName, OBJPROP_TIME, tEnd);
            ObjectSetDouble(0, wickTxtName, OBJPROP_PRICE, g_WickSniper_Setup.wickEquilibrium);
         }
         string dirTag = (g_WickSniper_Setup.direction == ORDER_TYPE_BUY) ? "Buy Reversal" : "Sell Reversal";
         string wickLabel = StringFormat("  🎯 50%% Wick H1 [%.2f] (%s)", g_WickSniper_Setup.wickEquilibrium, dirTag);
         ObjectSetString(0, wickTxtName, OBJPROP_TEXT, wickLabel);
         ObjectSetInteger(0, wickTxtName, OBJPROP_COLOR, wickCol);
         ObjectSetString(0, wickTxtName, OBJPROP_FONT, "Segoe UI Bold");
         ObjectSetInteger(0, wickTxtName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, wickTxtName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "VIS_WICK_50_LINE");
         ObjectDelete(0, GUI_PREFIX + "VIS_WICK_50_TXT");
      }

      // Plan Entry Line
      string planTag = (g_PlanSource == "ACTIVE_BUY" || g_PlanSource == "ACTIVE_SELL") ? "ACTIVE" : g_PlanSource;
      string entryDesc = StringFormat("🎯 ENTRY • %s (%s %s)", DoubleToString(g_PlanEntry, _Digits), planTag, (isBullPlan ? "BUY" : "SELL"));
      DrawPlanLine("ENTRY", entryDesc, g_PlanEntry, clrWhite, STYLE_SOLID, 2);

      // Plan SL Line
      if(g_PlanSL > 0)
      {
         double slPts = MathAbs(g_PlanEntry - g_PlanSL) / _Point;
         string slDesc = StringFormat("🛑 SL • %s (%s)", DoubleToString(g_PlanSL, _Digits), FormatPlanDistStr(slPts, true));
         DrawPlanLine("SL", slDesc, g_PlanSL, clrCrimson, STYLE_SOLID, 2);
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "VIS_PLAN_SL");
         ObjectDelete(0, GUI_PREFIX + "VIS_TXT_PLAN_SL");
      }

      // Plan TP1 Line
      if(g_PlanTP1 > 0)
      {
         double tp1Pts = MathAbs(g_PlanTP1 - g_PlanEntry) / _Point;
         string tp1Note = (g_PlanSource == "SPIKE") ? "1.0x" : ((g_PlanSource == "ACTIVE_BUY" || g_PlanSource == "ACTIVE_SELL") ? "ล็อกกำไร +800 pts" : "50% BE");
         string tp1Desc = StringFormat("🎯 TP1 • %s (%s | RR 1:%.1f | %s)", DoubleToString(g_PlanTP1, _Digits), FormatPlanDistStr(tp1Pts, false), liveRR1, tp1Note);
         DrawPlanLine("TP1", tp1Desc, g_PlanTP1, clrAqua, STYLE_SOLID, 2);
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "VIS_PLAN_TP1");
         ObjectDelete(0, GUI_PREFIX + "VIS_TXT_PLAN_TP1");
      }

      // Plan TP2 Line
      if(g_PlanTP2 > 0)
      {
         double tp2Pts = MathAbs(g_PlanTP2 - g_PlanEntry) / _Point;
         string tp2Note = (g_PlanSource == "SPIKE") ? "1.6x" : "Wave 3";
         string tp2Desc = StringFormat("🚀 TP2 • %s (%s | RR 1:%.1f | %s)", DoubleToString(g_PlanTP2, _Digits), FormatPlanDistStr(tp2Pts, false), liveRR2, tp2Note);
         DrawPlanLine("TP2", tp2Desc, g_PlanTP2, clrLimeGreen, STYLE_SOLID, 2);
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "VIS_PLAN_TP2");
         ObjectDelete(0, GUI_PREFIX + "VIS_TXT_PLAN_TP2");
      }

      // Plan TP3 Line
      if(g_PlanTP3 > 0)
      {
         double tp3Pts = MathAbs(g_PlanTP3 - g_PlanEntry) / _Point;
         string tp3Note = (g_PlanSource == "SPIKE") ? "2.6x" : "Runner";
         string tp3Desc = StringFormat("👑 TP3 • %s (%s | RR 1:%.1f | %s)", DoubleToString(g_PlanTP3, _Digits), FormatPlanDistStr(tp3Pts, false), liveRR3, tp3Note);
         DrawPlanLine("TP3", tp3Desc, g_PlanTP3, clrGold, STYLE_SOLID, 2);
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "VIS_PLAN_TP3");
         ObjectDelete(0, GUI_PREFIX + "VIS_TXT_PLAN_TP3");
      }
   }
   else
   {
      RemoveActivePlanVisuals();
   }

   // Cleanup legacy target names if present
   ObjectDelete(0, GUI_PREFIX + "VIS_TARGET_TP1");
   ObjectDelete(0, GUI_PREFIX + "VIS_TXT_TARGET_TP1");
   ObjectDelete(0, GUI_PREFIX + "VIS_TARGET_TP2");
   ObjectDelete(0, GUI_PREFIX + "VIS_TXT_TARGET_TP2");
   ObjectDelete(0, GUI_PREFIX + "VIS_TARGET_TP3");
   ObjectDelete(0, GUI_PREFIX + "VIS_TXT_TARGET_TP3");
   ObjectDelete(0, GUI_PREFIX + "VIS_TARGET_SL");
   ObjectDelete(0, GUI_PREFIX + "VIS_TXT_TARGET_SL");
   ObjectDelete(0, GUI_PREFIX + "FIBO_TARGET_SL");

   // 3. Draw FVG Box if Active
   if(g_FVG_Active && g_ActiveFVG.isActive)
   {
      string fvgBox = GUI_PREFIX + "VIS_FVG_BOX";
      string fvgLbl = GUI_PREFIX + "VIS_FVG_LBL";
      datetime t1 = g_ActiveFVG.time;
      datetime t2 = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 15);
      color fvgCol = (g_ActiveFVG.direction == 1) ? InpColorBullishFVG : InpColorBearishFVG;

      if(ObjectFind(0, fvgBox) < 0)
         ObjectCreate(0, fvgBox, OBJ_RECTANGLE, 0, t1, g_ActiveFVG.topPrice, t2, g_ActiveFVG.bottomPrice);
      else
      {
         ObjectSetInteger(0, fvgBox, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, fvgBox, OBJPROP_PRICE, 0, g_ActiveFVG.topPrice);
         ObjectSetInteger(0, fvgBox, OBJPROP_TIME, 1, t2);
         ObjectSetDouble(0, fvgBox, OBJPROP_PRICE, 1, g_ActiveFVG.bottomPrice);
      }
      ObjectSetInteger(0, fvgBox, OBJPROP_COLOR, fvgCol);
      ObjectSetInteger(0, fvgBox, OBJPROP_FILL, true);
      ObjectSetInteger(0, fvgBox, OBJPROP_BACK, true);

      // Clean label directly inside the FVG box
      if(ObjectFind(0, fvgLbl) < 0)
         ObjectCreate(0, fvgLbl, OBJ_TEXT, 0, t1, g_ActiveFVG.topPrice);
      else
      {
         ObjectSetInteger(0, fvgLbl, OBJPROP_TIME, t1);
         ObjectSetDouble(0, fvgLbl, OBJPROP_PRICE, g_ActiveFVG.topPrice);
      }
      ObjectSetString(0, fvgLbl, OBJPROP_TEXT, (g_ActiveFVG.direction == 1 ? " ⚡ BULLISH FVG " : " ⚡ BEARISH FVG "));
      ObjectSetString(0, fvgLbl, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, fvgLbl, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, fvgLbl, OBJPROP_COLOR, (g_ActiveFVG.direction == 1 ? clrSkyBlue : clrOrangeRed));
      ObjectSetInteger(0, fvgLbl, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   }

   // 5. Draw ChoCH / BOS Break Level on Chart
   if(g_StructLevel > 0 && g_StructEvent != STRUCT_NONE)
   {
      color structCol = (g_MarketTrend == TREND_BULLISH ? clrLime : clrCrimson);
      DrawStructureLine("STRUCT_LINE", g_StructEventName, g_StructLevel, structCol);
   }

   // 6. Draw Institutional SMC Visual Suite (BOS, Liquidity Pools, MTF Zones & POC)
   DrawSMCVisuals();

   // 7. Draw Elliott Wave Dual Swing Visuals
   if(InpEnableElliottWave && InpShowElliottVisuals)
      DrawElliottVisuals();

   // 8. Draw ATH Smart Confluence Grid Lines
   if(InpUseATHGrid && InpDrawATHLines)
      UpdateATHGridLines(m_symbol.Ask());

   // 9. Draw Linear Regression Channel Visuals
   DrawLinearRegressionVisuals();

   // 10. Draw SMC BSL / SSL Multi-Timeframe Liquidity Radar Visuals
   if(InpShowSMC_BSL_SSL)
      DrawLiquidityRadarVisuals();
   else
      RemoveLiquidityRadarVisuals();

   // 11. Draw Asian Range Box & London Judas Swing Visuals
   if(InpUseAsianRangeJudas)
      DrawAsianRangeBox();
   else
   {
      ObjectDelete(0, GUI_PREFIX + "ASIAN_BOX");
      ObjectDelete(0, GUI_PREFIX + "ASIAN_AH");
      ObjectDelete(0, GUI_PREFIX + "ASIAN_AL");
      ObjectDelete(0, GUI_PREFIX + "ASIAN_AH_LBL");
      ObjectDelete(0, GUI_PREFIX + "ASIAN_AL_LBL");
   }

   // 12. Draw CME Call & Put Wall Visuals
   DrawCMEWallVisuals();

   // 13. Draw ABCD Wave & Smart Action Suite Visuals
   if(g_ShowABCDWave)
      DrawABCDWaveVisuals();
   else
      ObjectsDeleteAll(0, GUI_PREFIX + "ABCD_");

   // 14. Draw Multi-TF EMA 14 Matrix & Institutional EMA 200 Visuals
   if(g_ShowEMAVisuals && (InpShowMultiTF_EMA14 || InpShowEMA200_Line))
      DrawMultiTF_EMA14_Visuals();
   else
      RemoveMultiTF_EMA14_Visuals();
}

//+------------------------------------------------------------------+
//| 🌊 DRAW ABCD WAVE & LIQUIDITY TRAP VISUALS ON CHART              |
//+------------------------------------------------------------------+
void DrawABCDWaveVisuals()
{
   if(!g_ShowABCDWave || !g_ShowVisuals)
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "ABCD_");
      return;
   }

   SABCDWaveData wave = CalculateABCDWave(InpTimeframe);
   if(wave.priceA <= 0 || wave.priceB <= 0 || wave.direction == 0)
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "ABCD_");
      return;
   }

   bool isBull = (wave.direction == 1);
   color colA  = isBull ? clrLime : clrTomato;
   color colB  = clrGold;
   color colC  = isBull ? clrAqua : clrOrange;

   // 1. Point A Label
   string nameA = GUI_PREFIX + "ABCD_PT_A";
   if(ObjectFind(0, nameA) < 0)
      ObjectCreate(0, nameA, OBJ_TEXT, 0, wave.timeA, wave.priceA);
   else
   {
      ObjectSetInteger(0, nameA, OBJPROP_TIME, 0, wave.timeA);
      ObjectSetDouble(0, nameA, OBJPROP_PRICE, 0, wave.priceA);
   }
   ObjectSetString(0, nameA, OBJPROP_TEXT, isBull ? "🟢 [ A: จุดเริ่มคลื่น 📈 ]" : "🔴 [ A: จุดเริ่มคลื่น 📉 ]");
   ObjectSetString(0, nameA, OBJPROP_FONT, "Segoe UI Black");
   ObjectSetInteger(0, nameA, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, nameA, OBJPROP_COLOR, colA);
   ObjectSetInteger(0, nameA, OBJPROP_ANCHOR, isBull ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, nameA, OBJPROP_BACK, false);

   // 2. Point B Label
   string nameB = GUI_PREFIX + "ABCD_PT_B";
   if(ObjectFind(0, nameB) < 0)
      ObjectCreate(0, nameB, OBJ_TEXT, 0, wave.timeB, wave.priceB);
   else
   {
      ObjectSetInteger(0, nameB, OBJPROP_TIME, 0, wave.timeB);
      ObjectSetDouble(0, nameB, OBJPROP_PRICE, 0, wave.priceB);
   }
   ObjectSetString(0, nameB, OBJPROP_TEXT, isBull ? "⏸️ [ B: ยอดคลื่นแรก ]" : "⏸️ [ B: ก้นคลื่นแรก ]");
   ObjectSetString(0, nameB, OBJPROP_FONT, "Segoe UI Black");
   ObjectSetInteger(0, nameB, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, nameB, OBJPROP_COLOR, colB);
   ObjectSetInteger(0, nameB, OBJPROP_ANCHOR, isBull ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0, nameB, OBJPROP_BACK, false);

   // 3. Point C - OTE Shaded Zone Box & Label
   datetime timeStartC = wave.timeB;
   datetime timeEndC   = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 25);
   string boxC = GUI_PREFIX + "ABCD_BOX_OTE";
   if(ObjectFind(0, boxC) < 0)
      ObjectCreate(0, boxC, OBJ_RECTANGLE, 0, timeStartC, wave.oteHigh, timeEndC, wave.oteLow);
   else
   {
      ObjectSetInteger(0, boxC, OBJPROP_TIME, 0, timeStartC);
      ObjectSetDouble(0, boxC, OBJPROP_PRICE, 0, wave.oteHigh);
      ObjectSetInteger(0, boxC, OBJPROP_TIME, 1, timeEndC);
      ObjectSetDouble(0, boxC, OBJPROP_PRICE, 1, wave.oteLow);
   }
   color oteBoxColor = isBull ? C'18,55,38' : C'55,20,25';
   ObjectSetInteger(0, boxC, OBJPROP_COLOR, oteBoxColor);
   ObjectSetInteger(0, boxC, OBJPROP_FILL, true);
   ObjectSetInteger(0, boxC, OBJPROP_BACK, true);

   string nameC = GUI_PREFIX + "ABCD_PT_C";
   datetime timeLabelC = wave.timeB + (PeriodSeconds(InpTimeframe) * 3);
   if(ObjectFind(0, nameC) < 0)
      ObjectCreate(0, nameC, OBJ_TEXT, 0, timeLabelC, wave.priceC);
   else
   {
      ObjectSetInteger(0, nameC, OBJPROP_TIME, 0, timeLabelC);
      ObjectSetDouble(0, nameC, OBJPROP_PRICE, 0, wave.priceC);
   }
   string cLabelTxt = isBull ? "🛒 [ โซน OTE ช้อนซื้อ 61.8%-78.6% ]" : "🛒 [ โซน OTE ดักขาย 61.8%-78.6% ]";
   ObjectSetString(0, nameC, OBJPROP_TEXT, cLabelTxt);
   ObjectSetString(0, nameC, OBJPROP_FONT, "Segoe UI Bold");
   ObjectSetInteger(0, nameC, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, nameC, OBJPROP_COLOR, colC);
   ObjectSetInteger(0, nameC, OBJPROP_ANCHOR, isBull ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, nameC, OBJPROP_BACK, false);

   // 4. Point D - Extension Target Line & Label
   string lineD = GUI_PREFIX + "ABCD_LINE_D";
   if(ObjectFind(0, lineD) < 0)
      ObjectCreate(0, lineD, OBJ_TREND, 0, wave.timeB, wave.priceD, timeEndC, wave.priceD);
   else
   {
      ObjectSetInteger(0, lineD, OBJPROP_TIME, 0, wave.timeB);
      ObjectSetDouble(0, lineD, OBJPROP_PRICE, 0, wave.priceD);
      ObjectSetInteger(0, lineD, OBJPROP_TIME, 1, timeEndC);
      ObjectSetDouble(0, lineD, OBJPROP_PRICE, 1, wave.priceD);
   }
   ObjectSetInteger(0, lineD, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, lineD, OBJPROP_STYLE, STYLE_DASHDOT);
   ObjectSetInteger(0, lineD, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lineD, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, lineD, OBJPROP_BACK, false);

   string nameD = GUI_PREFIX + "ABCD_PT_D";
   datetime timeD = timeEndC;
   ENUM_ANCHOR_POINT anchorD = isBull ? ANCHOR_LOWER : ANCHOR_UPPER;

   // Anti-collision with Plan TP2: if active Plan TP2 is near Point D,
   // place Point D earlier on the projection line (near Point B) to eliminate overlap with the TP2 badge!
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   double pMax = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double pMin = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   double pxPrice = (chartH > 0 && pMax > pMin) ? ((pMax - pMin) / (double)chartH) : (wave.priceD * 0.00004);
   double planCollisionDist = MathMax(pxPrice * 22.0, 35 * _Point);

   if(g_PlanTP2 > 0 && MathAbs(wave.priceD - g_PlanTP2) < planCollisionDist)
   {
      timeD = wave.timeB + (PeriodSeconds(InpTimeframe) * 6);
      anchorD = isBull ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER;
   }

   if(ObjectFind(0, nameD) < 0)
      ObjectCreate(0, nameD, OBJ_TEXT, 0, timeD, wave.priceD);
   else
   {
      ObjectSetInteger(0, nameD, OBJPROP_TIME, 0, timeD);
      ObjectSetDouble(0, nameD, OBJPROP_PRICE, 0, wave.priceD);
   }
   string dLabelTxt = (_Digits > 2) ? StringFormat("🚀 [ D: เป้าขยาย 161.8%% • %.1f ]", wave.priceD) : StringFormat("🚀 [ D: เป้าขยาย 161.8%% • %.2f ]", wave.priceD);
   ObjectSetString(0, nameD, OBJPROP_TEXT, dLabelTxt);
   ObjectSetString(0, nameD, OBJPROP_FONT, "Segoe UI Black");
   ObjectSetInteger(0, nameD, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, nameD, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, nameD, OBJPROP_ANCHOR, anchorD);
   ObjectSetInteger(0, nameD, OBJPROP_BACK, false);

    // 5. Trap Warning Tags on Chart
   double trapOffset = MathMax(60.0, (double)g_AssetProfile.fallbackSL * 0.10) * _Point;
   string trapBslName = GUI_PREFIX + "ABCD_TRAP_BSL";
   if(g_LQ_Radar.bslSwept)
   {
      double trapPrice = (wave.priceB > 0) ? wave.priceB + trapOffset : (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trapOffset);
      if(ObjectFind(0, trapBslName) < 0)
         ObjectCreate(0, trapBslName, OBJ_TEXT, 0, TimeCurrent(), trapPrice);
      else
      {
         ObjectSetInteger(0, trapBslName, OBJPROP_TIME, 0, TimeCurrent());
         ObjectSetDouble(0, trapBslName, OBJPROP_PRICE, 0, trapPrice);
      }
      ObjectSetString(0, trapBslName, OBJPROP_TEXT, "⚠️ กับดักกลับตัวขาลงหลอก! (Bull Trap / BSL Sweep ล้าง SL)");
      ObjectSetString(0, trapBslName, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, trapBslName, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, trapBslName, OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, trapBslName, OBJPROP_ANCHOR, ANCHOR_LOWER);
      ObjectSetInteger(0, trapBslName, OBJPROP_BACK, false);
   }
   else
   {
      ObjectDelete(0, trapBslName);
   }

   string trapSslName = GUI_PREFIX + "ABCD_TRAP_SSL";
   if(g_LQ_Radar.sslSwept)
   {
      double trapPrice = (wave.priceA > 0) ? wave.priceA - trapOffset : (SymbolInfoDouble(_Symbol, SYMBOL_BID) - trapOffset);
      if(ObjectFind(0, trapSslName) < 0)
         ObjectCreate(0, trapSslName, OBJ_TEXT, 0, TimeCurrent(), trapPrice);
      else
      {
         ObjectSetInteger(0, trapSslName, OBJPROP_TIME, 0, TimeCurrent());
         ObjectSetDouble(0, trapSslName, OBJPROP_PRICE, 0, trapPrice);
      }
      ObjectSetString(0, trapSslName, OBJPROP_TEXT, "⚠️ กับดักกลับตัวลงหลอก! (Bear Trap / SSL Sweep ล้าง SL)");
      ObjectSetString(0, trapSslName, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, trapSslName, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, trapSslName, OBJPROP_COLOR, clrDeepSkyBlue);
      ObjectSetInteger(0, trapSslName, OBJPROP_ANCHOR, ANCHOR_UPPER);
      ObjectSetInteger(0, trapSslName, OBJPROP_BACK, false);
   }
   else
   {
      ObjectDelete(0, trapSslName);
   }
}

void DrawStructureLine(string name, string desc, double price, color col)
{
   string objName = GUI_PREFIX + "VIS_" + name;
   datetime time1 = TimeCurrent() - (PeriodSeconds(InpTimeframe) * 35);
   datetime time2 = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 20);

   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_TREND, 0, time1, price, time2, price);
   else
   {
      ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price);
      ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price);
   }
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
   ObjectSetString(0, objName, OBJPROP_TEXT, " " + desc + " ");
}

void DrawSwingText(string name, datetime t, double price, string text, color col)
{
   string objName = GUI_PREFIX + "VIS_" + name;

   // Multi-Timeframe and Asset-Aware adaptive vertical offset
   double offset = 50 * _Point;
   ENUM_TIMEFRAMES currentTF = (InpTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTimeframe);
   double tfMult = 1.0;
   switch(currentTF)
   {
      case PERIOD_M1:  offset = 35 * _Point;  tfMult = 0.5; break;
      case PERIOD_M5:  offset = 65 * _Point;  tfMult = 0.8; break;
      case PERIOD_M15: offset = 110 * _Point; tfMult = 1.0; break;
      case PERIOD_M30: offset = 160 * _Point; tfMult = 1.3; break;
      case PERIOD_H1:  offset = 260 * _Point; tfMult = 1.8; break;
      case PERIOD_H4:  offset = 550 * _Point; tfMult = 2.8; break;
      case PERIOD_D1:  offset = 1200 * _Point; tfMult = 4.5; break;
      default:         offset = 70 * _Point;  tfMult = 1.0; break;
   }

   // Dynamic asset volatility scaling (Prevents label from sitting inside candles on Crypto or high ATR assets)
   double dynamicMinSwing = g_AssetProfile.minSwing * _Point;
   offset = MathMax(offset, dynamicMinSwing * 0.12 * tfMult);

   if(InpUseDynamicATR && m_hATR != INVALID_HANDLE)
   {
      double atr[1];
      if(CopyBuffer(m_hATR, 0, 0, 1, atr) > 0)
         offset = MathMax(offset, atr[0] * 0.45);
   }

   // Robust High vs Low swing detection: matches "HH", "LH", "HH • Weak High", "LH • Strong High", or name "_H"
   bool isHigh = (StringFind(text, "H •") >= 0 || StringFind(text, "High") >= 0 || text == "HH" || text == "LH" || StringFind(name, "_H") >= 0);
   double drawPrice = isHigh ? (price + offset) : (price - offset);

   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_TEXT, 0, t, drawPrice);
   else
   {
      ObjectSetInteger(0, objName, OBJPROP_TIME, t);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, drawPrice);
   }
   ObjectSetString(0, objName, OBJPROP_TEXT, " " + text + " ");
   ObjectSetString(0, objName, OBJPROP_FONT, "Segoe UI Black");
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
}

void DrawFiboLine(string name, string desc, double price, color col, ENUM_LINE_STYLE style, int width=1)
{
   string lineName = GUI_PREFIX + "VIS_" + name;
   string textName = GUI_PREFIX + "VIS_TXT_" + name;

   int tfSec = PeriodSeconds(GetCurrentExecutionTF());
   datetime time1 = TimeCurrent() - (tfSec * 45);
   datetime time2 = TimeCurrent() + (tfSec * 6);

   // 1. Clean Horizontal Trendline
   if(ObjectFind(0, lineName) < 0)
      ObjectCreate(0, lineName, OBJ_TREND, 0, time1, price, time2, price);
   else
   {
      ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, time1);
      ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, price);
      ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, time2);
      ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, price);
   }
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
   ObjectSetInteger(0, lineName, OBJPROP_ZORDER, 0);
   ObjectSetString(0, lineName, OBJPROP_TEXT, "");

   // 2. Right-Side Clean Floating Badge (Positioned on the right margin with dynamic asset-scaled offset)
   datetime textTime = TimeCurrent() + (tfSec * 9);
   
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   double pMax = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double pMin = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   double pxPrice = (chartH > 0 && pMax > pMin) ? ((pMax - pMin) / (double)chartH) : (price * 0.00004);

   double tfOffset = MathMax(pxPrice * 3.0, (g_AssetProfile.minSwing * 0.035 * _Point));
   ENUM_ANCHOR_POINT fiboAnchor = ANCHOR_LEFT_LOWER;
   double labelPrice = price + tfOffset;

   // Universal Anti-Collision with Active Trading Plan (Entry, SL, TP1, TP2, TP3):
   // If ANY Fibo line is within 22 vertical pixels of an active Plan target,
   // flip the Fibo badge to the LEFT side of the current candle (-14 bars) with ANCHOR_RIGHT_LOWER.
   // This guarantees 100% separation: Fibo label on the left, Plan target label on the right!
   double planCollisionDist = MathMax(pxPrice * 22.0, 35 * _Point);
   bool collidesWithPlan = false;
   if(g_PlanDirection != 0)
   {
      if(g_PlanEntry > 0 && MathAbs(price - g_PlanEntry) < planCollisionDist) collidesWithPlan = true;
      else if(g_PlanSL > 0 && MathAbs(price - g_PlanSL) < planCollisionDist) collidesWithPlan = true;
      else if(g_PlanTP1 > 0 && MathAbs(price - g_PlanTP1) < planCollisionDist) collidesWithPlan = true;
      else if(g_PlanTP2 > 0 && MathAbs(price - g_PlanTP2) < planCollisionDist) collidesWithPlan = true;
      else if(g_PlanTP3 > 0 && MathAbs(price - g_PlanTP3) < planCollisionDist) collidesWithPlan = true;
   }

   if(collidesWithPlan)
   {
      textTime = TimeCurrent() - (tfSec * 14);
      labelPrice = price + tfOffset;
      fiboAnchor = ANCHOR_RIGHT_LOWER;
   }
   else
   {
      // Universal Pixel-Based Anti-Collision with Institutional SSL / BSL Badges:
      // If ANY Fibo line is within 28 vertical pixels of active SSL or BSL,
      // shift the Fibo badge further right (+24 bars) so it clears the SSL/BSL badge completely!
      double collisionDist = MathMax(pxPrice * 28.0, 50 * _Point);
      if(g_LQ_Radar.ssl.isValid && MathAbs(price - g_LQ_Radar.ssl.price) < collisionDist)
      {
         textTime = TimeCurrent() + (tfSec * 24);
         labelPrice = price - (pxPrice * 4.0);
         fiboAnchor = ANCHOR_LEFT_UPPER;
      }
      else if(g_LQ_Radar.bsl.isValid && MathAbs(price - g_LQ_Radar.bsl.price) < collisionDist)
      {
         textTime = TimeCurrent() + (tfSec * 24);
         labelPrice = price + (pxPrice * 4.0);
         fiboAnchor = ANCHOR_LEFT_LOWER;
      }
   }

   if(ObjectFind(0, textName) < 0)
      ObjectCreate(0, textName, OBJ_TEXT, 0, textTime, labelPrice);
   else
   {
      ObjectSetInteger(0, textName, OBJPROP_TIME, textTime);
      ObjectSetDouble(0, textName, OBJPROP_PRICE, labelPrice);
   }
   ObjectSetString(0, textName, OBJPROP_TEXT, "  " + desc);
   ObjectSetString(0, textName, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, textName, OBJPROP_ANCHOR, fiboAnchor);
   ObjectSetInteger(0, textName, OBJPROP_BACK, true);
   ObjectSetInteger(0, textName, OBJPROP_ZORDER, 0);
}

void DrawPlanLine(string name, string desc, double price, color col, ENUM_LINE_STYLE style, int width=2)
{
   string lineName = GUI_PREFIX + "VIS_PLAN_" + name;
   string textName = GUI_PREFIX + "VIS_TXT_PLAN_" + name;

   datetime time1 = TimeCurrent() - (PeriodSeconds(InpTimeframe) * 45);
   datetime time2 = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 6);

   // 1. Clean Horizontal Plan Line (Foreground Layer)
   if(ObjectFind(0, lineName) < 0)
      ObjectCreate(0, lineName, OBJ_TREND, 0, time1, price, time2, price);
   else
   {
      ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, time1);
      ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, price);
      ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, time2);
      ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, price);
   }
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lineName, OBJPROP_ZORDER, 2);
   ObjectSetString(0, lineName, OBJPROP_TEXT, "");

   // 2. Right-Side Plan Floating Badge (Foreground High-Contrast Segoe UI Bold)
   datetime textTime = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 14);
   
   double tfOffset = MathMax(20 * _Point, (g_AssetProfile.minSwing * 0.035 * _Point));
   double labelPrice = price + tfOffset;

   if(ObjectFind(0, textName) < 0)
      ObjectCreate(0, textName, OBJ_TEXT, 0, textTime, labelPrice);
   else
   {
      ObjectSetInteger(0, textName, OBJPROP_TIME, textTime);
      ObjectSetDouble(0, textName, OBJPROP_PRICE, labelPrice);
   }
   ObjectSetString(0, textName, OBJPROP_TEXT, "  " + desc);
   ObjectSetString(0, textName, OBJPROP_FONT, "Segoe UI Bold");
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, textName, OBJPROP_BACK, false);
   ObjectSetInteger(0, textName, OBJPROP_ZORDER, 2);
}

void RemoveActivePlanVisuals()
{
   ObjectDelete(0, GUI_PREFIX + "VIS_PLAN_ENTRY");
   ObjectDelete(0, GUI_PREFIX + "VIS_TXT_PLAN_ENTRY");
   ObjectDelete(0, GUI_PREFIX + "VIS_PLAN_SL");
   ObjectDelete(0, GUI_PREFIX + "VIS_TXT_PLAN_SL");
   ObjectDelete(0, GUI_PREFIX + "VIS_PLAN_TP1");
   ObjectDelete(0, GUI_PREFIX + "VIS_TXT_PLAN_TP1");
   ObjectDelete(0, GUI_PREFIX + "VIS_PLAN_TP2");
   ObjectDelete(0, GUI_PREFIX + "VIS_TXT_PLAN_TP2");
   ObjectDelete(0, GUI_PREFIX + "VIS_PLAN_TP3");
   ObjectDelete(0, GUI_PREFIX + "VIS_TXT_PLAN_TP3");
}

//+------------------------------------------------------------------+
//| SMC INSTITUTIONAL VISUAL SUITE ENGINES                           |
//+------------------------------------------------------------------+
void DetectStructureBreaks(const SSwingPoint &rawSwings[], int count, const MqlRates &rates[], int totalBars)
{
   ArrayResize(g_SMC_BOS_Lines, 0);
   if(count < 2 || totalBars < 10)
      return;

   int maxScan = MathMin(16, count - 1);
   for(int i = 0; i < maxScan; i++)
   {
      double swingPrice = rawSwings[i].price;
      datetime swingTime = rawSwings[i].time;
      int swingBar = rawSwings[i].barIndex;
      int swingType = rawSwings[i].type; // 1 = High, -1 = Low

      for(int b = swingBar - 1; b >= 0; b--)
      {
         bool isBroken = (swingType == 1 && rates[b].close > swingPrice) ||
                         (swingType == -1 && rates[b].close < swingPrice);

         if(isBroken)
         {
            int n = ArraySize(g_SMC_BOS_Lines);
            ArrayResize(g_SMC_BOS_Lines, n + 1);
            g_SMC_BOS_Lines[n].timeStart = swingTime;
            g_SMC_BOS_Lines[n].timeEnd   = rates[b].time;
            g_SMC_BOS_Lines[n].price     = swingPrice;
            
            if(swingType == 1)
            {
               g_SMC_BOS_Lines[n].tag = (rawSwings[i].labelType == SWING_LH) ? "CHoCH" : "BOS";
               g_SMC_BOS_Lines[n].col = (g_SMC_BOS_Lines[n].tag == "CHoCH") ? clrAqua : clrLime;
            }
            else
            {
               g_SMC_BOS_Lines[n].tag = (rawSwings[i].labelType == SWING_HL) ? "CHoCH" : "BOS";
               g_SMC_BOS_Lines[n].col = (g_SMC_BOS_Lines[n].tag == "CHoCH") ? clrDeepPink : clrOrangeRed;
            }
            g_SMC_BOS_Lines[n].isActive = true;
            break;
         }
      }
      if(ArraySize(g_SMC_BOS_Lines) >= 7)
         break;
   }
}

void DetectLiquidityPools(const SSwingPoint &rawSwings[], int count)
{
   ArrayResize(g_SMC_LiquidityPools, 0);
   if(count < 3)
      return;

   ENUM_TIMEFRAMES currentTF = (InpTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTimeframe);
   double tol = 30 * _Point;
   if(currentTF == PERIOD_M1) tol = 18 * _Point;
   else if(currentTF >= PERIOD_H1) tol = 80 * _Point;

   for(int i = 0; i < MathMin(8, count - 1); i++)
   {
      if(rawSwings[i].type == 1)
      {
         for(int j = i + 1; j < MathMin(12, count); j++)
         {
            if(rawSwings[j].type == 1)
            {
               if(MathAbs(rawSwings[i].price - rawSwings[j].price) <= tol)
               {
                  int n = ArraySize(g_SMC_LiquidityPools);
                  ArrayResize(g_SMC_LiquidityPools, n + 1);
                  g_SMC_LiquidityPools[n].timeStart = rawSwings[j].time;
                  g_SMC_LiquidityPools[n].timeEnd   = rawSwings[i].time;
                  g_SMC_LiquidityPools[n].price     = (rawSwings[i].price + rawSwings[j].price) / 2.0;
                  g_SMC_LiquidityPools[n].tag       = "EQH";
                  g_SMC_LiquidityPools[n].col       = clrGold;
                  g_SMC_LiquidityPools[n].isActive  = true;
                  break;
               }
            }
         }
      }
      else if(rawSwings[i].type == -1)
      {
         for(int j = i + 1; j < MathMin(12, count); j++)
         {
            if(rawSwings[j].type == -1)
            {
               if(MathAbs(rawSwings[i].price - rawSwings[j].price) <= tol)
               {
                  int n = ArraySize(g_SMC_LiquidityPools);
                  ArrayResize(g_SMC_LiquidityPools, n + 1);
                  g_SMC_LiquidityPools[n].timeStart = rawSwings[j].time;
                  g_SMC_LiquidityPools[n].timeEnd   = rawSwings[i].time;
                  g_SMC_LiquidityPools[n].price     = (rawSwings[i].price + rawSwings[j].price) / 2.0;
                  g_SMC_LiquidityPools[n].tag       = "EQL";
                  g_SMC_LiquidityPools[n].col       = clrDeepSkyBlue;
                  g_SMC_LiquidityPools[n].isActive  = true;
                  break;
               }
            }
         }
      }
      if(ArraySize(g_SMC_LiquidityPools) >= 4)
         break;
   }
}


void DetectMTFOrderBlocks()
{
   ArrayResize(g_SMC_MTF_Zones, 0);
   ENUM_TIMEFRAMES tfs[] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1};
   string tfNames[] = {"M5", "M15", "M30", "H1", "H4", "D1", "W1"};
   int numTFs = 7;

   color demandCols[] = {
      C'0,140,255',  // M5: Dodger Blue
      C'0,110,230',  // M15: Royal Blue
      C'0,85,200',   // M30: Medium Blue
      C'15,65,180',  // H1: Deep Blue
      C'30,50,160',  // H4: Slate Blue
      C'45,35,140',  // D1: Navy Indigo
      C'60,25,120'   // W1: Royal Indigo
   };

   color supplyCols[] = {
      C'235,55,115', // M5: Deep Pink
      C'215,40,95',  // M15: Crimson Pink
      C'195,30,80',  // M30: Dark Crimson
      C'175,25,65',  // H1: Ruby Red
      C'155,20,55',  // H4: Maroon Red
      C'135,15,45',  // D1: Dark Maroon
      C'115,10,35'   // W1: Deep Maroon
   };

   ENUM_TIMEFRAMES activeTF = GetCurrentExecutionTF();
   int activeRank = GetTFRank(activeTF);
   int tfSec = PeriodSeconds(activeTF);

   double maxZoneHeight = (g_AssetProfile.assetType == ASSET_CRYPTO) ? (1500.0 * _Point) :
                          (g_AssetProfile.assetType == ASSET_GOLD   ? (600.0  * _Point) : (180.0 * _Point));

   int effectiveNumTFs = (activeRank <= 5) ? 6 : numTFs;

   for(int t = 0; t < effectiveNumTFs; t++)
   {
      // Only scan from active chart timeframe up to D1!
      if(GetTFRank(tfs[t]) < activeRank)
         continue;

      MqlRates mtfRates[];
      ArraySetAsSeries(mtfRates, true);
      int copied = CopyRates(_Symbol, tfs[t], 0, 30, mtfRates);
      if(copied < 10)
         continue;

      int maxScan = MathMin(20, copied - 3);

      // 1. Bullish Demand Order Block (Natural Candle Range)
      for(int i = 2; i < maxScan; i++)
      {
         if(mtfRates[i].close < mtfRates[i].open &&
            mtfRates[i-1].close > mtfRates[i-1].open &&
            mtfRates[i-2].close > mtfRates[i-2].open &&
            mtfRates[i-2].close > mtfRates[i].high)
         {
            double top = mtfRates[i].high;
            double btm = mtfRates[i].low;
            if((top - btm) > maxZoneHeight)
               btm = top - maxZoneHeight;

            if(m_symbol.Bid() >= top)
            {
               bool merged = false;
               for(int k = 0; k < ArraySize(g_SMC_MTF_Zones); k++)
               {
                  if(g_SMC_MTF_Zones[k].direction == 1 &&
                     MathAbs(g_SMC_MTF_Zones[k].topPrice - top) <= (35 * _Point) &&
                     MathAbs(g_SMC_MTF_Zones[k].bottomPrice - btm) <= (35 * _Point))
                  {
                     if(StringFind(g_SMC_MTF_Zones[k].tfName, tfNames[t]) < 0)
                        g_SMC_MTF_Zones[k].tfName += " • " + tfNames[t];
                     merged = true;
                     break;
                  }
               }

               if(!merged)
               {
                  int z = ArraySize(g_SMC_MTF_Zones);
                  ArrayResize(g_SMC_MTF_Zones, z + 1);
                  g_SMC_MTF_Zones[z].timeStart   = mtfRates[i].time;
                  g_SMC_MTF_Zones[z].timeEnd     = TimeCurrent() + (tfSec * 25);
                  g_SMC_MTF_Zones[z].topPrice    = top;
                  g_SMC_MTF_Zones[z].bottomPrice = btm;
                  g_SMC_MTF_Zones[z].direction   = 1;
                  g_SMC_MTF_Zones[z].tfName      = "Demand " + tfNames[t];
                  g_SMC_MTF_Zones[z].boxColor    = demandCols[t];
                  g_SMC_MTF_Zones[z].isActive    = true;
               }
               break;
            }
         }
      }

      // 2. Bearish Supply Order Block (Natural Candle Range)
      for(int i = 2; i < maxScan; i++)
      {
         if(mtfRates[i].close > mtfRates[i].open &&
            mtfRates[i-1].close < mtfRates[i-1].open &&
            mtfRates[i-2].close < mtfRates[i-2].open &&
            mtfRates[i-2].close < mtfRates[i].low)
         {
            double top = mtfRates[i].high;
            double btm = mtfRates[i].low;
            if((top - btm) > maxZoneHeight)
               top = btm + maxZoneHeight;

            if(m_symbol.Ask() <= btm)
            {
               bool merged = false;
               for(int k = 0; k < ArraySize(g_SMC_MTF_Zones); k++)
               {
                  if(g_SMC_MTF_Zones[k].direction == -1 &&
                     MathAbs(g_SMC_MTF_Zones[k].topPrice - top) <= (35 * _Point) &&
                     MathAbs(g_SMC_MTF_Zones[k].bottomPrice - btm) <= (35 * _Point))
                  {
                     if(StringFind(g_SMC_MTF_Zones[k].tfName, tfNames[t]) < 0)
                        g_SMC_MTF_Zones[k].tfName += " • " + tfNames[t];
                     merged = true;
                     break;
                  }
               }

               if(!merged)
               {
                  int z = ArraySize(g_SMC_MTF_Zones);
                  ArrayResize(g_SMC_MTF_Zones, z + 1);
                  g_SMC_MTF_Zones[z].timeStart   = mtfRates[i].time;
                  g_SMC_MTF_Zones[z].timeEnd     = TimeCurrent() + (tfSec * 25);
                  g_SMC_MTF_Zones[z].topPrice    = top;
                  g_SMC_MTF_Zones[z].bottomPrice = btm;
                  g_SMC_MTF_Zones[z].direction   = -1;
                  g_SMC_MTF_Zones[z].tfName      = "Supply " + tfNames[t];
                  g_SMC_MTF_Zones[z].boxColor    = supplyCols[t];
                  g_SMC_MTF_Zones[z].isActive    = true;
               }
               break;
            }
         }
      }
   }
}

void CalculateSessionPOC()
{
   datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0);
   MqlRates sessionRates[];
   ArraySetAsSeries(sessionRates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, startOfDay, TimeCurrent(), sessionRates);
   if(copied < 10)
      return;

   double highestPrice = sessionRates[0].high;
   double lowestPrice  = sessionRates[0].low;
   for(int i = 0; i < copied; i++)
   {
      if(sessionRates[i].high > highestPrice) highestPrice = sessionRates[i].high;
      if(sessionRates[i].low < lowestPrice)   lowestPrice  = sessionRates[i].low;
   }

   double range = highestPrice - lowestPrice;
   if(range <= 0) return;

   int bins = 20;
   double binSize = range / (double)bins;
   long volumeInBin[];
   ArrayResize(volumeInBin, bins);
   ArrayInitialize(volumeInBin, 0);

   for(int i = 0; i < copied; i++)
   {
      double mid = (sessionRates[i].high + sessionRates[i].low) / 2.0;
      int binIdx = (int)((mid - lowestPrice) / binSize);
      if(binIdx >= 0 && binIdx < bins)
         volumeInBin[binIdx] += sessionRates[i].tick_volume;
   }

   long maxVol = 0;
   int maxBin = 0;
   long minVol = 99999999;
   int minBin = 0;

   for(int b = 0; b < bins; b++)
   {
      if(volumeInBin[b] > maxVol)
      {
         maxVol = volumeInBin[b];
         maxBin = b;
      }
      if(volumeInBin[b] < minVol && volumeInBin[b] > 0)
      {
         minVol = volumeInBin[b];
         minBin = b;
      }
   }

   g_SessionPOC = lowestPrice + (maxBin * binSize) + (binSize / 2.0);
   g_SessionLVN = lowestPrice + (minBin * binSize) + (binSize / 2.0);
}

void DrawSMCVisuals()
{
   int tfSec = PeriodSeconds(GetCurrentExecutionTF());

   // 1. Draw BOS & CHoCH Lines (Latest 7 Swings)
   if(InpShowSMC_BOS)
   {
      for(int i = ArraySize(g_SMC_BOS_Lines); i < 15; i++)
      {
         ObjectDelete(0, GUI_PREFIX + "SMC_BOS_L_" + IntegerToString(i));
         ObjectDelete(0, GUI_PREFIX + "SMC_BOS_T_" + IntegerToString(i));
      }

      for(int i = 0; i < ArraySize(g_SMC_BOS_Lines); i++)
      {
         if(!g_SMC_BOS_Lines[i].isActive) continue;
         string lineName = GUI_PREFIX + "SMC_BOS_L_" + IntegerToString(i);
         string textName = GUI_PREFIX + "SMC_BOS_T_" + IntegerToString(i);

         if(ObjectFind(0, lineName) < 0)
            ObjectCreate(0, lineName, OBJ_TREND, 0, g_SMC_BOS_Lines[i].timeStart, g_SMC_BOS_Lines[i].price, g_SMC_BOS_Lines[i].timeEnd, g_SMC_BOS_Lines[i].price);
         else
         {
            ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, g_SMC_BOS_Lines[i].timeStart);
            ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, g_SMC_BOS_Lines[i].price);
            ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, g_SMC_BOS_Lines[i].timeEnd);
            ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, g_SMC_BOS_Lines[i].price);
         }
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, g_SMC_BOS_Lines[i].col);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
         ObjectSetInteger(0, lineName, OBJPROP_ZORDER, 0);

         datetime midTime = g_SMC_BOS_Lines[i].timeStart + (datetime)((g_SMC_BOS_Lines[i].timeEnd - g_SMC_BOS_Lines[i].timeStart) / 2);
         if(ObjectFind(0, textName) < 0)
            ObjectCreate(0, textName, OBJ_TEXT, 0, midTime, g_SMC_BOS_Lines[i].price);
         else
         {
            ObjectSetInteger(0, textName, OBJPROP_TIME, midTime);
            ObjectSetDouble(0, textName, OBJPROP_PRICE, g_SMC_BOS_Lines[i].price);
         }
         string badgeText = (g_SMC_BOS_Lines[i].tag == "CHoCH") ? " CHoCH 🔄 " : " BOS ➔ ";
         ObjectSetString(0, textName, OBJPROP_TEXT, badgeText);
         ObjectSetString(0, textName, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, textName, OBJPROP_COLOR, g_SMC_BOS_Lines[i].col);
         ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, textName, OBJPROP_BACK, true);
         ObjectSetInteger(0, textName, OBJPROP_ZORDER, 0);
      }
   }

   // 2. Draw Liquidity Pools (EQH / EQL)
   if(InpShowSMC_Liquidity)
   {
      for(int i = 0; i < ArraySize(g_SMC_LiquidityPools); i++)
      {
         if(!g_SMC_LiquidityPools[i].isActive) continue;

         // If Institutional LQ Radar is active, skip pools that are already tracked by BSL or SSL to avoid duplicate lines!
         if(InpShowSMC_BSL_SSL)
         {
            if(g_LQ_Radar.bsl.isValid && MathAbs(g_SMC_LiquidityPools[i].price - g_LQ_Radar.bsl.price) < (g_AssetProfile.minSwing * 0.25 * _Point))
               continue;
            if(g_LQ_Radar.ssl.isValid && MathAbs(g_SMC_LiquidityPools[i].price - g_LQ_Radar.ssl.price) < (g_AssetProfile.minSwing * 0.25 * _Point))
               continue;
         }

         string lineName = GUI_PREFIX + "SMC_LIQ_L_" + IntegerToString(i);
         string textName = GUI_PREFIX + "SMC_LIQ_T_" + IntegerToString(i);

         if(ObjectFind(0, lineName) < 0)
            ObjectCreate(0, lineName, OBJ_TREND, 0, g_SMC_LiquidityPools[i].timeStart, g_SMC_LiquidityPools[i].price, g_SMC_LiquidityPools[i].timeEnd, g_SMC_LiquidityPools[i].price);
         else
         {
            ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, g_SMC_LiquidityPools[i].timeStart);
            ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, g_SMC_LiquidityPools[i].price);
            ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, g_SMC_LiquidityPools[i].timeEnd);
            ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, g_SMC_LiquidityPools[i].price);
         }
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, g_SMC_LiquidityPools[i].col);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);

         datetime tagTime = g_SMC_LiquidityPools[i].timeEnd;
         if(ObjectFind(0, textName) < 0)
            ObjectCreate(0, textName, OBJ_TEXT, 0, tagTime, g_SMC_LiquidityPools[i].price);
         else
         {
            ObjectSetInteger(0, textName, OBJPROP_TIME, tagTime);
            ObjectSetDouble(0, textName, OBJPROP_PRICE, g_SMC_LiquidityPools[i].price);
         }
         ObjectSetString(0, textName, OBJPROP_TEXT, " " + g_SMC_LiquidityPools[i].tag + " 🎯");
         ObjectSetString(0, textName, OBJPROP_FONT, "Segoe UI Bold");
         ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, textName, OBJPROP_COLOR, g_SMC_LiquidityPools[i].col);
         ObjectSetInteger(0, textName, OBJPROP_ANCHOR, (g_SMC_LiquidityPools[i].tag == "EQH" ? ANCHOR_LOWER : ANCHOR_UPPER));
      }
   }

   // 3. Draw Multi-Timeframe Demand & Supply Zones (Clean & Non-overlapping)
   if(InpShowSMC_MTFZones)
   {
      for(int i = 0; i < ArraySize(g_SMC_MTF_Zones); i++)
      {
         if(!g_SMC_MTF_Zones[i].isActive) continue;
         string boxName = GUI_PREFIX + "SMC_MTF_B_" + IntegerToString(i);
         string lblName = GUI_PREFIX + "SMC_MTF_L_" + IntegerToString(i);

         datetime t2 = TimeCurrent() + (tfSec * 25);

         if(ObjectFind(0, boxName) < 0)
            ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, g_SMC_MTF_Zones[i].timeStart, g_SMC_MTF_Zones[i].topPrice, t2, g_SMC_MTF_Zones[i].bottomPrice);
         else
         {
            ObjectSetInteger(0, boxName, OBJPROP_TIME, 0, g_SMC_MTF_Zones[i].timeStart);
            ObjectSetDouble(0, boxName, OBJPROP_PRICE, 0, g_SMC_MTF_Zones[i].topPrice);
            ObjectSetInteger(0, boxName, OBJPROP_TIME, 1, t2);
            ObjectSetDouble(0, boxName, OBJPROP_PRICE, 1, g_SMC_MTF_Zones[i].bottomPrice);
         }
         ObjectSetInteger(0, boxName, OBJPROP_COLOR, g_SMC_MTF_Zones[i].boxColor);
         ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
         ObjectSetInteger(0, boxName, OBJPROP_BACK, true);

         // Center text vertically inside zone box, placed with horizontal stagger so multiple overlapping zones never clash
         double labelPrice  = (g_SMC_MTF_Zones[i].topPrice + g_SMC_MTF_Zones[i].bottomPrice) / 2.0;
         datetime safeRight = TimeCurrent() - (tfSec * (14 + (i * 4)));
         datetime labelTime = MathMax(g_SMC_MTF_Zones[i].timeStart + (tfSec * 2), safeRight);

         if(ObjectFind(0, lblName) < 0)
            ObjectCreate(0, lblName, OBJ_TEXT, 0, labelTime, labelPrice);
         else
         {
            ObjectSetInteger(0, lblName, OBJPROP_TIME, labelTime);
            ObjectSetDouble(0, lblName, OBJPROP_PRICE, labelPrice);
         }
         ObjectSetString(0, lblName, OBJPROP_TEXT, " " + g_SMC_MTF_Zones[i].tfName + " ");
         ObjectSetString(0, lblName, OBJPROP_FONT, "Segoe UI Bold");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
   }

   // 4. Draw Session Point of Control (POC) & Low Volume Node (LVN) with Collision-Free Inner Right Stagger
   if(InpShowSMC_POC)
   {
      if(g_SessionPOC > 0)
      {
         string pocLine = GUI_PREFIX + "SMC_POC_L";
         string pocLbl  = GUI_PREFIX + "SMC_POC_T";
         datetime t1 = iTime(_Symbol, PERIOD_D1, 0);
         datetime t2 = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 14);

         if(ObjectFind(0, pocLine) < 0)
            ObjectCreate(0, pocLine, OBJ_TREND, 0, t1, g_SessionPOC, t2, g_SessionPOC);
         else
         {
            ObjectSetInteger(0, pocLine, OBJPROP_TIME, 0, t1);
            ObjectSetDouble(0, pocLine, OBJPROP_PRICE, 0, g_SessionPOC);
            ObjectSetInteger(0, pocLine, OBJPROP_TIME, 1, t2);
            ObjectSetDouble(0, pocLine, OBJPROP_PRICE, 1, g_SessionPOC);
         }
         ObjectSetInteger(0, pocLine, OBJPROP_COLOR, clrGoldenrod);
         ObjectSetInteger(0, pocLine, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetInteger(0, pocLine, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, pocLine, OBJPROP_RAY_RIGHT, true);

         // Place POC label on the inner right (+3 bars) with ANCHOR_LEFT_UPPER to completely avoid colliding with Fibo levels (+12 bars)
         datetime pocTagTime = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 3);
         if(ObjectFind(0, pocLbl) < 0)
            ObjectCreate(0, pocLbl, OBJ_TEXT, 0, pocTagTime, g_SessionPOC);
         else
         {
            ObjectSetInteger(0, pocLbl, OBJPROP_TIME, pocTagTime);
            ObjectSetDouble(0, pocLbl, OBJPROP_PRICE, g_SessionPOC);
         }
         ObjectSetString(0, pocLbl, OBJPROP_TEXT, StringFormat("  [ POC • %.2f ]", g_SessionPOC));
         ObjectSetString(0, pocLbl, OBJPROP_FONT, "Segoe UI Bold");
         ObjectSetInteger(0, pocLbl, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, pocLbl, OBJPROP_COLOR, clrGoldenrod);
         ObjectSetInteger(0, pocLbl, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      }

      if(g_SessionLVN > 0)
      {
         string lvnLine = GUI_PREFIX + "SMC_LVN_L";
         string lvnLbl  = GUI_PREFIX + "SMC_LVN_T";
         datetime t1 = iTime(_Symbol, PERIOD_D1, 0);
         datetime t2 = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 18);

         if(ObjectFind(0, lvnLine) < 0)
            ObjectCreate(0, lvnLine, OBJ_TREND, 0, t1, g_SessionLVN, t2, g_SessionLVN);
         else
         {
            ObjectSetInteger(0, lvnLine, OBJPROP_TIME, 0, t1);
            ObjectSetDouble(0, lvnLine, OBJPROP_PRICE, 0, g_SessionLVN);
            ObjectSetInteger(0, lvnLine, OBJPROP_TIME, 1, t2);
            ObjectSetDouble(0, lvnLine, OBJPROP_PRICE, 1, g_SessionLVN);
         }
         ObjectSetInteger(0, lvnLine, OBJPROP_COLOR, clrCadetBlue);
         ObjectSetInteger(0, lvnLine, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, lvnLine, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lvnLine, OBJPROP_RAY_RIGHT, true);

         // Place LVN label on the inner right (+6 bars) with distinct bracket styling
         datetime lvnTagTime = TimeCurrent() + (PeriodSeconds(InpTimeframe) * 6);
         if(ObjectFind(0, lvnLbl) < 0)
            ObjectCreate(0, lvnLbl, OBJ_TEXT, 0, lvnTagTime, g_SessionLVN);
         else
         {
            ObjectSetInteger(0, lvnLbl, OBJPROP_TIME, lvnTagTime);
            ObjectSetDouble(0, lvnLbl, OBJPROP_PRICE, g_SessionLVN);
         }
         ObjectSetString(0, lvnLbl, OBJPROP_TEXT, StringFormat("  [ LVN • %.2f ]", g_SessionLVN));
         ObjectSetString(0, lvnLbl, OBJPROP_FONT, "Segoe UI Bold");
         ObjectSetInteger(0, lvnLbl, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lvnLbl, OBJPROP_COLOR, clrCadetBlue);
         ObjectSetInteger(0, lvnLbl, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      }
   }
}

//+------------------------------------------------------------------+
//| 14.2 SMC MULTI-TIMEFRAME BSL / SSL INSTITUTIONAL LIQUIDITY RADAR |
//+------------------------------------------------------------------+
string GetTFShortName(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "M15";
   }
}

string FormatLQDistance(int distPts, ENUM_ASSET_CLASS assetType, double point)
{
   if(assetType == ASSET_CRYPTO || MathAbs(distPts * point) >= 100.0)
   {
      double dollarDist = distPts * point;
      string sign = (dollarDist >= 0) ? "+" : "-";
      double absVal = MathAbs(dollarDist);
      if(absVal >= 100.0)
         return StringFormat("%s$%.0f", sign, absVal);
      else
         return StringFormat("%s$%.2f", sign, absVal);
   }
   return StringFormat("%s%d pts", (distPts > 0 ? "+" : ""), distPts);
}

void UpdateLiquidityRadar()
{
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   if(ask <= 0 || bid <= 0)
      return;

   // 1. Full Multi-TF Scanning throttled or on timeframe change
   static datetime lastLQFullScan = 0;
   static ENUM_TIMEFRAMES lastScanTF = PERIOD_CURRENT;
   datetime curTime = TimeCurrent();
   ENUM_TIMEFRAMES activeTF = GetCurrentExecutionTF();
   bool tfChanged = (activeTF != lastScanTF);
   if(tfChanged) lastScanTF = activeTF;

   double priceRef = (ask > 0) ? ask : 2500.0;
   bool needFullScan = tfChanged || (curTime - lastLQFullScan >= 2) || (g_LQ_Radar.bsl.price <= 0 || g_LQ_Radar.ssl.price <= 0);

   if(needFullScan)
   {
      lastLQFullScan = curTime;
      g_LQ_Radar.lastScanTime = curTime;

      int activeRank = GetTFRank(activeTF);

      // Candidate TFs: Prioritize active timeframe and immediate higher timeframes
      // Ensures the liquidity pools are directly relevant and visible on the active chart!
      const ENUM_TIMEFRAMES candidateTFs[6] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1};

      double bestBSL_Price = 0;
      double bestBSL_Rank  = -999.0;
      ENUM_TIMEFRAMES bestBSL_TF = activeTF;
      string bestBSL_Tag   = "";

      double bestSSL_Price = 0;
      double bestSSL_Rank  = -999.0;
      ENUM_TIMEFRAMES bestSSL_TF = activeTF;
      string bestSSL_Tag   = "";

      // -------------------------------------------------------------
      // A. Scan Active Timeframe and Higher Timeframes for Fractal Swings & EQH/EQL
      // -------------------------------------------------------------
      for(int t = 0; t < 6; t++)
      {
         ENUM_TIMEFRAMES tf = candidateTFs[t];
         if(GetTFRank(tf) < activeRank && tf != activeTF)
            continue;

         MqlRates tfRates[];
         ArraySetAsSeries(tfRates, true);
         int copied = CopyRates(_Symbol, tf, 0, 50, tfRates);
         if(copied < 10) continue;

         // Adaptive EQH/EQL tolerance calibrated by asset price (e.g. $0.50-$1.50 on Gold, $15-$40 on BTC)
         double tol = priceRef * (tf <= PERIOD_M5 ? 0.0002 : (tf <= PERIOD_M30 ? 0.00035 : 0.0007));
         tol = MathMax(tol, _Point * 20.0);

         for(int i = 2; i < copied - 2; i++)
         {
            // BSL Candidate (Fractal Swing High)
            if(tfRates[i].high >= tfRates[i-1].high && tfRates[i].high >= tfRates[i-2].high &&
               tfRates[i].high >= tfRates[i+1].high && tfRates[i].high >= tfRates[i+2].high)
            {
               double hPrice = tfRates[i].high;
               if(hPrice > ask + (10 * _Point))
               {
                  bool isEQH = false;
                  for(int j = i + 1; j < MathMin(copied - 2, i + 15); j++)
                  {
                     if(tfRates[j].high >= tfRates[j-1].high && tfRates[j].high >= tfRates[j+1].high)
                     {
                        if(MathAbs(hPrice - tfRates[j].high) <= tol)
                        {
                           isEQH = true;
                           hPrice = MathMax(hPrice, tfRates[j].high);
                           break;
                        }
                     }
                  }

                  double distDollar = hPrice - ask;
                  double distPct = (distDollar / priceRef) * 100.0;

                  // Structural Base Weight
                  double score = (isEQH ? 35.0 : 0.0);
                  if(tf == activeTF)
                     score += 45.0; // Primary active chart structure
                  else if(GetTFRank(tf) == activeRank + 1)
                     score += 35.0; // Immediate higher TF
                  else if(GetTFRank(tf) == activeRank + 2)
                     score += 25.0;
                  else
                     score += 15.0;

                  // Proximity Score (Visible on Chart Sweet Spot)
                  if(distPct >= 0.03 && distPct <= 1.0)
                     score += 50.0; // In immediate chart viewport!
                  else if(distPct > 1.0 && distPct <= 2.5)
                     score += 25.0; // Near viewport (1 screen)
                  else if(distPct > 2.5 && distPct <= 5.0)
                     score += 5.0;
                  else if(distPct > 5.0 && distPct <= 8.0)
                     score -= 25.0;
                  else if(distPct > 8.0)
                     score -= 60.0; // Off-screen macro

                  // Recency factor (more recent swings are fresher liquidity)
                  score += MathMax(0.0, (20.0 - (double)i * 0.5));

                  if(bestBSL_Price == 0 || score > bestBSL_Rank || (MathAbs(score - bestBSL_Rank) < 5.0 && distDollar < MathAbs(bestBSL_Price - ask)))
                  {
                     bestBSL_Price = hPrice;
                     bestBSL_Rank  = score;
                     bestBSL_TF    = tf;
                     bestBSL_Tag   = isEQH ? "EQH" : "SWING";
                  }
               }
            }

            // SSL Candidate (Fractal Swing Low)
            if(tfRates[i].low <= tfRates[i-1].low && tfRates[i].low <= tfRates[i-2].low &&
               tfRates[i].low <= tfRates[i+1].low && tfRates[i].low <= tfRates[i+2].low)
            {
               double lPrice = tfRates[i].low;
               if(lPrice < bid - (10 * _Point))
               {
                  bool isEQL = false;
                  for(int j = i + 1; j < MathMin(copied - 2, i + 15); j++)
                  {
                     if(tfRates[j].low <= tfRates[j-1].low && tfRates[j].low <= tfRates[j+1].low)
                     {
                        if(MathAbs(lPrice - tfRates[j].low) <= tol)
                        {
                           isEQL = true;
                           lPrice = MathMin(lPrice, tfRates[j].low);
                           break;
                        }
                     }
                  }

                  double distDollar = bid - lPrice;
                  double distPct = (distDollar / priceRef) * 100.0;

                  // Structural Base Weight
                  double score = (isEQL ? 35.0 : 0.0);
                  if(tf == activeTF)
                     score += 45.0; // Primary active chart structure
                  else if(GetTFRank(tf) == activeRank + 1)
                     score += 35.0; // Immediate higher TF
                  else if(GetTFRank(tf) == activeRank + 2)
                     score += 25.0;
                  else
                     score += 15.0;

                  // Proximity Score (Visible on Chart Sweet Spot)
                  if(distPct >= 0.03 && distPct <= 1.0)
                     score += 50.0; // In immediate chart viewport!
                  else if(distPct > 1.0 && distPct <= 2.5)
                     score += 25.0; // Near viewport (1 screen)
                  else if(distPct > 2.5 && distPct <= 5.0)
                     score += 5.0;
                  else if(distPct > 5.0 && distPct <= 8.0)
                     score -= 25.0;
                  else if(distPct > 8.0)
                     score -= 60.0; // Off-screen macro

                  // Recency factor
                  score += MathMax(0.0, (20.0 - (double)i * 0.5));

                  if(bestSSL_Price == 0 || score > bestSSL_Rank || (MathAbs(score - bestSSL_Rank) < 5.0 && distDollar < MathAbs(bid - bestSSL_Price)))
                  {
                     bestSSL_Price = lPrice;
                     bestSSL_Rank  = score;
                     bestSSL_TF    = tf;
                     bestSSL_Tag   = isEQL ? "EQL" : "SWING";
                  }
               }
            }
         }
      }

      // -------------------------------------------------------------
      // B. Evaluate D1 High & Low (PDH & PDL) fairly with proportional distance
      // -------------------------------------------------------------
      double pdh = iHigh(_Symbol, PERIOD_D1, 1);
      double pdl = iLow(_Symbol, PERIOD_D1, 1);

      if(pdh > ask + (10 * _Point))
      {
         double distDollar = pdh - ask;
         double distPct = (distDollar / priceRef) * 100.0;
         double pdhScore = 25.0; // Base D1 weight
         if(distPct <= 1.0)
            pdhScore += 50.0; // Visible near current price!
         else if(distPct <= 2.5)
            pdhScore += 25.0;
         else if(distPct > 5.0)
            pdhScore -= 30.0; // Far away, should not displace local M15 swings!

         if(bestBSL_Price == 0 || pdhScore > bestBSL_Rank)
         {
            bestBSL_Price = pdh;
            bestBSL_Rank  = pdhScore;
            bestBSL_TF    = PERIOD_D1;
            bestBSL_Tag   = "PDH";
         }
      }

      if(pdl > 0 && pdl < bid - (10 * _Point))
      {
         double distDollar = bid - pdl;
         double distPct = (distDollar / priceRef) * 100.0;
         double pdlScore = 25.0; // Base D1 weight
         if(distPct <= 1.0)
            pdlScore += 50.0; // Visible near current price!
         else if(distPct <= 2.5)
            pdlScore += 25.0;
         else if(distPct > 5.0)
            pdlScore -= 30.0; // Far away, should not displace local M15 swings!

         if(bestSSL_Price == 0 || pdlScore > bestSSL_Rank)
         {
            bestSSL_Price = pdl;
            bestSSL_Rank  = pdlScore;
            bestSSL_TF    = PERIOD_D1;
            bestSSL_Tag   = "PDL";
         }
      }

      // -------------------------------------------------------------
      // C. Absolute Fallbacks: Guarantee On-Screen Levels
      // If still missing or too far off-screen (> 4% away), use active TF swings/extremes!
      // -------------------------------------------------------------
      if(bestBSL_Price <= 0 || (bestBSL_Price - ask) / priceRef > 0.04)
      {
         if(g_LastSwingHigh.price > ask + (10 * _Point) && (g_LastSwingHigh.price - ask) / priceRef <= 0.04)
         {
            bestBSL_Price = g_LastSwingHigh.price;
            bestBSL_TF    = activeTF;
            bestBSL_Tag   = "SWING";
         }
         else
         {
            int hhBar = iHighest(_Symbol, activeTF, MODE_HIGH, 30, 1);
            if(hhBar > 0)
            {
               double localHigh = iHigh(_Symbol, activeTF, hhBar);
               if(localHigh > ask + (10 * _Point))
               {
                  bestBSL_Price = localHigh;
                  bestBSL_TF    = activeTF;
                  bestBSL_Tag   = "SWING";
               }
            }
         }
      }

      if(bestSSL_Price <= 0 || (bid - bestSSL_Price) / priceRef > 0.04)
      {
         if(g_LastSwingLow.price > 0 && g_LastSwingLow.price < bid - (10 * _Point) && (bid - g_LastSwingLow.price) / priceRef <= 0.04)
         {
            bestSSL_Price = g_LastSwingLow.price;
            bestSSL_TF    = activeTF;
            bestSSL_Tag   = "SWING";
         }
         else
         {
            int llBar = iLowest(_Symbol, activeTF, MODE_LOW, 30, 1);
            if(llBar > 0)
            {
               double localLow = iLow(_Symbol, activeTF, llBar);
               if(localLow > 0 && localLow < bid - (10 * _Point))
               {
                  bestSSL_Price = localLow;
                  bestSSL_TF    = activeTF;
                  bestSSL_Tag   = "SWING";
               }
            }
         }
      }

      // Update radar targets
      if(bestBSL_Price > 0)
      {
         g_LQ_Radar.bsl.price   = bestBSL_Price;
         g_LQ_Radar.bsl.tf      = bestBSL_TF;
         g_LQ_Radar.bsl.tfStr   = (bestBSL_Tag == "PDH") ? "D1-PDH" : (bestBSL_Tag == "EQH" ? "EQH-" + GetTFShortName(bestBSL_TF) : GetTFShortName(bestBSL_TF));
         g_LQ_Radar.bsl.isValid = true;
      }

      if(bestSSL_Price > 0)
      {
         g_LQ_Radar.ssl.price   = bestSSL_Price;
         g_LQ_Radar.ssl.tf      = bestSSL_TF;
         g_LQ_Radar.ssl.tfStr   = (bestSSL_Tag == "PDL") ? "D1-PDL" : (bestSSL_Tag == "EQL" ? "EQL-" + GetTFShortName(bestSSL_TF) : GetTFShortName(bestSSL_TF));
         g_LQ_Radar.ssl.isValid = true;
      }
   }

   // 2. Real-time live distance & sweep trigger on EVERY single tick
   double sweepResetPts = MathMax((priceRef * 0.003) / _Point, 250.0);

   if(g_LQ_Radar.bsl.isValid && g_LQ_Radar.bsl.price > 0)
   {
      g_LQ_Radar.bsl.distancePts = (int)MathRound((g_LQ_Radar.bsl.price - ask) / _Point);
      if(ask >= g_LQ_Radar.bsl.price)
      {
         g_LQ_Radar.bslSwept = true;
         g_LQ_Radar.bslSweptTime = curTime;
      }
      else
      {
         // Expire sweep status if time exceeds 15 minutes (900s) OR price moved far away beyond reset distance
         if(g_LQ_Radar.bslSwept && (curTime - g_LQ_Radar.bslSweptTime > 900 || g_LQ_Radar.bsl.distancePts > (int)sweepResetPts))
         {
            g_LQ_Radar.bslSwept = false;
         }
      }
   }

   if(g_LQ_Radar.ssl.isValid && g_LQ_Radar.ssl.price > 0)
   {
      g_LQ_Radar.ssl.distancePts = (int)MathRound((g_LQ_Radar.ssl.price - bid) / _Point);
      if(bid <= g_LQ_Radar.ssl.price)
      {
         g_LQ_Radar.sslSwept = true;
         g_LQ_Radar.sslSweptTime = curTime;
      }
      else
      {
         // Expire sweep status if time exceeds 15 minutes (900s) OR price moved far away beyond reset distance
         if(g_LQ_Radar.sslSwept && (curTime - g_LQ_Radar.sslSweptTime > 900 || g_LQ_Radar.ssl.distancePts < -(int)sweepResetPts))
         {
            g_LQ_Radar.sslSwept = false;
         }
      }
   }
}

void DrawLiquidityRadarVisuals()
{
   if(!InpShowSMC_BSL_SSL || !g_ShowVisuals)
   {
      RemoveLiquidityRadarVisuals();
      return;
   }

   datetime curTime = TimeCurrent();
   int tfSec = PeriodSeconds(GetCurrentExecutionTF());
   datetime tStart = curTime - (tfSec * 60);
   datetime tEnd   = curTime + (tfSec * 20);

   // Adaptive vertical and horizontal coordinate calculations
   double refPrice = (g_LQ_Radar.bsl.price > 0) ? g_LQ_Radar.bsl.price : ((g_LQ_Radar.ssl.price > 0) ? g_LQ_Radar.ssl.price : 2500.0);

   int chartWidth  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   double pMax     = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double pMin     = ChartGetDouble(0, CHART_PRICE_MIN, 0);

   // Precise pixel-to-price conversion for consistent gap across all assets (XAUUSD, BTCUSD, etc.)
   double pricePerPixel = (chartHeight > 0 && pMax > pMin) ? ((pMax - pMin) / (double)chartHeight) : (refPrice * 0.000035);
   double vLineGap = pricePerPixel * 14.0; // 14 pixels between line 1 & line 2
   double vMargin  = pricePerPixel * 4.0;  // 4 pixels margin from dashed level line

   // Dynamic Chart Shift & Candlestick Protection:
   // When Chart Shift is active (default), place badges in the forward open space (curTime + tfSec * 2)
   // with ANCHOR_LEFT so they extend rightwards into the empty margin, NEVER cutting across candlestick bodies or wicks!
   // If Chart Shift is off, anchor at level start (tStart + tfSec * 2) so they remain cleanly on-screen.
   bool isShifted = (bool)ChartGetInteger(0, CHART_SHIFT, 0);
   datetime badgeTime = isShifted ? (curTime + (tfSec * 7)) : (tStart + (tfSec * 2));

   ENUM_ANCHOR_POINT anchorBSL = ANCHOR_LEFT_LOWER;
   ENUM_ANCHOR_POINT anchorSSL = ANCHOR_LEFT_UPPER;

   // 1. Draw BSL (Buy-Side Liquidity: จุดดักกิน SL SELL เพื่อทุบ Sell กลับลงมา!)
   if(g_LQ_Radar.bsl.isValid && g_LQ_Radar.bsl.price > 0)
   {
      string lineName   = GUI_PREFIX + "LQ_BSL_LINE";
      string badge1Name = GUI_PREFIX + "LQ_BSL_BADGE1";
      string badge2Name = GUI_PREFIX + "LQ_BSL_BADGE2";

      if(ObjectFind(0, lineName) < 0)
         ObjectCreate(0, lineName, OBJ_TREND, 0, tStart, g_LQ_Radar.bsl.price, tEnd, g_LQ_Radar.bsl.price);
      else
      {
         ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, tStart);
         ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, g_LQ_Radar.bsl.price);
         ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, tEnd);
         ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, g_LQ_Radar.bsl.price);
      }
      color bslColor = g_LQ_Radar.bslSwept ? clrGold : InpColorBSL;
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, bslColor);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);

      // Live Real-Time Distance from current Ask
      double curAsk = m_symbol.Ask();
      int liveBSLDist = (curAsk > 0) ? (int)MathRound((g_LQ_Radar.bsl.price - curAsk) / _Point) : g_LQ_Radar.bsl.distancePts;

      // Clean 2-Line Stacked Architecture (Never clipped on right margin 100%)
      string bslText1 = StringFormat(" ◆ BSL [%s] %s (%s) ",
                                     g_LQ_Radar.bsl.tfStr,
                                     DoubleToString(g_LQ_Radar.bsl.price, _Digits),
                                     FormatLQDistance(liveBSLDist, g_AssetProfile.assetType, _Point));
      string bslText2 = "   ▼ เพื่อทุบ Sell (จุดดักกิน SL)";

      double bslPrice2 = g_LQ_Radar.bsl.price + vMargin;
      double bslPrice1 = bslPrice2 + vLineGap;

      color bslText1Col = g_LQ_Radar.bslSwept ? clrGold : InpColorBSL_Text;
      color bslText2Col = g_LQ_Radar.bslSwept ? clrGold : C'255,215,0'; // Bright Gold: High contrast on both dark chart and red/pink supply zones!

      // Line 1 (Main Details - Crisp High-Contrast Pure White)
      if(ObjectFind(0, badge1Name) < 0)
         ObjectCreate(0, badge1Name, OBJ_TEXT, 0, badgeTime, bslPrice1);
      else
      {
         ObjectSetInteger(0, badge1Name, OBJPROP_TIME, badgeTime);
         ObjectSetDouble(0, badge1Name, OBJPROP_PRICE, bslPrice1);
      }
      ObjectSetString(0, badge1Name, OBJPROP_TEXT, bslText1);
      ObjectSetString(0, badge1Name, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, badge1Name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, badge1Name, OBJPROP_COLOR, bslText1Col);
      ObjectSetInteger(0, badge1Name, OBJPROP_ANCHOR, anchorBSL);
      ObjectSetInteger(0, badge1Name, OBJPROP_BACK, false);
      ObjectSetInteger(0, badge1Name, OBJPROP_SELECTABLE, false);

      // Line 2 (Action Purpose Subtitle - Bright Luminous Gold)
      if(ObjectFind(0, badge2Name) < 0)
         ObjectCreate(0, badge2Name, OBJ_TEXT, 0, badgeTime, bslPrice2);
      else
      {
         ObjectSetInteger(0, badge2Name, OBJPROP_TIME, badgeTime);
         ObjectSetDouble(0, badge2Name, OBJPROP_PRICE, bslPrice2);
      }
      ObjectSetString(0, badge2Name, OBJPROP_TEXT, bslText2);
      ObjectSetString(0, badge2Name, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, badge2Name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, badge2Name, OBJPROP_COLOR, bslText2Col);
      ObjectSetInteger(0, badge2Name, OBJPROP_ANCHOR, anchorBSL);
      ObjectSetInteger(0, badge2Name, OBJPROP_BACK, false);
      ObjectSetInteger(0, badge2Name, OBJPROP_SELECTABLE, false);

      // Cleanup legacy single-line badge if present
      ObjectDelete(0, GUI_PREFIX + "LQ_BSL_BADGE");
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "LQ_BSL_LINE");
      ObjectDelete(0, GUI_PREFIX + "LQ_BSL_BADGE");
      ObjectDelete(0, GUI_PREFIX + "LQ_BSL_BADGE1");
      ObjectDelete(0, GUI_PREFIX + "LQ_BSL_BADGE2");
   }

   // 2. Draw SSL (Sell-Side Liquidity: จุดดักกิน SL BUY เพื่อช้อน Buy บินกลับขึ้นไป!)
   if(g_LQ_Radar.ssl.isValid && g_LQ_Radar.ssl.price > 0)
   {
      string lineName   = GUI_PREFIX + "LQ_SSL_LINE";
      string badge1Name = GUI_PREFIX + "LQ_SSL_BADGE1";
      string badge2Name = GUI_PREFIX + "LQ_SSL_BADGE2";

      if(ObjectFind(0, lineName) < 0)
         ObjectCreate(0, lineName, OBJ_TREND, 0, tStart, g_LQ_Radar.ssl.price, tEnd, g_LQ_Radar.ssl.price);
      else
      {
         ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, tStart);
         ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, g_LQ_Radar.ssl.price);
         ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, tEnd);
         ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, g_LQ_Radar.ssl.price);
      }
      color sslColor = g_LQ_Radar.sslSwept ? clrGold : InpColorSSL;
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, sslColor);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);

      // Live Real-Time Distance from current Bid
      double curBid = m_symbol.Bid();
      int liveSSLDist = (curBid > 0) ? (int)MathRound((g_LQ_Radar.ssl.price - curBid) / _Point) : g_LQ_Radar.ssl.distancePts;

      // Clean 2-Line Stacked Architecture (Never clipped on right margin 100%)
      string sslText1 = StringFormat(" ◆ SSL [%s] %s (%s) ",
                                     g_LQ_Radar.ssl.tfStr,
                                     DoubleToString(g_LQ_Radar.ssl.price, _Digits),
                                     FormatLQDistance(liveSSLDist, g_AssetProfile.assetType, _Point));
      string sslText2 = "   ▲ เพื่อช้อน Buy (จุดดักกิน SL)";

      double sslPrice1 = g_LQ_Radar.ssl.price - vMargin;
      double sslPrice2 = sslPrice1 - vLineGap;

      color sslText1Col = g_LQ_Radar.sslSwept ? clrGold : InpColorSSL_Text;
      color sslText2Col = g_LQ_Radar.sslSwept ? clrGold : C'80,250,160'; // Bright Luminous Mint: High contrast on both dark chart and blue demand zones!

      // Line 1 (Main Details - Crisp High-Contrast Pure White)
      if(ObjectFind(0, badge1Name) < 0)
         ObjectCreate(0, badge1Name, OBJ_TEXT, 0, badgeTime, sslPrice1);
      else
      {
         ObjectSetInteger(0, badge1Name, OBJPROP_TIME, badgeTime);
         ObjectSetDouble(0, badge1Name, OBJPROP_PRICE, sslPrice1);
      }
      ObjectSetString(0, badge1Name, OBJPROP_TEXT, sslText1);
      ObjectSetString(0, badge1Name, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, badge1Name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, badge1Name, OBJPROP_COLOR, sslText1Col);
      ObjectSetInteger(0, badge1Name, OBJPROP_ANCHOR, anchorSSL);
      ObjectSetInteger(0, badge1Name, OBJPROP_BACK, false);
      ObjectSetInteger(0, badge1Name, OBJPROP_SELECTABLE, false);

      // Line 2 (Action Purpose Subtitle - Bright Luminous Mint)
      if(ObjectFind(0, badge2Name) < 0)
         ObjectCreate(0, badge2Name, OBJ_TEXT, 0, badgeTime, sslPrice2);
      else
      {
         ObjectSetInteger(0, badge2Name, OBJPROP_TIME, badgeTime);
         ObjectSetDouble(0, badge2Name, OBJPROP_PRICE, sslPrice2);
      }
      ObjectSetString(0, badge2Name, OBJPROP_TEXT, sslText2);
      ObjectSetString(0, badge2Name, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, badge2Name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, badge2Name, OBJPROP_COLOR, sslText2Col);
      ObjectSetInteger(0, badge2Name, OBJPROP_ANCHOR, anchorSSL);
      ObjectSetInteger(0, badge2Name, OBJPROP_BACK, false);
      ObjectSetInteger(0, badge2Name, OBJPROP_SELECTABLE, false);

      // Cleanup legacy single-line badge if present
      ObjectDelete(0, GUI_PREFIX + "LQ_SSL_BADGE");
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "LQ_SSL_LINE");
      ObjectDelete(0, GUI_PREFIX + "LQ_SSL_BADGE");
      ObjectDelete(0, GUI_PREFIX + "LQ_SSL_BADGE1");
      ObjectDelete(0, GUI_PREFIX + "LQ_SSL_BADGE2");
   }
}

void RemoveLiquidityRadarVisuals()
{
   ObjectDelete(0, GUI_PREFIX + "LQ_BSL_LINE");
   ObjectDelete(0, GUI_PREFIX + "LQ_BSL_BADGE");
   ObjectDelete(0, GUI_PREFIX + "LQ_BSL_BADGE1");
   ObjectDelete(0, GUI_PREFIX + "LQ_BSL_BADGE2");
   ObjectDelete(0, GUI_PREFIX + "LQ_SSL_LINE");
   ObjectDelete(0, GUI_PREFIX + "LQ_SSL_BADGE");
   ObjectDelete(0, GUI_PREFIX + "LQ_SSL_BADGE1");
   ObjectDelete(0, GUI_PREFIX + "LQ_SSL_BADGE2");
}

void DrawSwingBadge(string name, datetime t, double price, string text, color col, bool isHigh)
{
   string objName = GUI_PREFIX + name;
   double offset = 75 * _Point;
   ENUM_TIMEFRAMES currentTF = (InpTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTimeframe);
   switch(currentTF)
   {
      case PERIOD_M1:  offset = 45 * _Point;  break;
      case PERIOD_M5:  offset = 80 * _Point;  break;
      case PERIOD_M15: offset = 140 * _Point; break;
      case PERIOD_M30: offset = 210 * _Point; break;
      case PERIOD_H1:  offset = 350 * _Point; break;
      case PERIOD_H4:  offset = 700 * _Point; break;
      case PERIOD_D1:  offset = 1500 * _Point; break;
      default:         offset = 90 * _Point;  break;
   }
   double drawPrice = isHigh ? (price + offset) : (price - offset);

   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_TEXT, 0, t, drawPrice);
   else
   {
      ObjectSetInteger(0, objName, OBJPROP_TIME, t);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, drawPrice);
   }
   ObjectSetString(0, objName, OBJPROP_TEXT, " " + text + " ");
   ObjectSetString(0, objName, OBJPROP_FONT, "Segoe UI Black");
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
}

//+------------------------------------------------------------------+
//| DETECT SPIKE REVERSAL & FLASH SNIPER SIGNALS                     |
//+------------------------------------------------------------------+
void DetectSpikeReversalSignal()
{
   ZeroMemory(g_SpikeSignal);
   if(!InpEnableSpikeSniper && !g_AutoSniperActive)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpTimeframe, 0, 5, rates) < 4)
      return;

   // Check newly closed bar (Bar 1)
   MqlRates b = rates[1];
   double barRange = (b.high - b.low) / _Point;
   
   int baseSpikePoints = g_AssetProfile.spikeMinPts;
   int effSpikePoints = baseSpikePoints;
   ENUM_TIMEFRAMES currentTF = (InpTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTimeframe);
   if(currentTF == PERIOD_M1) effSpikePoints = (int)(baseSpikePoints * 0.60);
   else if(currentTF >= PERIOD_M15) effSpikePoints = (int)(baseSpikePoints * 1.75);

   if(barRange < effSpikePoints)
      return;

   double body = MathAbs(b.close - b.open);
   double lowerWick = MathMin(b.open, b.close) - b.low;
   double upperWick = b.high - MathMax(b.open, b.close);

   double lowerWickPct = (lowerWick / (b.high - b.low)) * 100.0;
   double upperWickPct = (upperWick / (b.high - b.low)) * 100.0;

   // Check HTF Zone Collision
   bool hitHTFDemand = false;
   bool hitHTFSupply = false;

   if(InpRequireHTFZone)
   {
      for(int z = 0; z < ArraySize(g_SMC_MTF_Zones); z++)
      {
         if(!g_SMC_MTF_Zones[z].isActive) continue;
         if(g_SMC_MTF_Zones[z].direction == 1) // Demand
         {
            if(b.low <= g_SMC_MTF_Zones[z].topPrice && b.low >= g_SMC_MTF_Zones[z].bottomPrice - (50 * _Point))
               hitHTFDemand = true;
         }
         else if(g_SMC_MTF_Zones[z].direction == -1) // Supply
         {
            if(b.high >= g_SMC_MTF_Zones[z].bottomPrice && b.high <= g_SMC_MTF_Zones[z].topPrice + (50 * _Point))
               hitHTFSupply = true;
         }
      }

      if(g_Fibo.p786 > 0 && b.low <= g_Fibo.p786) hitHTFDemand = true;
      if(g_Fibo.p236 > 0 && b.high >= g_Fibo.p236) hitHTFSupply = true;
   }
   else
   {
      hitHTFDemand = true;
      hitHTFSupply = true;
   }

   // 1. Bullish Spike Rejection (Long Lower Wick at Demand)
   if(lowerWickPct >= InpMinWickPercent && hitHTFDemand && b.close > b.low + (lowerWick * 0.7))
   {
      double slBuf = MathMax(InpSpikeSL_Buffer * _Point, g_AssetProfile.beLock * _Point);
      double tpTarget = MathMax(InpSpikeTP_Target * _Point, (g_AssetProfile.fallbackTP * 0.45 * _Point));
      g_SpikeSignal.isValid    = true;
      g_SpikeSignal.direction  = 1;
      g_SpikeSignal.barTime    = b.time;
      g_SpikeSignal.entryPrice = m_symbol.Ask();
      g_SpikeSignal.slPrice    = b.low - slBuf;
      g_SpikeSignal.tpPrice    = m_symbol.Ask() + tpTarget;
      g_SpikeSignal.spikeRange = barRange;
      g_SpikeSignal.wickRange  = lowerWick / _Point;
      g_SpikeSignal.reason     = StringFormat("Bullish Pinbar (ไส้ %.0f pts)", g_SpikeSignal.wickRange);
   }
   // 2. Bearish Spike Rejection (Long Upper Wick at Supply)
   else if(upperWickPct >= InpMinWickPercent && hitHTFSupply && b.close < b.high - (upperWick * 0.7))
   {
      double slBuf = MathMax(InpSpikeSL_Buffer * _Point, g_AssetProfile.beLock * _Point);
      double tpTarget = MathMax(InpSpikeTP_Target * _Point, (g_AssetProfile.fallbackTP * 0.45 * _Point));
      g_SpikeSignal.isValid    = true;
      g_SpikeSignal.direction  = -1;
      g_SpikeSignal.barTime    = b.time;
      g_SpikeSignal.entryPrice = m_symbol.Bid();
      g_SpikeSignal.slPrice    = b.high + slBuf;
      g_SpikeSignal.tpPrice    = m_symbol.Bid() - tpTarget;
      g_SpikeSignal.spikeRange = barRange;
      g_SpikeSignal.wickRange  = upperWick / _Point;
      g_SpikeSignal.reason     = StringFormat("Bearish Pinbar (ไส้ %.0f pts)", g_SpikeSignal.wickRange);
   }
}

//+------------------------------------------------------------------+
//| EXECUTE SPIKE SNIPER ORDER                                       |
//+------------------------------------------------------------------+
void ExecuteSpikeSniperOrder()
{
   if(!g_SpikeSignal.isValid)
   {
      Print("Warning: No valid Spike Sniper signal active.");
      Alert("⚠️ [Good Trade Gold] ไม่มีสัญญาณสไนเปอร์ที่พร้อมยิงในขณะนี้");
      return;
   }

   m_symbol.RefreshRates();
   double spread = (m_symbol.Ask() - m_symbol.Bid()) / _Point;
   if(spread > g_AssetProfile.maxSpread)
   {
      Print("Spike Sniper Blocked: Spread too high (", DoubleToString(spread, 1), " pts)");
      Alert(StringFormat("🛑 [Good Trade Gold] สเปรดสูงเกินไป (%.0f pts > %d pts) ชะลอการยิงสไนเปอร์", spread, g_AssetProfile.maxSpread));
      return;
   }

   double entry = (g_SpikeSignal.direction == 1) ? m_symbol.Ask() : m_symbol.Bid();
   double sl    = g_SpikeSignal.slPrice;
   double tp    = g_SpikeSignal.tpPrice;

   // Safety bounds on SL distance
   double minAllowedSLPts = MathMax((double)g_AssetProfile.fallbackSL * 0.40, 150.0);
   double maxAllowedSLPts = MathMax((double)g_AssetProfile.fallbackSL * 1.50, 600.0);
   if(g_SpikeSignal.direction == 1)
   {
      if(sl >= entry || (entry - sl) / _Point < minAllowedSLPts) sl = entry - (minAllowedSLPts * _Point);
      if((entry - sl) / _Point > maxAllowedSLPts) sl = entry - (maxAllowedSLPts * _Point);
   }
   else
   {
      if(sl <= entry || (sl - entry) / _Point < minAllowedSLPts) sl = entry + (minAllowedSLPts * _Point);
      if((sl - entry) / _Point > maxAllowedSLPts) sl = entry + (maxAllowedSLPts * _Point);
   }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double lots = (g_LotMode == LOT_FIXED) ? g_CurrentLot : CalculateLotSize(entry, sl);
   if(lots <= 0) lots = m_symbol.LotsMin();

   string ceilMsg = "";
   if(!CheckMaxVolumeCeilingGuard(lots, ceilMsg))
   {
      Print(">>> 🛑 [SPIKE SNIPER BLOCKED] ", ceilMsg);
      Alert(StringFormat("🛑 [Good Trade Gold] สไนเปอร์ถูกระงับ: %s", ceilMsg));
      return;
   }

   string comment = "GTG_SPIKE_SNIPER";
   bool res = false;

   if(g_SpikeSignal.direction == 1)
      res = m_trade.Buy(lots, _Symbol, entry, sl, tp, comment);
   else
      res = m_trade.Sell(lots, _Symbol, entry, sl, tp, comment);

   if(res)
   {
      g_LastAnyOrderTime = TimeCurrent();
      Print("🎯 [SPIKE SNIPER] Executed Successfully: ", (g_SpikeSignal.direction == 1 ? "BUY" : "SELL"), 
            " Lot: ", lots, " Price: ", entry, " SL: ", sl, " TP: ", tp);
      SendTradeNotification(StringFormat("🎯 [SPIKE SNIPER] %s @ %.2f | Lot: %.2f | SL: %.2f | TP: %.2f", 
                            (g_SpikeSignal.direction == 1 ? "BUY" : "SELL"), entry, lots, sl, tp));
      g_SpikeSignal.isValid = false;
      UpdateHUDValues();
      ChartRedraw();
   }
   else
   {
      Print("Error: Spike Sniper execution failed. Error: ", GetLastError());
      Alert(StringFormat("❌ [Good Trade Gold] ยิงสไนเปอร์ไม่สำเร็จ (Error: %d)", GetLastError()));
   }
}

//+------------------------------------------------------------------+
//| DETECT HTF ZONE CANDLESTICK REVERSAL (DEMAND BUY / SUPPLY SELL)   |
//+------------------------------------------------------------------+
void DetectHTFZoneReversalTrigger()
{
   ZeroMemory(g_HTFReversal);
   if(!InpEnableHTFReversalSniper && !g_AutoSniperActive)
      return;

   // 1. Sideway & Low Momentum Shield (Active in Safe mode, bypassed in Aggressive Sniper mode)
   if(g_TradeMode == TRADE_MODE_SAFE_COPILOT && (g_MarketTrend == TREND_SIDEWAY || g_LiveADX_Val < 20.0))
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpTimeframe, 0, 4, rates) < 3)
      return;

   // Evaluate fully CLOSED bars: Bar 1 (newly closed) and Bar 2 (previous closed)
   MqlRates closedBar = rates[1];
   MqlRates prevBar   = rates[2];

   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();

   // Get dynamic ATR for safe SL buffer
   double currentATR = (double)g_AssetProfile.fallbackSL;
   if(m_hATR != INVALID_HANDLE)
   {
      double atrBuf[1];
      if(CopyBuffer(m_hATR, 0, 0, 1, atrBuf) > 0 && atrBuf[0] > 0)
         currentATR = atrBuf[0] / _Point;
   }

   // Adaptive zone entry tolerances calibrated to asset profile
   double nearMargin = MathMax(40.0, (double)g_AssetProfile.fallbackSL * 0.08) * _Point;
   double farMargin  = MathMax(60.0, (double)g_AssetProfile.fallbackSL * 0.15) * _Point;
   double tolMargin  = MathMax(150.0, (double)g_AssetProfile.fallbackSL * 0.40) * _Point;

   int baseTP1 = (g_AssetProfile.assetType == ASSET_GOLD) ? InpFallbackTP_Points  : g_AssetProfile.fallbackTP;
   int baseTP2 = (g_AssetProfile.assetType == ASSET_GOLD) ? InpFallbackTP2_Points : (int)(g_AssetProfile.fallbackTP * 2.0);
   int baseTP3 = (g_AssetProfile.assetType == ASSET_GOLD) ? InpFallbackTP3_Points : (int)(g_AssetProfile.fallbackTP * 3.0);
   double maxAllowedTPPts = (double)baseTP3 * 1.25;
   double tp1Pts = MathMin((double)baseTP1, maxAllowedTPPts);
   double tp2Pts = MathMin((double)baseTP2, maxAllowedTPPts);
   double tp3Pts = MathMin((double)baseTP3, maxAllowedTPPts);

   // 2. Scan Multi-Timeframe Zones (M5, M15, M30, H1, H4, D1, W1)
   for(int z = 0; z < ArraySize(g_SMC_MTF_Zones); z++)
   {
      if(!g_SMC_MTF_Zones[z].isActive) continue;

      // Filter out M1 noise, maintain full support for M5, M15, M30, H1, H4, D1, W1
      if(StringFind(g_SMC_MTF_Zones[z].tfName, "Demand M1") == 0 || StringFind(g_SMC_MTF_Zones[z].tfName, "Supply M1") == 0)
         continue;

      // ==========================================
      // A. BUY REVERSAL AT HTF DEMAND ZONE
      // ==========================================
      if(g_SMC_MTF_Zones[z].direction == 1) // Demand Zone
      {
         // Institutional Dip-Reversal: Allow confirmed Demand bounces with rejection wicks

         // Price must currently be inside or just touching the Demand zone (Not 1000s of points above it)
         bool isTouchingZone = (closedBar.low <= g_SMC_MTF_Zones[z].topPrice + nearMargin && 
                                closedBar.low >= g_SMC_MTF_Zones[z].bottomPrice - farMargin &&
                                ask <= g_SMC_MTF_Zones[z].topPrice + tolMargin);

         if(isTouchingZone)
         {
            bool candleConfirmed = false;
            string patternLabel = "";

            double candleRange = closedBar.high - closedBar.low;
            double lowerWick   = MathMin(closedBar.open, closedBar.close) - closedBar.low;
            
            // 1. Bullish Pinbar / Hammer on Closed Bar 1
            if(candleRange > 0 && (lowerWick / candleRange) >= 0.45 && closedBar.close > closedBar.low + (lowerWick * 0.60))
            {
               candleConfirmed = true;
               patternLabel = "Bullish Pinbar / Hammer 🔨";
            }
            // 2. Bullish Engulfing
            else if(closedBar.close > closedBar.open && prevBar.close < prevBar.open && closedBar.close >= prevBar.open)
            {
               candleConfirmed = true;
               patternLabel = "Bullish Engulfing 🟢";
            }
            // 3. Known Institutional Reversal Pattern
            else if(g_DetectedPattern == PA_BULLISH_PINBAR || g_DetectedPattern == PA_BULLISH_ENGULFING || 
                    g_DetectedPattern == PA_INVERTED_HAMMER || g_DetectedPattern == PA_MORNING_STAR || 
                    g_DetectedPattern == PA_PIERCING_LINE || g_DetectedPattern == PA_THREE_WHITE_SOLDIERS)
            {
               candleConfirmed = true;
               patternLabel = g_PatternName;
            }
            // 4. Pure Price Action Rejection Trigger
            else if(g_PABuyTrigger)
            {
               candleConfirmed = true;
               patternLabel = (g_PARejectionType != "") ? g_PARejectionType : "PA Rejection Wick ⚡";
            }

            if(!InpRequireCandleReversal)
               candleConfirmed = true;

            string blockReason = "";
            if(!IsTradeAllowedByExhaustionGuard(ORDER_TYPE_BUY, blockReason, true))
               candleConfirmed = false;

            if(candleConfirmed)
            {
               g_HTFReversal.isValid     = true;
               g_HTFReversal.direction   = 1; // BUY
               g_HTFReversal.barTime     = closedBar.time;
               g_HTFReversal.entryPrice  = ask;
               g_HTFReversal.zoneName    = g_SMC_MTF_Zones[z].tfName;
               g_HTFReversal.patternName = patternLabel;

               // Robust Structural SL placed safely below Demand Zone with ATR buffer & Sanity Cap
               double slBufferPts = MathMax((double)InpHTFReversalSL_Buffer, currentATR * 0.45);
               double maxAllowedSLPts = MathMax((double)g_AssetProfile.fallbackSL * 1.50, 500.0); // Hard Cap 500-600 pts max on Gold
               double minAllowedSLPts = MathMax((double)g_AssetProfile.fallbackSL * 0.50, 200.0);

               double targetSL = closedBar.low - (slBufferPts * _Point);
               if(g_SMC_MTF_Zones[z].bottomPrice < closedBar.low && (ask - g_SMC_MTF_Zones[z].bottomPrice) / _Point <= maxAllowedSLPts)
               {
                  targetSL = g_SMC_MTF_Zones[z].bottomPrice - (slBufferPts * _Point);
               }

               double riskPts = (ask - targetSL) / _Point;
               if(riskPts > maxAllowedSLPts)
               {
                  riskPts = maxAllowedSLPts;
                  targetSL = ask - (riskPts * _Point);
               }
               else if(riskPts < minAllowedSLPts)
               {
                  riskPts = minAllowedSLPts;
                  targetSL = ask - (riskPts * _Point);
               }

               g_HTFReversal.slPrice  = NormalizeDouble(targetSL, _Digits);

               g_HTFReversal.tp1Price = NormalizeDouble(ask + (tp1Pts * _Point), _Digits);
               g_HTFReversal.tp2Price = NormalizeDouble(ask + (tp2Pts * _Point), _Digits);
               g_HTFReversal.tp3Price = NormalizeDouble(ask + (tp3Pts * _Point), _Digits);
               g_HTFReversal.tpPrice  = g_HTFReversal.tp2Price;

               g_HTFReversal.reason   = StringFormat("DEMAND %s + %s", g_HTFReversal.zoneName, patternLabel);
               return;
            }
         }
      }
      // ==========================================
      // B. SELL REVERSAL AT HTF SUPPLY ZONE
      // ==========================================
      else if(g_SMC_MTF_Zones[z].direction == -1) // Supply Zone
      {
         // Institutional Peak-Reversal: Allow confirmed Supply rejections with rejection wicks from the peak!

         // Price must currently be inside or just touching the Supply zone
         bool isTouchingZone = (closedBar.high >= g_SMC_MTF_Zones[z].bottomPrice - nearMargin && 
                                closedBar.high <= g_SMC_MTF_Zones[z].topPrice + farMargin &&
                                bid >= g_SMC_MTF_Zones[z].bottomPrice - tolMargin);

         if(isTouchingZone)
         {
            bool candleConfirmed = false;
            string patternLabel = "";

            double candleRange = closedBar.high - closedBar.low;
            double upperWick   = closedBar.high - MathMax(closedBar.open, closedBar.close);
            
            // 1. Bearish Shooting Star / Pinbar on Closed Bar 1
            if(candleRange > 0 && (upperWick / candleRange) >= 0.45 && closedBar.close < closedBar.high - (upperWick * 0.60))
            {
               candleConfirmed = true;
               patternLabel = "Bearish Shooting Star / Pinbar ⚡";
            }
            // 2. Bearish Engulfing
            else if(closedBar.close < closedBar.open && prevBar.close > prevBar.open && closedBar.close <= prevBar.open)
            {
               candleConfirmed = true;
               patternLabel = "Bearish Engulfing 🔴";
            }
            // 3. Known Institutional Reversal Pattern
            else if(g_DetectedPattern == PA_BEARISH_PINBAR || g_DetectedPattern == PA_BEARISH_ENGULFING || 
                    g_DetectedPattern == PA_EVENING_STAR || g_DetectedPattern == PA_DARK_CLOUD_COVER || 
                    g_DetectedPattern == PA_THREE_BLACK_CROWS)
            {
               candleConfirmed = true;
               patternLabel = g_PatternName;
            }
            // 4. Pure Price Action Rejection Trigger
            else if(g_PASellTrigger)
            {
               candleConfirmed = true;
               patternLabel = (g_PARejectionType != "") ? g_PARejectionType : "PA Rejection Wick ⚡";
            }

            if(!InpRequireCandleReversal)
               candleConfirmed = true;

            string blockReason = "";
            if(!IsTradeAllowedByExhaustionGuard(ORDER_TYPE_SELL, blockReason, true))
               candleConfirmed = false;

            if(candleConfirmed)
            {
               g_HTFReversal.isValid     = true;
               g_HTFReversal.direction   = -1; // SELL
               g_HTFReversal.barTime     = closedBar.time;
               g_HTFReversal.entryPrice  = bid;
               g_HTFReversal.zoneName    = g_SMC_MTF_Zones[z].tfName;
               g_HTFReversal.patternName = patternLabel;

               // Robust Structural SL placed safely above Supply Zone with ATR buffer & Sanity Cap
               double slBufferPts = MathMax((double)InpHTFReversalSL_Buffer, currentATR * 0.45);
               double maxAllowedSLPts = MathMax((double)g_AssetProfile.fallbackSL * 1.50, 500.0); // Hard Cap 500-600 pts max on Gold
               double minAllowedSLPts = MathMax((double)g_AssetProfile.fallbackSL * 0.50, 200.0);

               double targetSL = closedBar.high + (slBufferPts * _Point);
               if(g_SMC_MTF_Zones[z].topPrice > closedBar.high && (g_SMC_MTF_Zones[z].topPrice - bid) / _Point <= maxAllowedSLPts)
               {
                  targetSL = g_SMC_MTF_Zones[z].topPrice + (slBufferPts * _Point);
               }

               double riskPts = (targetSL - bid) / _Point;
               if(riskPts > maxAllowedSLPts)
               {
                  riskPts = maxAllowedSLPts;
                  targetSL = bid + (riskPts * _Point);
               }
               else if(riskPts < minAllowedSLPts)
               {
                  riskPts = minAllowedSLPts;
                  targetSL = bid + (riskPts * _Point);
               }

               g_HTFReversal.slPrice  = NormalizeDouble(targetSL, _Digits);

               g_HTFReversal.tp1Price = NormalizeDouble(bid - (tp1Pts * _Point), _Digits);
               g_HTFReversal.tp2Price = NormalizeDouble(bid - (tp2Pts * _Point), _Digits);
               g_HTFReversal.tp3Price = NormalizeDouble(bid - (tp3Pts * _Point), _Digits);
               g_HTFReversal.tpPrice  = g_HTFReversal.tp2Price;

               g_HTFReversal.reason   = StringFormat("SUPPLY %s + %s", g_HTFReversal.zoneName, patternLabel);
               return;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| EXECUTE HTF ZONE CANDLESTICK REVERSAL ORDER                      |
//+------------------------------------------------------------------+
void ExecuteHTFReversalOrder()
{
   if(!g_HTFReversal.isValid)
      return;

   ENUM_ORDER_TYPE orderType = (g_HTFReversal.direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   string blockReason = "";
   if(!IsTradeAllowedByExhaustionGuard(orderType, blockReason, true))
   {
      Print(">>> 🛡️ [HTF REVERSAL BLOCKED BY EXHAUSTION GUARD] ", blockReason);
      g_HTFReversal.isValid = false;
      return;
   }

   int openCount = CountOpenPositions(InpManageManualTrades);
   if(!g_AllowMultiPos && openCount > 0)
      return;
   if(openCount >= InpMaxOpenPos)
      return;

   m_symbol.RefreshRates();
   double spread = (m_symbol.Ask() - m_symbol.Bid()) / _Point;
   if(spread > g_AssetProfile.maxSpread)
      return;

   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();

   if(g_HTFReversal.direction == 1) // BUY
   {
      double entry = ask;
      double sl    = NormalizeDouble(g_HTFReversal.slPrice, _Digits);
      double tp    = NormalizeDouble(g_HTFReversal.tpPrice, _Digits);
      double lot   = CalculateLotSize(entry, sl);
      string ceilMsg = "";
      if(!CheckMaxVolumeCeilingGuard(lot, ceilMsg))
      {
         Print(">>> 🛑 [HTF REVERSAL BUY BLOCKED] ", ceilMsg);
         g_HTFReversal.isValid = false;
         return;
      }

      string comment = StringFormat("GTG_HTF_DEMAND_BUY #%d", openCount + 1);
      if(m_trade.Buy(lot, _Symbol, entry, sl, tp, comment))
      {
         g_LastAnyOrderTime = TimeCurrent();
         Print(">>> 🟢 [HTF DEMAND DIP-BUY] Executed @ ", entry, " Lot: ", lot, " SL: ", sl, " TP: ", tp, " Reason: ", g_HTFReversal.reason);
         SendTradeNotification(StringFormat("🟢 [Good Trade Gold] HTF DEMAND DIP-BUY @ %.2f | Lot: %.2f | SL: %.2f | TP: %.2f | %s", entry, lot, sl, tp, g_HTFReversal.reason));
         g_BotState = STATE_IN_POSITION;
         g_HTFReversal.isValid = false;
         UpdateHUDValues();
         ChartRedraw();
      }
   }
   else if(g_HTFReversal.direction == -1) // SELL
   {
      double entry = bid;
      double sl    = NormalizeDouble(g_HTFReversal.slPrice, _Digits);
      double tp    = NormalizeDouble(g_HTFReversal.tpPrice, _Digits);
      double lot   = CalculateLotSize(entry, sl);
      string ceilMsg = "";
      if(!CheckMaxVolumeCeilingGuard(lot, ceilMsg))
      {
         Print(">>> 🛑 [HTF REVERSAL SELL BLOCKED] ", ceilMsg);
         g_HTFReversal.isValid = false;
         return;
      }

      string comment = StringFormat("GTG_HTF_SUPPLY_SELL #%d", openCount + 1);
      if(m_trade.Sell(lot, _Symbol, entry, sl, tp, comment))
      {
         g_LastAnyOrderTime = TimeCurrent();
         Print(">>> 🔴 [HTF SUPPLY DIP-SELL] Executed @ ", entry, " Lot: ", lot, " SL: ", sl, " TP: ", tp, " Reason: ", g_HTFReversal.reason);
         SendTradeNotification(StringFormat("🔴 [Good Trade Gold] HTF SUPPLY DIP-SELL @ %.2f | Lot: %.2f | SL: %.2f | TP: %.2f | %s", entry, lot, sl, tp, g_HTFReversal.reason));
         g_BotState = STATE_IN_POSITION;
         g_HTFReversal.isValid = false;
         UpdateHUDValues();
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| ADX MOMENTUM TURBO GATE ENGINE                                   |
//+------------------------------------------------------------------+
void UpdateADXMomentumTurboGate()
{
   if(!InpUseADXTurboGate)
   {
      g_ADXMode = ADX_MODE_NORMAL;
      g_ADXStatusStr = "TURBO GATE ● OFF";
      return;
   }

   if(m_hADX_Current == INVALID_HANDLE)
      m_hADX_Current = iADX(_Symbol, InpTimeframe, InpADX_Period);

   if(m_hADX_Current == INVALID_HANDLE)
   {
      g_ADXMode = ADX_MODE_NORMAL;
      g_ADXStatusStr = "ADX: Initializing...";
      return;
   }

   double adxVal[1];
   if(CopyBuffer(m_hADX_Current, 0, 0, 1, adxVal) > 0)
   {
      g_LiveADX_Val = adxVal[0];
      if(g_LiveADX_Val >= InpADX_TurboLevel)
      {
         g_ADXMode = ADX_MODE_TURBO;
         g_ADXStatusStr = StringFormat("TURBO 🚀 (%.1f | Super Trend)", g_LiveADX_Val);
      }
      else if(g_LiveADX_Val <= InpADX_RangeLevel)
      {
         g_ADXMode = ADX_MODE_RANGE;
         g_ADXStatusStr = StringFormat("RANGE/SCALP 🟡 (%.1f | Quick Exit)", g_LiveADX_Val);
      }
      else
      {
         g_ADXMode = ADX_MODE_NORMAL;
         g_ADXStatusStr = StringFormat("NORMAL 🟢 (%.1f | Balanced)", g_LiveADX_Val);
      }
   }
}

//+------------------------------------------------------------------+
//| DYNAMIC TIMEFRAME-ADAPTIVE SL & TP SCALING ENGINE                |
//+------------------------------------------------------------------+
void GetTimeframeAdaptiveSLTP(ENUM_TIMEFRAMES tf, int &slPts, int &tp1Pts, int &tp2Pts, int &tp3Pts)
{
   ENUM_TIMEFRAMES currentTF = (tf == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : tf);
   
   int baseSL  = (g_AssetProfile.assetType == ASSET_GOLD) ? InpFallbackSL_Points  : g_AssetProfile.fallbackSL;
   int baseTP1 = (g_AssetProfile.assetType == ASSET_GOLD) ? InpFallbackTP_Points  : g_AssetProfile.fallbackTP;
   int baseTP2 = (g_AssetProfile.assetType == ASSET_GOLD) ? InpFallbackTP2_Points : (int)(g_AssetProfile.fallbackTP * 2.0);
   int baseTP3 = (g_AssetProfile.assetType == ASSET_GOLD) ? InpFallbackTP3_Points : (int)(g_AssetProfile.fallbackTP * 3.0);
   
   switch(currentTF)
   {
      case PERIOD_M1:
         slPts  = MathMax(250, (int)(baseSL  * 0.40)); // ~308 pts ($3.08)
         tp1Pts = MathMax(400, (int)(baseTP1 * 0.45)); // ~427 pts ($4.27)
         tp2Pts = MathMax(750, (int)(baseTP2 * 0.45)); // ~855 pts ($8.55)
         tp3Pts = MathMax(1200,(int)(baseTP3 * 0.45)); // ~1282 pts ($12.82)
         break;
      case PERIOD_M5:
         slPts  = MathMax(350, (int)(baseSL  * 0.55)); // ~423 pts ($4.23)
         tp1Pts = MathMax(600, (int)(baseTP1 * 0.65)); // ~617 pts ($6.17)
         tp2Pts = MathMax(1100,(int)(baseTP2 * 0.65)); // ~1235 pts ($12.35)
         tp3Pts = MathMax(1800,(int)(baseTP3 * 0.65)); // ~1852 pts ($18.52)
         break;
      case PERIOD_M15:
         slPts  = baseSL;                              // 777 pts ($7.77)
         tp1Pts = baseTP1;                             // 950 pts ($9.50)
         tp2Pts = baseTP2;                             // 1900 pts ($19.00)
         tp3Pts = baseTP3;                             // 2850 pts ($28.50)
         break;
      case PERIOD_M30:
         slPts  = (int)(baseSL  * 1.25);               // ~962 pts ($9.62)
         tp1Pts = (int)(baseTP1 * 1.30);               // ~1235 pts ($12.35)
         tp2Pts = (int)(baseTP2 * 1.30);               // ~2470 pts ($24.70)
         tp3Pts = (int)(baseTP3 * 1.30);               // ~3705 pts ($37.05)
         break;
      case PERIOD_H1:
         slPts  = (int)(baseSL  * 1.60);               // ~1232 pts ($12.32)
         tp1Pts = (int)(baseTP1 * 1.60);               // ~1520 pts ($15.20)
         tp2Pts = (int)(baseTP2 * 1.60);               // ~3040 pts ($30.40)
         tp3Pts = (int)(baseTP3 * 1.60);               // ~4560 pts ($45.60)
         break;
      case PERIOD_H4:
         slPts  = (int)(baseSL  * 2.50);               // ~1925 pts ($19.25)
         tp1Pts = (int)(baseTP1 * 2.50);               // ~2375 pts ($23.75)
         tp2Pts = (int)(baseTP2 * 2.50);               // ~4750 pts ($47.50)
         tp3Pts = (int)(baseTP3 * 2.50);               // ~7125 pts ($71.25)
         break;
      case PERIOD_D1:
      case PERIOD_W1:
      case PERIOD_MN1:
         slPts  = (int)(baseSL  * 4.00);               // ~3080 pts ($30.80)
         tp1Pts = (int)(baseTP1 * 4.00);               // ~3800 pts ($38.00)
         tp2Pts = (int)(baseTP2 * 4.00);               // ~7600 pts ($76.00)
         tp3Pts = (int)(baseTP3 * 4.00);               // ~11400 pts ($114.00)
         break;
      default:
         slPts  = baseSL;
         tp1Pts = baseTP1;
         tp2Pts = baseTP2;
         tp3Pts = baseTP3;
         break;
   }
}

//+------------------------------------------------------------------+
//| CALCULATE ADAPTIVE RUNNER TRAILING DISTANCE (ADX & ATR ELASTIC)  |
//+------------------------------------------------------------------+
void CalculateAdaptiveTrailingDistance(ulong ticket, double &trailDistPts, double &trailStepPts, string &trailModeStr)
{
   double baseDist = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpTrailingDist : (double)g_AssetProfile.trailDist;
   double baseStep = (g_AssetProfile.assetType == ASSET_GOLD) ? (double)InpTrailingStep : (double)g_AssetProfile.trailStep;
   trailDistPts = baseDist;
   trailStepPts = baseStep;
   trailModeStr = "Standard Trailing";

   if(!InpUseAdaptiveTrailing)
      return;

   // Get current dynamic ATR
   double currentATR = 0.0;
   if(m_hATR != INVALID_HANDLE)
   {
      double atrBuf[1];
      if(CopyBuffer(m_hATR, 0, 0, 1, atrBuf) > 0 && atrBuf[0] > 0)
         currentATR = atrBuf[0] / _Point;
   }
   if(currentATR <= 0)
      currentATR = baseDist;

   bool isRunner = IsPartialTP_Executed(ticket);

   // 1. TIGHT TRAILING (ADX < 20 / Sideway or Weak Trend)
   if(g_ADXMode == ADX_MODE_RANGE || g_LiveADX_Val < InpADX_RangeLevel)
   {
      trailDistPts = MathMax(baseDist * 0.85, currentATR * 0.85);
      trailStepPts = MathMax(baseStep * 0.75, currentATR * 0.35);
      trailModeStr = "TIGHT TRAIL 🛡️ (0.85x ATR)";
   }
   // 2. ELASTIC RUNNER TRAILING (ADX >= 25.0 / Super Turbo Trend)
   else if(g_ADXMode == ADX_MODE_TURBO || g_LiveADX_Val >= InpADX_TurboLevel)
   {
      if(isRunner)
      {
         // Extra elastic breathing room for Wave 3 / Wave 5 Runner
         trailDistPts = MathMax(baseDist * 1.35, currentATR * 1.50);
         trailStepPts = MathMax(baseStep, currentATR * 0.50);
         trailModeStr = "ELASTIC RUNNER 🚀 (1.5x ATR)";
      }
      else
      {
         trailDistPts = MathMax(baseDist * 1.15, currentATR * 1.20);
         trailStepPts = MathMax(baseStep, currentATR * 0.40);
         trailModeStr = "TURBO TRAIL ⚡ (1.2x ATR)";
      }
   }
   // 3. STANDARD SWING TRAILING (20 <= ADX < 25 / Normal Wave 3 Trend)
   else
   {
      if(isRunner)
      {
         trailDistPts = MathMax(baseDist * 1.15, currentATR * 1.25);
         trailStepPts = MathMax(baseStep, currentATR * 0.40);
         trailModeStr = "SWING RUNNER 🌊 (1.25x ATR)";
      }
      else
      {
         trailDistPts = MathMax(baseDist, currentATR * 1.00);
         trailStepPts = MathMax(baseStep, currentATR * 0.35);
         trailModeStr = "SWING TRAIL 🟢 (1.0x ATR)";
      }
   }

   g_AdaptiveTrailModeStr = trailModeStr;
}

//+------------------------------------------------------------------+
//| VALIDATE MULTI-TIMEFRAME ADX TREND STRENGTH                     |
//+------------------------------------------------------------------+
bool ValidateADXTrend()
{
   if(!InpUseADXFilter)
      return true; // Bypass immediately when disabled (Never blocks trading!)

   double adx1[1], adx2[1], adx3[1];
   bool ok1 = (m_hADX_TF1 != INVALID_HANDLE && CopyBuffer(m_hADX_TF1, 0, 0, 1, adx1) > 0) ? (adx1[0] >= InpADX_Threshold) : true;
   bool ok2 = (m_hADX_TF2 != INVALID_HANDLE && CopyBuffer(m_hADX_TF2, 0, 0, 1, adx2) > 0) ? (adx2[0] >= InpADX_Threshold) : true;
   bool ok3 = (m_hADX_TF3 != INVALID_HANDLE && CopyBuffer(m_hADX_TF3, 0, 0, 1, adx3) > 0) ? (adx3[0] >= InpADX_Threshold) : true;

   return (ok1 && ok2 && ok3);
}

//+------------------------------------------------------------------+
//| ANALYZE ELLIOTT WAVE DUAL SWING (P0->P1->P2 & 1-2-3-4-5 / a-b-c) |
//+------------------------------------------------------------------+
void AnalyzeElliottDualSwings()
{
   ZeroMemory(g_ElliottState);
   g_ElliottState.isADXValid = ValidateADXTrend();

   if(!InpEnableElliottWave || g_MarketTrend != TREND_BULLISH)
   {
      g_ElliottState.statusStr = (g_MarketTrend == TREND_BEARISH) ? "BEARISH WAVE (พักสวิง)" : "รอสวิง P0 ➔ P1 ⏳";
      return;
   }

   // 1. Assign Major Swings
   g_ElliottState.P0 = (g_PrevSwingLow.price > 0 && g_PrevSwingLow.time < g_LastSwingHigh.time) ? g_PrevSwingLow : g_LastSwingLow;
   g_ElliottState.P1 = g_LastSwingHigh;
   g_ElliottState.P2 = g_LastSwingLow;

   double majorRange = g_ElliottState.P1.price - g_ElliottState.P0.price;
   if(majorRange <= 0)
   {
      g_ElliottState.statusStr = "รอสวิง P0 ➔ P1 ⏳";
      return;
   }

   // 2. Check Golden Retracement Zone (61.8% - 78.5%)
   double ask = m_symbol.Ask();
   double p618 = g_ElliottState.P1.price - (majorRange * 0.618);
   double p785 = g_ElliottState.P1.price - (majorRange * 0.785);

   g_ElliottState.isImpulseValid = true; // P0 -> P1 forms verified major impulse

   // Check Correction Wave c = P2
   if(ask <= p618 + (30 * _Point) && ask >= p785 - (50 * _Point))
   {
      g_ElliottState.isCorrectionValid = true;
      g_ElliottState.isCConfirmed      = true;
      g_ElliottState.statusStr         = StringFormat("c = P2 (Buy Zone 🎯 %.2f - %.2f)", p785, p618);
   }
   else if(ask > p618)
   {
      g_ElliottState.statusStr = StringFormat("คลื่นย่อ a-b (ย่อหา P2 @ %.2f) ⏳", p618);
   }
   else
   {
      g_ElliottState.statusStr = "ทดสอบแนวรับลึก P0 🛡️";
   }
}

//+------------------------------------------------------------------+
//| DRAW ELLIOTT WAVE DUAL SWING VISUALS ON CHART                    |
//+------------------------------------------------------------------+
void DrawElliottVisuals()
{
   if(!InpEnableElliottWave || !InpShowElliottVisuals)
      return;

   double vOffset = 80 * _Point;
   if(InpUseDynamicATR && m_hATR != INVALID_HANDLE)
   {
      double atrVal[1];
      if(CopyBuffer(m_hATR, 0, 0, 1, atrVal) > 0)
         vOffset = MathMax(vOffset, atrVal[0] * 0.45);
   }

   // 1. Draw Major Swing P0 -> P1
   if(g_ElliottState.P0.price > 0 && g_ElliottState.P1.price > 0 && g_ElliottState.P1.time > g_ElliottState.P0.time)
   {
      string p01Line = GUI_PREFIX + "ELLIOTT_P0_P1";
      if(ObjectFind(0, p01Line) < 0)
         ObjectCreate(0, p01Line, OBJ_TREND, 0, g_ElliottState.P0.time, g_ElliottState.P0.price, g_ElliottState.P1.time, g_ElliottState.P1.price);
      else
      {
         ObjectSetInteger(0, p01Line, OBJPROP_TIME, 0, g_ElliottState.P0.time);
         ObjectSetDouble(0, p01Line, OBJPROP_PRICE, 0, g_ElliottState.P0.price);
         ObjectSetInteger(0, p01Line, OBJPROP_TIME, 1, g_ElliottState.P1.time);
         ObjectSetDouble(0, p01Line, OBJPROP_PRICE, 1, g_ElliottState.P1.price);
      }
      ObjectSetInteger(0, p01Line, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, p01Line, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, p01Line, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, p01Line, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, p01Line, OBJPROP_BACK, true);
      ObjectSetInteger(0, p01Line, OBJPROP_ZORDER, 0);

      // P0 Badge
      string p0Lbl = GUI_PREFIX + "ELLIOTT_P0_LBL";
      if(ObjectFind(0, p0Lbl) < 0)
         ObjectCreate(0, p0Lbl, OBJ_TEXT, 0, g_ElliottState.P0.time, g_ElliottState.P0.price - vOffset);
      else
      {
         ObjectSetInteger(0, p0Lbl, OBJPROP_TIME, g_ElliottState.P0.time);
         ObjectSetDouble(0, p0Lbl, OBJPROP_PRICE, g_ElliottState.P0.price - vOffset);
      }
      ObjectSetString(0, p0Lbl, OBJPROP_TEXT, " P0 (Start) ");
      ObjectSetString(0, p0Lbl, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, p0Lbl, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, p0Lbl, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, p0Lbl, OBJPROP_ANCHOR, ANCHOR_UPPER);
      ObjectSetInteger(0, p0Lbl, OBJPROP_BACK, true);
      ObjectSetInteger(0, p0Lbl, OBJPROP_ZORDER, 0);

      // P1 Badge
      string p1Lbl = GUI_PREFIX + "ELLIOTT_P1_LBL";
      if(ObjectFind(0, p1Lbl) < 0)
         ObjectCreate(0, p1Lbl, OBJ_TEXT, 0, g_ElliottState.P1.time, g_ElliottState.P1.price + vOffset);
      else
      {
         ObjectSetInteger(0, p1Lbl, OBJPROP_TIME, g_ElliottState.P1.time);
         ObjectSetDouble(0, p1Lbl, OBJPROP_PRICE, g_ElliottState.P1.price + vOffset);
      }
      ObjectSetString(0, p1Lbl, OBJPROP_TEXT, " P1 ▲ ");
      ObjectSetString(0, p1Lbl, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, p1Lbl, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, p1Lbl, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, p1Lbl, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
      ObjectSetInteger(0, p1Lbl, OBJPROP_BACK, true);
      ObjectSetInteger(0, p1Lbl, OBJPROP_ZORDER, 0);
   }

   // 2. Draw Correction P1 -> P2
   if(g_ElliottState.P1.price > 0 && g_ElliottState.P2.price > 0 && g_ElliottState.P2.time > g_ElliottState.P1.time)
   {
      string p12Line = GUI_PREFIX + "ELLIOTT_P1_P2";
      if(ObjectFind(0, p12Line) < 0)
         ObjectCreate(0, p12Line, OBJ_TREND, 0, g_ElliottState.P1.time, g_ElliottState.P1.price, g_ElliottState.P2.time, g_ElliottState.P2.price);
      else
      {
         ObjectSetInteger(0, p12Line, OBJPROP_TIME, 0, g_ElliottState.P1.time);
         ObjectSetDouble(0, p12Line, OBJPROP_PRICE, 0, g_ElliottState.P1.price);
         ObjectSetInteger(0, p12Line, OBJPROP_TIME, 1, g_ElliottState.P2.time);
         ObjectSetDouble(0, p12Line, OBJPROP_PRICE, 1, g_ElliottState.P2.price);
      }
      ObjectSetInteger(0, p12Line, OBJPROP_COLOR, clrAqua);
      ObjectSetInteger(0, p12Line, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, p12Line, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, p12Line, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, p12Line, OBJPROP_BACK, true);
      ObjectSetInteger(0, p12Line, OBJPROP_ZORDER, 0);

      // c = P2 Badge
      string p2Lbl = GUI_PREFIX + "ELLIOTT_P2_LBL";
      if(ObjectFind(0, p2Lbl) < 0)
         ObjectCreate(0, p2Lbl, OBJ_TEXT, 0, g_ElliottState.P2.time, g_ElliottState.P2.price - vOffset);
      else
      {
         ObjectSetInteger(0, p2Lbl, OBJPROP_TIME, g_ElliottState.P2.time);
         ObjectSetDouble(0, p2Lbl, OBJPROP_PRICE, g_ElliottState.P2.price - vOffset);
      }
      ObjectSetString(0, p2Lbl, OBJPROP_TEXT, " c = P2 (Buy Zone 🎯) ");
      ObjectSetString(0, p2Lbl, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, p2Lbl, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, p2Lbl, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, p2Lbl, OBJPROP_ANCHOR, ANCHOR_UPPER);
      ObjectSetInteger(0, p2Lbl, OBJPROP_BACK, true);
      ObjectSetInteger(0, p2Lbl, OBJPROP_ZORDER, 0);
   }
}

void RemoveVisualDrawings()
{
   RemoveActivePlanVisuals();
   ObjectsDeleteAll(0, GUI_PREFIX + "VIS_");
   ObjectsDeleteAll(0, GUI_PREFIX + "SMC_");
   ObjectsDeleteAll(0, GUI_PREFIX + "ELLIOTT_");
   ObjectsDeleteAll(0, GUI_PREFIX + "LRL_");
   ObjectsDeleteAll(0, GUI_PREFIX + "LQ_");
   ObjectsDeleteAll(0, GUI_PREFIX + "ATH_");
   ObjectsDeleteAll(0, GUI_PREFIX + "ASIAN_");
   ObjectsDeleteAll(0, GUI_PREFIX + "CME_");
   ObjectsDeleteAll(0, GUI_PREFIX + "ABCD_");
   ObjectsDeleteAll(0, GUI_PREFIX + "EMA14_");
   ObjectsDeleteAll(0, GUI_PREFIX + "EMA200_");
}

//+------------------------------------------------------------------+
//| 16. GUI OBJECT CREATION HELPERS                                  |
//+------------------------------------------------------------------+
void CreateRectLabel(string name, int x, int y, int w, int h, color bg, color border, int borderWidth=1)
{
   string objName = GUI_PREFIX + name;
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 10);
}

void CreateLabel(string name, int x, int y, string text, string font="Segoe UI", int size=9, color col=clrWhite)
{
   string objName = GUI_PREFIX + name;
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 50);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color bg, color textCol=clrWhite)
{
   string objName = GUI_PREFIX + name;
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetString(0, objName, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, textCol);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 200);
}

void CreateEdit(string name, int x, int y, int w, int h, string text, color bg, color textCol=clrLime)
{
   string objName = GUI_PREFIX + name;
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_EDIT, 0, 0, 0);

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, textCol);
   ObjectSetInteger(0, objName, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 200);
}

void UpdateButtonState(string name, string text, color bg)
{
   string objName = GUI_PREFIX + name;
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);
}

void DestroyGUI()
{
   ObjectsDeleteAll(0, GUI_PREFIX);
   ObjectsDeleteAll(0, "GTG_");
   ObjectsDeleteAll(0, "btn_tf_toggle");
   ObjectDelete(0, "UI_Account_Type");
}

//+------------------------------------------------------------------+
//| 17. UNIVERSAL AUTO SYMBOL & MULTI-ASSET ADAPTATION ENGINE        |
//+------------------------------------------------------------------+
void AutoDetectAssetProfile()
{
   string sym = _Symbol;
   StringToUpper(sym);

   // 1. GOLD Detection
   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
   {
      g_AssetProfile.assetType     = ASSET_GOLD;
      g_AssetProfile.categoryName  = "GOLD (ทองคำ)";
      g_AssetProfile.iconStr       = "🥇";
      g_AssetProfile.maxSpread     = InpMaxSpreadPoints;
      g_AssetProfile.minSwing      = InpMinSwingPoints;
      g_AssetProfile.fallbackSL    = InpFallbackSL_Points;
      g_AssetProfile.fallbackTP    = InpFallbackTP_Points;
      g_AssetProfile.spikeMinPts   = InpSpikeMinPoints;
      g_AssetProfile.newsBodyPts   = 1500;
      g_AssetProfile.beTrigger     = InpBreakEvenTrigger;
      g_AssetProfile.beLock        = InpBreakEvenLock;
      g_AssetProfile.trailStart    = InpTrailingStart;
      g_AssetProfile.trailDist     = InpTrailingDist;
      g_AssetProfile.trailStep     = InpTrailingStep;
   }
   // 2. SILVER Detection
   else if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
   {
      g_AssetProfile.assetType     = ASSET_SILVER;
      g_AssetProfile.categoryName  = "SILVER (แร่เงิน)";
      g_AssetProfile.iconStr       = "🥈";
      g_AssetProfile.maxSpread     = 40;
      g_AssetProfile.minSwing      = 150;
      g_AssetProfile.fallbackSL    = 300;
      g_AssetProfile.fallbackTP    = 900;
      g_AssetProfile.spikeMinPts   = 250;
      g_AssetProfile.newsBodyPts   = 1000;
      g_AssetProfile.beTrigger     = 200;
      g_AssetProfile.beLock        = 40;
      g_AssetProfile.trailStart    = 300;
      g_AssetProfile.trailStep     = 100;
   }
   // 3. CRYPTO Detection
   else if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 || StringFind(sym, "SOL") >= 0 || StringFind(sym, "CRYPTO") >= 0 || StringFind(sym, "BITCOIN") >= 0)
   {
      g_AssetProfile.assetType     = ASSET_CRYPTO;
      g_AssetProfile.categoryName  = "CRYPTO (คริปโต)";
      g_AssetProfile.iconStr       = "₿";
      g_AssetProfile.maxSpread     = 5000;
      g_AssetProfile.minSwing      = 25000;
      g_AssetProfile.fallbackSL    = 30000;
      g_AssetProfile.fallbackTP    = 90000;
      g_AssetProfile.spikeMinPts   = 35000;
      g_AssetProfile.newsBodyPts   = 80000;
      g_AssetProfile.beTrigger     = 20000;
      g_AssetProfile.beLock        = 3000;
      g_AssetProfile.trailStart    = 30000;
      g_AssetProfile.trailStep     = 10000;
   }
   // 4. INDICES Detection
   else if(StringFind(sym, "US30") >= 0 || StringFind(sym, "NAS") >= 0 || StringFind(sym, "USTEC") >= 0 || StringFind(sym, "GER") >= 0 || StringFind(sym, "DAX") >= 0 || StringFind(sym, "SPX") >= 0 || StringFind(sym, "WS30") >= 0)
   {
      g_AssetProfile.assetType     = ASSET_INDEX;
      g_AssetProfile.categoryName  = "INDICES (ดัชนี)";
      g_AssetProfile.iconStr       = "📊";
      g_AssetProfile.maxSpread     = 450;
      g_AssetProfile.minSwing      = 2000;
      g_AssetProfile.fallbackSL    = 2500;
      g_AssetProfile.fallbackTP    = 7500;
      g_AssetProfile.spikeMinPts   = 2500;
      g_AssetProfile.newsBodyPts   = 6000;
      g_AssetProfile.beTrigger     = 1800;
      g_AssetProfile.beLock        = 300;
      g_AssetProfile.trailStart    = 2500;
      g_AssetProfile.trailStep     = 800;
   }
   // 5. FOREX Detection (EUR, GBP, JPY, AUD, CAD, CHF, NZD)
   else
   {
      g_AssetProfile.assetType     = ASSET_FOREX;
      g_AssetProfile.categoryName  = "FOREX (คู่เงิน)";
      g_AssetProfile.iconStr       = "💱";
      g_AssetProfile.maxSpread     = 30;
      g_AssetProfile.minSwing      = 120;
      g_AssetProfile.fallbackSL    = 180;
      g_AssetProfile.fallbackTP    = 500;
      g_AssetProfile.spikeMinPts   = 150;
      g_AssetProfile.newsBodyPts   = 500;
      g_AssetProfile.beTrigger     = 150;
      g_AssetProfile.beLock        = 25;
      g_AssetProfile.trailStart    = 200;
      g_AssetProfile.trailStep     = 70;
   }
}

//+------------------------------------------------------------------+
//| 18. IN-EA REMOTE AUTO-UPDATER ENGINE                             |
//+------------------------------------------------------------------+
string ExtractJsonValue(const string &json, const string &key)
{
   string searchKey = "\"" + key + "\"";
   int pos = StringFind(json, searchKey);
   if(pos < 0) return "";
   
   int colonPos = StringFind(json, ":", pos);
   if(colonPos < 0) return "";
   
   int quoteStart = StringFind(json, "\"", colonPos);
   if(quoteStart < 0) return "";
   
   int quoteEnd = StringFind(json, "\"", quoteStart + 1);
   if(quoteEnd < 0) return "";
   
   return StringSubstr(json, quoteStart + 1, quoteEnd - quoteStart - 1);
}

void CheckRemoteUpdate(bool isManual)
{
   g_LastUpdateCheck = TimeCurrent();
   char postData[], resultData[];
   string headers;
   
   ResetLastError();
   int res = WebRequest("GET", UPDATE_MANIFEST_URL, NULL, NULL, 5000, postData, 0, resultData, headers);
   
   if(res == 200)
   {
      string json = CharArrayToString(resultData);
      string latest = ExtractJsonValue(json, "latest_version");
      string dlUrl  = ExtractJsonValue(json, "download_url");
      string notes  = ExtractJsonValue(json, "changelog");
      
      if(StringLen(latest) > 0)
         g_LatestVersion = latest;
      if(StringLen(dlUrl) > 0)
         g_DownloadUrl = dlUrl;
      if(StringLen(notes) > 0)
         g_ReleaseNotes = notes;
         
      if(StringCompare(g_LatestVersion, BOT_VERSION) > 0)
      {
         g_UpdateAvailable = true;
         g_UpdateStatusText = StringFormat("ðŸš€ à¸­à¸±à¸›à¹€à¸”à¸• v%s", g_LatestVersion);
         g_UpdateStatusText = StringFormat("ðŸš€ à¸­à¸±à¸›à¹€à¸”à¸• v%s", g_LatestVersion);
         ObjectSetInteger(0, GUI_PREFIX + "HUD_BTN_UPDATE", OBJPROP_COLOR, clrWhite);
         ChartRedraw();
         
         Print("🔔 [AUTO-UPDATER] ตรวจพบเวอร์ชันใหม่: v", g_LatestVersion, " (เวอร์ชันปัจจุบัน: v", BOT_VERSION, ")");
         if(isManual)
         {
            Alert("🔔 มีเวอร์ชันใหม่ v", g_LatestVersion, " พร้อมให้อัปเดต!\nคลิกที่ปุ่ม [🚀 อัปเดต v", g_LatestVersion, "] บนหน้าจอกราฟเพื่อดาวน์โหลดทันที");
         }
      }
      else
      {
         g_UpdateAvailable = false;
         g_UpdateStatusText = "v8.05 â— à¸¥à¹ˆà¸²à¸ªà¸¸à¸”";
         g_UpdateStatusText = "v8.05 â— à¸¥à¹ˆà¸²à¸ªà¸¸à¸”";
         ObjectSetInteger(0, GUI_PREFIX + "HUD_BTN_UPDATE", OBJPROP_COLOR, clrAqua);
         ChartRedraw();
         
         if(isManual)
         {
            Alert("✅ คุณกำลังใช้งานเวอร์ชันล่าสุดอยู่แล้ว (v", BOT_VERSION, ")");
         }
      }
   }
   else
   {
      int err = GetLastError();
      Print("⚠️ [AUTO-UPDATER] ตรวจสอบอัปเดตไม่สำเร็จ (HTTP: ", res, ", Err: ", err, ")");
      if(isManual)
      {
         if(err == 4060 || res == -1)
         {
            Alert("⚠️ MT5 ยังไม่อนุญาตการเชื่อมต่อ WebRequest!\n\nวิธีเปิดใช้งาน:\n1. กด Ctrl+O -> ไปที่แถบ Expert Advisors\n2. ติ๊กถูก 'Allow WebRequest for listed URL'\n3. เพิ่ม URL: https://raw.githubusercontent.com");
         }
         else if(res == 404)
         {
            Alert("⚠️ [HTTP 404] ไม่สามารถเข้าถึงไฟล์ version.json ได้!\nสาเหตุ: GitHub Repository เป็น Private ทำให้บุคคลภายนอก/MT5 ดึงข้อมูลไม่ได้");
         }
         else
         {
            Alert(StringFormat("⚠️ ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ (HTTP: %d, Err: %d)", res, err));
         }
      }
   }
}

void TriggerAutoUpdate()
{
   if(StringLen(g_DownloadUrl) == 0)
      g_DownloadUrl = UPDATE_EX5_FALLBACK_URL;
      
   UpdateButtonState("HUD_BTN_UPDATE", "⏳ กำลังโหลด...", C'180,100,0');
   ObjectSetInteger(0, GUI_PREFIX + "HUD_BTN_UPDATE", OBJPROP_COLOR, clrWhite);
   ChartRedraw();
   
   char postData[], ex5Data[];
   string headers;
   ResetLastError();
   
   int res = WebRequest("GET", g_DownloadUrl, NULL, NULL, 15000, postData, 0, ex5Data, headers);
   
   if(res == 200 && ArraySize(ex5Data) > 50000)
   {
      // Save binary safely into MQL5\Files (MT5 sandbox restricts .ex5 extension in FileOpen)
      int fileHandle = FileOpen("Good_Trade_Gold_EA_Update.bin", FILE_WRITE|FILE_BIN);
      if(fileHandle != INVALID_HANDLE)
      {
         FileWriteArray(fileHandle, ex5Data);
         FileClose(fileHandle);
      }
      
      PlaySound("ok.wav");
      Alert("🎉 [UPDATE INFO] มีเวอร์ชันใหม่ v", g_LatestVersion, " พร้อมใช้งาน!\n(ไฟล์ .ex5 ล่าสุดถูกส่งมอบผ่าน Git/Releases เรียบร้อยแล้วครับ)");
      
      g_UpdateAvailable = false;
      g_UpdateStatusText = "v8.05 â— à¸¥à¹ˆà¸²à¸ªà¸¸à¸”";
      g_UpdateStatusText = "v8.05 â— à¸¥à¹ˆà¸²à¸ªà¸¸à¸”";
      ObjectSetInteger(0, GUI_PREFIX + "HUD_BTN_UPDATE", OBJPROP_COLOR, clrMediumSpringGreen);
      ChartRedraw();
      return;
   }
   else
   {
      int err = GetLastError();
      Alert("❌ ดาวน์โหลดไม่สำเร็จ (HTTP: ", res, ", Err: ", err, ")\nโปรดตรวจเช็คอินเทอร์เน็ตหรือ Allow WebRequest ใน MT5");
      UpdateButtonState("HUD_BTN_UPDATE", "❌ ลองใหม่อีกครั้ง", C'150,30,30');
      ChartRedraw();
   }
}
