//+------------------------------------------------------------------+
//|                                            DeungDang_Trade.mq5   |
//|                    Good Trade Gold & Kamnan Ball Trading Suite   |
//|               Visual Training Co-Pilot & Manual Precision Radar  |
//|             (ตัวชี้เป้าและฝึกดูสิ่งที่กำนันบอลสอน - ไม่ใช่บอทออโต้)            |
//+------------------------------------------------------------------+
#property copyright   "Good Trade Gold & Kamnan Ball Trading Suite"
#property link        "https://github.com/eaeybaent51-creator/Good"
#property version     "2.39"
#property description "DeungDang_Trade V2.39 - All-TF Real-Time CF/Retest Arrow Pointers, Auto Sideway Range Box & 3-Regime Adaptive Suite"
#property description "CF M1 เสมอ (เส้นเกาะปลายไส้ที่สั้นที่สุด + แท่งกลืนกิน), คำนวณ Lot จากความเสี่ยง ÷ SL จุด (เก็บ 3R), Gann Grid 45°, Phase Space Energy (x, v, A), VSL Lock Floor (+10 pts), Samurai MTF Strip, CME Options Wall, สปีดไลน์, คลื่น A-B-C-D, กลับตัวหลอก, Demand/Supply, ICT Unicorn"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

#resource "\\Files\\triam_buy.wav"
#resource "\\Files\\triam_sell.wav"

//+------------------------------------------------------------------+
//| MACROS & ENUMS                                                   |
//+------------------------------------------------------------------+
#define GUI_PREFIX "DT_"
#define APP_VERSION "2.40"

enum ENUM_ASSET_CLASS
{
   ASSET_GOLD   = 0, // ทองคำ (XAUUSD, GOLD)
   ASSET_CRYPTO = 1, // คริปโต (BTCUSD, ETHUSD)
   ASSET_FOREX  = 2, // คู่เงิน Forex (EURUSD, GBPUSD ฯลฯ)
   ASSET_INDEX  = 3  // ดัชนี (US30, NAS100 ฯลฯ)
};

enum ENUM_SNIPER_STAGE
{
   STAGE_WATCH_TREND = 0, // 1. กำลังวิ่งในสปีดไลน์ / รอกราฟฟอร์มตัว
   STAGE_ALERT_BREAK = 1, // 2. ปริ้นสปีด + ขาดการทำนิวไฮ/นิวโล (เตรียมกด BUY / SELL)
   STAGE_IN_ZONE     = 2, // 3. กราฟย้อนเด้ง/ย่อเข้าโซนซุ่มยิง (แตะโซน + EMA 14)
   STAGE_TRIGGER_PA  = 3  // 4. แท่งเทียนทิ้งไส้คอนเฟิร์ม (กดได้ทันที!)
};

enum ENUM_SW_REGIME
{
   SW_NONE       = 0, // สภาวะเทรนด์ปกติ
   SW_UP_ACCUM   = 1, // SW Up: กินดีมานด์ตัวเอง ➔ เตรียมทุบ SELL
   SW_DOWN_DIST  = 2, // SW Down: กินซัพพลายตัวเอง ➔ เตรียมพุ่ง BUY
   SW_HORIZONTAL = 3  // SW ออกข้าง (ตีปิงปอง) ➔ นั่งทับมือ ห้ามเทรด!
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== [ 1. การบริหารการออกไม้ด้วยมือ (Manual Cockpit) ] ==="
input ulong    InpMagicNumber       = 789100;     // Magic Number
input double   InpDefaultLot        = 0.01;       // ขนาด Lot เริ่มต้น
input int      InpSlippagePts       = 30;         // Slippage (จุด)
input int      InpSharedSL_Gold     = 1000;       // ทองคำ: ระยะ SL มาตรฐานกำนันบอล (จุด)
input double   InpSharedSL_CryptoPct= 1.20;       // คริปโต: ระยะ SL คิดเป็น % ของราคา (เช่น 1.2%)
input int      InpSharedSL_Forex    = 250;        // Forex: ระยะ SL มาตรฐาน (จุด)
input int      InpBE_BufferPts      = 50;         // บังหน้าทุน BE: กำไรเผื่อค่าสเปรด (จุด)

input group "=== [ 2. การวิเคราะห์ตามตำรากำนันบอล & พี่ชนัฐ ] ==="
input int      InpSwingBars         = 3;          // จำนวนแท่งตรวจสอบสวิงซ้าย/ขวา
input int      InpMaxBarsScan       = 150;        // จำนวนแท่งย้อนหลังที่สแกน
input int      InpEMA_Period        = 14;         // เส้น EMA พี่ชนัฐ (ค่าเริ่มต้น: 14)
input double   InpHiddenBladeRatio  = 0.50;       // สัดส่วนไส้เทียน Hidden Blade (50%)
input bool     InpEnableSoundAlert  = true;       // เปิดเสียงเตือนเมื่อแท่งเทียนคอนเฟิร์ม (ติ๊ง!)

input group "=== [ 3. แถบแท่งเทียน MTF SAMURAI (SAMURAI MTF STRIP) ] ==="
input bool     InpUseSamuraiMTFStrip= true;       // เปิดแถบแท่งเทียน 9 Timeframes ของ Samurai ใน Subwindow
input bool     InpSamuraiGoldenAlert= true;       // ไฟเตือนสีทอง (Golden Flash Alert เมื่อเวลาแท่ง <= 15 วิ)

input group "=== [ 4. กรอบราคา SAMURAI EXACT WICKS LINEAR REGRESSION ] ==="
input bool     InpEnableLRLChannel  = true;       // เปิดแสดงกรอบราคา Linear Regression Channel
input int      InpLRL_Bars          = 100;        // จำนวนแท่งคำนวณกรอบ Channel (100 แท่ง)

input group "=== [ 5. การแสดงผลบนชาร์ต (Visual HUD & Objects) ] ==="
input bool     InpShowHUD           = true;       // แสดงแผงแดชบอร์ดสรุปผล
input int      InpHUD_X             = 20;         // ตำแหน่งแผงแดชบอร์ด แกน X
input int      InpHUD_Y             = 35;         // ตำแหน่งแผงแดชบอร์ด แกน Y
input color    InpColorSpeedlineUp  = clrDodgerBlue; // สีเส้นสปีดไลน์ขาขึ้น
input color    InpColorSpeedlineDn  = clrOrangeRed;  // สีเส้นสปีดไลน์ขาลง
input color    InpColorDemandZone    = C'20,60,140';  // สี Demand Zone (DZ) ทั่วไป
input color    InpColorSupplyZone    = C'140,25,50';  // สี Supply Zone (SZ) ทั่วไป
input color    InpColorConfluenceDZ  = C'0,140,255';  // สี Confluence DZ (รวมร่างหลาย TF)
input color    InpColorConfluenceSZ  = C'235,45,95';  // สี Confluence SZ (รวมร่างหลาย TF)
input bool     InpShowFreshZonesOnly = true;          // แสดงเฉพาะโซนสดใหม่ที่ยังไม่ถูกใช้ (Fresh Only)
input int      InpMaxHTFZonesPerSide = 4;             // จำนวนโซน TF ใหญ่ต่อฝั่ง (H1/H4/D1/W1/MN1)
input int      InpMaxLTFZonesPerSide = 2;             // จำนวนโซน TF เล็กต่อฝั่ง (M1-M30)
input bool     InpEnableZoneFusion   = true;          // รวมร่างโซนซ้อนทับใน TF เล็ก (Confluence Fusion)
input color    InpColorHiddenBlade   = clrGold;       // สีเส้น Hidden Blade 50%
input color    InpColorUnicorn       = C'147,112,219';// สีกล่อง ICT Unicorn (Medium Purple)

input group "=== [ 6. โครงสร้าง SMC & MULTI-TF EMA 14 (พี่ชนัฐ) ] ==="
input bool     InpShowMultiTF_EMA14  = true;           // แสดงเส้นประ Multi-TF EMA 14 บนกราฟ (ทุก TF)
input bool     InpShowEMA14_M1       = true;           // แสดง EMA 14 [M1]
input bool     InpShowEMA14_M5       = true;           // แสดง EMA 14 [M5]
input bool     InpShowEMA14_M15      = true;           // แสดง EMA 14 [M15]
input bool     InpShowEMA14_M30      = true;           // แสดง EMA 14 [M30]
input bool     InpShowEMA14_H1       = true;           // แสดง EMA 14 [H1]
input bool     InpShowEMA14_H4       = true;           // แสดง EMA 14 [H4]
input bool     InpShowEMA14_D1       = true;           // แสดง EMA 14 [D1]
input bool     InpUseTF_Colors_EMA14 = true;           // แยกสีเฉพาะแต่ละ TF สไตล์พี่ชนัฐ (Color-Coded)
input color    InpColorEMA14_Lines   = C'185,100,255'; // สีเส้นประ EMA 14 สำรอง (กรณีไม่แยกสี)
input bool     InpShowSMC_BOS        = true;           // แสดงเส้นและป้าย Break of Structure (BOS / CHoCH)
input bool     InpShowSMC_StrongWeak = true;           // แสดงป้าย Weak High / Strong Low บนสวิง

input group "=== [ 7. ระบบเสียงพูดแจ้งเตือน (VOICE ALERTS) ] ==="
input bool     InpEnableVoiceAlert   = true;           // 🔊 เปิดเสียงพูดเตือน (เตรียม Buy นะๆ / เตรียม Sell นะๆ)

input group "=== [ 8. ควบคุมความเร็วหน้าจอและความนุ่มนวล (Zero-Flicker & Refresh Rate) ] ==="
input int      InpGUI_RefreshRateMs  = 1000;           // ความเร็วอัปเดตหน้าจอ (ms: 500=ลื่นไหล, 1000=มาตรฐานนิ่งสนิท, 2000=สบายตาสูงสุด)
input int      InpTimer_Seconds      = 1;              // รอบนับถอยหลังแท่งเทียน Subwindow (วินาที: 1 วินาที สบายตา ไม่กระตุก)

input group "=== [ 9. กำแพงสถาบัน CME OPTIONS WALL & OPEN INTEREST MATRIX ] ==="
input bool     InpUseCME_OI          = true;             // 🏛️ เปิดระบบเรดาร์กำแพงเจ้ามือ CME Options Wall
input bool     InpCME_ShowMajorWalls = true;             // 🔴/🔵 แสดงกำแพงหลัก (00 & Mega Clusters)
input bool     InpCME_ShowHalfCentury= true;             // 🔶/🔷 แสดงด่านครึ่งร้อย (.50)
input bool     InpCME_ShowSpeedBumps = true;             // 🔸/🔹 แสดงด่านลูกระนาดระหว่างทาง (OI >= 110+)
input int      InpCME_MinOI_Threshold= 110;              // เกณฑ์สัญญาคงค้างขั้นต่ำสำหรับด่านย่อย (110+ OI)
input int      InpCME_ProximityPts   = 2500;             // รัศมีดักจับด่านรอบราคาปัจจุบัน (Points: 2500 pts = $25.00)
input color    InpColorCME_Resistance= C'255,65,85';     // 🔴 สีแนวต้าน (Call Walls / Upper Levels)
input color    InpColorCME_Support   = C'30,170,255';    // 🔵 สีแนวรับ (Put Walls / Lower Levels)

input group "=== [ 10. ระบบคลื่น A-B-C-D & ดักจับกลับตัวหลอก (EP เสริม 4) ] ==="
input bool     InpUseWave_D_Targets  = true;             // 🎯 เปิดระบบคำนวณและวาดเป้าหมายขา D (127.2% - 261.8%)
input bool     InpUseFakeoutTrapRadar= true;             // ⚡ เปิดเรดาร์ตรวจจับ "กลับตัวลงหลอก / กลับตัวขึ้นหลอก"
input bool     InpDrawWave_D_Lines   = true;             // 📐 แสดงเส้นระดับเป้าหมายขา D บนชาร์ต
input color    InpColorWave_D_Target = C'255,215,0';     // 🟡 สีเป้าหมายหลักขา D (161.8% Golden Target)
input color    InpColorFakeoutAlert  = C'0,225,255';     // 💠 สีแจ้งเตือนกับดักกลับตัวหลอก (Cyan Alert)

input group "=== [ 11. ตาข่ายสมดุลและเรดาร์พลังงานคลื่น (GANN & WAVE ENERGY RADAR) ] ==="
input bool     InpUseGannEquilibriumGrid = false;          // 🌐 เปิดตารางตาข่ายสมดุลราคาและเวลา (Gann Equilibrium Grid 45°)
input color    InpColorGannGrid          = C'32,85,160';  // 🔷 สีเส้นตาข่ายสมดุล (ฟ้าครามโปร่งสบายตา)
input ENUM_LINE_STYLE InpStyleGannGrid   = STYLE_DOT;     // รูปแบบเส้นตาข่าย (STYLE_DOT เส้นประนุ่มนวล / STYLE_SOLID)
input double   InpGann_ScalePoints       = 0.0;           // สเกลความกว้างตาข่าย (จุดต่อแท่ง: 0 = อัตโนมัติตามฐานสิบ)
input bool     InpShowGannZeroLine       = false;          // ⚖️ แสดงเส้นระดับจุดสมดุลเลขกลมกลางรอบคลื่น (Zero Origin Line)
input color    InpColorGannZeroLine      = C'65,145,225'; // 🔵 สีเส้นจุดสมดุลเลขกลม (DodgerBlue)
input bool     InpUseWaveEnergyRadar     = true;          // ⚡ เปิดเรดาร์คำนวณพลังงานคลื่นและจุดหมดแรง (Phase Space v≈0)
input bool     InpUseVSL_LockFloor       = false;         // 🛡️ ปิดระบบล็อกหน้าทุนอัตโนมัติถาวร (ให้ผู้เทรดกดปุ่ม [บังทุน] เองเมื่อต้องการ)
input bool     InpSyncSharedSL           = false;         // ⛔ ปิดระบบซิงค์ SL ร่วมกันอัตโนมัติถาวร (ห้ามแตะต้องไม้ผู้เทรดเด็ดขาด)
input int      InpVSL_TriggerProfitPts   = 200;           // กำไรขั้นต่ำก่อนเปิดระบบหมดแรงล็อกทุน (จุด: 200 pts)
input int      InpVSL_FloorPts           = 10;            // ระยะล็อกกำไรหน้าทุนเมื่อราคาหมดแรง (จุด: +10 pts)

input group "=== [ 12. ระบบโครงสร้าง SMC สไตล์ อ.เดช (TRUE SWING, LQ & 1R:3R) ] ==="
input bool            InpUseDTD_CF_M1           = true;          // 🎯 เปิดเรดาร์คอนเฟิร์ม CF & โครงสร้าง อ.เดช (ทุก TF)
input ENUM_TIMEFRAMES InpDTD_TF                 = PERIOD_CURRENT;// ⏱️ ไทม์เฟรมวิเคราะห์โครงสร้าง (PERIOD_CURRENT = ปรับตามชาร์ตทุก TF อัตโนมัติ!)
input bool            InpDrawDTD_M1_Visuals     = true;          // 📐 วาดเส้นระดับ "ขึ้น"/"ลง" & กล่องวัดระยะ 1R:3R บนชาร์ต
input bool            InpDrawDTD_StructureLegs  = false;         // ⚡ วาดเส้นโครงสร้างสวิงซิกแซก (ปิดไว้เพื่อชาร์ตคลีน โปร่งสบายตา)
input bool            InpDrawDTD_LQ_Line        = true;          // 💧 แสดงเส้นประและป้าย '• • • LQ • • •' สไตล์ อ.เดช
input bool            InpDrawDTD_CandleStickers = true;          // 🏷️ แปะป้ายสติกเกอร์ 'RETEST' และ 'CF' บนตัวแท่งเทียนจริง
input bool            InpDrawDTD_SW_Box         = true;          // 📦 ตีกรอบคุม SW HIGH / SW LOW อัตโนมัติเมื่อตลาดเป็น Sideway (ทุก TF)
input bool            InpDTD_TradingViewStyle   = true;          // 🎨 กล่องวัดระยะ 1R:3R สไตล์ TradingView (เทา-ฟ้า โปร่งแสง)
input color           InpColorDTD_Up            = clrWhite;      // ⚪ สีเส้นและป้าย "ขึ้น" (สีขาวสว่างชัดเจน ไม่โดนพื้นหลังกลืน 100%)
input color           InpColorDTD_Down          = clrWhite;      // ⚪ สีเส้นและป้าย "ลง" (สีขาวสว่างชัดเจน ไม่โดนพื้นหลังกลืน 100%)
input int             InpDTD_LineThickness      = 2;             // 📏 ความหนาเส้น "ขึ้น" และ "ลง" บนชาร์ต (2 px คมชัด)
input double          InpDTD_RiskMoney          = 20.0;          // 💵 เงินความเสี่ยงต่อไม้ ($ หรือ USC) คำนวณ Lot = ความเสี่ยง ÷ ระยะ SL
input double          InpDTD_TargetRR           = 3.0;           // 🏆 เป้าความคุ้มค่า RR ตามสูตรอาจารย์เดช (แนะนำ 3.0 เท่า = 3R)
input int             InpDTD_SL_BufferPts       = 35;            // 🛡️ ระยะเผื่อสเปรดใต้/เหนือจุดสวิงโครงสร้าง (จุดฐาน M1)
input bool            InpRequireM15_Alignment   = true;          // 🎯 กฎเหล็ก อ.เดช: กรองทิศทางกับ TF ใหญ่กว่า (ห้ามสวนเทรนด์แม่)

input group "=== [ 13. ระบบคาดการณ์ราคา 2 ฝั่ง (BUY & SELL) & สแกนหา LQ สถาบัน ] ==="
input bool     InpUseDualForecast        = true;          // 🔮 เปิดระบบคาดการณ์ราคาพร้อมกันทั้งฝั่ง BUY และ SELL (Dual Forecast)
input bool     InpDrawDualForecastOnChart= true;          // 📐 วาดเส้นคาดการณ์เป้าหมายรองอีกฝั่งบนชาร์ต (Dual Target Projection)
input bool     InpUseLQ_Scanner          = true;          // 🧲 เปิดเรดาร์สแกนหาจุดสภาพคล่องที่น่าสนใจ (BSL & SSL Liquidity Scanner)
input bool     InpDrawLQ_OnChart         = true;          // 📐 วาดเส้นประและป้ายชี้เป้า BSL / SSL บนชาร์ต
input color    InpColorBSL_Pool          = C'255,95,120'; // 🔴 สีเส้นสภาพคล่องฝั่งบน BSL (จุดดักกิน SL ฝั่ง Sell)
input color    InpColorSSL_Pool          = C'50,235,150'; // 🟢 สีเส้นสภาพคล่องฝั่งล่าง SSL (จุดดักกิน SL ฝั่ง Buy)

//+------------------------------------------------------------------+
//| STRUCTS FOR MARKET ANALYSIS                                      |
//+------------------------------------------------------------------+
enum ENUM_SWING_TYPE
{
   SWING_NONE = 0,
   SWING_HH   = 1,
   SWING_HL   = 2,
   SWING_LH   = 3,
   SWING_LL   = 4
};

struct SSwing
{
   datetime        time;
   double          price;
   bool            isHigh;
   int             bar;
   ENUM_SWING_TYPE labelType;
   string          labelStr;
};

struct S_BOS_Line
{
   datetime timeStart;
   datetime timeEnd;
   double   price;
   string   tag; // "BOS" or "CHoCH"
   color    col;
   bool     isActive;
};

struct SSamuraiMTFState
{
   bool   isBullish[6];
   bool   isBearish[6];
   double momentumPct[6];
   double bullScore;
   string summaryStr; // "M1:🔴 M5:🟢 M15:🟢 M30:🟢 H1:🟢 H4:🟢"
   int    consensusDir;
   string gradeStr;
};

struct SZone
{
   datetime time;
   double   high;
   double   low;
   bool     isDemand;     // true = Demand Zone (DZ), false = Supply Zone (SZ)
   bool     isActive;
   int      touches;
   string   tfName;
   bool     isConfluence; // true = โซนที่เกิดจากการรวมร่างหลาย TF (A+ Setup)
   bool     isHTF;        // true = โซนระดับภาพใหญ่ (H1/H4/D1/W1/MN1)
   int      tfCount;      // จำนวน TF ที่ซ้อนทับกัน
   color    boxColor;     // สีของกล่องโซนตาม Timeframe แบบ Flagship EA
};

struct SHiddenBlade
{
   datetime time;
   double   price50;
   bool     isUpper;
   bool     isActive;
   string   tfName;
};

struct SAssetProfile
{
   ENUM_ASSET_CLASS assetType;
   string           name;
   string           unitStr;
   int              slPoints;
   int              tp1Points;
   int              tp2Points;
   int              tp3Points;
   int              beBuffer;
};

struct SLRLChannel
{
   double slope;
   double intercept;
   double upperDev;
   double lowerDev;
   double angle;
   double curMid;
   double curUpper;
   double curLower;
   datetime tStart;
   datetime tEnd;
   double pStartMid, pEndMid;
   double pStartUp,  pEndUp;
   double pStartDn,  pEndDn;
};

struct SCME_Level
{
   double strike;
   int    callOI;
   int    putOI;
   bool   isMajor;
   bool   isHalfCentury;
};

struct SCME_ActiveDisplay
{
   double strike;
   bool   isResistance;
   int    oiCount;
   int    levelTier;
   string labelText;
   color  lineCol;
   ENUM_LINE_STYLE lineStyle;
   int    lineWidth;
};

struct SGannWaveEnergy
{
   double   zeroPrice;          // จุดสมดุลเลขกลมกลางรอบคลื่น (Zero Origin)
   double   displacementPts;    // ระยะยืดจากจุดสมดุล (+/- จุด)
   double   displacementMoney;  // ระยะยืดคิดเป็นหน่วยราคา ($)
   double   velocityPtsSec;     // ความเร็วพุ่งตัว (จุด/วินาที)
   double   accelPtsSec2;       // ความเร่ง/การชะลอตัว (Taylor Curvature)
   double   amplitudeEnergy;    // แรงสวิงคลื่นรวม (Phase Space A(t))
   bool     isStationPoint;     // จริงเมื่อตรวจพบราคาหมดแรงที่ปลายคลื่น (v ≈ 0)
   int      stationDirection;   // +1 = หมดแรงที่ยอดดอย (ระวังร่วง/เตรียมทุบ Sell), -1 = หมดแรงที่ก้นเหว (ระวังดีด/เตรียมช้อน Buy)
   string   energyStatus;       // สถานะพลังงานคลื่นภาษาไทยเข้าใจง่าย
   color    statusColor;        // สีแสดงสถานะ
   datetime anchorTime;         // เวลาของแท่งสวิงอ้างอิง
   double   gridScale;          // สเกลจุดต่อแท่งของตาข่ายแกนน์
};

#define MAX_DTD_M1_SWINGS 8
struct SDTD_M1_Swing
{
   double   price;
   datetime time;
   int      type; // +1 = High, -1 = Low
};

struct SDTD_ConfirmState
{
   int             setupSide;          // +1 = แผน BUY, -1 = แผน SELL, 0 = รอเข้าโซน
   ENUM_TIMEFRAMES activeTF;           // ไทม์เฟรมที่กำลังวิเคราะห์ (เช่น M1, M5, M15, H1, H4, D1)
   string          tfName;             // ชื่อย่อไทม์เฟรม (เช่น "M1", "M15", "H1")
   int      m1StructDir;        // +1 = M1 เปลี่ยนเป็น "ขึ้น", -1 = M1 เปลี่ยนเป็น "ลง"
   bool     hasM1Shift;         // จริงเมื่อ M1 เปลี่ยนโครงสร้างในทิศทางเดียวกับแผนแล้ว
   double   m1ShiftBreakPrice;  // ระดับราคาที่ M1 เบรกเปลี่ยนโครงสร้าง ("ขึ้น" / "ลง")
   datetime m1ShiftTime;        // เวลาของแท่งที่เบรกโครงสร้าง M1
   double   m1SwingHighPrice;   // ระดับสวิงไฮ M1 ที่มีป้าย "ขึ้น"
   datetime m1SwingHighTime;    // เวลาสวิงไฮ M1
   double   m1SwingLowPrice;    // ระดับสวิงโลว์ M1 ที่มีป้าย "ลง"
   datetime m1SwingLowTime;     // เวลาสวิงโลว์ M1
   bool     isRetestConfirmed;  // มีการย่อรีเทสต์เส้นโครงสร้าง M1 แล้ว
   double   shortestWickPrice;  // ระดับราคาของ "ปลายไส้ที่สั้นที่สุด" ในรอบย่อตัว
   datetime shortestWickTime;   // เวลาของแท่งปลายไส้ที่สั้นที่สุด
   bool     isEngulfConfirmed;  // จริงเมื่อแท่งเทียน M1 ปิดเนื้อเทียนกลืนกินปลายไส้สั้นสุดสำเร็จ!
   double   confirmEntryPrice;  // ราคาเข้าอ้างอิงชุดคอนเฟิร์ม M1
   double   confirmSLPrice;     // ราคา SL ใต้/เหนือชุดคอนเฟิร์ม M1 (+ Buffer)
   double   confirmTP1RPrice;   // ราคา TP ที่ 1 เท่าของ SL (1R:1R)
   double   confirmTP2RPrice;   // ราคา TP ที่ 2 เท่าของ SL (2R)
   double   confirmTP3RPrice;   // ราคา TP ที่ 3 เท่าของ SL (3R แนะนำของอาจารย์เดช)
   double   slDistPoints;       // ระยะ SL ของชุดคอนเฟิร์ม M1 (จุด)
   double   tp1RDistPoints;     // ระยะ TP 1R (จุด)
   double   tp2RDistPoints;     // ระยะ TP 2R (จุด)
   double   tp3RDistPoints;     // ระยะ TP 3R (จุด)
   double   recommendedLot;     // ขนาด Lot ที่คำนวณจาก (ความเสี่ยง ÷ ระยะ SL จุด)
   string   statusText;         // ข้อความสถานะ CF M1 ภาษาไทยเข้าใจง่าย
   string   mmPlanText;         // ข้อความแผนความคุ้มค่า 3R & Lot แนะนำ
   color    statusColor;        // สีแสดงสถานะบนแดชบอร์ด

   // Dual-Directional Tracking (สแกนทั้ง BUY และ SELL ขนานกันแบบเรียลไทม์)
   bool     buyEngulfConfirmed;
   double   buyShortestWickPrice;
   datetime buyShortestWickTime;
   double   buyConfirmEntryPrice;
   double   buyConfirmSLPrice;
   double   buyConfirmTP1RPrice;
   double   buyConfirmTP2RPrice;
   double   buyConfirmTP3RPrice;
   double   buySlDistPoints;
   double   buyRecommendedLot;

   bool     sellEngulfConfirmed;
   double   sellShortestWickPrice;
   datetime sellShortestWickTime;
   double   sellConfirmEntryPrice;
   double   sellConfirmSLPrice;
   double   sellConfirmTP1RPrice;
   double   sellConfirmTP2RPrice;
   double   sellConfirmTP3RPrice;
   double   sellSlDistPoints;
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
   double   latchedSLDist;
   double   latchedLot;
   double   latchedShortestWick;
   datetime latchedRetestTime;
   double   latchedRetestPrice;
   datetime latchedConfirmTime;
   double   latchedConfirmPrice;
   double   latchedLQPrice;
   datetime latchedLQTime;
   bool     latchedLQSwept;

   // On-Candle Badges & Ajarn Dech Signature Elements
   datetime retestBarTime;               // เวลาแท่งที่ย่อเทสต์ (สำหรับแปะป้าย RETEST)
   double   retestBarPrice;              // ราคาแท่งที่ย่อเทสต์
   datetime confirmBarTime;              // เวลาแท่งที่คอนเฟิร์มกลืนกิน (สำหรับแปะป้าย CF)
   double   confirmBarPrice;             // ราคาแท่งที่คอนเฟิร์มกลืนกิน
   double   lqLinePrice;                 // ระดับราคาเส้น LQ สไตล์ อ.เดช
   datetime lqLineTime;                  // เวลาจุดกำเนิดเส้น LQ
   bool     lqIsSwept;                   // จริงเมื่อเกิดการกวาด Sweep ไส้ทะลุ
   SDTD_M1_Swing m1Swings[MAX_DTD_M1_SWINGS]; // จุดสวิงโครงสร้างสำหรับวาด Zigzag Path
   int           m1SwingCount;                // จำนวนจุดสวิงโครงสร้างที่บันทึกได้
   // Sideway Range Box & 3-Regime Adaptive Engine (รองรับทุก Timeframe อัตโนมัติ)
   int           marketRegime;        // 0 = SW (ไซด์เวย์ในกรอบ), 1 = UPTREND (เทรนด์ขาขึ้น), -1 = DOWNTREND (เทรนด์ขาลง)
   string        regimeBadgeText;     // ป้ายบอกสภาวะตลาดปัจจุบัน
   bool          swBoxActive;         // แสดงกรอบ SW HIGH / SW LOW บนกราฟ
   double        swBoxHigh;           // ขอบบนกรอบ Sideway (SW HIGH)
   double        swBoxLow;            // ขอบล่างกรอบ Sideway (SW LOW)
   double        swBoxMid;            // เส้นกึ่งกลาง 50% กรอบ Sideway (No-Trade Zone)
   datetime      swBoxStartTime;      // เวลาเริ่มกรอบ Sideway
   int           swBreakState;        // 0=ในกรอบ, 1=เบรกขึ้นจริง, -1=หลุดลงจริง, 2=Sweep ขอบบน, -2=Sweep ขอบล่าง
   string        swStatusText;        // ข้อความสถานะกรอบ SW แบบ Realtime
   double        avgBarRange;         // ระยะแท่งเทียนเฉลี่ยของ Timeframe ปัจจุบัน
};

struct SLQPool
{
   bool     isValid;
   bool     isBSL;         // true = BSL (เหนือราคา), false = SSL (ใต้ราคา)
   double   price;         // ระดับราคา LQ
   datetime time;          // เวลาเกิดสวิงหลัก
   string   tfName;        // เช่น "M15", "H1", "D1"
   string   poolType;      // เช่น "EQH (ไฮคู่แฝด)", "IDM (ล่อเม่า)", "PDH (ไฮเมื่อวาน)", "Swing High"
   string   shortTag;      // เช่น "EQH", "IDM", "PDH", "Swing"
   double   distPts;       // ระยะห่างจากราคาปัจจุบัน (จุด)
   int      score;         // คะแนนความน่าสนใจ (0-100)
   int      touches;       // จำนวนครั้งที่ทดสอบ
   bool     isSweptNow;    // เพิ่งถูกกวาดแล้วรูดไส้กลับสดๆ ร้อนๆ
};

struct SLQRadarState
{
   SLQPool  bsl1;          // พิกัด BSL อันดับ 1 (น่าสนใจและใกล้ที่สุดเหนือราคา)
   SLQPool  bsl2;          // พิกัด BSL อันดับ 2 (เป้าหมายถัดไปด้านบน)
   SLQPool  ssl1;          // พิกัด SSL อันดับ 1 (น่าสนใจและใกล้ที่สุดใต้ราคา)
   SLQPool  ssl2;          // พิกัด SSL อันดับ 2 (เป้าหมายถัดไปด้านล่าง)
   bool     hasSweepAlert; // มีการกวาด LQ สดๆ ร้อนๆ
   int      sweepSide;     // +1 = กวาด SSL ล่างแล้วดึงกลับ (เล็ง BUY), -1 = กวาด BSL บนแล้วทุบกลับ (เล็ง SELL)
   double   sweepPrice;    // ระดับราคาที่เพิ่งถูกกวาด
   string   sweepAlertStr; // ข้อความแจ้งเตือนการกวาด LQ
   string   hudBSLStr;     // ข้อความแสดงบน HUD สำหรับ BSL
   string   hudSSLStr;     // ข้อความแสดงบน HUD สำหรับ SSL
};

struct SDualForecast
{
   int      buyProbPct;
   bool     buyIsReady;
   double   buyEntryPrice;
   double   buyPullbackPrice;
   double   buySLPrice;
   double   buySLDistPts;
   double   buyTP1Price;
   double   buyTP2Price;
   double   buyTP3Price;
   double   buyLot;
   string   buyPlanLine1;
   string   buyPlanLine2;
   string   buyPlanLine3;

   int      sellProbPct;
   bool     sellIsReady;
   double   sellEntryPrice;
   double   sellPullbackPrice;
   double   sellSLPrice;
   double   sellSLDistPts;
   double   sellTP1Price;
   double   sellTP2Price;
   double   sellTP3Price;
   double   sellLot;
   string   sellPlanLine1;
   string   sellPlanLine2;
   string   sellPlanLine3;
};

//+------------------------------------------------------------------+
//| GLOBAL SYSTEM VARIABLES                                          |
//+------------------------------------------------------------------+
CTrade          m_trade;
CSymbolInfo     m_symbol;
CPositionInfo   m_position;

SAssetProfile     g_Asset;
SGannWaveEnergy   g_GannEnergy;
SDTD_ConfirmState g_DTD;
SLQRadarState     g_LQ;
SDualForecast     g_Forecast;
ENUM_SNIPER_STAGE g_SniperStage = STAGE_WATCH_TREND;
ENUM_SW_REGIME    g_Regime      = SW_NONE;

// Master Dashboard & Card Accordion States
bool            g_Dashboard_Visible = true;
bool            g_Card1_Expanded    = true;
bool            g_Card2_Expanded    = true;
bool            g_Card3_Expanded    = true;

// CME Options Matrix & Wall State
#define MAX_CME_DISPLAYS 10
SCME_ActiveDisplay g_CME_Displays[MAX_CME_DISPLAYS];
int                g_CME_DisplayCount  = 0;
double             g_CME_NearResStrike = 0.0;
double             g_CME_NearSupStrike = 0.0;
int                g_CME_NearResOI     = 0;
int                g_CME_NearSupOI     = 0;
string             g_CME_NearResStr    = "ไม่มี";
string             g_CME_NearSupStr    = "ไม่มี";

// Swings & Waves
SSwing          g_Swings[];
int             g_SwingCount = 0;

// Speedlines
bool            g_HasUpSpeedline = false;
datetime        g_UpSL_Time1, g_UpSL_Time2;
double          g_UpSL_Price1, g_UpSL_Price2;
bool            g_IsUpSL_Broken = false;

bool            g_HasDnSpeedline = false;
datetime        g_DnSL_Time1, g_DnSL_Time2;
double          g_DnSL_Price1, g_DnSL_Price2;
bool            g_IsDnSL_Broken = false;

// Wave A-B-C & Cycle Resolution Engine (กำนันบอล: การแพ้ชนะของรอบคลื่น)
bool            g_WaveFormed = false;
int             g_WaveSide   = 0; // +1 = Buy Setup, -1 = Sell Setup
double          g_WaveA_Price = 0.0;
datetime        g_WaveA_Time  = 0;
double          g_WaveB_Price = 0.0;
datetime        g_WaveB_Time  = 0;
double          g_WaveC_Price = 0.0;
datetime        g_WaveC_Time  = 0;
bool            g_IsFailedHigh = false; // ขาดการเบรกไฮ (ฝั่ง Sell)
bool            g_IsFailedLow  = false; // ขาดการหลุดโล (ฝั่ง Buy)
bool            g_WaveCycleCompleted = false; // ตรวจจับการจบการแพ้ชนะของรอบคลื่น
string          g_WaveCompletionDesc = "";    // คำอธิบายผลการแพ้ชนะของรอบคลื่น

// Wave D Extension Targets & Fakeout Trap Radar (EP เสริม 4)
double          g_WaveD_1272 = 0.0;
double          g_WaveD_1618 = 0.0; // 🎯 Golden Target ขา D หลัก (161.8%)
double          g_WaveD_2000 = 0.0;
double          g_WaveD_2618 = 0.0;
bool            g_HasWave_D  = false;

bool            g_IsFakeoutTrap = false; // ตรวจพบ "กลับตัวหลอก" (Sweep Trap)
int             g_FakeoutSide   = 0;     // +1 = กลับตัวลงหลอก (Bear Trap -> Buy), -1 = กลับตัวขึ้นหลอก (Bull Trap -> Sell)
double          g_FakeoutPrice  = 0.0;
datetime        g_FakeoutTime   = 0;
string          g_FakeoutDesc   = "";

// Zones & Hidden Blades
SZone           g_Zones[];
int             g_ZoneCount = 0;
SHiddenBlade    g_Blades[];
int             g_BladeCount = 0;

// ICT Unicorn
bool            g_HasUnicorn  = false;
int             g_UnicornSide = 0; // +1 = BUY (Green), -1 = SELL (Red)
double          g_UnicornHigh = 0.0;
double          g_UnicornLow  = 0.0;

// Indicators
double          g_EMA14_Val   = 0.0;
int             g_EMA_Handle  = INVALID_HANDLE;
SLRLChannel     g_LRL;

// Targets
double          g_EntryMin = 0.0;
double          g_EntryMax = 0.0;
double          g_TargetSL = 0.0;
double          g_TargetTP1 = 0.0;
double          g_TargetTP2 = 0.0;
double          g_TargetTP3 = 0.0;
double          g_RR_Ratio  = 0.0;

// Shared SL Memory
double          g_ZoneSharedSL = 0.0;
datetime        g_LastAlertBar = 0;
double          g_CurrentLot   = 0.01;

// Multi-TF EMA 14 Matrix (M1, M5, M15, M30, H1, H4, D1 - สไตล์พี่ชนัฐ 100%)
#define NUM_EMA14_TFS 7
const ENUM_TIMEFRAMES g_EMA14_TFs[NUM_EMA14_TFS] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1};
const string          g_EMA14_Tags[NUM_EMA14_TFS] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1"};
const color           g_EMA14_Cols[NUM_EMA14_TFS] = {
   C'140,180,255', // M1: ฟ้าอ่อน (Sky Blue)
   C'0,230,255',   // M5: ฟ้าสว่างนีออน (Neon Cyan)
   C'50,230,130',  // M15: เขียวสปริง (Spring Green)
   C'255,215,0',   // M30: สีทองสว่าง (Gold)
   C'255,135,50',  // H1: สีส้มคอรัล (Coral Orange)
   C'220,80,255',  // H4: สีม่วงกล้วยไม้ (Orchid Purple)
   C'255,60,100'   // D1: สีแดงกุหลาบ (Rose Red)
};
const string          g_EMA14_Icons[NUM_EMA14_TFS] = {"⚡", "💧", "🟢", "🟡", "🟠", "🟣", "🔴"};

int                   g_hEMA14[NUM_EMA14_TFS];
double                g_EMA14_Vals[NUM_EMA14_TFS];

// Aliases for backward compatibility
double                g_EMA14_H1_Val = 0.0;
double                g_EMA14_H4_Val = 0.0;

// SMC Structure Breaks
S_BOS_Line       g_BOS_Lines[];
int              g_BOS_Count    = 0;

// Directional Bias & Sessions
int              g_MarketBiasBuyPct  = 50;
int              g_MarketBiasSellPct = 50;
string           g_SessionName       = "ACTIVE";
string           g_StepTitle         = "🎯 สเต็ป 1 (กวาด SL): รอกราฟฟอร์มตัว...";
string           g_StepDesc          = "👉 กราฟกำลังวิ่งตามเทรนด์ปกติ";
color            g_StepColor         = clrGold;
SSamuraiMTFState g_SamuraiMTF;

// Forward Declarations
void AutoDetectAssetProfile();
void ScanSwings(const MqlRates &rates[], int total);
void ClassifySwingsAndBreaks(const MqlRates &rates[], int total);
void UpdateMultiTF_EMA14();
void UpdateMarketBiasAndSession(const MqlRates &rates[], int total);
void UpdateSpeedlines(const MqlRates &rates[], int total);
void AnalyzeWaveStructure(const MqlRates &rates[], int total);
void CalculateWave_D_Targets();
void DetectFakeoutTrap(const MqlRates &rates[], int total);
void DrawStandardFibonacci();
void ScanDemandSupplyZones(const MqlRates &rates[], int total);
void ScanHiddenBladeWicks();
void CheckICTUnicorn(const MqlRates &rates[], int total);
void CheckSidewayRegime(const MqlRates &rates[], int total);
void CheckCandlePATrigger(const MqlRates &rates[]);
void CalculateDynamicTargets();
void CalculateLRLChannel(const MqlRates &rates[], int total);
void SynchronizeSharedSL();
void EnsureSamuraiSubwindow();
void UpdateSamuraiMTFGoldenAlert();
void DrawStructureBreaks();
bool IsEMA14Enabled(int index);
void DrawMultiTF_EMA14_Lines();
void DrawSwingPinAndLabel(int index, bool isHigh, datetime t, double price, string labelStr, ENUM_SWING_TYPE labelType, color col);
void CreateOrUpdateRectLabel(string name, int subwin, int x, int y, int w, int h, color bgCol);
void CreateOrUpdateTextLabel(string name, int subwin, int x, int y, string text, string font, int fontSize, color col, ENUM_ANCHOR_POINT anchor);
void RenderDashboard();
void DrawVisualsOnChart();
void CleanupVisuals();
void ExecuteManualTrade(ENUM_ORDER_TYPE orderType);
void ExecuteBreakEven();
void ExecutePartialClose(double pct = 0.80);
void ExecuteCloseAll();
void CheckVoiceAlerts();
string FormatMoneyOrPoints(double points);
string GetCleanTFName(ENUM_TIMEFRAMES tf);
void ScanCME_OptionsMatrix();
void DrawCME_OptionsWalls();
string FormatOI_Number(int count);
void PreloadChartHistory();
void CalculateGannWaveEnergy(const MqlRates &rates[], int copied);
void DrawGannEquilibriumGrid();
void CheckVelocityStopLockFloor();
bool IsCentAccount();
void ScanDTD_CF_M1();
void DrawDTD_M1_Visuals();
void ScanInstitutionalLiquidity();
void DrawLiquidityVisuals();
void CalculateDualPriceForecast();
void RunFullAnalysisScan(const MqlRates &rates[], int copied);

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION HANDLER                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!m_symbol.Name(_Symbol))
   {
      Print("[DeungDang_Trade] Symbol Error: ", _Symbol);
      return INIT_FAILED;
   }
   m_symbol.Refresh();
   PreloadChartHistory();

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippagePts);

   // Adaptive Broker Trade Filling Engine
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_IOC) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else if((filling & SYMBOL_FILLING_FOK) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   double initMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(initMinLot <= 0.0) initMinLot = 0.01;
   double initMaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(initMaxLot <= 0.0) initMaxLot = 100.0;

   g_CurrentLot = InpDefaultLot;
   if(g_CurrentLot < initMinLot) g_CurrentLot = initMinLot;
   if(g_CurrentLot > initMaxLot) g_CurrentLot = initMaxLot;

   // Initialize Indicator Handles for Multi-TF EMA 14 (M1 to D1)
   g_EMA_Handle = iMA(_Symbol, _Period, InpEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   for(int i = 0; i < NUM_EMA14_TFS; i++)
   {
      g_hEMA14[i] = iMA(_Symbol, g_EMA14_TFs[i], InpEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      g_EMA14_Vals[i] = 0.0;
   }

   AutoDetectAssetProfile();
   ArrayResize(g_Swings, 100);
   ArrayResize(g_Zones, 80);
   ArrayResize(g_Blades, 20);
   ArrayResize(g_BOS_Lines, 20);

   // Load persistent accordion & master dashboard visibility states
   string gvDashVis = "DT_DASH_VIS_" + _Symbol;
   if(GlobalVariableCheck(gvDashVis))
      g_Dashboard_Visible = (GlobalVariableGet(gvDashVis) > 0.5);
   else
      g_Dashboard_Visible = true;

   string gvC1 = "DT_CARD1_EXP_" + _Symbol;
   if(GlobalVariableCheck(gvC1)) g_Card1_Expanded = (GlobalVariableGet(gvC1) > 0.5);

   string gvC2 = "DT_CARD2_EXP_" + _Symbol;
   if(GlobalVariableCheck(gvC2)) g_Card2_Expanded = (GlobalVariableGet(gvC2) > 0.5);

   string gvC3 = "DT_CARD3_EXP_" + _Symbol;
   if(GlobalVariableCheck(gvC3)) g_Card3_Expanded = (GlobalVariableGet(gvC3) > 0.5);

   string gvLot = "DT_LOT_" + _Symbol;
   if(GlobalVariableCheck(gvLot))
   {
      double savedLot = GlobalVariableGet(gvLot);
      if(savedLot >= initMinLot && savedLot <= initMaxLot)
         g_CurrentLot = NormalizeDouble(savedLot, 2);
   }

   Print(">>> [DeungDang_Trade] เริ่มต้นระบบชี้เป้าและฝึกดูกราฟกำนันบอล Master Flagship V1.70 (CME Options Wall Edition): ", _Symbol, " Lot: ", g_CurrentLot);

   // Clean up any legacy visual objects on startup to ensure perfect Z-order hierarchy
   CleanupVisuals();

   // ปลดระวางและลบวัตถุตาข่ายแกนน์ทั้งหมดออกถาวรทันที
   ObjectDelete(0, GUI_PREFIX + "GANN_GRID");
   ObjectDelete(0, GUI_PREFIX + "GANN_ZERO_LINE");
   ObjectDelete(0, GUI_PREFIX + "GANN_ZERO_LBL");
   for(int i = ObjectsTotal(0, 0, OBJ_GANNGRID) - 1; i >= 0; i--)
   {
      string gName = ObjectName(0, i, 0, OBJ_GANNGRID);
      ObjectDelete(0, gName);
   }

   // Ensure Samurai Multi-TF Strip in Subwindow 1
   if(InpUseSamuraiMTFStrip)
   {
      EnsureSamuraiSubwindow();
   }

   // Enable 1-second Timer for Calm & Smooth Countdown (No 250ms High-Frequency Screen Strobing)
   EventSetTimer(InpTimer_Seconds > 0 ? InpTimer_Seconds : 1);

   // Initial Full Scan (ครบทุกโมดูล 100% แม้เปิดกราฟในวันหยุดเสาร์-อาทิตย์)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 0, InpMaxBarsScan, rates);
   if(copied >= 15)
   {
      RunFullAnalysisScan(rates, copied);
      DrawVisualsOnChart();
      if(InpShowHUD) RenderDashboard();
      if(InpUseSamuraiMTFStrip) UpdateSamuraiMTFGoldenAlert();
   }

   DumpAccountTradeHistory();
   ChartRedraw();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| AUTO PORTFOLIO TRADE HISTORY EXPORTER (CSV SYNC)                 |
//+------------------------------------------------------------------+
void DumpAccountTradeHistory()
{
   long loginId = AccountInfoInteger(ACCOUNT_LOGIN);
   if(loginId <= 0) return;

   string filename = StringFormat("trade_history_%I64d.csv", loginId);
   for(int pass = 0; pass < 2; pass++)
   {
      int flags = FILE_WRITE | FILE_CSV | FILE_ANSI;
      if(pass == 1) flags |= FILE_COMMON;
      int fileHandle = FileOpen(filename, flags, ",");
      if(fileHandle != INVALID_HANDLE)
      {
         FileWrite(fileHandle, "CATEGORY", "TICKET", "ORDER", "TIME", "SYMBOL", "TYPE", "ENTRY", "VOLUME", "PRICE", "PROFIT", "COMMISSION", "SWAP", "MAGIC", "COMMENT");
         FileWrite(fileHandle, "ACCOUNT", IntegerToString(loginId), AccountInfoString(ACCOUNT_NAME),
                   DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
                   AccountInfoString(ACCOUNT_CURRENCY), IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)));

         if(HistorySelect(0, TimeCurrent()))
         {
            int dealsTotal = HistoryDealsTotal();
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
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION HANDLER                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   CleanupVisuals();
   if(g_EMA_Handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_EMA_Handle);
      g_EMA_Handle = INVALID_HANDLE;
   }
   for(int i = 0; i < NUM_EMA14_TFS; i++)
   {
      if(g_hEMA14[i] != INVALID_HANDLE)
      {
         IndicatorRelease(g_hEMA14[i]);
         g_hEMA14[i] = INVALID_HANDLE;
      }
   }
   ChartRedraw();
   Print("[DeungDang_Trade] ปิดระบบและทำความสะอาดหน้าจอเรียบร้อย.");
}

//+------------------------------------------------------------------+
//| EXPERT TIMER HANDLER (COUNTDOWN & CANDLE RENDERING)              |
//+------------------------------------------------------------------+
void RunFullAnalysisScan(const MqlRates &rates[], int copied)
{
   if(g_EMA_Handle != INVALID_HANDLE)
   {
      double emaBuf[1];
      if(CopyBuffer(g_EMA_Handle, 0, 0, 1, emaBuf) > 0)
         g_EMA14_Val = emaBuf[0];
   }
   UpdateMultiTF_EMA14();
   UpdateMarketBiasAndSession(rates, copied);
   ScanSwings(rates, copied);
   ClassifySwingsAndBreaks(rates, copied);
   UpdateSpeedlines(rates, copied);
   AnalyzeWaveStructure(rates, copied);
   CalculateWave_D_Targets();
   DetectFakeoutTrap(rates, copied);
   DrawStandardFibonacci();
   ScanDemandSupplyZones(rates, copied);
   ScanHiddenBladeWicks();
   CheckICTUnicorn(rates, copied);
   CheckSidewayRegime(rates, copied);
   CalculateLRLChannel(rates, copied);
   CheckCandlePATrigger(rates);
   CalculateDynamicTargets();
   ScanCME_OptionsMatrix();
   CalculateGannWaveEnergy(rates, copied);
   ScanInstitutionalLiquidity();
   ScanDTD_CF_M1();
   CalculateDualPriceForecast();
   UpdateMarketBiasAndSession(rates, copied);
   CheckVoiceAlerts();
}

void CheckTimeframeSwitchReset()
{
   static ENUM_TIMEFRAMES s_LastPeriod = PERIOD_CURRENT;
   if(s_LastPeriod != _Period)
   {
      ObjectDelete(0, GUI_PREFIX + "SL_UP");
      ObjectDelete(0, GUI_PREFIX + "SL_DN");
      ObjectDelete(0, GUI_PREFIX + "WAVE_A");
      ObjectDelete(0, GUI_PREFIX + "WAVE_B");
      ObjectDelete(0, GUI_PREFIX + "WAVE_C");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_AB");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_BC");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_CD");
      ObjectDelete(0, GUI_PREFIX + "WAVE_D_1618");
      ObjectDelete(0, GUI_PREFIX + "WAVE_D_LBL");
      ObjectDelete(0, GUI_PREFIX + "TRAP_ICON");
      ObjectDelete(0, GUI_PREFIX + "STD_FIBO");
      ObjectDelete(0, GUI_PREFIX + "GANN_GRID");
      ObjectDelete(0, GUI_PREFIX + "GANN_ZERO_LINE");
      ObjectDelete(0, GUI_PREFIX + "GANN_ZERO_LBL");
      ObjectsDeleteAll(0, GUI_PREFIX + "DTD_");
      ObjectsDeleteAll(0, GUI_PREFIX + "LQ_");
      g_DTD.isLatched      = false;
      g_DTD.latchedSide    = 0;
      g_DTD.retestBarTime  = 0;
      g_DTD.confirmBarTime = 0;
      g_DTD.swBoxActive    = false;

      g_HasUpSpeedline = false;
      g_HasDnSpeedline = false;
      g_IsUpSL_Broken  = false;
      g_IsDnSL_Broken  = false;
      g_WaveFormed     = false;
      g_WaveSide       = 0;
      g_WaveCycleCompleted = false;
      g_WaveCompletionDesc = "";
      g_HasWave_D      = false;
      g_IsFakeoutTrap  = false;
      g_FakeoutSide    = 0;
      g_FakeoutPrice   = 0.0;
      g_FakeoutTime    = 0;
      g_FakeoutDesc    = "";

      s_LastPeriod = _Period;
   }
}

void OnTimer()
{
   static int s_dumpCount = 0;
   s_dumpCount++;
   if(s_dumpCount == 3 || s_dumpCount == 6 || s_dumpCount == 12 || (s_dumpCount % 120 == 0))
   {
      DumpAccountTradeHistory();
   }
   if(InpUseSamuraiMTFStrip)
   {
      UpdateSamuraiMTFGoldenAlert();
   }

   // อัปเดตการวิเคราะห์และหน้าจออัตโนมัติแม้ในวันเสาร์-อาทิตย์ที่ตลาดปิด หรือเมื่อสลับ Timeframe
   static ENUM_TIMEFRAMES s_TimerLastTF = PERIOD_CURRENT;
   bool tfChanged = (s_TimerLastTF != _Period);
   bool needsInitRefresh = (g_DTD.recommendedLot <= 0.0 || g_GannEnergy.zeroPrice <= 0.0 || g_Forecast.buyEntryPrice <= 0.0);
   if(tfChanged || needsInitRefresh || (s_dumpCount % 3 == 0))
   {
      s_TimerLastTF = _Period;
      CheckTimeframeSwitchReset();
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(_Symbol, _Period, 0, InpMaxBarsScan, rates);
      if(copied >= 15)
      {
         RunFullAnalysisScan(rates, copied);
         DrawVisualsOnChart();
         if(InpShowHUD) RenderDashboard();
         if(tfChanged || needsInitRefresh) ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| EXPERT TICK HANDLER                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   m_symbol.Refresh();
   CheckTimeframeSwitchReset();

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 0, InpMaxBarsScan, rates);
   if(copied < 15) return;

   // Perform Full Market Structure, Liquidity & Dual Forecast Analysis
   RunFullAnalysisScan(rates, copied);

   // 3. Synchronize Shared SL & VSL Floor Lock for Manual Positions
   // SynchronizeSharedSL(); // ปิดถาวรตามคำสั่งเด็ดขาดของคุณเอ้
   // CheckVelocityStopLockFloor(); // ปิดถาวรตามคำสั่งเด็ดขาดของคุณเอ้

   // 4. Update Visuals & Dashboard (Throttled to InpGUI_RefreshRateMs, Stable In-Place Rendering, Zero Screen Flickering)
   ulong curTickMs = GetTickCount64();
   static ulong lastGuiTickMs = 0;
   int refreshMs = (InpGUI_RefreshRateMs >= 100) ? InpGUI_RefreshRateMs : 1000;
   if(curTickMs - lastGuiTickMs >= (ulong)refreshMs)
   {
      lastGuiTickMs = curTickMs;
      DrawVisualsOnChart();
      if(InpShowHUD) RenderDashboard();
      // ไม่เรียก ChartRedraw() ใน OnTick: ป้องกัน Windows Repaint วูบวาบ ลายตา มึนหัว 100%
   }
}

//+------------------------------------------------------------------+
//| CHART EVENT HANDLER (INTERACTIVE BUTTONS & ACCORDION FOLDING)    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == GUI_PREFIX + "BTN_BUY")
      {
         ExecuteManualTrade(ORDER_TYPE_BUY);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_SELL")
      {
         ExecuteManualTrade(ORDER_TYPE_SELL);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_BE")
      {
         ExecuteBreakEven();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_PARTIAL")
      {
         ExecutePartialClose(0.80);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_CLOSE")
      {
         ExecuteCloseAll();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_DTD_LOT")
      {
         if(g_DTD.recommendedLot > 0.0)
         {
            g_CurrentLot = g_DTD.recommendedLot;
            GlobalVariableSet("DT_LOT_" + _Symbol, g_CurrentLot);
            ObjectSetString(0, GUI_PREFIX + "LOT_VAL", OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
            Print(">>> [DeungDang_Trade] 🎯 ปรับใช้ขนาด Lot ตามสูตร MM อ.เดช (1:3R): ", g_CurrentLot);
            if(InpShowHUD) RenderDashboard();
            ChartRedraw();
         }
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == GUI_PREFIX + "BTN_DTD_LOT_BUY")
      {
         double targetLot = (g_Forecast.buyLot > 0.0) ? g_Forecast.buyLot : g_DTD.buyRecommendedLot;
         if(targetLot > 0.0)
         {
            g_CurrentLot = targetLot;
            GlobalVariableSet("DT_LOT_" + _Symbol, g_CurrentLot);
            ObjectSetString(0, GUI_PREFIX + "LOT_VAL", OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
            Print(">>> [DeungDang_Trade] 🟢 ปรับใช้ขนาด Lot แผนคาดการณ์ BUY (1:3R): ", g_CurrentLot);
            if(InpShowHUD) RenderDashboard();
            ChartRedraw();
         }
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == GUI_PREFIX + "BTN_DTD_LOT_SELL")
      {
         double targetLot = (g_Forecast.sellLot > 0.0) ? g_Forecast.sellLot : g_DTD.sellRecommendedLot;
         if(targetLot > 0.0)
         {
            g_CurrentLot = targetLot;
            GlobalVariableSet("DT_LOT_" + _Symbol, g_CurrentLot);
            ObjectSetString(0, GUI_PREFIX + "LOT_VAL", OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
            Print(">>> [DeungDang_Trade] 🔴 ปรับใช้ขนาด Lot แผนคาดการณ์ SELL (1:3R): ", g_CurrentLot);
            if(InpShowHUD) RenderDashboard();
            ChartRedraw();
         }
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == GUI_PREFIX + "LOT_MINUS")
      {
         double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         if(step <= 0.0) step = 0.01;
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(minLot <= 0.0) minLot = 0.01;

         g_CurrentLot -= step;
         if(g_CurrentLot < minLot) g_CurrentLot = minLot;
         g_CurrentLot = NormalizeDouble(g_CurrentLot, 2);
         GlobalVariableSet("DT_LOT_" + _Symbol, g_CurrentLot);
         ObjectSetString(0, GUI_PREFIX + "LOT_VAL", OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Print(">>> [DeungDang_Trade] ➖ ปรับลดขนาด Lot: ", g_CurrentLot);
         if(InpShowHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "LOT_PLUS")
      {
         double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         if(step <= 0.0) step = 0.01;
         double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
         if(maxLot <= 0.0) maxLot = 100.0;

         g_CurrentLot += step;
         if(g_CurrentLot > maxLot) g_CurrentLot = maxLot;
         g_CurrentLot = NormalizeDouble(g_CurrentLot, 2);
         GlobalVariableSet("DT_LOT_" + _Symbol, g_CurrentLot);
         ObjectSetString(0, GUI_PREFIX + "LOT_VAL", OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Print(">>> [DeungDang_Trade] ➕ ปรับเพิ่มขนาด Lot: ", g_CurrentLot);
         if(InpShowHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "LOT_VAL")
      {
         // Quick Lot Preset Cycle: 0.01 -> 0.02 -> 0.05 -> 0.10 -> 0.20 -> 0.50 -> 1.00 -> 0.01
         if(g_CurrentLot < 0.02 - 0.001) g_CurrentLot = 0.02;
         else if(g_CurrentLot < 0.05 - 0.001) g_CurrentLot = 0.05;
         else if(g_CurrentLot < 0.10 - 0.001) g_CurrentLot = 0.10;
         else if(g_CurrentLot < 0.20 - 0.001) g_CurrentLot = 0.20;
         else if(g_CurrentLot < 0.50 - 0.001) g_CurrentLot = 0.50;
         else if(g_CurrentLot < 1.00 - 0.001) g_CurrentLot = 1.00;
         else g_CurrentLot = 0.01;
         g_CurrentLot = NormalizeDouble(g_CurrentLot, 2);
         GlobalVariableSet("DT_LOT_" + _Symbol, g_CurrentLot);
         ObjectSetString(0, GUI_PREFIX + "LOT_VAL", OBJPROP_TEXT, DoubleToString(g_CurrentLot, 2));
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Print(">>> [DeungDang_Trade] 🔄 สลับขนาด Lot ด่วน: ", g_CurrentLot);
         if(InpShowHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_HIDE_DASH")
      {
         g_Dashboard_Visible = false;
         GlobalVariableSet("DT_DASH_VIS_" + _Symbol, 0.0);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_SHOW_DASH")
      {
         g_Dashboard_Visible = true;
         GlobalVariableSet("DT_DASH_VIS_" + _Symbol, 1.0);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_MIN_C1")
      {
         g_Card1_Expanded = !g_Card1_Expanded;
         GlobalVariableSet("DT_CARD1_EXP_" + _Symbol, g_Card1_Expanded ? 1.0 : 0.0);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_MIN_C2")
      {
         g_Card2_Expanded = !g_Card2_Expanded;
         GlobalVariableSet("DT_CARD2_EXP_" + _Symbol, g_Card2_Expanded ? 1.0 : 0.0);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowHUD) RenderDashboard();
         ChartRedraw();
      }
      else if(sparam == GUI_PREFIX + "BTN_MIN_C3")
      {
         g_Card3_Expanded = !g_Card3_Expanded;
         GlobalVariableSet("DT_CARD3_EXP_" + _Symbol, g_Card3_Expanded ? 1.0 : 0.0);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         if(InpShowHUD) RenderDashboard();
         ChartRedraw();
      }
   }
   else if(id == CHARTEVENT_CHART_CHANGE)
   {
      if(InpUseDTD_CF_M1 && InpDrawDTD_M1_Visuals && InpDrawDTD_CandleStickers)
         DrawDTD_M1_Visuals();
      if(InpShowHUD) RenderDashboard();
   }
}

//+------------------------------------------------------------------+
//| 0B. IS CENT ACCOUNT DETECTOR                                     |
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

//+------------------------------------------------------------------+
//| 1. AUTO ASSET PROFILE DETECTOR                                   |
//+------------------------------------------------------------------+
void AutoDetectAssetProfile()
{
   string sym = _Symbol;
   StringToUpper(sym);

   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
   {
      g_Asset.assetType = ASSET_GOLD;
      g_Asset.name      = "ทองคำ (Gold)";
      g_Asset.unitStr   = "จุด";
      g_Asset.slPoints  = InpSharedSL_Gold;
      g_Asset.tp1Points = 600;
      g_Asset.tp2Points = 1300;
      g_Asset.tp3Points = 2600;
      g_Asset.beBuffer  = InpBE_BufferPts;
   }
   else if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 || StringFind(sym, "CRYPTO") >= 0)
   {
      g_Asset.assetType = ASSET_CRYPTO;
      g_Asset.name      = "คริปโต (Bitcoin/Crypto)";
      g_Asset.unitStr   = "ดอลลาร์";

      double curPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(curPrice <= 0) curPrice = 85000.0;
      double slCash = curPrice * (InpSharedSL_CryptoPct / 100.0);
      g_Asset.slPoints  = (int)(slCash / _Point);
      g_Asset.tp1Points = (int)(g_Asset.slPoints * 1.5);
      g_Asset.tp2Points = (int)(g_Asset.slPoints * 3.0);
      g_Asset.tp3Points = (int)(g_Asset.slPoints * 5.0);
      g_Asset.beBuffer  = (int)((curPrice * 0.001) / _Point);
   }
   else if(StringFind(sym, "US30") >= 0 || StringFind(sym, "NAS") >= 0 || StringFind(sym, "SPX") >= 0)
   {
      g_Asset.assetType = ASSET_INDEX;
      g_Asset.name      = "ดัชนี (Indices)";
      g_Asset.unitStr   = "จุด";
      g_Asset.slPoints  = 2000;
      g_Asset.tp1Points = 2500;
      g_Asset.tp2Points = 5000;
      g_Asset.tp3Points = 9000;
      g_Asset.beBuffer  = 200;
   }
   else
   {
      g_Asset.assetType = ASSET_FOREX;
      g_Asset.name      = "คู่เงิน (Forex)";
      g_Asset.unitStr   = "จุด";
      g_Asset.slPoints  = InpSharedSL_Forex;
      g_Asset.tp1Points = 350;
      g_Asset.tp2Points = 700;
      g_Asset.tp3Points = 1400;
      g_Asset.beBuffer  = 30;
   }
}

string FormatMoneyOrPoints(double points)
{
   if(g_Asset.assetType == ASSET_CRYPTO)
   {
      double cash = points * _Point;
      return StringFormat("$%.2f", cash);
   }
   return StringFormat("%.0f จุด", points);
}

string GetCleanTFName(ENUM_TIMEFRAMES tf)
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
      case PERIOD_MN1: return "MN";
      default:         return EnumToString(tf);
   }
}

//+------------------------------------------------------------------+
//| PRELOAD CHART HISTORY (FORCE BROKER SYNC ON STARTUP)             |
//+------------------------------------------------------------------+
void PreloadChartHistory()
{
   ENUM_TIMEFRAMES preTFs[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1};
   for(int i = 0; i < 7; i++)
   {
      MqlRates dummy[];
      CopyRates(_Symbol, preTFs[i], 0, 150, dummy);
   }
}

//+------------------------------------------------------------------+
//| 2. ENSURE SAMURAI SUBWINDOW (OPENS SUBWINDOW 1)                  |
//+------------------------------------------------------------------+
void EnsureSamuraiSubwindow()
{
   GlobalVariableSet("GV_SAMURAI_TF_STATUS", 1.0);
   GlobalVariableSet("GV_SAMURAI_TF_STATUS" + _Symbol, 1.0);
   GlobalVariableSet("GV_SAMURAI_TF_STATUS" + _Symbol + (string)ChartID(), 1.0);

   int totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   if(totalWindows < 2)
   {
      int hFallback = iATR(_Symbol, _Period, 14);
      if(hFallback != INVALID_HANDLE)
         ChartIndicatorAdd(0, 1, hFallback);
   }

   totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   if(totalWindows > 1)
   {
      ChartSetInteger(0, CHART_HEIGHT_IN_PIXELS, 1, 130);
   }
}

//+------------------------------------------------------------------+
//| 3. SAMURAI MTF 9-TIMEFRAME STRIP WITH 36 MINI CANDLESTICKS       |
//+------------------------------------------------------------------+
void UpdateSamuraiMTFGoldenAlert()
{
   int totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   int targetWin    = (totalWindows >= 2) ? 1 : 0;
   if(targetWin == 0) return;

   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int winH   = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, targetWin);
   if(chartW <= 0) chartW = 1200;
   if(winH < 65)   winH   = 130;

   // Deep dark background covering Subwindow 1
   CreateOrUpdateRectLabel(GUI_PREFIX + "MTF_WIN_BG", targetWin, 0, 0, chartW, winH, C'10,16,24');

   const ENUM_TIMEFRAMES tfs[9] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
   const string tfNames[9]      = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN"};

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

   int colSpacing = (chartW - 60) / 9;
   if(colSpacing < 68)  colSpacing = 68;
   if(colSpacing > 185) colSpacing = 185;
   int totalSpan = 9 * colSpacing;
   int startX = (chartW > totalSpan) ? (chartW - totalSpan) / 2 + colSpacing / 2 : 30 + colSpacing / 2;

   double liveBid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime curTime = TimeCurrent();

   // Top-left PA subwindow badge
   CreateOrUpdateRectLabel(GUI_PREFIX + "MTF_PA_BG", targetWin, 15, 8, 28, 16, C'30,70,130');
   CreateOrUpdateTextLabel(GUI_PREFIX + "MTF_PA", targetWin, 29, 16, "PA", "Arial Bold", 8, clrWhite, ANCHOR_CENTER);

   for(int i = 0; i < 9; i++)
   {
      int colX = startX + i * colSpacing;

      MqlRates rates[4];
      int copied = CopyRates(_Symbol, tfs[i], 0, 4, rates);
      if(copied < 1)
         copied = CopyRates(_Symbol, tfs[i], 0, 1, rates);

      if(copied < 1)
      {
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
            double refP = (liveBid > 0) ? liveBid : 85000.0;
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

      // Calculate high/low extreme of the 4 candles
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

         // 2. Body (solid rectangle)
         string objBody = GUI_PREFIX + "MTF_B_" + tfNames[i] + "_" + IntegerToString(b);
         CreateOrUpdateRectLabel(objBody, targetWin, candleCenterX - cBodyW / 2, bodyTop, cBodyW, bodyH, candleCol);
      }

      // Clean up unused bar slots
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
      color baseCol = isCurrentTF ? clrGold : C'30,90,160';
      string objBase = GUI_PREFIX + "MTF_BASE_" + tfNames[i];
      CreateOrUpdateRectLabel(objBase, targetWin, colX - baseLineW / 2, yBaseLine, baseLineW, 2, baseCol);

      // 5. Timeframe Label & Countdown Calculation
      MqlDateTime dt;
      TimeToStruct(curTime, dt);
      long remaining = 0;
      if(tfs[i] <= PERIOD_D1)
      {
         int pSecs = PeriodSeconds(tfs[i]);
         datetime barTime = (copied > 0) ? rates[copied - 1].time : iTime(_Symbol, tfs[i], 0);
         if(barTime > 0) remaining = (long)((barTime + pSecs) - curTime);
         if(remaining < 0) remaining = 0;
         if(remaining > pSecs) remaining = pSecs;
      }
      else if(tfs[i] == PERIOD_W1)
      {
         datetime barTime = (copied > 0) ? rates[copied - 1].time : iTime(_Symbol, PERIOD_W1, 0);
         long weekTradingSecs = 5 * 86400; // Mon 00:00 to Fri 23:59:59
         if(barTime > 0) remaining = (long)((barTime + weekTradingSecs) - curTime);
         if(remaining < 0) remaining = 0;
         if(remaining > weekTradingSecs) remaining = weekTradingSecs;
      }
      else // PERIOD_MN1
      {
         int daysInMonth = 30;
         if(dt.mon == 1 || dt.mon == 3 || dt.mon == 5 || dt.mon == 7 || dt.mon == 8 || dt.mon == 10 || dt.mon == 12) daysInMonth = 31;
         else if(dt.mon == 2) daysInMonth = ((dt.year % 4 == 0 && dt.year % 100 != 0) || (dt.year % 400 == 0)) ? 29 : 28;
         int remDays = daysInMonth - dt.day;
         if(remDays < 0) remDays = 0;
         remaining = remDays * 86400 + (86400 - (dt.hour * 3600 + dt.min * 60 + dt.sec));
         if(remaining < 0) remaining = 0;
      }

      bool isAlert = (InpSamuraiGoldenAlert && remaining <= 15 && PeriodSeconds(tfs[i]) <= 3600);
      color lblCol = isAlert ? clrGold : (isCurrentTF ? clrGold : (color)10526880);

      string objLbl = GUI_PREFIX + "MTF_L_" + tfNames[i];
      CreateOrUpdateTextLabel(objLbl, targetWin, colX, yTfLabel, tfNames[i], "Arial Black", 9, lblCol, ANCHOR_CENTER);

      string countStr = "";
      if(remaining >= 3600)
         countStr = StringFormat("%02d:%02d:%02d", remaining / 3600, (remaining % 3600) / 60, remaining % 60);
      else
         countStr = StringFormat("%02d:%02d", remaining / 60, remaining % 60);

      color countCol = isAlert ? clrGold : (isCurrentTF ? clrWhite : (color)8421504);
      string objCnt = GUI_PREFIX + "MTF_C_" + tfNames[i];
      CreateOrUpdateTextLabel(objCnt, targetWin, colX, yCountdown, countStr, "Arial", 8, countCol, ANCHOR_CENTER);
   }
}

//+------------------------------------------------------------------+
//| 4. SCAN SWING PIVOTS                                             |
//+------------------------------------------------------------------+
void ScanSwings(const MqlRates &rates[], int total)
{
   g_SwingCount = 0;
   int strength = InpSwingBars;

   for(int i = strength; i < total - strength && g_SwingCount < 95; i++)
   {
      bool isHigh = true;
      bool isLow  = true;

      for(int k = 1; k <= strength; k++)
      {
         if(rates[i].high <= rates[i - k].high || rates[i].high <= rates[i + k].high) isHigh = false;
         if(rates[i].low  >= rates[i - k].low  || rates[i].low  >= rates[i + k].low)  isLow  = false;
      }

      if(isHigh)
      {
         g_Swings[g_SwingCount].time      = rates[i].time;
         g_Swings[g_SwingCount].price     = rates[i].high;
         g_Swings[g_SwingCount].isHigh    = true;
         g_Swings[g_SwingCount].bar       = i;
         g_Swings[g_SwingCount].labelType = SWING_NONE;
         g_Swings[g_SwingCount].labelStr  = "";
         g_SwingCount++;
      }
      else if(isLow)
      {
         g_Swings[g_SwingCount].time      = rates[i].time;
         g_Swings[g_SwingCount].price     = rates[i].low;
         g_Swings[g_SwingCount].isHigh    = false;
         g_Swings[g_SwingCount].bar       = i;
         g_Swings[g_SwingCount].labelType = SWING_NONE;
         g_Swings[g_SwingCount].labelStr  = "";
         g_SwingCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| 4.1 UPDATE MULTI-TF EMA 14 HANDLES (M1 TO D1)                    |
//+------------------------------------------------------------------+
void UpdateMultiTF_EMA14()
{
   for(int i = 0; i < NUM_EMA14_TFS; i++)
   {
      if(g_hEMA14[i] != INVALID_HANDLE)
      {
         double buf[1];
         if(CopyBuffer(g_hEMA14[i], 0, 0, 1, buf) > 0)
         {
            g_EMA14_Vals[i] = buf[0];
         }
      }
   }
   // Sync legacy aliases
   g_EMA14_H1_Val = g_EMA14_Vals[4]; // H1
   g_EMA14_H4_Val = g_EMA14_Vals[5]; // H4
}

//+------------------------------------------------------------------+
//| 4.2 CLASSIFY SWINGS (HH/HL/LH/LL) & DETECT BOS / CHOCH           |
//+------------------------------------------------------------------+
void ClassifySwingsAndBreaks(const MqlRates &rates[], int total)
{
   g_BOS_Count = 0;
   if(g_SwingCount < 2) return;

   // 1. Classify Swings by comparing each swing to the preceding older swing of the same type
   for(int i = 0; i < g_SwingCount; i++)
   {
      if(g_Swings[i].isHigh)
      {
         int prevH = -1;
         for(int k = i + 1; k < g_SwingCount; k++)
         {
            if(g_Swings[k].isHigh) { prevH = k; break; }
         }
         if(prevH != -1)
         {
            if(g_Swings[i].price >= g_Swings[prevH].price)
            {
               g_Swings[i].labelType = SWING_HH;
               g_Swings[i].labelStr  = "HH";
            }
            else
            {
               g_Swings[i].labelType = SWING_LH;
               g_Swings[i].labelStr  = "LH";
            }
         }
         else
         {
            g_Swings[i].labelType = SWING_HH;
            g_Swings[i].labelStr  = "HH";
         }
      }
      else
      {
         int prevL = -1;
         for(int k = i + 1; k < g_SwingCount; k++)
         {
            if(!g_Swings[k].isHigh) { prevL = k; break; }
         }
         if(prevL != -1)
         {
            if(g_Swings[i].price >= g_Swings[prevL].price)
            {
               g_Swings[i].labelType = SWING_HL;
               g_Swings[i].labelStr  = "HL";
            }
            else
            {
               g_Swings[i].labelType = SWING_LL;
               g_Swings[i].labelStr  = "LL";
            }
         }
         else
         {
            g_Swings[i].labelType = SWING_HL;
            g_Swings[i].labelStr  = "HL";
         }
      }
   }

   // 2. Detect Structure Breaks (BOS / CHoCH)
   int maxScan = MathMin(14, g_SwingCount - 1);
   for(int i = 0; i < maxScan && g_BOS_Count < 10; i++)
   {
      double   swPrice  = g_Swings[i].price;
      datetime swTime   = g_Swings[i].time;
      int      swBar    = g_Swings[i].bar;
      bool     swIsHigh = g_Swings[i].isHigh;

      for(int b = swBar - 1; b >= 0; b--)
      {
         bool isBroken = (swIsHigh && rates[b].close > swPrice) || (!swIsHigh && rates[b].close < swPrice);
         if(isBroken)
         {
            int n = g_BOS_Count;
            g_BOS_Lines[n].timeStart = swTime;
            g_BOS_Lines[n].timeEnd   = rates[b].time;
            g_BOS_Lines[n].price     = swPrice;
            g_BOS_Lines[n].isActive  = true;

            if(swIsHigh)
            {
               g_BOS_Lines[n].tag = (g_Swings[i].labelType == SWING_LH) ? "CHoCH" : "BOS";
               g_BOS_Lines[n].col = (g_BOS_Lines[n].tag == "CHoCH") ? clrAqua : clrLime;
            }
            else
            {
               g_BOS_Lines[n].tag = (g_Swings[i].labelType == SWING_HL) ? "CHoCH" : "BOS";
               g_BOS_Lines[n].col = (g_BOS_Lines[n].tag == "CHoCH") ? clrDeepPink : clrOrangeRed;
            }

            g_BOS_Count++;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 4.3 UPDATE MARKET BIAS, SESSIONS & SAMURAI 6-TF CONFLUENCE       |
//+------------------------------------------------------------------+
void UpdateMarketBiasAndSession(const MqlRates &rates[], int total)
{
   // 1. Session Detection (GMT / Broker server time aware)
   MqlDateTime dt;
   TimeCurrent(dt);
   int hour = dt.hour;
   if(hour >= 7 && hour < 22)
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

   // 2. 6-TF Samurai Momentum & Summary Dots (M1, M5, M15, M30, H1, H4)
   const ENUM_TIMEFRAMES tfs[6] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
   const string tfNames[6]      = {"M1", "M5", "M15", "M30", "H1", "H4"};
   const double tfWeights[6]    = {1.0, 1.0, 1.2, 1.5, 2.0, 2.0};

   double totalWeight = 0.0;
   double weightedBullSum = 0.0;
   string str = "";
   double liveBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = 0; i < 6; i++)
   {
      MqlRates mRates[4];
      int copied = CopyRates(_Symbol, tfs[i], 0, 4, mRates);
      bool bull = false;
      bool bear = false;
      double mom = 50.0;

      if(copied >= 4)
      {
         if(liveBid > 0) mRates[3].close = liveBid;
         double c0 = mRates[3].close;
         double o0 = mRates[3].open;
         double c1 = mRates[2].close;

         double body0 = MathAbs(c0 - o0);
         double rng0  = mRates[3].high - mRates[3].low;
         mom = (rng0 > _Point) ? MathMin(100.0, (body0 / rng0) * 100.0) : 50.0;

         double highestH = mRates[0].high;
         double lowestL  = mRates[0].low;
         for(int b = 1; b < 4; b++)
         {
            if(mRates[b].high > highestH) highestH = mRates[b].high;
            if(mRates[b].low  < lowestL)  lowestL  = mRates[b].low;
         }
         double midPoint = (highestH + lowestL) / 2.0;

         if((c0 >= o0 && c0 > midPoint) || (c0 > c1 && mRates[3].high >= mRates[2].high))
            bull = true;
         else if((c0 < o0 && c0 < midPoint) || (c0 < c1 && mRates[3].low <= mRates[2].low))
            bear = true;
      }
      else
      {
         if(g_WaveSide == 1) bull = true;
         else if(g_WaveSide == -1) bear = true;
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
      g_SamuraiMTF.gradeStr     = StringFormat("STRONG BUY (%d%%)", (int)MathRound(pct));
   }
   else if(pct <= 38.0)
   {
      g_SamuraiMTF.consensusDir = -1;
      g_SamuraiMTF.gradeStr     = StringFormat("STRONG SELL (%d%%)", (int)MathRound(100.0 - pct));
   }
   else
   {
      g_SamuraiMTF.consensusDir = 0;
      g_SamuraiMTF.gradeStr     = "NEUTRAL SIDEWAY";
   }

   // 3. Directional Bias Engine Live Update
   g_MarketBiasBuyPct  = (int)MathRound(pct);
   g_MarketBiasBuyPct  = MathMax(0, MathMin(100, g_MarketBiasBuyPct));
   g_MarketBiasSellPct = 100 - g_MarketBiasBuyPct;

   // 4. Formulate Kamnan Ball & SMC 3-Step Execution
   if(g_SniperStage == STAGE_TRIGGER_PA)
   {
      if(g_WaveSide == -1)
      {
         g_StepTitle = "🚀 สเต็ป 3 (ลั่นไก): แตะ Supply + แท่งทิ้งไส้";
         g_StepDesc  = "👉 แรงซื้อหมดเกลี้ยง ➔ [ กดปุ่ม SELL ได้ทันที ] 🔴";
         g_StepColor = clrCrimson;
      }
      else
      {
         g_StepTitle = "🚀 สเต็ป 3 (ลั่นไก): แตะ Demand + แท่งทิ้งไส้";
         g_StepDesc  = "👉 แรงขายหมดเกลี้ยง ➔ [ กดปุ่ม BUY ได้ทันที ] 🟢";
         g_StepColor = clrLime;
      }
   }
   else if(g_SniperStage == STAGE_IN_ZONE)
   {
      if(g_WaveSide == -1)
      {
         g_StepTitle = "🎯 สเต็ป 3: ราคาแตะ Supply Zone / Hidden Blade";
         g_StepDesc  = "👉 รอแท่งปิดทิ้งไส้คอนเฟิร์ม ➔ เตรียมกด SELL 🔴";
         g_StepColor = clrTomato;
      }
      else
      {
         g_StepTitle = "🎯 สเต็ป 3: ราคาแตะ Demand Zone / Hidden Blade";
         g_StepDesc  = "👉 รอแท่งปิดทิ้งไส้คอนเฟิร์ม ➔ เตรียมกด BUY 🟢";
         g_StepColor = C'80,240,160';
      }
   }
   else if(g_SniperStage == STAGE_ALERT_BREAK || (g_IsFailedHigh && g_WaveSide == -1) || (g_IsFailedLow && g_WaveSide == 1))
   {
      if(g_WaveSide == -1)
      {
         g_StepTitle = "🛒 สเต็ป 2: ปริ้นสปีดขึ้น + ขาดการเบรกไฮ (BOS)";
         g_StepDesc  = "👉 รอราคายกตัวรีเทสต์เข้า Supply ➔ เตรียมกด SELL 🔴";
         g_StepColor = C'255,140,140';
      }
      else
      {
         g_StepTitle = "🛒 สเต็ป 2: ปริ้นสปีดลง + ขาดการหลุดโล (BOS)";
         g_StepDesc  = "👉 รอราคาย่อตัวรีเทสต์เข้า Demand ➔ เตรียมกด BUY 🟢";
         g_StepColor = C'140,240,180';
      }
   }
   else
   {
      // Step 1: Cycle Completed / Sweep / Wait Structure / CF M1 Active Sync
      if(InpUseDTD_CF_M1 && g_DTD.isEngulfConfirmed)
      {
         if(g_DTD.setupSide == -1)
         {
            g_StepTitle = "🎯 สเต็ป 3 (CF M1): จบแท่งกลืนกิน SELL คอนเฟิร์มแล้ว!";
            g_StepDesc  = "👉 โครงสร้างลงคุมตลาด ➔ ดักเด้ง/ลั่นไก SELL ตามแผน 1:3R 🔴";
            g_StepColor = C'255,100,120';
         }
         else
         {
            g_StepTitle = "🎯 สเต็ป 3 (CF M1): จบแท่งกลืนกิน BUY คอนเฟิร์มแล้ว!";
            g_StepDesc  = "👉 โครงสร้างขึ้นคุมตลาด ➔ ดักย่อ/ลั่นไก BUY ตามแผน 1:3R 🟢";
            g_StepColor = C'80,240,160';
         }
      }
      else if(g_WaveCycleCompleted)
      {
         g_StepTitle = "🏁 สถานะคลื่น: " + g_WaveCompletionDesc;
         g_StepDesc  = "👉 รอบเดิมจบแล้ว ➔ สแกนหา Step 1 กวาดสวิง High/Low หรือรอ CF M1 ⏳";
         g_StepColor = clrGold;
      }
      else if(g_WaveSide == -1)
      {
         g_StepTitle = "⚠️ สเต็ป 1: แตะ High (BSL Sweep กวาดเหยื่อ)";
         g_StepDesc  = "👉 รอแท่งแดงหลุด Low สปีดไลน์ยืนยัน ChoCH ⏳";
         g_StepColor = clrOrange;
      }
      else if(g_WaveSide == 1)
      {
         g_StepTitle = "⚠️ สเต็ป 1: แตะ Low (SSL Sweep กวาดเหยื่อ)";
         g_StepDesc  = "👉 รอแท่งเขียวเบรก High สปีดไลน์ยืนยัน ChoCH ⏳";
         g_StepColor = clrGold;
      }
      else
      {
         g_StepTitle = "🎯 สเต็ป 1: รอกราฟกวาดสวิง High / Low";
         g_StepDesc  = "👉 กราฟวิ่งปกติ ➔ รอสปีดไลน์และโครงสร้างคลื่น ⏳";
         g_StepColor = clrSkyBlue;
      }
   }
}

//+------------------------------------------------------------------+
//| 5. DRAW SPEEDLINES (กำนันบอล: สปีดไลน์จับเทรนด์ & ปริ้นสปีดไลน์)       |
//| ระบบ Auto-Reset สดใหม่ & กรองการหมดอายุ (Broken SL Expiry)          |
//+------------------------------------------------------------------+
void UpdateSpeedlines(const MqlRates &rates[], int total)
{
   g_HasUpSpeedline = false;
   g_HasDnSpeedline = false;
   g_IsUpSL_Broken  = false;
   g_IsDnSL_Broken  = false;

   if(g_SwingCount < 2)
   {
      ObjectDelete(0, GUI_PREFIX + "SL_UP");
      ObjectDelete(0, GUI_PREFIX + "SL_DN");
      return;
   }

   // ปรับ Lookback และระยะห่างสวิงขั้นต่ำตาม Timeframe ป้องกันดึงสวิงโบราณ
   int maxBarLookback = 35;
   int minSwingBars   = 4;

   if(_Period == PERIOD_M1)
   {
      maxBarLookback = 25; // M1: ย้อนหลังไม่เกิน 25 แท่ง
      minSwingBars   = 4;
   }
   else if(_Period == PERIOD_M5)
   {
      maxBarLookback = 30; // M5: ย้อนหลังไม่เกิน 30 แท่ง
      minSwingBars   = 4;
   }
   else if(_Period <= PERIOD_M30)
   {
      maxBarLookback = 40;
      minSwingBars   = 3;
   }
   else
   {
      maxBarLookback = 50;
      minSwingBars   = 3;
   }

   int maxScanSwings = MathMin(10, g_SwingCount);
   double maxPtsPerBar = MathMax(g_Asset.slPoints * 0.30, 25.0); // เพดานความชันสูงสุด ป้องกันสปีดไลน์ดิ่งเป็นจรวด
   int maxLatestPivotBar = (_Period <= PERIOD_M5) ? 12 : 18;     // สวิงล่าสุด l1/h1 ต้องสดใหม่ ไม่ตกค้าง

   // -------------------------------------------------------------
   // 1. Uptrend Speedline: เชื่อม 2 Higher Lows (HL) ล่าสุดในรอบคลื่นสด
   // -------------------------------------------------------------
   int l1 = -1, l2 = -1;
   for(int i = 0; i < maxScanSwings; i++)
   {
      if(!g_Swings[i].isHigh && g_Swings[i].bar <= maxBarLookback)
      {
         if(l1 == -1)
         {
            if(g_Swings[i].bar <= maxLatestPivotBar)
               l1 = i;
         }
         else
         {
            int barSpan = g_Swings[i].bar - g_Swings[l1].bar;
            if(barSpan >= minSwingBars && g_Swings[l1].price > g_Swings[i].price)
            {
               double ptsPerBar = (g_Swings[l1].price - g_Swings[i].price) / (double)barSpan / _Point;
               if(ptsPerBar <= maxPtsPerBar)
               {
                  l2 = i;
                  break;
               }
            }
         }
      }
   }

   if(l1 != -1 && l2 != -1)
   {
      datetime t1 = g_Swings[l2].time; // จุดเก่า
      double   p1 = g_Swings[l2].price;
      datetime t2 = g_Swings[l1].time; // จุดใหม่
      double   p2 = g_Swings[l1].price;

      double dt = (double)(rates[0].time - t1);
      double slope = (p2 - p1) / (double)MathMax((long)(t2 - t1), 1);
      double currentLinePrice = p1 + (slope * dt);

      // ตรวจสอบระยะห่างจากสปีดไลน์
      double distFromLine = currentLinePrice - rates[0].close; // ถ้าราคาอยู่ใต้เส้น ค่าจะเป็นบวก

      // ตรวจจับการหลุด/ปริ้นสปีดไลน์ขาขึ้น
      bool isBroken = (rates[0].close < currentLinePrice || rates[1].close < (p1 + (slope * (double)(rates[1].time - t1))));

      // เงื่อนไขหมดอายุของสปีดไลน์ (Auto-Reset / Expiry Rules):
      // 1. ถ้าราคายังอยู่เหนือเส้นหรือเพิ่งแตะเส้น: ต้องไม่ลอยห่างเกิน 2.0 * SL
      // 2. ถ้าหลุดเส้นแล้ว (Broken): ถ้าราคาปิดหลุดต่ำกว่าเส้นเกิน 0.70 * SL หรือสวิง l1 เก่าเกิน 15 แท่ง ➔ ถือว่าหมดอายุ ตัดทิ้งทันที!
      bool isExpired = false;
      if(isBroken)
      {
         if(distFromLine > g_Asset.slPoints * 0.70 * _Point || g_Swings[l1].bar > 15)
            isExpired = true;
      }
      else
      {
         if(MathAbs(rates[0].close - currentLinePrice) > g_Asset.slPoints * 2.0 * _Point)
            isExpired = true;
      }

      if(!isExpired)
      {
         g_HasUpSpeedline = true;
         g_UpSL_Time1     = t1;
         g_UpSL_Price1    = p1;
         g_UpSL_Time2     = t2;
         g_UpSL_Price2    = p2;
         g_IsUpSL_Broken  = isBroken;
      }
   }

   // -------------------------------------------------------------
   // 2. Downtrend Speedline: เชื่อม 2 Lower Highs (LH) ล่าสุดในรอบคลื่นสด
   // -------------------------------------------------------------
   int h1 = -1, h2 = -1;
   for(int i = 0; i < maxScanSwings; i++)
   {
      if(g_Swings[i].isHigh && g_Swings[i].bar <= maxBarLookback)
      {
         if(h1 == -1)
         {
            if(g_Swings[i].bar <= maxLatestPivotBar)
               h1 = i;
         }
         else
         {
            int barSpan = g_Swings[i].bar - g_Swings[h1].bar;
            if(barSpan >= minSwingBars && g_Swings[h1].price < g_Swings[i].price)
            {
               double ptsPerBar = (g_Swings[i].price - g_Swings[h1].price) / (double)barSpan / _Point;
               if(ptsPerBar <= maxPtsPerBar)
               {
                  h2 = i;
                  break;
               }
            }
         }
      }
   }

   if(h1 != -1 && h2 != -1)
   {
      datetime t1 = g_Swings[h2].time; // จุดเก่า
      double   p1 = g_Swings[h2].price;
      datetime t2 = g_Swings[h1].time; // จุดใหม่
      double   p2 = g_Swings[h1].price;

      double dt = (double)(rates[0].time - t1);
      double slope = (p2 - p1) / (double)MathMax((long)(t2 - t1), 1);
      double currentLinePrice = p1 + (slope * dt);

      // ตรวจสอบระยะห่างจากสปีดไลน์
      double distFromLine = rates[0].close - currentLinePrice; // ถ้าราคาอยู่เหนือเส้น ค่าจะเป็นบวก

      // ตรวจจับการหลุด/ปริ้นสปีดไลน์ขาลง
      bool isBroken = (rates[0].close > currentLinePrice || rates[1].close > (p1 + (slope * (double)(rates[1].time - t1))));

      // เงื่อนไขหมดอายุของสปีดไลน์:
      bool isExpired = false;
      if(isBroken)
      {
         if(distFromLine > g_Asset.slPoints * 0.70 * _Point || g_Swings[h1].bar > 15)
            isExpired = true;
      }
      else
      {
         if(MathAbs(rates[0].close - currentLinePrice) > g_Asset.slPoints * 2.0 * _Point)
            isExpired = true;
      }

      if(!isExpired)
      {
         g_HasDnSpeedline = true;
         g_DnSL_Time1     = t1;
         g_DnSL_Price1    = p1;
         g_DnSL_Time2     = t2;
         g_DnSL_Price2    = p2;
         g_IsDnSL_Broken  = isBroken;
      }
   }

   // -------------------------------------------------------------
   // 3. Mutual Exclusivity: กฎคัดกรองสปีดไลน์เดี่ยว ป้องกัน 2 เส้นกากบาทตัดกัน
   // -------------------------------------------------------------
   if(g_HasUpSpeedline && g_HasDnSpeedline)
   {
      // กรณี 1: เส้นหนึ่งยังไม่หัก (วิ่งตามเทรนด์สด) แต่อีกเส้นหักแล้ว ➔ เลือกเส้นที่ยังไม่หัก
      if(!g_IsUpSL_Broken && g_IsDnSL_Broken)
      {
         g_HasDnSpeedline = false;
      }
      else if(g_IsUpSL_Broken && !g_IsDnSL_Broken)
      {
         g_HasUpSpeedline = false;
      }
      else
      {
         // กรณี 2: ทั้งคู่สถานะเดียวกัน (ยังไม่หักทั้งคู่ หรือหักทั้งคู่) ➔ เลือกเส้นที่จุดสวิงล่าสุดใหม่กว่า (Fresher Pivot)
         if(g_UpSL_Time2 >= g_DnSL_Time2)
            g_HasDnSpeedline = false;
         else
            g_HasUpSpeedline = false;
      }
   }

   // ลบ Object ทันทีหากเส้นถูกปิดใช้งาน เพื่อไม่ให้มีเส้นค้างคาตา
   if(!g_HasUpSpeedline) ObjectDelete(0, GUI_PREFIX + "SL_UP");
   if(!g_HasDnSpeedline) ObjectDelete(0, GUI_PREFIX + "SL_DN");
}

//+------------------------------------------------------------------+
//| 6. ANALYZE WAVE A-B-C (กำนันบอล: ขาดการเบรกไฮ / ขาดการหลุดโล)       |
//| ผสานระบบตรวจจับการจบการแพ้ชนะของรอบคลื่น (Wave Battle Resolution)      |
//| และ Auto-Reset ทันทีเมื่อรอบคลื่นสิ้นสุด ไม่ค้างคาหน้ากราฟ                |
//+------------------------------------------------------------------+
void AnalyzeWaveStructure(const MqlRates &rates[], int total)
{
   g_WaveFormed         = false;
   g_WaveSide           = 0;
   g_IsFailedHigh       = false;
   g_IsFailedLow        = false;
   g_SniperStage        = STAGE_WATCH_TREND;
   g_WaveCycleCompleted = false;
   g_WaveCompletionDesc = "";

   if(g_SwingCount < 3)
   {
      ObjectDelete(0, GUI_PREFIX + "WAVE_A");
      ObjectDelete(0, GUI_PREFIX + "WAVE_B");
      ObjectDelete(0, GUI_PREFIX + "WAVE_C");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_AB");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_BC");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_CD");
      ObjectDelete(0, GUI_PREFIX + "WAVE_D_1618");
      ObjectDelete(0, GUI_PREFIX + "WAVE_D_LBL");
      return;
   }

   int maxRecentSwings = MathMin(8, g_SwingCount);
   int maxBarLookback  = 70; // สวิงคลื่น A-B-C ต้องอยู่ในกรอบ 70 แท่งล่าสุดเท่านั้น

   // -------------------------------------------------------------
   // 1. SCAN FOR CANDIDATE SELL SETUP (Peak A -> Valley B -> Retest C)
   // -------------------------------------------------------------
   bool   sellValid = false;
   bool   sellCycleCompleted = false;
   string sellCompletionReason = "";
   int    sellA_Idx = -1, sellB_Idx = -1, sellC_Idx = -1;
   double sellA_Price = 0.0, sellB_Price = 0.0, sellC_Price = 0.0;
   datetime sellA_Time = 0, sellB_Time = 0, sellC_Time = 0;

   // วนลูปจากสวิงไฮสดใหม่ (a = 1) ไปยังสวิงไฮเก่า เพื่อค้นหาคลื่นที่กำลัง Active สดๆ ก่อน
   for(int pass = 0; pass < 2 && !sellValid; pass++)
   {
      for(int a = 1; a < maxRecentSwings; a++)
      {
         if(!g_Swings[a].isHigh || g_Swings[a].bar > maxBarLookback) continue;

         double aPrice = g_Swings[a].price;
         datetime aTime = g_Swings[a].time;

         // จุด B: สวิงโลว์ต่ำสุดที่เกิดหลังจุด A
         int bIdx = -1;
         double bPrice = 9999999.0;
         datetime bTime = 0;
         for(int b = a - 1; b >= 0; b--)
         {
            if(!g_Swings[b].isHigh && g_Swings[b].time > aTime)
            {
               if(bIdx == -1 || g_Swings[b].price < bPrice)
               {
                  bPrice = g_Swings[b].price;
                  bTime  = g_Swings[b].time;
                  bIdx   = b;
               }
            }
         }
         if(bIdx == -1) continue;

         double drop = aPrice - bPrice;
         if(drop < g_Asset.slPoints * 0.15 * _Point) continue;

         // จุด C: สวิงไฮที่เกิดหลังจุด B
         int cIdx = -1;
         double cPrice = 0.0;
         datetime cTime = 0;
         for(int c = bIdx - 1; c >= 0; c--)
         {
            if(g_Swings[c].isHigh && g_Swings[c].time > bTime)
            {
               if(cIdx == -1 || g_Swings[c].price > cPrice)
               {
                  cIdx   = c;
                  cPrice = g_Swings[c].price;
                  cTime  = g_Swings[c].time;
               }
            }
         }

         // หากยังไม่ยืนยัน Swing High ให้ตรวจจับ High ของแท่งรีเทสต์ล่าสุดหลัง B
         if(cIdx == -1)
         {
            double retestH = rates[0].high;
            datetime retestT = rates[0].time;
            for(int k = 1; k < 25 && k < total; k++)
            {
               if(rates[k].time <= bTime) break;
               if(rates[k].high > retestH)
               {
                  retestH = rates[k].high;
                  retestT = rates[k].time;
               }
            }
            cPrice = retestH;
            cTime  = retestT;
         }

         // กฎกำนันบอล: ขาดการเบรกไฮ (C < A)
         if(cPrice >= aPrice) continue;

         // ตรวจสอบการจบการแพ้ชนะของรอบคลื่น (Wave Battle Resolution)
         // 1) ฝั่งตรงข้ามชนะ (ChoCH เสียทรง / เบรกยอด C หรือ A ขึ้นไป)
         bool isLost = false;
         if(rates[0].close >= aPrice || rates[0].high >= aPrice)
            isLost = true;
         else if(cIdx >= 0 && rates[0].time > cTime)
         {
            if(rates[0].close > cPrice + (3 * _Point) || (rates[1].time > cTime && rates[1].close > cPrice + (3 * _Point)))
               isLost = true;
         }

         // 1B) ตรวจสอบการกลับตัวภายในหลังจุด B (Internal Bullish ChoCH: เกิด Higher Low และเบรก High ย่อย)
         if(!isLost && bIdx >= 2)
         {
            double firstHighAfterB = 0.0;
            for(int s = bIdx - 1; s >= 0; s--)
            {
               if(g_Swings[s].isHigh && g_Swings[s].time > bTime)
               {
                  if(firstHighAfterB == 0.0) firstHighAfterB = g_Swings[s].price;
               }
               else if(!g_Swings[s].isHigh && g_Swings[s].time > bTime && g_Swings[s].price > bPrice)
               {
                  if(firstHighAfterB > 0.0 && rates[0].close > firstHighAfterB)
                     isLost = true;
               }
            }
         }

         // 2) ฝั่ง Sell ชนะแล้ว จบรอบสมบูรณ์ (ราคาหลุด B เข้าเป้า TP หลังเกิดจุด C)
         bool isWon = false;
         if(cIdx >= 0 && rates[0].time > cTime)
         {
            if(rates[0].close < bPrice || rates[0].low <= (bPrice - (g_Asset.slPoints * 0.05 * _Point)))
               isWon = true;
         }

         // 3) จุด C เก่าเกินไป (มีสวิงใหม่ฟอร์มตัวทับซ้อนเกิน 2 สวิง)
         bool isStale = (cIdx >= 2);

         if(!isLost && !isWon && !isStale)
         {
            // รอบคลื่นกำลังต่อสู้สดๆ ตรงหน้า!
            sellValid     = true;
            sellA_Idx     = a;
            sellA_Price   = aPrice;
            sellA_Time    = aTime;
            sellB_Idx     = bIdx;
            sellB_Price   = bPrice;
            sellB_Time    = bTime;
            sellC_Idx     = cIdx;
            sellC_Price   = cPrice;
            sellC_Time    = cTime;
            break;
         }
         else if(pass == 1 && !sellCycleCompleted)
         {
            sellCycleCompleted = true;
            if(isWon)
               sellCompletionReason = "ฝั่ง Sell ชนะ (หลุด B เข้าเป้า TP จบรอบ)";
            else if(isLost)
               sellCompletionReason = "ฝั่ง Sell แพ้ (เบรกทะลุ C เสียทรง ChoCH)";
            else
               sellCompletionReason = "รอบคลื่นหมดอายุ (มีสวิงใหม่ทับซ้อน)";
         }
      }
   }

   // -------------------------------------------------------------
   // 2. SCAN FOR CANDIDATE BUY SETUP (Valley A -> Peak B -> Retest C)
   // -------------------------------------------------------------
   bool   buyValid = false;
   bool   buyCycleCompleted = false;
   string buyCompletionReason = "";
   int    buyA_Idx = -1, buyB_Idx = -1, buyC_Idx = -1;
   double buyA_Price = 0.0, buyB_Price = 0.0, buyC_Price = 0.0;
   datetime buyA_Time = 0, buyB_Time = 0, buyC_Time = 0;

   // วนลูปจากสวิงโลว์สดใหม่ (a = 1) ไปยังสวิงโลว์เก่า เพื่อค้นหาคลื่นที่กำลัง Active สดๆ ก่อน
   for(int pass = 0; pass < 2 && !buyValid; pass++)
   {
      for(int a = 1; a < maxRecentSwings; a++)
      {
         if(g_Swings[a].isHigh || g_Swings[a].bar > maxBarLookback) continue;

         double aPrice = g_Swings[a].price;
         datetime aTime = g_Swings[a].time;

         // จุด B: สวิงไฮสูงสุดที่เกิดหลังจุด A
         int bIdx = -1;
         double bPrice = 0.0;
         datetime bTime = 0;
         for(int b = a - 1; b >= 0; b--)
         {
            if(g_Swings[b].isHigh && g_Swings[b].time > aTime)
            {
               if(bIdx == -1 || g_Swings[b].price > bPrice)
               {
                  bPrice = g_Swings[b].price;
                  bTime  = g_Swings[b].time;
                  bIdx   = b;
               }
            }
         }
         if(bIdx == -1) continue;

         double rally = bPrice - aPrice;
         if(rally < g_Asset.slPoints * 0.15 * _Point) continue;

         // จุด C: สวิงโลว์ที่เกิดหลังจุด B
         int cIdx = -1;
         double cPrice = 9999999.0;
         datetime cTime = 0;
         for(int c = bIdx - 1; c >= 0; c--)
         {
            if(!g_Swings[c].isHigh && g_Swings[c].time > bTime)
            {
               if(cIdx == -1 || g_Swings[c].price < cPrice)
               {
                  cIdx   = c;
                  cPrice = g_Swings[c].price;
                  cTime  = g_Swings[c].time;
               }
            }
         }

         // หากยังไม่ยืนยัน Swing Low ให้ตรวจจับ Low ของแท่งรีเทสต์ล่าสุดหลัง B
         if(cIdx == -1)
         {
            double retestL = rates[0].low;
            datetime retestT = rates[0].time;
            for(int k = 1; k < 25 && k < total; k++)
            {
               if(rates[k].time <= bTime) break;
               if(rates[k].low < retestL)
               {
                  retestL = rates[k].low;
                  retestT = rates[k].time;
               }
            }
            cPrice = retestL;
            cTime  = retestT;
         }

         // กฎกำนันบอล: ขาดการหลุดโล (C > A)
         if(cPrice <= aPrice) continue;

         // ตรวจสอบการจบการแพ้ชนะของรอบคลื่น (Wave Battle Resolution)
         // 1) ฝั่งตรงข้ามชนะ (ChoCH เสียทรง / หลุดก้น C หรือ A ลงไป)
         bool isLost = false;
         if(rates[0].close <= aPrice || rates[0].low <= aPrice)
            isLost = true;
         else if(cIdx >= 0 && rates[0].time > cTime)
         {
            if(rates[0].close < cPrice - (3 * _Point) || (rates[1].time > cTime && rates[1].close < cPrice - (3 * _Point)))
               isLost = true;
         }

         // 1B) ตรวจสอบการกลับตัวภายในหลังจุด B (Internal Bearish ChoCH: เกิด Lower High หลัง B แล้วทุบหลุด Low ย่อย)
         if(!isLost && bIdx >= 2)
         {
            double firstLowAfterB = 9999999.0;
            bool   hasLowerHighAfterB = false;
            for(int s = bIdx - 1; s >= 0; s--)
            {
               if(!g_Swings[s].isHigh && g_Swings[s].time > bTime)
               {
                  if(firstLowAfterB == 9999999.0) firstLowAfterB = g_Swings[s].price;
               }
               else if(g_Swings[s].isHigh && g_Swings[s].time > bTime && g_Swings[s].price < bPrice)
               {
                  hasLowerHighAfterB = true;
               }
            }
            if(hasLowerHighAfterB && firstLowAfterB < 9999999.0 && (rates[0].close < firstLowAfterB || cPrice < firstLowAfterB))
               isLost = true;
         }

         // 2) ฝั่ง Buy ชนะแล้ว จบรอบสมบูรณ์ (ราคาเบรกทะลุ B เข้าเป้า TP หลังเกิดจุด C)
         bool isWon = false;
         if(cIdx >= 0 && rates[0].time > cTime)
         {
            if(rates[0].close > bPrice || rates[0].high >= (bPrice + (g_Asset.slPoints * 0.05 * _Point)))
               isWon = true;
         }

         // 3) จุด C เก่าเกินไป (มีสวิงใหม่ฟอร์มตัวทับซ้อนเกิน 2 สวิง)
         bool isStale = (cIdx >= 2);

         if(!isLost && !isWon && !isStale)
         {
            // รอบคลื่นกำลังต่อสู้สดๆ ตรงหน้า!
            buyValid     = true;
            buyA_Idx     = a;
            buyA_Price   = aPrice;
            buyA_Time    = aTime;
            buyB_Idx     = bIdx;
            buyB_Price   = bPrice;
            buyB_Time    = bTime;
            buyC_Idx     = cIdx;
            buyC_Price   = cPrice;
            buyC_Time    = cTime;
            break;
         }
         else if(pass == 1 && !buyCycleCompleted)
         {
            buyCycleCompleted = true;
            if(isWon)
               buyCompletionReason = "ฝั่ง Buy ชนะ (เบรก B เข้าเป้า TP จบรอบ)";
            else if(isLost)
               buyCompletionReason = "ฝั่ง Buy แพ้ (หลุดทะลุ C เสียทรง ChoCH)";
            else
               buyCompletionReason = "รอบคลื่นหมดอายุ (มีสวิงใหม่ทับซ้อน)";
         }
      }
   }

   // -------------------------------------------------------------
   // 3. DETERMINE THE ACTIVE DOMINANT WAVE CYCLE (WITH MTF HARMONY GUARD)
   // -------------------------------------------------------------
   int chosen = 0;
   if(sellValid && buyValid)
   {
      if(g_SamuraiMTF.consensusDir == -1 && g_MarketBiasSellPct >= 62)      chosen = -1;
      else if(g_SamuraiMTF.consensusDir == 1 && g_MarketBiasBuyPct >= 62)   chosen = 1;
      else if(sellB_Time != buyB_Time) chosen = (sellB_Time > buyB_Time) ? -1 : 1;
      else if(sellC_Time >= buyC_Time) chosen = -1;
      else                             chosen = 1;
   }
   else if(sellValid)
   {
      // ป้องกันการชี้เป้า SELL สวนมติตลาดขาขึ้นรุนแรง (BUY >= 75%)
      if(g_SamuraiMTF.consensusDir == 1 && g_MarketBiasBuyPct >= 75 && g_EMA14_Val > 0 && rates[0].close > g_EMA14_Val)
      {
         chosen = 0;
         sellCycleCompleted = true;
         sellCompletionReason = "เทรนด์ขาขึ้น MTF คุมตลาด (ยกเลิกคลื่นย่อยสวนเทรนด์)";
      }
      else chosen = -1;
   }
   else if(buyValid)
   {
      // ป้องกันการชี้เป้า BUY สวนมติตลาดขาลงรุนแรง (SELL >= 75%)
      if(g_SamuraiMTF.consensusDir == -1 && g_MarketBiasSellPct >= 75 && g_EMA14_Val > 0 && rates[0].close < g_EMA14_Val)
      {
         chosen = 0;
         buyCycleCompleted = true;
         buyCompletionReason = "เทรนด์ขาลง MTF คุมตลาด (ยกเลิกคลื่นย่อยสวนเทรนด์)";
      }
      else chosen = 1;
   }

   // -------------------------------------------------------------
   // 4. APPLY ACTIVE WAVE DATA OR REGISTER CYCLE RESOLUTION
   // -------------------------------------------------------------
   if(chosen == -1) // ACTIVE SELL SETUP
   {
      g_WaveFormed   = true;
      g_WaveSide     = -1;
      g_WaveA_Price  = sellA_Price;
      g_WaveA_Time   = sellA_Time;
      g_WaveB_Price  = sellB_Price;
      g_WaveB_Time   = sellB_Time;
      g_WaveC_Price  = sellC_Price;
      g_WaveC_Time   = sellC_Time;
      g_IsFailedHigh = true;
      g_SniperStage  = STAGE_ALERT_BREAK;
   }
   else if(chosen == 1) // ACTIVE BUY SETUP
   {
      g_WaveFormed   = true;
      g_WaveSide     = 1;
      g_WaveA_Price  = buyA_Price;
      g_WaveA_Time   = buyA_Time;
      g_WaveB_Price  = buyB_Price;
      g_WaveB_Time   = buyB_Time;
      g_WaveC_Price  = buyC_Price;
      g_WaveC_Time   = buyC_Time;
      g_IsFailedLow  = true;
      g_SniperStage  = STAGE_ALERT_BREAK;
   }
   else
   {
      // ไม่มีรอบคลื่นที่แอคทีฟ (รอบเดิมจบการแพ้ชนะแล้ว หรือรอสปีดไลน์ใหม่)
      g_WaveFormed = false;
      g_WaveSide   = 0;

      // ลบ Object คลื่นทันที เพื่อไม่ให้มีตัวหนังสือและเส้นคลื่นเดิมค้างบนหน้ากราฟ
      ObjectDelete(0, GUI_PREFIX + "WAVE_A");
      ObjectDelete(0, GUI_PREFIX + "WAVE_B");
      ObjectDelete(0, GUI_PREFIX + "WAVE_C");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_AB");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_BC");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_CD");
      ObjectDelete(0, GUI_PREFIX + "WAVE_D_1618");
      ObjectDelete(0, GUI_PREFIX + "WAVE_D_LBL");

      if(sellCycleCompleted || buyCycleCompleted)
      {
         g_WaveCycleCompleted = true;
         if(sellCycleCompleted && buyCycleCompleted)
            g_WaveCompletionDesc = (sellC_Time >= buyC_Time) ? sellCompletionReason : buyCompletionReason;
         else if(sellCycleCompleted)
            g_WaveCompletionDesc = sellCompletionReason;
         else
            g_WaveCompletionDesc = buyCompletionReason;

         // เมื่อรอบคลื่นจบการแพ้ชนะ สปีดไลน์เก่าที่ถูกเบรกในรอบนี้หมดอายุ รีเซ็ตทันที
         if(sellCycleCompleted && g_IsUpSL_Broken)
         {
            g_HasUpSpeedline = false;
            ObjectDelete(0, GUI_PREFIX + "SL_UP");
         }
         if(buyCycleCompleted && g_IsDnSL_Broken)
         {
            g_HasDnSpeedline = false;
            ObjectDelete(0, GUI_PREFIX + "SL_DN");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 6.1 CALCULATE WAVE D EXTENSION TARGETS (EP เสริม 4)              |
//|     - "จุดย่อ กับ จุดยืด กางฟิโบต่างกัน"                           |
//|     - ขา D (จุดยืด): กาง Fibo Extension จาก B ไป C                 |
//|     - C = 0.00%, B = 100.00%                                     |
//|     - D1 = 127.20% (เป้าทะลุแรก)                                  |
//|     - D2 = 161.80% (🎯 Golden Target ขา D หลัก วงกลมสีชมพู)        |
//|     - D3 = 200.00% (เป้าขยายรอบสอง)                              |
//|     - D4 = 261.80% (เป้า Super Trend สุดทาง)                     |
//+------------------------------------------------------------------+
void CalculateWave_D_Targets()
{
   g_HasWave_D  = false;
   g_WaveD_1272 = 0.0;
   g_WaveD_1618 = 0.0;
   g_WaveD_2000 = 0.0;
   g_WaveD_2618 = 0.0;

   if(!InpUseWave_D_Targets) return;
   if(!g_WaveFormed || g_WaveA_Price <= 0 || g_WaveB_Price <= 0 || g_WaveC_Price <= 0) return;

   if(g_WaveSide == 1) // BUY Setup (ฐาน A -> ยอด B -> ย่อ C -> บิน D)
   {
      double height = g_WaveB_Price - g_WaveC_Price;
      if(height <= 0) return;

      g_WaveD_1272 = NormalizeDouble(g_WaveC_Price + (1.272 * height), _Digits);
      g_WaveD_1618 = NormalizeDouble(g_WaveC_Price + (1.618 * height), _Digits);
      g_WaveD_2000 = NormalizeDouble(g_WaveC_Price + (2.000 * height), _Digits);
      g_WaveD_2618 = NormalizeDouble(g_WaveC_Price + (2.618 * height), _Digits);
      g_HasWave_D  = true;
   }
   else if(g_WaveSide == -1) // SELL Setup (ยอด A -> ก้น B -> เด้ง C -> ทุบ D)
   {
      double height = g_WaveC_Price - g_WaveB_Price;
      if(height <= 0) return;

      g_WaveD_1272 = NormalizeDouble(g_WaveC_Price - (1.272 * height), _Digits);
      g_WaveD_1618 = NormalizeDouble(g_WaveC_Price - (1.618 * height), _Digits);
      g_WaveD_2000 = NormalizeDouble(g_WaveC_Price - (2.000 * height), _Digits);
      g_WaveD_2618 = NormalizeDouble(g_WaveC_Price - (2.618 * height), _Digits);
      g_HasWave_D  = true;
   }
}

//+------------------------------------------------------------------+
//| 6.2 DETECT FAKEOUT TRAP (EP เสริม 4: กลับตัวลงหลอก / กลับตัวขึ้นหลอก) |
//|     - ตรวจจับการกวาดสภาพคล่อง (Liquidity Sweep & Stop Hunt)         |
//|     - แกล้งหลุดสวิงเดิม แล้วรูดไส้ Rejection ดึงกลับทันที             |
//+------------------------------------------------------------------+
void DetectFakeoutTrap(const MqlRates &rates[], int total)
{
   g_IsFakeoutTrap = false;
   g_FakeoutSide   = 0;
   g_FakeoutPrice  = 0.0;
   g_FakeoutTime   = 0;
   g_FakeoutDesc   = "";

   if(!InpUseFakeoutTrapRadar || total < 10) return;

   // Trend-Lock Shield: ห้ามส่งสัญญาณสวนเทรนด์หลักเมื่อมติ MTF แข็งแกร่ง (>= 68%) ป้องกัน Card 1 ขัดแย้งกับ Card 2
   bool strongUptrend   = (g_MarketBiasBuyPct >= 68);
   bool strongDowntrend = (g_MarketBiasSellPct >= 68);

   int lastHighIdx = -1, lastLowIdx = -1;
   for(int i = 0; i < g_SwingCount && i < 6; i++)
   {
      if(g_Swings[i].isHigh && lastHighIdx == -1) lastHighIdx = i;
      if(!g_Swings[i].isHigh && lastLowIdx == -1) lastLowIdx = i;
   }

   // 1. ตรวจสอบ "กลับตัวลงหลอก" (Bear Trap Sweep -> BUY) [บล็อกหากเป็นเทรนด์ขาลงแข็งแกร่ง ป้องกันการรับมีด]
   if(lastLowIdx >= 0 && !strongDowntrend)
   {
      double swingLowPrice = g_Swings[lastLowIdx].price;
      datetime swingLowTime = g_Swings[lastLowIdx].time;

      for(int bar = 1; bar <= 4 && bar < total - 1; bar++)
      {
         if(rates[0].close < rates[bar].low) continue;
         double barRange = rates[bar].high - rates[bar].low;
         if(barRange <= 0) continue;

         double lowerWick = MathMin(rates[bar].open, rates[bar].close) - rates[bar].low;
         bool piercedLow  = (rates[bar].low < swingLowPrice && rates[bar].time > swingLowTime);
         bool closedAbove = (rates[bar].close >= swingLowPrice - (g_Asset.slPoints * 0.05 * _Point));
         bool hasRejectionWick = (lowerWick >= barRange * 0.40);
         bool isBullishClose   = (rates[bar].close >= rates[bar].open || (bar == 1 && rates[0].close > rates[1].high));

         if(piercedLow && (closedAbove || hasRejectionWick) && isBullishClose)
         {
            g_IsFakeoutTrap = true;
            g_FakeoutSide   = 1; // BUY
            g_FakeoutPrice  = rates[bar].low;
            g_FakeoutTime   = rates[bar].time;
            g_FakeoutDesc   = StringFormat("กลับตัวลงหลอก (Sweep Low %.2f -> ดักช้อน BUY บินสู่ขา D)", swingLowPrice);
            return;
         }
      }
   }

   // 2. ตรวจสอบ "กลับตัวขึ้นหลอก" (Bull Trap Sweep -> SELL) [บล็อกหากเป็นเทรนด์ขาขึ้นแข็งแกร่ง ป้องกันการดักขวางรถไฟขาขึ้น]
   if(lastHighIdx >= 0 && !strongUptrend)
   {
      double swingHighPrice = g_Swings[lastHighIdx].price;
      datetime swingHighTime = g_Swings[lastHighIdx].time;

      for(int bar = 1; bar <= 4 && bar < total - 1; bar++)
      {
         if(rates[0].close > rates[bar].high) continue;
         double barRange = rates[bar].high - rates[bar].low;
         if(barRange <= 0) continue;

         double upperWick = rates[bar].high - MathMax(rates[bar].open, rates[bar].close);
         bool piercedHigh = (rates[bar].high > swingHighPrice && rates[bar].time > swingHighTime);
         bool closedBelow = (rates[bar].close <= swingHighPrice + (g_Asset.slPoints * 0.05 * _Point));
         bool hasRejectionWick = (upperWick >= barRange * 0.40);
         bool isBearishClose   = (rates[bar].close <= rates[bar].open || (bar == 1 && rates[0].close < rates[1].low));

         if(piercedHigh && (closedBelow || hasRejectionWick) && isBearishClose)
         {
            g_IsFakeoutTrap = true;
            g_FakeoutSide   = -1; // SELL
            g_FakeoutPrice  = rates[bar].high;
            g_FakeoutTime   = rates[bar].time;
            g_FakeoutDesc   = StringFormat("กลับตัวขึ้นหลอก (Sweep High %.2f -> ดักทุบ SELL ดิ่งสู่ขา D)", swingHighPrice);
            return;
         }
      }
   }
}
//+------------------------------------------------------------------+
//| 7. DRAW STANDARD MT5 FIBONACCI RETRACEMENT (OBJ_FIBO)            |
//+------------------------------------------------------------------+
void DrawStandardFibonacci()
{
   string fiboName = GUI_PREFIX + "STD_FIBO";
   datetime t1 = 0, t2 = 0;
   double   p1 = 0.0, p2 = 0.0;

   if(g_WaveFormed && g_WaveA_Price > 0 && g_WaveB_Price > 0)
   {
      // Point 0 (0.0%): Point B (จุดยอดหรือจุดก้นล่าสุด ที่การย่อ/เด้ง Wave C กำลังเริ่มขึ้น)
      // Point 1 (100.0%): Point A (จุดกำเนิดคลื่น Wave A - Base Invalidation)
      // กำหนดแกนเวลา t1 และ t2 โดยให้ t2 ทอดยาวไปในอนาคต (t1 < t2 เสมอ)
      // ป้องกัน MT5 Graphic Engine สลับจุด Point 0/1 ตามแกนเวลา ซึ่งเป็นต้นเหตุของบั๊กฟิโบกลับหัว
      t1 = g_WaveB_Time;  p1 = g_WaveB_Price;
      t2 = MathMax(t1, TimeCurrent()) + (PeriodSeconds() * 20);  p2 = g_WaveA_Price;
   }
   else
   {
      // If Wave A-B not formed yet or completed, anchor to recent swings (last 8 swings, max 70 bars)
      double maxP = 0.0, minP = 9999999.0;
      datetime maxT = 0, minT = 0;

      int maxScanFibo = MathMin(8, g_SwingCount);
      for(int i = 0; i < maxScanFibo; i++)
      {
         if(g_Swings[i].bar > 70) continue;
         if(g_Swings[i].isHigh && g_Swings[i].price > maxP)
         {
            maxP = g_Swings[i].price;
            maxT = g_Swings[i].time;
         }
         if(!g_Swings[i].isHigh && g_Swings[i].price < minP)
         {
            minP = g_Swings[i].price;
            minT = g_Swings[i].time;
         }
      }

      if(maxP > 0 && minP < 9999999.0 && maxT > 0 && minT > 0)
      {
         if(maxT > minT)
         {
            // คลื่นขึ้น (สวิงล่าสุดเป็นยอด High maxP ย่อลงหาก้น minP): 0.0% อยู่ที่ยอด, 100.0% อยู่ที่ก้น
            t1 = maxT; p1 = maxP;
            t2 = MathMax(maxT, TimeCurrent()) + (PeriodSeconds() * 20); p2 = minP;
         }
         else
         {
            // คลื่นลง (สวิงล่าสุดเป็นก้น Low minP เด้งขึ้นหายอด maxP): 0.0% อยู่ที่ก้น, 100.0% อยู่ที่ยอด
            t1 = minT; p1 = minP;
            t2 = MathMax(minT, TimeCurrent()) + (PeriodSeconds() * 20); p2 = maxP;
         }
      }
   }

   static datetime s_lastFiboT1 = 0, s_lastFiboT2 = 0;
   static double   s_lastFiboP1 = 0, s_lastFiboP2 = 0;

   if(t1 > 0 && t2 > 0 && p1 > 0 && p2 > 0)
   {
      if(t1 == s_lastFiboT1 && t2 == s_lastFiboT2 && p1 == s_lastFiboP1 && p2 == s_lastFiboP2 && ObjectFind(0, fiboName) >= 0)
         return;

      s_lastFiboT1 = t1; s_lastFiboT2 = t2;
      s_lastFiboP1 = p1; s_lastFiboP2 = p2;

      if(ObjectFind(0, fiboName) < 0)
      {
         ObjectCreate(0, fiboName, OBJ_FIBO, 0, t1, p1, t2, p2);
      }
      else
      {
         ObjectMove(0, fiboName, 0, t1, p1);
         ObjectMove(0, fiboName, 1, t2, p2);
      }

      ObjectSetInteger(0, fiboName, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, fiboName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, fiboName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, fiboName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, fiboName, OBJPROP_BACK, true);

      // Clean 8 Standard Retracement Levels (Including 70.5% OTE from EP เสริม 4)
      ObjectSetInteger(0, fiboName, OBJPROP_LEVELS, 8);

      ObjectSetDouble(0, fiboName, OBJPROP_LEVELVALUE, 0, 0.0);
      ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 0, "0.0 (%$)");
      ObjectSetInteger(0, fiboName, OBJPROP_LEVELCOLOR, 0, clrSilver);

      ObjectSetDouble(0, fiboName, OBJPROP_LEVELVALUE, 1, 0.236);
      ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 1, "23.6 (%$)");
      ObjectSetInteger(0, fiboName, OBJPROP_LEVELCOLOR, 1, clrDarkGray);

      ObjectSetDouble(0, fiboName, OBJPROP_LEVELVALUE, 2, 0.382);
      ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 2, "38.2 (%$)");
      ObjectSetInteger(0, fiboName, OBJPROP_LEVELCOLOR, 2, clrSilver);

      ObjectSetDouble(0, fiboName, OBJPROP_LEVELVALUE, 3, 0.500);
      ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 3, "50.0 [Golden Pocket] (%$)");
      ObjectSetInteger(0, fiboName, OBJPROP_LEVELCOLOR, 3, clrGold);

      ObjectSetDouble(0, fiboName, OBJPROP_LEVELVALUE, 4, 0.618);
      ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 4, "61.8 [Golden Pocket] (%$)");
      ObjectSetInteger(0, fiboName, OBJPROP_LEVELCOLOR, 4, clrGold);

      ObjectSetDouble(0, fiboName, OBJPROP_LEVELVALUE, 5, 0.705);
      ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 5, "70.5 [OTE Zone • EP เสริม 4] (%$)");
      ObjectSetInteger(0, fiboName, OBJPROP_LEVELCOLOR, 5, C'0,225,255');

      ObjectSetDouble(0, fiboName, OBJPROP_LEVELVALUE, 6, 0.786);
      ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 6, "78.6 [Discount Zone] (%$)");
      ObjectSetInteger(0, fiboName, OBJPROP_LEVELCOLOR, 6, clrOrange);

      ObjectSetDouble(0, fiboName, OBJPROP_LEVELVALUE, 7, 1.000);
      ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 7, "100.0 [Base Invalidation] (%$)");
      ObjectSetInteger(0, fiboName, OBJPROP_LEVELCOLOR, 7, clrCrimson);
   }
}

//+------------------------------------------------------------------+
//| 8. SCAN SMC DEMAND & SUPPLY ZONES (FLAGSHIP EA BOT MASTER SUITE) |
//|    - ยกโมเดลตรงมาจาก Good_Trade_Gold_EA (DetectMTFOrderBlocks)  |
//|    - สแกน Order Block แท้จริงจากแท่งเทียนต้นทาง (Natural Candle)  |
//|    - สแกนเฉพาะจาก Active Timeframe ขึ้นไป ไม่ย้อนไป TF เล็ก      |
//|    - ควบรวมก้อนที่ซ้อนทับกันอย่างนุ่มนวล (35 pts Merge)          |
//|    - โทนสีกรมท่า/รอยัลบลู (Demand) และ โทนสีแดงทับทิม/มารูน (Supply)|
//+------------------------------------------------------------------+
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
   }
   return 0;
}

void ScanDemandSupplyZones(const MqlRates &rates[], int total)
{
   g_ZoneCount = 0;
   ENUM_TIMEFRAMES tfs[] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1};
   string tfNames[]      = {"M5", "M15", "M30", "H1", "H4", "D1", "W1"};
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

   ENUM_TIMEFRAMES activeTF = (ENUM_TIMEFRAMES)_Period;
   int activeRank = GetTFRank(activeTF);

   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(curBid <= 0) curBid = rates[0].close;
   if(curAsk <= 0) curAsk = curBid;

   double mergeDist = (g_Asset.assetType == ASSET_CRYPTO) ? (300.0 * _Point) : (g_Asset.assetType == ASSET_GOLD ? (120.0 * _Point) : (35.0 * _Point));

   // กรองขนาดความกว้างสูงสุดของโซน (Institutional Order Block Max Height Filter)
   // ป้องกันโซนระดับ Macro (เช่น D1/W1) กว้างเป็นพันจุดจนกลืนชาร์ต M5
   double maxZoneHeight = (g_Asset.assetType == ASSET_CRYPTO) ? (1500.0 * _Point) :
                          (g_Asset.assetType == ASSET_GOLD   ? (600.0  * _Point) : (180.0 * _Point));

   // สำหรับชาร์ต Intraday (M1 ถึง H1) สแกนสูงสุดถึงแค่ PERIOD_D1 (ไม่สแกน W1 เพื่อไม่ให้แท่งสัปดาห์ขนาดยักษ์ครอบทับ M5)
   int effectiveNumTFs = numTFs;
   if(activeRank <= 5) // M1(1), M5(2), M15(3), M30(4), H1(5)
      effectiveNumTFs = 6; // สแกนถึงแค่ D1 (index 5)

   for(int t = 0; t < effectiveNumTFs; t++)
   {
      // สแกนเฉพาะจาก Timeframe ที่กำลังเปิดดูกราฟขึ้นไปจนถึง D1 (ไม่ย้อนไปดู TF เล็กกว่า)
      if(GetTFRank(tfs[t]) < activeRank)
         continue;

      MqlRates mtfRates[];
      ArraySetAsSeries(mtfRates, true);
      int copied = CopyRates(_Symbol, tfs[t], 0, 100, mtfRates);
      if(copied < 10)
         continue;

      int maxScan = MathMin(80, copied - 3);

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

            // ตรวจสอบว่าแท่งเทียนถัดมาระหว่างทางไม่เคยปิดหลุดก้น btm (Unmitigated / Valid Demand)
            bool isViolated = false;
            for(int k = i - 3; k >= 0; k--)
            {
               if(mtfRates[k].close < btm) { isViolated = true; break; }
            }
            if(isViolated) continue;

            // 1. Demand ต้องเป็นแนวรับอยู่ใต้ราคา หรือกำลังทดสอบขอบบนโซน (ห้ามราคาหลุดลึกต่ำกว่ายอดโซน)
            if(curBid < top - (maxZoneHeight * 0.40)) continue;
            if(curBid < btm - (g_Asset.slPoints * 0.10 * _Point)) continue;

            // 2. ปรับความสูงโซนให้กระชับคมชัด (Zone Height Capping): คัดกรองเน้นขอบบนของ Demand
            if((top - btm) > maxZoneHeight)
               btm = top - maxZoneHeight;

            bool merged = false;
            for(int k = 0; k < g_ZoneCount; k++)
            {
               if(g_Zones[k].isDemand &&
                  MathAbs(g_Zones[k].high - top) <= mergeDist &&
                  MathAbs(g_Zones[k].low - btm)  <= mergeDist)
               {
                  if(StringFind(g_Zones[k].tfName, tfNames[t]) < 0)
                     g_Zones[k].tfName += " • " + tfNames[t];
                  g_Zones[k].isConfluence = true;
                  merged = true;
                  break;
               }
            }

            if(!merged && g_ZoneCount < 60)
            {
               int z = g_ZoneCount++;
               g_Zones[z].time         = mtfRates[i].time;
               g_Zones[z].high         = top;
               g_Zones[z].low          = btm;
               g_Zones[z].isDemand     = true;
               g_Zones[z].isActive     = true;
               g_Zones[z].touches      = 0;
               g_Zones[z].tfName       = tfNames[t];
               g_Zones[z].isConfluence = false;
               g_Zones[z].isHTF        = (tfs[t] >= PERIOD_H1);
               g_Zones[z].tfCount      = 1;
               g_Zones[z].boxColor     = demandCols[t];
            }
            break;
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

            // ตรวจสอบว่าแท่งเทียนถัดมาระหว่างทางไม่เคยปิดทะลุยอด top (Unmitigated / Valid Supply)
            bool isViolated = false;
            for(int k = i - 3; k >= 0; k--)
            {
               if(mtfRates[k].close > top) { isViolated = true; break; }
            }
            if(isViolated) continue;

            // 1. Supply ต้องเป็นแนวต้านอยู่เหนือราคา หรือกำลังทดสอบขอบล่างโซน (ห้ามราคาพุ่งทะลุสูงกว่าก้นโซน)
            if(curAsk > btm + (maxZoneHeight * 0.40)) continue;
            if(curAsk > top + (g_Asset.slPoints * 0.10 * _Point)) continue;

            // 2. ปรับความสูงโซนให้กระชับคมชัด (Zone Height Capping): คัดกรองเน้นขอบล่างของ Supply
            if((top - btm) > maxZoneHeight)
               top = btm + maxZoneHeight;

            bool merged = false;
            for(int k = 0; k < g_ZoneCount; k++)
            {
               if(!g_Zones[k].isDemand &&
                  MathAbs(g_Zones[k].high - top) <= mergeDist &&
                  MathAbs(g_Zones[k].low - btm)  <= mergeDist)
               {
                  if(StringFind(g_Zones[k].tfName, tfNames[t]) < 0)
                     g_Zones[k].tfName += " • " + tfNames[t];
                  g_Zones[k].isConfluence = true;
                  merged = true;
                  break;
               }
            }

            if(!merged && g_ZoneCount < 60)
            {
               int z = g_ZoneCount++;
               g_Zones[z].time         = mtfRates[i].time;
               g_Zones[z].high         = top;
               g_Zones[z].low          = btm;
               g_Zones[z].isDemand     = false;
               g_Zones[z].isActive     = true;
               g_Zones[z].touches      = 0;
               g_Zones[z].tfName       = tfNames[t];
               g_Zones[z].isConfluence = false;
               g_Zones[z].isHTF        = (tfs[t] >= PERIOD_H1);
               g_Zones[z].tfCount      = 1;
               g_Zones[z].boxColor     = supplyCols[t];
            }
            break;
         }
      }
   }

   // 3. Cross-Zone Reconciliation (กำจัดโซนทับซ้อน/ชนขอบระหว่าง Demand กับ Supply)
   for(int d = 0; d < g_ZoneCount; d++)
   {
      if(!g_Zones[d].isActive || !g_Zones[d].isDemand) continue;
      for(int s = 0; s < g_ZoneCount; s++)
      {
         if(!g_Zones[s].isActive || g_Zones[s].isDemand) continue;

         // ตรวจสอบว่าขอบบน Demand ชนหรือซ้อนทับกับขอบล่าง Supply
         if(g_Zones[d].high >= g_Zones[s].low)
         {
            // หาก Supply เกิดทีหลัง Demand (แรงขายกดลงมาสร้าง Supply ใหม่)
            if(g_Zones[s].time >= g_Zones[d].time)
            {
               if(g_Zones[d].low >= g_Zones[s].low)
               {
                  g_Zones[d].isActive = false; // Demand ถูกกลืนกินหมดสิ้น
               }
               else
               {
                  // ปรับทอนขอบบน Demand ลงมาให้ต่ำกว่าขอบล่าง Supply เล็กน้อย ป้องกันสัญญาณขัดแย้ง
                  double trimHigh = g_Zones[s].low - (g_Asset.slPoints * 0.05 * _Point);
                  if(trimHigh > g_Zones[d].low)
                     g_Zones[d].high = trimHigh;
                  else
                     g_Zones[d].isActive = false;
               }
            }
            // หาก Demand เกิดทีหลัง Supply (แรงซื้อพุ่งดันทะลุสร้าง Demand ใหม่)
            else
            {
               if(g_Zones[s].high <= g_Zones[d].high)
               {
                  g_Zones[s].isActive = false; // Supply ถูกทะลวงพังทลาย
               }
               else
               {
                  // ปรับทอนขอบล่าง Supply ขึ้นไปให้อยู่เหนือขอบบน Demand
                  double trimLow = g_Zones[d].high + (g_Asset.slPoints * 0.05 * _Point);
                  if(trimLow < g_Zones[s].high)
                     g_Zones[s].low = trimLow;
                  else
                     g_Zones[s].isActive = false;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 9. SCAN HIDDEN BLADE WICKS (โซนไส้ดาบ 50% เฉพาะสดใหม่)           |
//+------------------------------------------------------------------+
void ScanHiddenBladeWicks()
{
   g_BladeCount = 0;
   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   int copied = CopyRates(_Symbol, PERIOD_H4, 0, 30, htfRates);
   if(copied < 10) return;

   double liveBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(liveBid <= 0) liveBid = htfRates[0].close;

   for(int i = 1; i < copied && g_BladeCount < 4; i++)
   {
      double range = htfRates[i].high - htfRates[i].low;
      if(range <= 0) continue;

      double upperWick = htfRates[i].high - MathMax(htfRates[i].open, htfRates[i].close);
      double lowerWick = MathMin(htfRates[i].open, htfRates[i].close) - htfRates[i].low;

      if(upperWick >= range * InpHiddenBladeRatio && upperWick >= g_Asset.slPoints * 0.30 * _Point)
      {
         double p50 = htfRates[i].high - (upperWick * 0.50);
         // Hidden Blade ฝั่ง Sell ต้องอยู่เหนือราคา และยังไม่เคยถูกทดสอบ
         if(p50 > liveBid + (5 * _Point))
         {
            bool isMitigated = false;
            for(int k = i - 1; k >= 1; k--)
            {
               if(htfRates[k].high >= p50) { isMitigated = true; break; }
            }
            if(!isMitigated)
            {
               g_Blades[g_BladeCount].time     = htfRates[i].time;
               g_Blades[g_BladeCount].price50  = p50;
               g_Blades[g_BladeCount].isUpper  = true;
               g_Blades[g_BladeCount].isActive = true;
               g_Blades[g_BladeCount].tfName   = "H4";
               g_BladeCount++;
            }
         }
      }
      if(lowerWick >= range * InpHiddenBladeRatio && lowerWick >= g_Asset.slPoints * 0.30 * _Point)
      {
         double p50 = htfRates[i].low + (lowerWick * 0.50);
         // Hidden Blade ฝั่ง Buy ต้องอยู่ใต้ราคา และยังไม่เคยถูกทดสอบ
         if(p50 < liveBid - (5 * _Point))
         {
            bool isMitigated = false;
            for(int k = i - 1; k >= 1; k--)
            {
               if(htfRates[k].low <= p50) { isMitigated = true; break; }
            }
            if(!isMitigated)
            {
               g_Blades[g_BladeCount].time     = htfRates[i].time;
               g_Blades[g_BladeCount].price50  = p50;
               g_Blades[g_BladeCount].isUpper  = false;
               g_Blades[g_BladeCount].isActive = true;
               g_Blades[g_BladeCount].tfName   = "H4";
               g_BladeCount++;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 10. CHECK ICT UNICORN MODEL (BREAKER BLOCK + FVG OVERLAP)        |
//+------------------------------------------------------------------+
void CheckICTUnicorn(const MqlRates &rates[], int total)
{
   g_HasUnicorn  = false;
   g_UnicornSide = 0;

   double minGap = MathMax(g_Asset.slPoints * 0.08 * _Point, 20.0 * _Point);

   // 1. ตรวจจับตามทิศทางคลื่น A-B-C ที่ฟอร์มตัวแล้ว
   if(g_WaveFormed && g_WaveSide != 0)
   {
      for(int i = 2; i < 25 && i < total - 2; i++)
      {
         if(g_WaveSide == -1) // SELL Setup (Bearish Breaker + Bearish FVG)
         {
            if(rates[i + 1].low > rates[i - 1].high)
            {
               double fvgTop = rates[i + 1].low;
               double fvgBot = rates[i - 1].high;
               if((fvgTop - fvgBot) < minGap) continue;

               // ตรวจสอบว่า FVG ยังไม่ถูกเคลียร์ทะลุไปก่อนหน้านี้
               bool mitigated = false;
               for(int k = i - 1; k >= 1; k--)
               {
                  if(rates[k].high >= fvgTop) { mitigated = true; break; }
               }
               if(mitigated) continue;

               if(rates[0].high >= fvgBot && rates[0].low <= fvgTop)
               {
                  g_HasUnicorn  = true;
                  g_UnicornSide = -1; // SELL (สีแดง)
                  g_UnicornHigh = fvgTop;
                  g_UnicornLow  = fvgBot;
                  return;
               }
            }
         }
         else if(g_WaveSide == 1) // BUY Setup (Bullish Breaker + Bullish FVG)
         {
            if(rates[i - 1].low > rates[i + 1].high)
            {
               double fvgTop = rates[i - 1].low;
               double fvgBot = rates[i + 1].high;
               if((fvgTop - fvgBot) < minGap) continue;

               // ตรวจสอบว่า FVG ยังไม่ถูกเคลียร์ทะลุไปก่อนหน้านี้
               bool mitigated = false;
               for(int k = i - 1; k >= 1; k--)
               {
                  if(rates[k].low <= fvgBot) { mitigated = true; break; }
               }
               if(mitigated) continue;

               if(rates[0].high >= fvgBot && rates[0].low <= fvgTop)
               {
                  g_HasUnicorn  = true;
                  g_UnicornSide = 1; // BUY (สีเขียว)
                  g_UnicornHigh = fvgTop;
                  g_UnicornLow  = fvgBot;
                  return;
               }
            }
         }
      }
   }
   else
   {
      // 2. หากยังไม่ฟอร์มคลื่น ตรวจจับ FVG ปัจจุบันที่ราคากำลังทดสอบ
      for(int i = 2; i < 25 && i < total - 2; i++)
      {
         // Bullish FVG (BUY)
         if(rates[i - 1].low > rates[i + 1].high)
         {
            double fvgTop = rates[i - 1].low;
            double fvgBot = rates[i + 1].high;
            if((fvgTop - fvgBot) >= minGap)
            {
               bool mitigated = false;
               for(int k = i - 1; k >= 1; k--)
               {
                  if(rates[k].low <= fvgBot) { mitigated = true; break; }
               }
               if(!mitigated && rates[0].high >= fvgBot && rates[0].low <= fvgTop)
               {
                  g_HasUnicorn  = true;
                  g_UnicornSide = 1; // BUY (สีเขียว)
                  g_UnicornHigh = fvgTop;
                  g_UnicornLow  = fvgBot;
                  return;
               }
            }
         }
         // Bearish FVG (SELL)
         if(rates[i + 1].low > rates[i - 1].high)
         {
            double fvgTop = rates[i + 1].low;
            double fvgBot = rates[i - 1].high;
            if((fvgTop - fvgBot) >= minGap)
            {
               bool mitigated = false;
               for(int k = i - 1; k >= 1; k--)
               {
                  if(rates[k].high >= fvgTop) { mitigated = true; break; }
               }
               if(!mitigated && rates[0].high >= fvgBot && rates[0].low <= fvgTop)
               {
                  g_HasUnicorn  = true;
                  g_UnicornSide = -1; // SELL (สีแดง)
                  g_UnicornHigh = fvgTop;
                  g_UnicornLow  = fvgBot;
                  return;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 11. CHECK SIDEWAY REGIMES                                        |
//+------------------------------------------------------------------+
void CheckSidewayRegime(const MqlRates &rates[], int total)
{
   g_Regime = SW_NONE;

   int hlCount = 0;
   int lhCount = 0;
   int latestH = -1, prevH = -1;
   int latestL = -1, prevL = -1;

   for(int i = 0; i < g_SwingCount && i < 12; i++)
   {
      if(g_Swings[i].isHigh)
      {
         if(g_Swings[i].labelType == SWING_LH) lhCount++;
         if(latestH == -1) latestH = i;
         else if(prevH == -1) prevH = i;
      }
      else
      {
         if(g_Swings[i].labelType == SWING_HL) hlCount++;
         if(latestL == -1) latestL = i;
         else if(prevL == -1) prevL = i;
      }
   }

   // Kamnan Ball: SW Up เกิดขึ้นเมื่อ Low ยกตัว (HL) แต่ High ตัน/ไม่ทำ New High (ขาดการทำ New High)
   if(hlCount >= 2 && g_HasUpSpeedline)
   {
      if(latestH != -1 && prevH != -1 && g_Swings[latestH].price <= g_Swings[prevH].price + (g_Asset.slPoints * 0.10 * _Point))
         g_Regime = SW_UP_ACCUM;
   }
   // Kamnan Ball: SW Down เกิดขึ้นเมื่อ High เตี้ยลง (LH) แต่ Low ติดแนวรับ/ไม่ทำ New Low (ขาดการทำ New Low)
   else if(lhCount >= 2 && g_HasDnSpeedline)
   {
      if(latestL != -1 && prevL != -1 && g_Swings[latestL].price >= g_Swings[prevL].price - (g_Asset.slPoints * 0.10 * _Point))
         g_Regime = SW_DOWN_DIST;
   }
   else
   {
      double highest30 = rates[0].high, lowest30 = rates[0].low;
      for(int i = 1; i < 30; i++)
      {
         if(rates[i].high > highest30) highest30 = rates[i].high;
         if(rates[i].low  < lowest30)  lowest30  = rates[i].low;
      }
      double range30 = highest30 - lowest30;
      if(range30 < g_Asset.slPoints * 0.60 * _Point)
         g_Regime = SW_HORIZONTAL;
   }
}

//+------------------------------------------------------------------+
//| 12. CALCULATE SAMURAI EXACT WICKS LINEAR REGRESSION CHANNEL      |
//+------------------------------------------------------------------+
void CalculateLRLChannel(const MqlRates &rates[], int total)
{
   if(!InpEnableLRLChannel) return;

   int targetBars = MathMax(20, InpLRL_Bars);
   MqlRates lrlRates[];
   ArraySetAsSeries(lrlRates, true);

   int copied = CopyRates(_Symbol, _Period, 0, targetBars, lrlRates);
   if(copied < 20)
   {
      if(total >= 20)
      {
         ArrayCopy(lrlRates, rates, 0, 0, MathMin(targetBars, total));
         copied = MathMin(targetBars, total);
      }
      else return;
   }
   int n = MathMin(targetBars, copied);
   if(n < 20) return;

   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   for(int i = 0; i < n; i++)
   {
      double x = (double)(n - 1 - i);
      double y = lrlRates[i].close;
      sumX  += x;
      sumY  += y;
      sumXY += x * y;
      sumX2 += x * x;
   }

   double denom = (n * sumX2) - (sumX * sumX);
   if(MathAbs(denom) < 0.000001) return;

   g_LRL.slope     = ((n * sumXY) - (sumX * sumY)) / denom;
   g_LRL.intercept = (sumY - (g_LRL.slope * sumX)) / n;

   double maxUpDev = 0.0;
   double maxDnDev = 0.0;
   for(int i = 0; i < n; i++)
   {
      double x = (double)(n - 1 - i);
      double mid = g_LRL.intercept + (g_LRL.slope * x);
      double upD = lrlRates[i].high - mid;
      double dnD = mid - lrlRates[i].low;
      if(upD > maxUpDev) maxUpDev = upD;
      if(dnD > maxDnDev) maxDnDev = dnD;
   }

   g_LRL.upperDev = maxUpDev;
   g_LRL.lowerDev = maxDnDev;

   g_LRL.tStart    = lrlRates[n - 1].time;
   g_LRL.tEnd      = lrlRates[0].time;
   g_LRL.pStartMid = g_LRL.intercept;
   g_LRL.pEndMid   = g_LRL.intercept + (g_LRL.slope * (double)(n - 1));

   g_LRL.pStartUp  = g_LRL.pStartMid + g_LRL.upperDev;
   g_LRL.pEndUp    = g_LRL.pEndMid   + g_LRL.upperDev;

   g_LRL.pStartDn  = g_LRL.pStartMid - g_LRL.lowerDev;
   g_LRL.pEndDn    = g_LRL.pEndMid   - g_LRL.lowerDev;

   g_LRL.curMid    = g_LRL.pEndMid;
   g_LRL.curUpper  = g_LRL.pEndUp;
   g_LRL.curLower  = g_LRL.pEndDn;

   double priceSpan = MathMax(lrlRates[0].close * 0.005, 5.0);
   g_LRL.angle = MathArctan((g_LRL.slope * 30.0) / priceSpan) * (180.0 / M_PI);
}

//+------------------------------------------------------------------+
//| 13. CHECK CANDLESTICK PA TRIGGER & CHIME                         |
//+------------------------------------------------------------------+
void CheckCandlePATrigger(const MqlRates &rates[])
{
   double range1 = rates[1].high - rates[1].low;
   if(range1 <= 0) return;

   double upperWick1 = rates[1].high - MathMax(rates[1].open, rates[1].close);
   double lowerWick1 = MathMin(rates[1].open, rates[1].close) - rates[1].low;

   // Price Action Rejection: Pinbar (>= 50% wick), Engulfing, or strong directional body
   bool isSellPA = (upperWick1 >= range1 * 0.50) || 
                   (rates[1].close < rates[1].open && rates[1].close < rates[2].low) ||
                   (rates[1].close < rates[1].open && (rates[1].open - rates[1].close) >= range1 * 0.55);

   bool isBuyPA  = (lowerWick1 >= range1 * 0.50) || 
                   (rates[1].close > rates[1].open && rates[1].close > rates[2].high) ||
                   (rates[1].close > rates[1].open && (rates[1].close - rates[1].open) >= range1 * 0.55);

   if(g_SniperStage >= STAGE_ALERT_BREAK)
   {
      double curPrice = rates[0].close;
      double curHigh  = MathMax(rates[0].high, rates[1].high);
      double curLow   = MathMin(rates[0].low, rates[1].low);

      if(g_WaveSide == -1 && g_IsFailedHigh)
      {
         bool inPremiumZone = false;
         bool touchedZone   = false;

         // 1. Check Supply Zones (Wick touches zone or inside zone)
         for(int i = 0; i < g_ZoneCount; i++)
         {
            if(g_Zones[i].isActive && !g_Zones[i].isDemand)
            {
               if((curHigh >= g_Zones[i].low && curLow <= g_Zones[i].high) ||
                  (curPrice >= g_Zones[i].low - (g_Asset.slPoints * 0.15 * _Point) && curPrice <= g_Zones[i].high + (g_Asset.slPoints * 0.10 * _Point)))
               {
                  touchedZone   = true;
                  inPremiumZone = true;
                  break;
               }
            }
         }

         // 2. Check Hidden Blade Wicks
         if(!touchedZone)
         {
            for(int b = 0; b < g_BladeCount; b++)
            {
               if(g_Blades[b].isUpper && MathAbs(curHigh - g_Blades[b].price50) < g_Asset.slPoints * 0.25 * _Point)
               {
                  touchedZone   = true;
                  inPremiumZone = true;
                  break;
               }
            }
         }

         // 3. Check Fibonacci Golden Pocket & Premium Zone (50.0% - 78.6%)
         if(g_WaveA_Price > 0 && g_WaveA_Price > g_WaveB_Price)
         {
            double f50  = g_WaveB_Price + (0.50 * (g_WaveA_Price - g_WaveB_Price));
            double f786 = g_WaveB_Price + (0.786 * (g_WaveA_Price - g_WaveB_Price));
            if(curHigh >= f50 - (g_Asset.slPoints * 0.10 * _Point))
               inPremiumZone = true;

            if(!touchedZone && curHigh >= f50 - (g_Asset.slPoints * 0.10 * _Point) && curLow <= f786 + (g_Asset.slPoints * 0.10 * _Point))
               touchedZone = true;
         }

         // 4. EMA 14 touch only qualifies if price is within Premium Zone (not selling at bottom!)
         if(!touchedZone && inPremiumZone && g_EMA14_Val > 0)
         {
            if(MathAbs(curPrice - g_EMA14_Val) < g_Asset.slPoints * 0.25 * _Point)
               touchedZone = true;
         }

         if(touchedZone)
         {
            g_SniperStage = STAGE_IN_ZONE;
            if(isSellPA)
            {
               g_SniperStage = STAGE_TRIGGER_PA;
               if(rates[0].time != g_LastAlertBar)
               {
                  g_LastAlertBar = rates[0].time;
                  if(InpEnableSoundAlert) PlaySound("alert.wav");
               }
            }
         }
      }
      else if(g_WaveSide == 1 && g_IsFailedLow)
      {
         bool inDiscountZone = false;
         bool touchedZone    = false;

         // 1. Check Demand Zones (Wick touches zone or inside zone)
         for(int i = 0; i < g_ZoneCount; i++)
         {
            if(g_Zones[i].isActive && g_Zones[i].isDemand)
            {
               if((curLow <= g_Zones[i].high && curHigh >= g_Zones[i].low) ||
                  (curPrice <= g_Zones[i].high + (g_Asset.slPoints * 0.15 * _Point) && curPrice >= g_Zones[i].low - (g_Asset.slPoints * 0.10 * _Point)))
               {
                  touchedZone    = true;
                  inDiscountZone = true;
                  break;
               }
            }
         }

         // 2. Check Hidden Blade Wicks
         if(!touchedZone)
         {
            for(int b = 0; b < g_BladeCount; b++)
            {
               if(!g_Blades[b].isUpper && MathAbs(curLow - g_Blades[b].price50) < g_Asset.slPoints * 0.25 * _Point)
               {
                  touchedZone    = true;
                  inDiscountZone = true;
                  break;
               }
            }
         }

         // 3. Check Fibonacci Golden Pocket & Discount Zone (50.0% - 78.6%)
         if(g_WaveA_Price > 0 && g_WaveB_Price > g_WaveA_Price)
         {
            double f50  = g_WaveB_Price - (0.50 * (g_WaveB_Price - g_WaveA_Price));
            double f786 = g_WaveB_Price - (0.786 * (g_WaveB_Price - g_WaveA_Price));
            if(curLow <= f50 + (g_Asset.slPoints * 0.10 * _Point))
               inDiscountZone = true;

            if(!touchedZone && curLow <= f50 + (g_Asset.slPoints * 0.10 * _Point) && curHigh >= f786 - (g_Asset.slPoints * 0.10 * _Point))
               touchedZone = true;
         }

         // 4. EMA 14 touch only qualifies if price is within Discount Zone (not buying at peak!)
         if(!touchedZone && inDiscountZone && g_EMA14_Val > 0)
         {
            if(MathAbs(curPrice - g_EMA14_Val) < g_Asset.slPoints * 0.25 * _Point)
               touchedZone = true;
         }

         if(touchedZone)
         {
            g_SniperStage = STAGE_IN_ZONE;
            if(isBuyPA)
            {
               g_SniperStage = STAGE_TRIGGER_PA;
               if(rates[0].time != g_LastAlertBar)
               {
                  g_LastAlertBar = rates[0].time;
                  if(InpEnableSoundAlert) PlaySound("alert.wav");
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 14. CALCULATE DYNAMIC TARGETS (ENTRY, SL, TP1, TP2, TP3, R:R)    |
//+------------------------------------------------------------------+
void CalculateDynamicTargets()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = MathMax((double)stopsLevel * _Point, MathMax(g_Asset.slPoints * 0.20 * _Point, 25.0 * _Point));

   if(g_WaveSide == -1) // SELL Setup
   {
      if(g_WaveA_Price > 0 && g_WaveB_Price > 0 && g_WaveA_Price > g_WaveB_Price)
      {
         double f50  = g_WaveB_Price + (0.50 * (g_WaveA_Price - g_WaveB_Price));
         double f786 = g_WaveB_Price + (0.786 * (g_WaveA_Price - g_WaveB_Price));
         g_EntryMin = NormalizeDouble(f50, _Digits);
         g_EntryMax = NormalizeDouble(f786, _Digits);
      }
      else
      {
         g_EntryMin = bid;
         g_EntryMax = (g_WaveA_Price > bid) ? (bid + (g_WaveA_Price - bid) * 0.35) : bid;
      }

      double calcSL = g_WaveA_Price + (g_Asset.beBuffer * _Point);
      if(g_IsFakeoutTrap && g_FakeoutSide == -1 && g_FakeoutPrice > 0)
      {
         double trapSL = g_FakeoutPrice + (g_Asset.beBuffer * _Point);
         if(trapSL > calcSL && trapSL > ask + minStopDist) calcSL = trapSL;
      }
      if(calcSL <= ask + minStopDist || calcSL - ask > g_Asset.slPoints * 1.5 * _Point)
         calcSL = ask + (g_Asset.slPoints * _Point);
      g_TargetSL = NormalizeDouble(MathMax(calcSL, ask + minStopDist), _Digits);

      g_TargetTP1 = (g_WaveB_Price > 0.0 && g_WaveB_Price < bid - minStopDist) ? g_WaveB_Price : (bid - (g_Asset.tp1Points * _Point));
      g_TargetTP1 = NormalizeDouble(MathMin(g_TargetTP1, bid - minStopDist), _Digits);

      g_TargetTP2 = (g_HasWave_D && g_WaveD_1618 > 0) ? g_WaveD_1618 : ((g_WaveB_Price > 0.0 && g_WaveA_Price > g_WaveB_Price) ? (g_WaveB_Price - (0.618 * (g_WaveA_Price - g_WaveB_Price))) : (bid - (g_Asset.tp2Points * _Point)));
      g_TargetTP2 = NormalizeDouble(MathMin(g_TargetTP2, g_TargetTP1 - minStopDist), _Digits);

      g_TargetTP3 = (g_HasWave_D && g_WaveD_2000 > 0) ? g_WaveD_2000 : ((g_WaveB_Price > 0.0 && g_WaveA_Price > g_WaveB_Price) ? (g_WaveB_Price - (1.618 * (g_WaveA_Price - g_WaveB_Price))) : (bid - (g_Asset.tp3Points * _Point)));
      g_TargetTP3 = NormalizeDouble(MathMin(g_TargetTP3, g_TargetTP2 - minStopDist), _Digits);

      double slDist = MathMax(g_TargetSL - ask, _Point);
      double tpDist = MathMax(bid - g_TargetTP1, _Point);
      g_RR_Ratio = NormalizeDouble(tpDist / slDist, 1);
   }
   else if(g_WaveSide == 1) // BUY Setup
   {
      if(g_WaveA_Price > 0 && g_WaveB_Price > 0 && g_WaveB_Price > g_WaveA_Price)
      {
         double f50  = g_WaveB_Price - (0.50 * (g_WaveB_Price - g_WaveA_Price));
         double f786 = g_WaveB_Price - (0.786 * (g_WaveB_Price - g_WaveA_Price));
         g_EntryMin = NormalizeDouble(f786, _Digits);
         g_EntryMax = NormalizeDouble(f50, _Digits);
      }
      else
      {
         g_EntryMin = (g_WaveA_Price < ask) ? (ask - (ask - g_WaveA_Price) * 0.35) : ask;
         g_EntryMax = ask;
      }

      double calcSL = g_WaveA_Price - (g_Asset.beBuffer * _Point);
      if(g_IsFakeoutTrap && g_FakeoutSide == 1 && g_FakeoutPrice > 0)
      {
         double trapSL = g_FakeoutPrice - (g_Asset.beBuffer * _Point);
         if(trapSL < calcSL && trapSL < bid - minStopDist) calcSL = trapSL;
      }
      if(calcSL >= bid - minStopDist || bid - calcSL > g_Asset.slPoints * 1.5 * _Point)
         calcSL = bid - (g_Asset.slPoints * _Point);
      g_TargetSL = NormalizeDouble(MathMin(calcSL, bid - minStopDist), _Digits);

      g_TargetTP1 = (g_WaveB_Price > 0.0 && g_WaveB_Price > ask + minStopDist) ? g_WaveB_Price : (ask + (g_Asset.tp1Points * _Point));
      g_TargetTP1 = NormalizeDouble(MathMax(g_TargetTP1, ask + minStopDist), _Digits);

      g_TargetTP2 = (g_HasWave_D && g_WaveD_1618 > 0) ? g_WaveD_1618 : ((g_WaveB_Price > 0.0 && g_WaveB_Price > g_WaveA_Price) ? (g_WaveB_Price + (0.618 * (g_WaveB_Price - g_WaveA_Price))) : (ask + (g_Asset.tp2Points * _Point)));
      g_TargetTP2 = NormalizeDouble(MathMax(g_TargetTP2, g_TargetTP1 + minStopDist), _Digits);

      g_TargetTP3 = (g_HasWave_D && g_WaveD_2000 > 0) ? g_WaveD_2000 : ((g_WaveB_Price > 0.0 && g_WaveB_Price > g_WaveA_Price) ? (g_WaveB_Price + (1.618 * (g_WaveB_Price - g_WaveA_Price))) : (ask + (g_Asset.tp3Points * _Point)));
      g_TargetTP3 = NormalizeDouble(MathMax(g_TargetTP3, g_TargetTP2 + minStopDist), _Digits);

      double slDist = MathMax(bid - g_TargetSL, _Point);
      double tpDist = MathMax(g_TargetTP1 - ask, _Point);
      g_RR_Ratio = NormalizeDouble(tpDist / slDist, 1);
   }
   else
   {
      if(g_MarketBiasSellPct > g_MarketBiasBuyPct || (g_SamuraiMTF.consensusDir == -1))
      {
         g_EntryMin  = bid;
         g_EntryMax  = ask;
         g_TargetSL  = NormalizeDouble(ask + MathMax(g_Asset.slPoints * _Point, minStopDist), _Digits);
         g_TargetTP1 = NormalizeDouble(bid - MathMax(g_Asset.tp1Points * _Point, minStopDist), _Digits);
         g_TargetTP2 = NormalizeDouble(bid - MathMax(g_Asset.tp2Points * _Point, minStopDist * 2.0), _Digits);
         g_TargetTP3 = NormalizeDouble(bid - MathMax(g_Asset.tp3Points * _Point, minStopDist * 3.0), _Digits);
      }
      else
      {
         g_EntryMin  = bid;
         g_EntryMax  = ask;
         g_TargetSL  = NormalizeDouble(bid - MathMax(g_Asset.slPoints * _Point, minStopDist), _Digits);
         g_TargetTP1 = NormalizeDouble(ask + MathMax(g_Asset.tp1Points * _Point, minStopDist), _Digits);
         g_TargetTP2 = NormalizeDouble(ask + MathMax(g_Asset.tp2Points * _Point, minStopDist * 2.0), _Digits);
         g_TargetTP3 = NormalizeDouble(ask + MathMax(g_Asset.tp3Points * _Point, minStopDist * 3.0), _Digits);
      }
      g_RR_Ratio  = 1.5;
   }
}

//+------------------------------------------------------------------+
//| 14.1 FORMAT OPEN INTEREST NUMBER (e.g. 10.2k, 1.2k, 829)         |
//+------------------------------------------------------------------+
string FormatOI_Number(int count)
{
   if(count >= 1000)
   {
      double k = (double)count / 1000.0;
      return StringFormat("%.1fk", k);
   }
   return IntegerToString(count);
}

//+------------------------------------------------------------------+
//| 14.2 CME OPTIONS MATRIX & OPEN INTEREST DATA (DEC 2026 OGZ6)     |
//| Calibrated: 28/10/2569 (25.69 DTE, Ref Futures $4,033.3)         |
//+------------------------------------------------------------------+
const SCME_Level g_CME_Levels[] = {
   {3300.0,   314,   694,  true, false}, // Major Century 3300
   {3350.0,     0,    50, false,  true}, // Half-Century Level 3350
   {3375.0,     0,   336, false, false}, // Speed Bump 3375
   {3400.0,     0,  2205,  true, false}, // Major Put Wall 3400 (2.21k OI)
   {3425.0,     0,   397, false, false}, // Speed Bump 3425
   {3450.0,     1,  1392, false,  true}, // Half-Century Level 3450
   {3465.0,     0,   235, false, false}, // Speed Bump 3465
   {3475.0,     0,   242, false, false}, // Speed Bump 3475
   {3480.0,     0,  1288, false, false}, // Key Put Wall 3480 (1,288 OI)
   {3485.0,     0,   151, false, false}, // Speed Bump 3485
   {3500.0,    17,  6341,  true, false}, // MONSTER Put Wall 3500 (6.3k OI)
   {3510.0,     0,   269, false, false}, // Speed Bump 3510
   {3515.0,     0,   136, false, false}, // Speed Bump 3515
   {3525.0,     0,   228, false, false}, // Speed Bump 3525
   {3550.0,     2,  2154, false,  true}, // Half-Century Put Wall 3550 (2.15k OI)
   {3585.0,     0,   341, false, false}, // Speed Bump 3585
   {3595.0,     0,   126, false, false}, // Speed Bump 3595
   {3600.0,     6,  2012,  true, false}, // Major Put Wall 3600 (2.01k OI)
   {3645.0,     0,   264, false, false}, // Speed Bump 3645
   {3650.0,     0,  1607, false,  true}, // Half-Century Level 3650
   {3655.0,     0,   245, false, false}, // Speed Bump 3655
   {3665.0,     0,   128, false, false}, // Speed Bump 3665
   {3670.0,     1,   181, false, false}, // Speed Bump 3670
   {3675.0,     0,   188, false, false}, // Speed Bump 3675
   {3680.0,     1,  4996, false, false}, // Key Put Wall 3680 (4,996 OI)
   {3685.0,     1,   494, false, false}, // Speed Bump 3685
   {3695.0,     1,   124, false, false}, // Speed Bump 3695
   {3700.0,   145,   145,  true, false}, // Major Century 3700
   {3710.0,     2,   172, false, false}, // Speed Bump 3710
   {3715.0,     0,   189, false, false}, // Speed Bump 3715
   {3725.0,     1,   231, false, false}, // Speed Bump 3725
   {3730.0,     0,   400, false, false}, // Speed Bump 3730
   {3735.0,     1,   183, false, false}, // Speed Bump 3735
   {3750.0,     8,  1689, false,  true}, // Half-Century Level 3750
   {3760.0,     3,   149, false, false}, // Speed Bump 3760
   {3785.0,     4,   138, false, false}, // Speed Bump 3785
   {3790.0,     2,   227, false, false}, // Speed Bump 3790
   {3795.0,     0,   178, false, false}, // Speed Bump 3795
   {3800.0,    27,  3027,  true, false}, // Major Put Wall 3800 (3.03k OI)
   {3805.0,     4,   152, false, false}, // Speed Bump 3805
   {3810.0,     0,   120, false, false}, // Speed Bump 3810
   {3825.0,     1,   228, false, false}, // Speed Bump 3825
   {3840.0,     1,   250, false, false}, // Speed Bump 3840
   {3845.0,     0,   277, false, false}, // Speed Bump 3845
   {3850.0,     2,  1326, false,  true}, // Half-Century Level 3850
   {3860.0,     2,   115, false, false}, // Speed Bump 3860
   {3875.0,     2,   183, false, false}, // Speed Bump 3875
   {3895.0,     5,   189, false, false}, // Speed Bump 3895
   {3900.0,    88,  5261,  true, false}, // MONSTER Put Wall 3900 (5.3k OI)
   {3905.0,     0,   101, false, false},
   {3910.0,     1,   134, false, false}, // Speed Bump 3910
   {3915.0,     7,   275, false, false}, // Speed Bump 3915
   {3920.0,     1,   116, false, false}, // Speed Bump 3920
   {3925.0,    13,   455, false, false}, // Speed Bump 3925
   {3930.0,     6,   295, false, false}, // Speed Bump 3930
   {3935.0,    17,   167, false, false}, // Speed Bump 3935
   {3940.0,     7,   279, false, false}, // Speed Bump 3940
   {3945.0,     2,   127, false, false}, // Speed Bump 3945
   {3950.0,    31,  4383, false,  true}, // Half-Century Put Wall 3950 (4.38k OI)
   {3955.0,  1065,   148, false, false}, // Key Call Wall 3955 (1,065 OI)
   {3960.0,    21,   413, false, false}, // Speed Bump 3960
   {3965.0,     2,    89, false, false},
   {3970.0,     0,   383, false, false}, // Speed Bump 3970
   {3975.0,    85,   957, false, false}, // Speed Bump 3975
   {3980.0,     6,   263, false, false}, // Speed Bump 3980
   {3985.0,    31,    99, false, false},
   {3990.0,     7,   445, false, false}, // Speed Bump 3990
   {3995.0,    24,    87, false, false},
   {4000.0,   327,  4993,  true, false}, // Major Put Wall 4000 (4.99k OI)
   {4005.0,    14,   200, false, false}, // Speed Bump 4005
   {4010.0,    30,   150, false, false}, // Speed Bump 4010
   {4015.0,    68,    97, false, false},
   {4020.0,   119,   106, false, false}, // Speed Bump 4020
   {4025.0,    79,  1155, false, false}, // Key Put Wall 4025 (1,155 OI)
   {4030.0,    52,   128, false, false}, // Speed Bump 4030
   {4035.0,   284,   120, false, false}, // Speed Bump 4035
   {4040.0,   280,   127, false, false}, // Speed Bump 4040
   {4045.0,    12,   129, false, false}, // Speed Bump 4045
   {4050.0,  1383,  2530, false,  true}, // Half-Century Put Wall 4050 (2.53k OI)
   {4055.0,    48,   113, false, false}, // Speed Bump 4055
   {4060.0,   208,   177, false, false}, // Speed Bump 4060
   {4065.0,    87,   148, false, false}, // Speed Bump 4065
   {4070.0,   122,    93, false, false}, // Speed Bump 4070
   {4075.0,   193,   386, false, false}, // Speed Bump 4075
   {4080.0,   285,   593, false, false}, // Speed Bump 4080
   {4085.0,    38,    60, false, false},
   {4090.0,    69,   238, false, false}, // Speed Bump 4090
   {4095.0,    52,   165, false, false}, // Speed Bump 4095
   {4100.0,  1808,  2255,  true, false}, // Major Put Wall 4100 (2.25k OI)
   {4105.0,   101,   129, false, false}, // Speed Bump 4105
   {4110.0,   226,    73, false, false}, // Speed Bump 4110
   {4115.0,    34,   108, false, false},
   {4120.0,   189,   704, false, false}, // Speed Bump 4120
   {4125.0,   167,   342, false, false}, // Speed Bump 4125
   {4130.0,   758,   729, false, false}, // Speed Bump 4130
   {4135.0,    96,    40, false, false},
   {4140.0,   123,   114, false, false}, // Speed Bump 4140
   {4145.0,   178,   142, false, false}, // Speed Bump 4145
   {4150.0,  1089,  1392, false,  true}, // Half-Century Level 4150
   {4160.0,   247,   345, false, false}, // Speed Bump 4160
   {4165.0,    96,   119, false, false}, // Speed Bump 4165
   {4170.0,   162,   337, false, false}, // Speed Bump 4170
   {4175.0,  1082,   443, false, false}, // Key Call Wall 4175 (1,082 OI)
   {4180.0,   304,   213, false, false}, // Speed Bump 4180
   {4190.0,   462,   506, false, false}, // Speed Bump 4190
   {4195.0,   133,    51, false, false}, // Speed Bump 4195
   {4200.0,  4353,  2373,  true, false}, // Major Call Wall 4200 (4.35k OI)
   {4205.0,   473,    68, false, false}, // Speed Bump 4205
   {4215.0,   150,   227, false, false}, // Speed Bump 4215
   {4220.0,   213,    62, false, false}, // Speed Bump 4220
   {4225.0,  1700,   321, false, false}, // Key Call Wall 4225 (1,700 OI)
   {4230.0,   106,   441, false, false}, // Speed Bump 4230
   {4235.0,    35,   120, false, false}, // Speed Bump 4235
   {4245.0,   224,    44, false, false}, // Speed Bump 4245
   {4250.0,  2144,  2422, false,  true}, // Half-Century Call Wall 4250 (2.14k OI)
   {4255.0,   136,    38, false, false}, // Speed Bump 4255
   {4260.0,   445,    78, false, false}, // Speed Bump 4260
   {4265.0,    53,   129, false, false}, // Speed Bump 4265
   {4270.0,   174,    27, false, false}, // Speed Bump 4270
   {4275.0,    99,   150, false, false}, // Speed Bump 4275
   {4280.0,   168,   178, false, false}, // Speed Bump 4280
   {4285.0,   158,    35, false, false}, // Speed Bump 4285
   {4290.0,   194,   237, false, false}, // Speed Bump 4290
   {4295.0,   111,    93, false, false}, // Speed Bump 4295
   {4300.0,  3766,  3281,  true, false}, // Major Call Wall 4300 (3.77k OI)
   {4310.0,    74,   236, false, false}, // Speed Bump 4310
   {4320.0,   236,   264, false, false}, // Speed Bump 4320
   {4325.0,   316,   866, false, false}, // Speed Bump 4325
   {4330.0,   197,    46, false, false}, // Speed Bump 4330
   {4335.0,   128,    56, false, false}, // Speed Bump 4335
   {4340.0,   167,   115, false, false}, // Speed Bump 4340
   {4345.0,   287,    23, false, false}, // Speed Bump 4345
   {4350.0,  6535,   717, false,  true}, // Half-Century Call Wall 4350 (6.54k OI)
   {4355.0,   132,    29, false, false}, // Speed Bump 4355
   {4360.0,   172,    99, false, false}, // Speed Bump 4360
   {4365.0,   217,   244, false, false}, // Speed Bump 4365
   {4370.0,   249,    58, false, false}, // Speed Bump 4370
   {4375.0,   576,   196, false, false}, // Speed Bump 4375
   {4380.0,   719,   156, false, false}, // Speed Bump 4380
   {4385.0,   175,    95, false, false}, // Speed Bump 4385
   {4390.0,   138,   245, false, false}, // Speed Bump 4390
   {4395.0,   164,    28, false, false}, // Speed Bump 4395
   {4400.0,  4374,  1183,  true, false}, // Major Call Wall 4400 (4.37k OI)
   {4405.0,   233,    74, false, false}, // Speed Bump 4405
   {4410.0,   148,    91, false, false}, // Speed Bump 4410
   {4415.0,   183,    11, false, false}, // Speed Bump 4415
   {4420.0,  1063,    45, false, false}, // Key Call Wall 4420 (1,063 OI)
   {4425.0,   741,   255, false, false}, // Speed Bump 4425
   {4430.0,   147,   172, false, false}, // Speed Bump 4430
   {4435.0,    89,   164, false, false}, // Speed Bump 4435
   {4445.0,    80,   200, false, false}, // Speed Bump 4445
   {4450.0,  1427,   588, false,  true}, // Half-Century Level 4450
   {4455.0,   468,    47, false, false}, // Speed Bump 4455
   {4460.0,   352,    73, false, false}, // Speed Bump 4460
   {4465.0,   157,    84, false, false}, // Speed Bump 4465
   {4470.0,   359,   171, false, false}, // Speed Bump 4470
   {4475.0,   469,   220, false, false}, // Speed Bump 4475
   {4480.0,   166,    51, false, false}, // Speed Bump 4480
   {4500.0, 10980,  1739,  true, false}, // MONSTER Call Wall 4500 (11.0k OI)
   {4510.0,  5071,    20, false, false}, // Key Call Wall 4510 (5,071 OI)
   {4515.0,   114,   271, false, false}, // Speed Bump 4515
   {4525.0,   736,   384, false, false}, // Speed Bump 4525
   {4530.0,    74,   334, false, false}, // Speed Bump 4530
   {4535.0,   115,   109, false, false}, // Speed Bump 4535
   {4545.0,   120,    61, false, false}, // Speed Bump 4545
   {4550.0,  2549,   321, false,  true}, // Half-Century Call Wall 4550 (2.55k OI)
   {4560.0,   596,    11, false, false}, // Speed Bump 4560
   {4575.0,   310,   221, false, false}, // Speed Bump 4575
   {4580.0,   350,   179, false, false}, // Speed Bump 4580
   {4585.0,   314,   345, false, false}, // Speed Bump 4585
   {4600.0,  6770,   973,  true, false}, // MONSTER Call Wall 4600 (6.8k OI)
   {4625.0,   543,    59, false, false}, // Speed Bump 4625
   {4630.0,   160,     4, false, false}, // Speed Bump 4630
   {4640.0,   210,   120, false, false}, // Speed Bump 4640
   {4650.0,  1594,   235, false,  true}, // Half-Century Level 4650
   {4660.0,   284,   122, false, false}, // Speed Bump 4660
   {4675.0,   350,    16, false, false}, // Speed Bump 4675
   {4680.0,   202,    64, false, false}, // Speed Bump 4680
   {4690.0,   273,   143, false, false}, // Speed Bump 4690
   {4695.0,   325,    32, false, false}, // Speed Bump 4695
   {4700.0,  6058,   678,  true, false}, // MONSTER Call Wall 4700 (6.1k OI)
   {4705.0,   151,    15, false, false}, // Speed Bump 4705
   {4715.0,   117,    12, false, false}, // Speed Bump 4715
   {4720.0,   143,    15, false, false}, // Speed Bump 4720
   {4725.0,  9558,   142, false, false}, // Key Call Wall 4725 (9,558 OI)
   {4730.0,   147,     0, false, false}, // Speed Bump 4730
   {4750.0,  3786,    71, false,  true}, // Half-Century Call Wall 4750 (3.79k OI)
   {4760.0,   161,    25, false, false}, // Speed Bump 4760
   {4775.0,   321,     6, false, false}, // Speed Bump 4775
   {4790.0,   242,    73, false, false}, // Speed Bump 4790
   {4795.0,   144,     1, false, false}, // Speed Bump 4795
   {4800.0,  8889,   361,  true, false}, // MONSTER Call Wall 4800 (8.9k OI)
   {4820.0,   210,    24, false, false}, // Speed Bump 4820
   {4825.0,   263,   114, false, false}, // Speed Bump 4825
   {4835.0,   169,   126, false, false}, // Speed Bump 4835
   {4840.0,   175,     0, false, false}, // Speed Bump 4840
   {4850.0,  3326,    14, false,  true}, // Half-Century Call Wall 4850 (3.33k OI)
   {4855.0,   138,     3, false, false}, // Speed Bump 4855
   {4875.0,   233,    16, false, false}, // Speed Bump 4875
   {4880.0,   313,    11, false, false}, // Speed Bump 4880
   {4895.0,   243,     2, false, false}, // Speed Bump 4895
   {4900.0,  5395,   115,  true, false}, // MONSTER Call Wall 4900 (5.4k OI)
   {4910.0,  2042,     0, false, false}, // Key Call Wall 4910 (2,042 OI)
   {4920.0,   142,     4, false, false}, // Speed Bump 4920
   {4925.0,   424,   240, false, false}, // Speed Bump 4925
   {4950.0,   642,    25, false,  true}, // Half-Century Level 4950
   {4960.0,   162,     0, false, false}, // Speed Bump 4960
   {4965.0,   142,     0, false, false}, // Speed Bump 4965
   {4970.0,   200,     1, false, false}, // Speed Bump 4970
   {4990.0,   509,     2, false, false}, // Speed Bump 4990
   {4995.0,   535,    32, false, false}, // Speed Bump 4995
   {5000.0, 12255,   531,  true, false}, // MONSTER Call Wall 5000 (12.3k OI)
   {5005.0,   516,     0, false, false}, // Speed Bump 5005
   {5025.0,   457,   217, false, false}, // Speed Bump 5025
   {5030.0,   119,     3, false, false}, // Speed Bump 5030
   {5050.0,   751,   201, false,  true}, // Half-Century Level 5050
   {5075.0,   145,   100, false, false}, // Speed Bump 5075
   {5100.0,  3643,    16,  true, false}, // Major Call Wall 5100 (3.64k OI)
   {5115.0,   114,     0, false, false}, // Speed Bump 5115
   {5120.0,   130,     0, false, false}, // Speed Bump 5120
   {5135.0,   136,     0, false, false}, // Speed Bump 5135
   {5150.0,   935,     0, false,  true}, // Half-Century Level 5150
   {5175.0,   231,     0, false, false}, // Speed Bump 5175
   {5195.0,   537,     5, false, false}, // Speed Bump 5195
   {5200.0,  2657,     1,  true, false}, // Major Call Wall 5200 (2.66k OI)
   {5205.0,   504,     0, false, false}, // Speed Bump 5205
   {5210.0,   148,     0, false, false}, // Speed Bump 5210
   {5215.0,   120,     0, false, false}, // Speed Bump 5215
   {5220.0,   111,     0, false, false}, // Speed Bump 5220
   {5225.0,  9411,     0, false, false}, // Key Call Wall 5225 (9,411 OI)
   {5250.0,  1847,     0, false,  true}, // Half-Century Level 5250
   {5300.0,  2365,     0,  true, false}, // Major Call Wall 5300 (2.37k OI)
   {5350.0,   901,     0, false,  true}, // Half-Century Level 5350
   {5360.0,   119,     0, false, false}, // Speed Bump 5360
   {5390.0,   214,     0, false, false}, // Speed Bump 5390
   {5400.0,  4232,     1,  true, false}, // Major Call Wall 5400 (4.23k OI)
   {5425.0,   269,     0, false, false}, // Speed Bump 5425
   {5450.0,   392,     0, false,  true}, // Half-Century Level 5450
   {5475.0,   588,     0, false, false}, // Speed Bump 5475
   {5500.0, 16933,     0,  true, false}, // MONSTER Call Wall 5500 (16.9k OI)
   {5525.0,   129,     0, false, false}, // Speed Bump 5525
   {5550.0,   472,     0, false,  true}, // Half-Century Level 5550
   {5570.0,   257,     0, false, false}, // Speed Bump 5570
   {5600.0,  3070,     0,  true, false}, // Major Call Wall 5600 (3.07k OI)
   {5650.0,   347,     0, false,  true}, // Half-Century Level 5650
   {5670.0,   161,     0, false, false}, // Speed Bump 5670
   {5700.0,   865,     0,  true, false}, // Major Century 5700
   {5750.0,   532,     0, false,  true}, // Half-Century Level 5750
   {5800.0,  2179,     0,  true, false}, // Major Call Wall 5800 (2.18k OI)
   {5850.0,   140,     0, false,  true}, // Half-Century Level 5850
   {5900.0,  1063,     0,  true, false}, // Major Century 5900
   {5950.0,   202,     0, false,  true}, // Half-Century Level 5950
   {6000.0, 14961,     0,  true, false}, // MONSTER Call Wall 6000 (15.0k OI)
   {6050.0,    57,     0, false,  true}, // Half-Century Level 6050
   {6100.0,   166,     0,  true, false}, // Major Century 6100
   {6150.0,    92,     0, false,  true}, // Half-Century Level 6150
   {6200.0,  3067,     0,  true, false}, // Major Call Wall 6200 (3.07k OI)
   {6250.0,  1015,     0, false,  true}, // Half-Century Level 6250
   {6300.0,   907,     0,  true, false}, // Major Century 6300
   {6400.0,   876,     0,  true, false}, // Major Century 6400
   {6500.0,  6895,     0,  true, false}, // MONSTER Call Wall 6500 (6.9k OI)
   {6750.0,   430,     0, false,  true}, // Half-Century Level 6750
   {6775.0,   240,     0, false, false}, // Speed Bump 6775
   {6800.0,  2009,     0,  true, false}, // Major Call Wall 6800 (2.01k OI)
   {6900.0,   141,     0,  true, false}, // Major Century 6900
   {7000.0, 10633,     0,  true, false}, // MONSTER Call Wall 7000 (10.6k OI)
   {7100.0,    10,     0,  true, false}, // Major Century 7100
   {7130.0,   201,     0, false, false}, // Speed Bump 7130
   {7150.0,   131,     0, false,  true}, // Half-Century Level 7150
   {7175.0,   133,     0, false, false}, // Speed Bump 7175
   {7200.0,    69,     0,  true, false}, // Major Century 7200
   {7250.0,   520,     0, false,  true}, // Half-Century Level 7250
   {7500.0,  3672,     0,  true, false}, // Major Call Wall 7500 (3.67k OI)
   {8000.0, 13511,     0,  true, false}, // MONSTER Call Wall 8000 (13.5k OI)
   {8125.0,   805,     0, false, false}, // Speed Bump 8125
   {8500.0,   719,     0,  true, false} // Major Century 8500
};


//+------------------------------------------------------------------+
//| 14.3 SCAN CME PROXIMITY RADAR                                    |
//+------------------------------------------------------------------+
void ScanCME_OptionsMatrix()
{
   if(!InpUseCME_OI || g_Asset.assetType != ASSET_GOLD)
   {
      g_CME_DisplayCount  = 0;
      g_CME_NearResStr    = "ไม่มี";
      g_CME_NearSupStr    = "ไม่มี";
      g_CME_NearResStrike = 0.0;
      g_CME_NearSupStrike = 0.0;
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0) return;

   double proxDist = (double)InpCME_ProximityPts * _Point;
   if(proxDist <= 0.0) proxDist = 2500.0 * _Point;

   double minResDist = 999999.0;
   int nearestResIdx = -1;
   double minSupDist = 999999.0;
   int nearestSupIdx = -1;

   g_CME_DisplayCount = 0;
   int totalCME = ArraySize(g_CME_Levels);

   for(int i = 0; i < totalCME; i++)
   {
      double st = g_CME_Levels[i].strike;

      // Resistance (above bid)
      if(st > bid)
      {
         double dist = st - bid;
         if(g_CME_Levels[i].callOI >= InpCME_MinOI_Threshold || g_CME_Levels[i].isMajor || g_CME_Levels[i].isHalfCentury)
         {
            if(dist < minResDist)
            {
               minResDist = dist;
               nearestResIdx = i;
            }
         }
      }

      // Support (below ask)
      if(st < ask)
      {
         double dist = ask - st;
         if(g_CME_Levels[i].putOI >= InpCME_MinOI_Threshold || g_CME_Levels[i].isMajor || g_CME_Levels[i].isHalfCentury)
         {
            if(dist < minSupDist)
            {
               minSupDist = dist;
               nearestSupIdx = i;
            }
         }
      }
   }

   if(nearestResIdx >= 0)
   {
      g_CME_NearResStrike = g_CME_Levels[nearestResIdx].strike;
      g_CME_NearResOI     = g_CME_Levels[nearestResIdx].callOI;
      g_CME_NearResStr    = StringFormat("ต้าน %.0f (Call %s)", g_CME_NearResStrike, FormatOI_Number(g_CME_NearResOI));
   }
   else
   {
      g_CME_NearResStrike = 0.0;
      g_CME_NearResOI     = 0;
      g_CME_NearResStr    = "ไม่มี";
   }

   if(nearestSupIdx >= 0)
   {
      g_CME_NearSupStrike = g_CME_Levels[nearestSupIdx].strike;
      g_CME_NearSupOI     = g_CME_Levels[nearestSupIdx].putOI;
      g_CME_NearSupStr    = StringFormat("รับ %.0f (Put %s)", g_CME_NearSupStrike, FormatOI_Number(g_CME_NearSupOI));
   }
   else
   {
      g_CME_NearSupStrike = 0.0;
      g_CME_NearSupOI     = 0;
      g_CME_NearSupStr    = "ไม่มี";
   }

   // Collect Resistance candidates within proximity (up to 3)
   int resCandidates[30];
   int resCandCount = 0;
   for(int i = 0; i < totalCME; i++)
   {
      if(g_CME_Levels[i].strike > bid && (g_CME_Levels[i].strike - bid) <= proxDist)
      {
         bool ok = false;
         if(g_CME_Levels[i].isMajor && InpCME_ShowMajorWalls) ok = true;
         else if(g_CME_Levels[i].isHalfCentury && InpCME_ShowHalfCentury) ok = true;
         else if(g_CME_Levels[i].callOI >= InpCME_MinOI_Threshold && InpCME_ShowSpeedBumps) ok = true;

         if(ok && resCandCount < 30) resCandidates[resCandCount++] = i;
      }
   }

   // Collect Support candidates within proximity (up to 3)
   int supCandidates[30];
   int supCandCount = 0;
   for(int i = totalCME - 1; i >= 0; i--)
   {
      if(g_CME_Levels[i].strike < ask && (ask - g_CME_Levels[i].strike) <= proxDist)
      {
         bool ok = false;
         if(g_CME_Levels[i].isMajor && InpCME_ShowMajorWalls) ok = true;
         else if(g_CME_Levels[i].isHalfCentury && InpCME_ShowHalfCentury) ok = true;
         else if(g_CME_Levels[i].putOI >= InpCME_MinOI_Threshold && InpCME_ShowSpeedBumps) ok = true;

         if(ok && supCandCount < 30) supCandidates[supCandCount++] = i;
      }
   }

   int addedRes = 0;
   for(int r = 0; r < resCandCount && addedRes < 3 && g_CME_DisplayCount < MAX_CME_DISPLAYS; r++)
   {
      int idx = resCandidates[r];
      SCME_ActiveDisplay disp;
      disp.strike = g_CME_Levels[idx].strike;
      disp.isResistance = true;
      disp.oiCount = g_CME_Levels[idx].callOI;
      disp.lineCol = InpColorCME_Resistance;

      if(g_CME_Levels[idx].isMajor)
      {
         disp.levelTier = 1;
         disp.lineStyle = STYLE_SOLID;
         disp.lineWidth = 2;
         disp.labelText = StringFormat(" 🔴 CME Major Call Wall: %.0f (%s Call OI) [เพดานหลัก]", disp.strike, FormatOI_Number(disp.oiCount));
      }
      else if(g_CME_Levels[idx].isHalfCentury)
      {
         disp.levelTier = 2;
         disp.lineStyle = STYLE_DASH;
         disp.lineWidth = 1;
         disp.labelText = StringFormat(" 🔶 CME Half-Century Call: %.0f (%s Call OI) [ด่านกึ่งกลาง]", disp.strike, FormatOI_Number(disp.oiCount));
      }
      else
      {
         disp.levelTier = 3;
         disp.lineStyle = STYLE_DOT;
         disp.lineWidth = 1;
         disp.labelText = StringFormat(" 🔸 CME Speed Bump: %.0f (%s Call OI) [ด่านหน่วงราคา]", disp.strike, FormatOI_Number(disp.oiCount));
      }

      g_CME_Displays[g_CME_DisplayCount++] = disp;
      addedRes++;
   }

   int addedSup = 0;
   for(int s = 0; s < supCandCount && addedSup < 3 && g_CME_DisplayCount < MAX_CME_DISPLAYS; s++)
   {
      int idx = supCandidates[s];
      SCME_ActiveDisplay disp;
      disp.strike = g_CME_Levels[idx].strike;
      disp.isResistance = false;
      disp.oiCount = g_CME_Levels[idx].putOI;
      disp.lineCol = InpColorCME_Support;

      if(g_CME_Levels[idx].isMajor)
      {
         disp.levelTier = 1;
         disp.lineStyle = STYLE_SOLID;
         disp.lineWidth = 2;
         disp.labelText = StringFormat(" 🔷 CME Major Put Wall: %.0f (%s Put OI) [ฐานรับใหญ่]", disp.strike, FormatOI_Number(disp.oiCount));
      }
      else if(g_CME_Levels[idx].isHalfCentury)
      {
         disp.levelTier = 2;
         disp.lineStyle = STYLE_DASH;
         disp.lineWidth = 1;
         disp.labelText = StringFormat(" 🔷 CME Half-Century Put: %.0f (%s Put OI) [ด่านกึ่งกลาง]", disp.strike, FormatOI_Number(disp.oiCount));
      }
      else
      {
         disp.levelTier = 3;
         disp.lineStyle = STYLE_DOT;
         disp.lineWidth = 1;
         disp.labelText = StringFormat(" 🔹 CME Speed Bump: %.0f (%s Put OI) [ด่านหน่วงราคา]", disp.strike, FormatOI_Number(disp.oiCount));
      }

      g_CME_Displays[g_CME_DisplayCount++] = disp;
      addedSup++;
   }
}

//+------------------------------------------------------------------+
//| CHART RIGHT-SIDE LABEL ANTI-COLLISION ENGINE                     |
//+------------------------------------------------------------------+
#define MAX_CHART_RIGHT_LABELS 80
double g_RightLabelPrices[MAX_CHART_RIGHT_LABELS];
int    g_RightLabelCount = 0;

void ResetChartRightLabelRegistry()
{
   g_RightLabelCount = 0;
   string fiboName = GUI_PREFIX + "STD_FIBO";
   if(ObjectFind(0, fiboName) >= 0)
   {
      double p1 = ObjectGetDouble(0, fiboName, OBJPROP_PRICE, 0);
      double p2 = ObjectGetDouble(0, fiboName, OBJPROP_PRICE, 1);
      if(p1 > 0.0 && p2 > 0.0)
      {
         const double fiboLevels[8] = {0.0, 0.236, 0.382, 0.500, 0.618, 0.705, 0.786, 1.000};
         for(int k = 0; k < 8 && g_RightLabelCount < MAX_CHART_RIGHT_LABELS - 2; k++)
         {
            double lvPrice1 = p2 + (p1 - p2) * fiboLevels[k];
            double lvPrice2 = p1 + (p2 - p1) * fiboLevels[k];
            g_RightLabelPrices[g_RightLabelCount++] = lvPrice1;
            if(MathAbs(lvPrice2 - lvPrice1) > _Point * 5.0)
               g_RightLabelPrices[g_RightLabelCount++] = lvPrice2;
         }
      }
   }
   // จองพื้นที่ความสูงของป้ายไฮไลต์ แนว 1.RETEST+CF เพื่อไม่ให้ป้าย EMA 14 หรือ SL/TP มาซ้อนทับ
   if(InpUseDTD_CF_M1 && InpDrawDTD_M1_Visuals && g_DTD.shortestWickPrice > 0.0 && g_RightLabelCount < MAX_CHART_RIGHT_LABELS)
   {
      g_RightLabelPrices[g_RightLabelCount++] = g_DTD.shortestWickPrice;
   }
}

double GetChartMinLabelSepPrice()
{
   double pMin = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   double pMax = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   int chartH  = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   if(chartH > 50 && pMax > pMin)
   {
      double pricePerPx = (pMax - pMin) / (double)chartH;
      return MathMax(pricePerPx * 18.0, 18.0 * _Point);
   }
   if(g_Asset.assetType == ASSET_CRYPTO) return (SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.0007);
   if(g_Asset.assetType == ASSET_GOLD)   return 110.0 * _Point;
   return 25.0 * _Point;
}


//+------------------------------------------------------------------+
//| GET DYNAMIC ANTI-CHASING THRESHOLD ACCORDING TO ASSET & SL DIST  |
//+------------------------------------------------------------------+
double GetAntiChasingThreshold(double slDistPts)
{
   if(g_Asset.assetType == ASSET_GOLD)
      return MathMax(250.0, slDistPts * 0.45);
   if(g_Asset.assetType == ASSET_CRYPTO)
      return MathMax(2500.0, slDistPts * 0.45);
   return MathMax(80.0, slDistPts * 0.45);
}

double ResolveRightChartLabelPrice(double rawPrice, int preferDir = 0)
{
   if(rawPrice <= 0.0) return rawPrice;
   double minSep = GetChartMinLabelSepPrice();

   bool collides = false;
   for(int k = 0; k < g_RightLabelCount; k++)
   {
      if(MathAbs(rawPrice - g_RightLabelPrices[k]) < minSep)
      {
         collides = true;
         break;
      }
   }

   if(!collides)
   {
      if(g_RightLabelCount < MAX_CHART_RIGHT_LABELS)
         g_RightLabelPrices[g_RightLabelCount++] = rawPrice;
      return rawPrice;
   }

   double bestPrice = rawPrice;
   double bestDist  = 9999999.0;
   int stepDir1 = (preferDir != 0) ? preferDir : 1;
   int stepDir2 = -stepDir1;
   double maxAllowedDist = minSep * 6.5; // รองรับการเรียงหลบกันสูงสุดถึง 10 ชั้นเมื่อเส้นมารวมกระจุกเดียวกัน

   for(int step = 1; step <= 10; step++)
   {
      int dirs[2];
      dirs[0] = stepDir1;
      dirs[1] = stepDir2;
      for(int d = 0; d < 2; d++)
      {
         double cand = rawPrice + (dirs[d] * step * minSep * 0.62);
         double dist = MathAbs(cand - rawPrice);
         if(dist > maxAllowedDist) continue;

         bool slotFree = true;
         for(int k = 0; k < g_RightLabelCount; k++)
         {
            if(MathAbs(cand - g_RightLabelPrices[k]) < minSep * 0.82)
            {
               slotFree = false;
               break;
            }
         }
         if(slotFree)
         {
            if(dist < bestDist)
            {
               bestDist  = dist;
               bestPrice = cand;
            }
         }
      }
      if(bestDist < 9999990.0) break;
   }

   if(bestDist >= 9999990.0)
      bestPrice = rawPrice + (stepDir1 * minSep * 1.25);

   if(g_RightLabelCount < MAX_CHART_RIGHT_LABELS)
      g_RightLabelPrices[g_RightLabelCount++] = bestPrice;

   return bestPrice;
}

//+------------------------------------------------------------------+
//| 14.4 DRAW CME OPTIONS WALLS (RED RESISTANCE & BLUE SUPPORT)      |
//+------------------------------------------------------------------+
void DrawCME_OptionsWalls()
{
   static int s_prevCMEDrawnCount = 0;

   if(!InpUseCME_OI || g_Asset.assetType != ASSET_GOLD)
   {
      for(int i = 0; i < s_prevCMEDrawnCount; i++)
      {
         ObjectDelete(0, GUI_PREFIX + "CME_LINE_" + IntegerToString(i));
         ObjectDelete(0, GUI_PREFIX + "CME_LBL_"  + IntegerToString(i));
      }
      s_prevCMEDrawnCount = 0;
      return;
   }

   datetime tStart   = TimeCurrent() - (PeriodSeconds() * 60);
   datetime tBaseEnd = TimeCurrent() + (PeriodSeconds() * 8);
   int secPerBar     = PeriodSeconds();

   int drawnCME = 0;
   for(int i = 0; i < g_CME_DisplayCount && drawnCME < MAX_CME_DISPLAYS; i++)
   {
      string lineName = GUI_PREFIX + "CME_LINE_" + IntegerToString(drawnCME);
      string lblName  = GUI_PREFIX + "CME_LBL_"  + IntegerToString(drawnCME);

      double val = g_CME_Displays[i].strike;
      color  col = g_CME_Displays[i].lineCol;

      datetime tLineEnd = tBaseEnd + (datetime)(secPerBar * ((i % 3) * 2));
      datetime tLbl     = tLineEnd + (datetime)(secPerBar * 1);
      double   lblPrice = ResolveRightChartLabelPrice(val, (i == 0 ? 1 : -1));

      // 1. Draw horizontal line
      if(ObjectFind(0, lineName) < 0)
      {
         ObjectCreate(0, lineName, OBJ_TREND, 0, tStart, val, tLineEnd, val);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, col);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, g_CME_Displays[i].lineStyle);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, g_CME_Displays[i].lineWidth);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, lineName, OBJPROP_TIME, 0) != tStart) ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, tStart);
         if(ObjectGetDouble(0, lineName, OBJPROP_PRICE, 0) != val) ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, val);
         if(ObjectGetInteger(0, lineName, OBJPROP_TIME, 1) != tLineEnd) ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, tLineEnd);
         if(ObjectGetDouble(0, lineName, OBJPROP_PRICE, 1) != val) ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, val);
         if((color)ObjectGetInteger(0, lineName, OBJPROP_COLOR) != col) ObjectSetInteger(0, lineName, OBJPROP_COLOR, col);
         if((ENUM_LINE_STYLE)ObjectGetInteger(0, lineName, OBJPROP_STYLE) != g_CME_Displays[i].lineStyle) ObjectSetInteger(0, lineName, OBJPROP_STYLE, g_CME_Displays[i].lineStyle);
         if(ObjectGetInteger(0, lineName, OBJPROP_WIDTH) != g_CME_Displays[i].lineWidth) ObjectSetInteger(0, lineName, OBJPROP_WIDTH, g_CME_Displays[i].lineWidth);
      }

      // 2. Draw text label
      if(ObjectFind(0, lblName) < 0)
      {
         ObjectCreate(0, lblName, OBJ_TEXT, 0, tLbl, lblPrice);
         ObjectSetString(0, lblName, OBJPROP_TEXT, g_CME_Displays[i].labelText);
         ObjectSetString(0, lblName, OBJPROP_FONT, "Segoe UI Semibold");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, col);
         ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
      }
      else
      {
         if(ObjectGetInteger(0, lblName, OBJPROP_TIME) != tLbl) ObjectSetInteger(0, lblName, OBJPROP_TIME, tLbl);
         if(ObjectGetDouble(0, lblName, OBJPROP_PRICE) != lblPrice) ObjectSetDouble(0, lblName, OBJPROP_PRICE, lblPrice);
         if(ObjectGetString(0, lblName, OBJPROP_TEXT) != g_CME_Displays[i].labelText) ObjectSetString(0, lblName, OBJPROP_TEXT, g_CME_Displays[i].labelText);
         if((color)ObjectGetInteger(0, lblName, OBJPROP_COLOR) != col) ObjectSetInteger(0, lblName, OBJPROP_COLOR, col);
      }

      drawnCME++;
   }

   // Cleanup unused CME objects from previous cycle
   for(int i = drawnCME; i < s_prevCMEDrawnCount; i++)
   {
      ObjectDelete(0, GUI_PREFIX + "CME_LINE_" + IntegerToString(i));
      ObjectDelete(0, GUI_PREFIX + "CME_LBL_"  + IntegerToString(i));
   }
   s_prevCMEDrawnCount = drawnCME;
}

//+------------------------------------------------------------------+
//| 14B. GANN EQUILIBRIUM LATTICE & WAVE ENERGY RADAR (QUANT PHASE)  |
//+------------------------------------------------------------------+
void CalculateGannWaveEnergy(const MqlRates &rates[], int copied)
{
   if(!InpUseWaveEnergyRadar && !InpUseGannEquilibriumGrid) return;
   if(copied < 30) return;

   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(curBid <= 0) curBid = rates[0].close;

   ulong curMs = GetTickCount64();

   // 1. Maintain Tick Rolling Velocity v(t) & Taylor Curvature a(t)
   static ulong  s_lastSampleMs = 0;
   static double s_lastPrice    = 0.0;
   static double s_prevVelocity = 0.0;

   if(s_lastPrice <= 0.0)
   {
      s_lastPrice    = curBid;
      s_lastSampleMs = curMs;
      s_prevVelocity = 0.0;
   }

   ulong deltaMs = curMs - s_lastSampleMs;
   if(deltaMs >= 400 || s_lastSampleMs == 0)
   {
      double dtSec = (double)deltaMs / 1000.0;
      if(dtSec < 0.1) dtSec = 0.1;

      double dPricePts = (curBid - s_lastPrice) / _Point;
      double instantVel = dPricePts / dtSec; // จุดต่อวินาที

      // ปรับความเร็วให้นุ่มนวลด้วย EMA Smoothing ไม่กระตุก
      g_GannEnergy.velocityPtsSec = (g_GannEnergy.velocityPtsSec * 0.70) + (instantVel * 0.30);

      // ความเร่ง/การชะลอตัว a(t) = dv/dt (Taylor second derivative)
      g_GannEnergy.accelPtsSec2 = (g_GannEnergy.velocityPtsSec - s_prevVelocity) / dtSec;
      s_prevVelocity = g_GannEnergy.velocityPtsSec;

      s_lastPrice    = curBid;
      s_lastSampleMs = curMs;
   }

   // 2. กำหนดฐานพหุคูณของ 10 (Decade Step) ตามสินทรัพย์
   double baseDecade = 10.0;
   if(g_Asset.assetType == ASSET_GOLD)        baseDecade = 10.0;
   else if(g_Asset.assetType == ASSET_CRYPTO) baseDecade = 500.0;
   else if(g_Asset.assetType == ASSET_INDEX)  baseDecade = 50.0;
   else                                       baseDecade = (100.0 * _Point); // Forex 10 pips

   // 3. สกัดหาจุดสมดุลเลขกลมกลางรอบคลื่น (Zero Origin Equilibrium Node)
   int lookback = MathMin(40, copied - 1);
   double highest = -1.0;
   double lowest  = 9999999.0;
   datetime anchorT = rates[lookback].time;

   for(int i = 0; i < lookback; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
      if(rates[i].low < lowest)   lowest  = rates[i].low;
   }

   double midWave = (highest + lowest) / 2.0;
   // ปัดเศษตรึงเข้าหาพหุคูณของ 10 เสมอ (Decadic Quantization)
   double zeroP = MathRound(midWave / baseDecade) * baseDecade;

   // หากราคาปัจจุบันหลุดห่างเกิน 2 ช่วงฐาน ให้เลื่อนจุดสมดุลเข้าหาหลักสิบที่ใกล้เคียงที่สุด
   if(MathAbs(curBid - zeroP) > (baseDecade * 2.0))
      zeroP = MathRound(curBid / baseDecade) * baseDecade;

   g_GannEnergy.zeroPrice  = zeroP;
   g_GannEnergy.anchorTime = anchorT;

   // 4. คำนวณระยะยืดจากจุดสมดุล x(t) (Displacement)
   g_GannEnergy.displacementPts   = (curBid - zeroP) / _Point;
   g_GannEnergy.displacementMoney = (curBid - zeroP);

   // 5. คำนวณแรงสวิงคลื่นรวมใน Phase Space A(t) = sqrt(x^2 + (v/omega)^2)
   double omega = 0.05;
   double vScaled = g_GannEnergy.velocityPtsSec / omega;
   g_GannEnergy.amplitudeEnergy = MathSqrt((g_GannEnergy.displacementPts * g_GannEnergy.displacementPts) + (vScaled * vScaled));

   // 6. คำนวณสเกลตาข่ายแกนน์ (Gann Grid Scale: จุดต่อแท่ง)
   if(InpGann_ScalePoints > 0.0)
   {
      g_GannEnergy.gridScale = InpGann_ScalePoints;
   }
   else
   {
      g_GannEnergy.gridScale = baseDecade / 10.0;
   }

   // 7. ตรวจจับจุดหมดแรงปลายคลื่น (Station Point: v ≈ 0 at Extreme Peak / Trough)
   double velScale = (g_Asset.assetType == ASSET_CRYPTO) ? 25.0 : 1.0;
   double extThreshPts = (baseDecade * 0.60) / _Point;
   bool isStretched    = (MathAbs(g_GannEnergy.displacementPts) >= extThreshPts);
   bool isLowVelocity  = (MathAbs(g_GannEnergy.velocityPtsSec) <= (1.8 * velScale));
   bool isDecelerating = (g_GannEnergy.accelPtsSec2 * g_GannEnergy.displacementPts <= 0.0);

   if(isStretched && isLowVelocity && isDecelerating)
   {
      g_GannEnergy.isStationPoint = true;
      if(g_GannEnergy.displacementPts > 0)
      {
         g_GannEnergy.stationDirection = 1; // หมดแรงที่ยอดดอย (เตือนเตรียมทุบ Sell)
         g_GannEnergy.energyStatus = "⚡ หมดแรงยอดดอย • ระวังร่วง 🔴";
         g_GannEnergy.statusColor  = C'255,80,90';
      }
      else
      {
         g_GannEnergy.stationDirection = -1; // หมดแรงที่ก้นเหว (เตือนเตรียมช้อน Buy)
         g_GannEnergy.energyStatus = "⚡ หมดแรงก้นเหว • ระวังดีด 🟢";
         g_GannEnergy.statusColor  = C'50,255,150';
      }
   }
   else
   {
      g_GannEnergy.isStationPoint   = false;
      g_GannEnergy.stationDirection = 0;

      double absV = MathAbs(g_GannEnergy.velocityPtsSec);
      if(absV >= (8.0 * velScale))
      {
         g_GannEnergy.energyStatus = "🚀 พุ่งแรงเต็มสปีด • คลื่นขยายตัว";
         g_GannEnergy.statusColor  = clrAqua;
      }
      else if(absV >= (2.5 * velScale))
      {
         g_GannEnergy.energyStatus = "🟢 วิ่งปกติ • มีแรงส่งต่อเนื่อง";
         g_GannEnergy.statusColor  = clrPaleGreen;
      }
      else
      {
         g_GannEnergy.energyStatus = "🟡 ชะลอตัว • สะสมพลังใกล้เบรก";
         g_GannEnergy.statusColor  = clrGold;
      }
   }
}

//+------------------------------------------------------------------+
//| 14C. DRAW GANN EQUILIBRIUM GRID & ZERO ORIGIN LINE               |
//+------------------------------------------------------------------+
void DrawGannEquilibriumGrid()
{
   // ตาข่ายสมดุลแกนน์ (Gann Grid) และเส้นสมดุล - ปลดระวางและลบออกถาวรตามคำสั่งของคุณเอ้ เพื่อชาร์ตสะอาด สบายตา ไร้การบดบัง
   string gridName = GUI_PREFIX + "GANN_GRID";
   ObjectDelete(0, gridName);

   string lineName = GUI_PREFIX + "GANN_ZERO_LINE";
   string lblName  = GUI_PREFIX + "GANN_ZERO_LBL";
   ObjectDelete(0, lineName);
   ObjectDelete(0, lblName);

   // ตรวจสอบและลบวัตถุประเภท OBJ_GANNGRID ทั้งหมดบนชาร์ตทันที
   for(int i = ObjectsTotal(0, 0, OBJ_GANNGRID) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_GANNGRID);
      ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+
//| 14D. VELOCITY STOP-LOCK FLOOR (+10 PTS ON STATION POINT)         |
//+------------------------------------------------------------------+
void CheckVelocityStopLockFloor()
{
   // ปิดการทำงานถาวร เพื่อไม่ให้ระบบดึง SL บังหน้าทุนเองเด็ดขาด (มอบอำนาจรันเทรนด์ให้ผู้เทรด 100%)
   return;
   if(!g_GannEnergy.isStationPoint) return;

   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(curBid <= 0) curBid = iClose(_Symbol, _Period, 0);
   if(curAsk <= 0) curAsk = curBid;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || m_position.Magic() == 0))
         {
            ENUM_POSITION_TYPE pType = m_position.PositionType();
            double openP = m_position.PriceOpen();
            double curSL = m_position.StopLoss();
            double curTP = m_position.TakeProfit();

            if(pType == POSITION_TYPE_BUY)
            {
               double profitPts = (curBid - openP) / _Point;
               // เมื่อกำไรถึงเกณฑ์ และราคาหมดแรงที่ยอดดอย (Station Direction = +1)
               if(profitPts >= InpVSL_TriggerProfitPts && g_GannEnergy.stationDirection == 1)
               {
                  double targetSL = openP + (InpVSL_FloorPts * _Point);
                  if(curSL < targetSL)
                  {
                     if(m_trade.PositionModify(m_position.Ticket(), targetSL, curTP))
                     {
                        Print(StringFormat("[VSL Lock Floor] ล็อกกำไรไม้ BUY #%d ที่ต้นทุน +%d จุด (ตรวจพบจุดหมดแรงยอดดอย v≈0)", m_position.Ticket(), InpVSL_FloorPts));
                     }
                  }
               }
            }
            else if(pType == POSITION_TYPE_SELL)
            {
               double profitPts = (openP - curAsk) / _Point;
               // เมื่อกำไรถึงเกณฑ์ และราคาหมดแรงที่ก้นเหว (Station Direction = -1)
               if(profitPts >= InpVSL_TriggerProfitPts && g_GannEnergy.stationDirection == -1)
               {
                  double targetSL = openP - (InpVSL_FloorPts * _Point);
                  if(curSL == 0.0 || curSL > targetSL)
                  {
                     if(m_trade.PositionModify(m_position.Ticket(), targetSL, curTP))
                     {
                        Print(StringFormat("[VSL Lock Floor] ล็อกกำไรไม้ SELL #%d ที่ต้นทุน +%d จุด (ตรวจพบจุดหมดแรงก้นเหว v≈0)", m_position.Ticket(), InpVSL_FloorPts));
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| M15 MULTI-TIMEFRAME DIRECTION DETECTOR                           |
//| คำนวณทิศทางแนวโน้ม M15 (EMA 14 + แท่งเทียน M15 + โมเมนตัม)       |
//| คืนค่า: +1 = ขาขึ้น (BULL), -1 = ขาลง (BEAR)                     |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetParentHTF(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return PERIOD_M15;
      case PERIOD_M2:  return PERIOD_M15;
      case PERIOD_M3:  return PERIOD_M15;
      case PERIOD_M4:  return PERIOD_M15;
      case PERIOD_M5:  return PERIOD_M15;
      case PERIOD_M6:  return PERIOD_M15;
      case PERIOD_M10: return PERIOD_M30;
      case PERIOD_M12: return PERIOD_H1;
      case PERIOD_M15: return PERIOD_H1;
      case PERIOD_M20: return PERIOD_H1;
      case PERIOD_M30: return PERIOD_H4;
      case PERIOD_H1:  return PERIOD_H4;
      case PERIOD_H2:  return PERIOD_H4;
      case PERIOD_H3:  return PERIOD_H4;
      case PERIOD_H4:  return PERIOD_D1;
      case PERIOD_H6:  return PERIOD_D1;
      case PERIOD_H8:  return PERIOD_D1;
      case PERIOD_H12: return PERIOD_D1;
      case PERIOD_D1:  return PERIOD_W1;
      case PERIOD_W1:  return PERIOD_MN1;
      default:         return PERIOD_M15;
   }
}

int GetHTF_TrendDirection(ENUM_TIMEFRAMES scanTF)
{
   ENUM_TIMEFRAMES parentTF = GetParentHTF(scanTF);
   MqlRates ratesHTF[];
   ArraySetAsSeries(ratesHTF, true);
   int copied = CopyRates(_Symbol, parentTF, 0, 30, ratesHTF);
   if(copied < 15) return 0;

   double ema14 = 0.0;
   double k = 2.0 / (14.0 + 1.0);
   double smaSum = 0.0;
   int startBar = copied - 1;
   for(int i = startBar; i > startBar - 14; i--)
      smaSum += ratesHTF[i].close;
   ema14 = smaSum / 14.0;
   for(int i = startBar - 14; i >= 0; i--)
      ema14 = (ratesHTF[i].close * k) + (ema14 * (1.0 - k));

   double curPrice = ratesHTF[0].close;
   double close1   = ratesHTF[1].close;
   double open1    = ratesHTF[1].open;

   bool priceAboveEMA = (curPrice >= ema14);
   bool priceBelowEMA = (curPrice <= ema14);
   bool bar1Bull      = (close1 >= open1);
   bool higherHigh    = (ratesHTF[0].high >= ratesHTF[1].high);
   bool lowerLow      = (ratesHTF[0].low <= ratesHTF[1].low);

   if(priceAboveEMA && (bar1Bull || higherHigh))
      return 1;  // ขาขึ้น (BULL)
   else if(priceBelowEMA && (!bar1Bull || lowerLow))
      return -1; // ขาลง (BEAR)
   else
      return (curPrice >= ema14) ? 1 : -1;
}

int GetM15_TrendDirection()
{
   ENUM_TIMEFRAMES scanTF = (InpDTD_TF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : InpDTD_TF;
   return GetHTF_TrendDirection(scanTF);
}

//+------------------------------------------------------------------+

//| 14E-0. FREE-MARGIN LOT CAP HELPER (PREVENT 'NOT ENOUGH MONEY')   |
//+------------------------------------------------------------------+
double CapLotByFreeMargin(double desiredLot, ENUM_ORDER_TYPE orderType, double price, double minLot, double maxLot, double stepLot)
{
   if(desiredLot < minLot) desiredLot = minLot;
   if(desiredLot > maxLot) desiredLot = maxLot;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(freeMargin <= 0.0) freeMargin = AccountInfoDouble(ACCOUNT_EQUITY);

   double marginPerOneLot = 0.0;
   if(price > 0.0 && freeMargin > 0.0 && OrderCalcMargin(orderType, _Symbol, 1.0, price, marginPerOneLot) && marginPerOneLot > 0.0)
   {
      // จำกัดขนาด Lot ไม่ให้ใช้ Margin เกิน 70% ของ Free Margin จริงในพอร์ต
      double maxAffordableLot = (freeMargin * 0.70) / marginPerOneLot;
      maxAffordableLot = MathFloor(maxAffordableLot / stepLot) * stepLot;
      if(maxAffordableLot < minLot) maxAffordableLot = minLot;
      if(desiredLot > maxAffordableLot) desiredLot = maxAffordableLot;
   }

   desiredLot = MathFloor((desiredLot + 0.000001) / stepLot) * stepLot;
   if(desiredLot < minLot) desiredLot = minLot;
   if(desiredLot > maxLot) desiredLot = maxLot;
   return NormalizeDouble(desiredLot, 2);
}

//+------------------------------------------------------------------+
//| 14E. DTD CONFIRMATION (CF M1) & MONEY MANAGEMENT 1:3R            |
//+------------------------------------------------------------------+
void ScanDTD_CF_M1()
{
   if(!InpUseDTD_CF_M1)
   {
      g_DTD.statusText = "🎯 CF: ปิดการใช้งาน";
      g_DTD.mmPlanText = "—";
      g_DTD.statusColor = clrSilver;
      return;
   }

   ENUM_TIMEFRAMES scanTF = (InpDTD_TF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : InpDTD_TF;
   g_DTD.activeTF = scanTF;
   g_DTD.tfName   = GetCleanTFName(scanTF);

   int tfSec = PeriodSeconds(scanTF);
   double tfMultiplier = 1.0;
   if(scanTF == PERIOD_M1)        tfMultiplier = 1.0;
   else if(scanTF == PERIOD_M5)   tfMultiplier = 1.5;
   else if(scanTF == PERIOD_M15)  tfMultiplier = 2.0;
   else if(scanTF == PERIOD_M30)  tfMultiplier = 2.5;
   else if(scanTF == PERIOD_H1)   tfMultiplier = 3.5;
   else if(scanTF == PERIOD_H4)   tfMultiplier = 6.0;
   else if(scanTF >= PERIOD_D1)   tfMultiplier = 10.0;

   MqlRates ratesDTD[];
   ArraySetAsSeries(ratesDTD, true);
   int copiedDTD = CopyRates(_Symbol, scanTF, 0, 100, ratesDTD);
   if(copiedDTD < 25 && scanTF != (ENUM_TIMEFRAMES)_Period)
   {
      copiedDTD = CopyRates(_Symbol, _Period, 0, 100, ratesDTD);
      if(copiedDTD >= 25)
      {
         g_DTD.activeTF = (ENUM_TIMEFRAMES)_Period;
         g_DTD.tfName   = GetCleanTFName((ENUM_TIMEFRAMES)_Period);
      }
   }
   if(copiedDTD < 10)
   {
      g_DTD.statusText  = StringFormat("🎯 CF %s: กำลังเตรียมข้อมูลแท่งเทียน...", g_DTD.tfName);
      g_DTD.mmPlanText  = "💵 แผน MM (1R/2R/3R): กำลังคำนวณระยะ SL และขนาด Lot...";
      g_DTD.statusColor = clrSilver;
      return;
   }

   // 1. ตรวจจับโครงสร้างสวิงไฮ/โลว์ สไตล์ อ.เดช (True SMC Fractal Swings)
   int highestBar = -1;
   int lowestBar = -1;
   double highestHigh = -1.0;
   double lowestLow = 999999999.0;

   // ค้นหา Fractal Swing High & Low ที่เป็นจุดสวิงโครงสร้างแท้จริง (แยกตัวจากแท่งข้างเคียง)
   for(int i = 2; i < 35 && i < copiedDTD - 2; i++)
   {
      bool isPeak = (ratesDTD[i].high > ratesDTD[i+1].high && ratesDTD[i].high > ratesDTD[i+2].high &&
                     ratesDTD[i].high >= ratesDTD[i-1].high);
      bool isValley = (ratesDTD[i].low < ratesDTD[i+1].low && ratesDTD[i].low < ratesDTD[i+2].low &&
                       ratesDTD[i].low <= ratesDTD[i-1].low);
      if(isPeak && ratesDTD[i].high > highestHigh)
      {
         highestHigh = ratesDTD[i].high;
         highestBar  = i;
      }
      if(isValley && ratesDTD[i].low < lowestLow)
      {
         lowestLow = ratesDTD[i].low;
         lowestBar = i;
      }
   }
   // Fallback สำรองหากโครงสร้างบีบตัวแคบ
   if(highestBar < 0 || highestHigh <= 0.0)
   {
      highestBar = 1; highestHigh = ratesDTD[1].high;
      for(int i = 1; i < 35 && i < copiedDTD; i++)
         if(ratesDTD[i].high > highestHigh) { highestHigh = ratesDTD[i].high; highestBar = i; }
   }
   if(lowestBar < 0 || lowestLow >= 999999999.0)
   {
      lowestBar = 1; lowestLow = ratesDTD[1].low;
      for(int i = 1; i < 35 && i < copiedDTD; i++)
         if(ratesDTD[i].low < lowestLow) { lowestLow = ratesDTD[i].low; lowestBar = i; }
   }

   g_DTD.m1SwingHighPrice = highestHigh;
   g_DTD.m1SwingHighTime  = ratesDTD[highestBar].time;
   g_DTD.m1SwingLowPrice  = lowestLow;
   g_DTD.m1SwingLowTime   = ratesDTD[lowestBar].time;

   // 1B. สแกนหาจุดสวิงโครงสร้าง (Fractal Swings) สำหรับวาด Zigzag Path สไตล์ อ.เดช
   g_DTD.m1SwingCount = 0;
   SDTD_M1_Swing rawSwings[16];
   int rawCount = 0;

   int scanLimit = MathMin(35, copiedDTD - 3);
   for(int b = scanLimit; b >= 2 && rawCount < 16; b--)
   {
      bool isHigh = (ratesDTD[b].high >= ratesDTD[b+1].high && ratesDTD[b].high >= ratesDTD[b-1].high);
      bool isLow  = (ratesDTD[b].low  <= ratesDTD[b+1].low  && ratesDTD[b].low  <= ratesDTD[b-1].low);

      if(isHigh && !isLow)
      {
         if(rawCount > 0 && rawSwings[rawCount-1].type == 1)
         {
            if(ratesDTD[b].high > rawSwings[rawCount-1].price)
            {
               rawSwings[rawCount-1].price = ratesDTD[b].high;
               rawSwings[rawCount-1].time  = ratesDTD[b].time;
            }
         }
         else
         {
            rawSwings[rawCount].price = ratesDTD[b].high;
            rawSwings[rawCount].time  = ratesDTD[b].time;
            rawSwings[rawCount].type  = 1;
            rawCount++;
         }
      }
      else if(isLow && !isHigh)
      {
         if(rawCount > 0 && rawSwings[rawCount-1].type == -1)
         {
            if(ratesDTD[b].low < rawSwings[rawCount-1].price)
            {
               rawSwings[rawCount-1].price = ratesDTD[b].low;
               rawSwings[rawCount-1].time  = ratesDTD[b].time;
            }
         }
         else
         {
            rawSwings[rawCount].price = ratesDTD[b].low;
            rawSwings[rawCount].time  = ratesDTD[b].time;
            rawSwings[rawCount].type  = -1;
            rawCount++;
         }
      }
   }

   // เชื่อมต่อแท่งเทียนปัจจุบันเข้าเป็นจุดปลาย
   if(rawCount > 0 && rawCount < 16)
   {
      rawSwings[rawCount].price = ratesDTD[0].close;
      rawSwings[rawCount].time  = ratesDTD[0].time;
      rawSwings[rawCount].type  = (ratesDTD[0].close >= rawSwings[rawCount-1].price ? 1 : -1);
      rawCount++;
   }

   int startIdx = MathMax(0, rawCount - MAX_DTD_M1_SWINGS);
   int outIdx = 0;
   for(int k = startIdx; k < rawCount && outIdx < MAX_DTD_M1_SWINGS; k++)
   {
      g_DTD.m1Swings[outIdx] = rawSwings[k];
      outIdx++;
   }
   g_DTD.m1SwingCount = outIdx;

   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(curBid <= 0) curBid = ratesDTD[0].close;
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

   long curSpreadPts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(curSpreadPts <= 0) curSpreadPts = (long)MathRound((curAsk - curBid) / _Point);

   double minBufferPts = (double)InpDTD_SL_BufferPts * tfMultiplier;
   if(g_Asset.assetType == ASSET_CRYPTO)
      minBufferPts = MathMax(minBufferPts, MathMax((double)curSpreadPts * 0.50, (curBid * 0.0002) / _Point));
   else
      minBufferPts = MathMax(minBufferPts, (double)curSpreadPts * 0.80);

   double buffer = minBufferPts * _Point;

   double minSLPts = 80.0 * tfMultiplier;
   if(g_Asset.assetType == ASSET_CRYPTO)
      minSLPts = MathMax((double)curSpreadPts * 2.0, (curBid * 0.00065) / _Point);
   else if(g_Asset.assetType == ASSET_GOLD)
      minSLPts = MathMax(80.0 * tfMultiplier, (double)curSpreadPts * 2.2);
   else
      minSLPts = MathMax(45.0 * tfMultiplier, (double)curSpreadPts * 2.2);

   string moneyUnit = IsCentAccount() ? "USC" : "$";

   // =========================================================================
   // 1A. คำนวณกรอบ Sideway Range Box (SW HIGH / SW LOW) & สภาวะตลาด 3 โหมด (ทุก TF)
   // =========================================================================
   double sumRange = 0.0;
   int rangeCount = MathMin(24, copiedDTD - 1);
   for(int r = 1; r <= rangeCount; r++) sumRange += (ratesDTD[r].high - ratesDTD[r].low);
   double avgBarRange = (rangeCount > 0) ? (sumRange / rangeCount) : (minSLPts * _Point);
   if(avgBarRange <= 0.0) avgBarRange = 50.0 * _Point * tfMultiplier;
   g_DTD.avgBarRange = avgBarRange;

   int swBars = MathMin(24, copiedDTD - 1);
   double rawSwHigh = ratesDTD[2].high, rawSwLow = ratesDTD[2].low;
   double bodySwHigh = MathMax(ratesDTD[2].open, ratesDTD[2].close);
   double bodySwLow  = MathMin(ratesDTD[2].open, ratesDTD[2].close);
   for(int s = 2; s <= swBars; s++)
   {
      if(ratesDTD[s].high > rawSwHigh) rawSwHigh = ratesDTD[s].high;
      if(ratesDTD[s].low  < rawSwLow)  rawSwLow  = ratesDTD[s].low;
      double bTop = MathMax(ratesDTD[s].open, ratesDTD[s].close);
      double bBot = MathMin(ratesDTD[s].open, ratesDTD[s].close);
      if(bTop > bodySwHigh) bodySwHigh = bTop;
      if(bBot < bodySwLow)  bodySwLow  = bBot;
   }
   // ใช้ขอบเนื้อเทียนผสมปลายไส้เพื่อให้จับทั้งจังหวะเบรกจริงและแหย่ไส้หลอก (Sweep) ขอบกล่องได้แม่นยำ
   g_DTD.swBoxHigh      = (rawSwHigh - bodySwHigh > avgBarRange * 0.6) ? ((rawSwHigh + bodySwHigh) * 0.5) : rawSwHigh;
   g_DTD.swBoxLow       = (bodySwLow - rawSwLow   > avgBarRange * 0.6) ? ((rawSwLow  + bodySwLow)  * 0.5) : rawSwLow;
   g_DTD.swBoxMid       = (g_DTD.swBoxHigh + g_DTD.swBoxLow) * 0.5;
   g_DTD.swBoxStartTime = ratesDTD[swBars].time;

   int midCrosses = 0;
   for(int s = 2; s <= swBars; s++)
   {
      if(ratesDTD[s].high >= g_DTD.swBoxMid && ratesDTD[s].low <= g_DTD.swBoxMid)
         midCrosses++;
   }
   double boxSpan = g_DTD.swBoxHigh - g_DTD.swBoxLow;
   bool isCompactRange = (boxSpan <= avgBarRange * 6.0 || midCrosses >= 4 || g_Regime != SW_NONE);
   bool isBalancedMTF  = (g_MarketBiasBuyPct >= 35 && g_MarketBiasBuyPct <= 65);

   // ตรวจจับการเบรกกรอบ SW จริง vs การแหย่ไส้หลอก (Fakeout Sweep) แบบ Realtime
   g_DTD.swBreakState = 0;
   double brkTol = avgBarRange * 0.08;
   if(ratesDTD[1].close > g_DTD.swBoxHigh + brkTol || ratesDTD[0].close > g_DTD.swBoxHigh + (avgBarRange * 0.20))
      g_DTD.swBreakState = 1;  // เบรกกรอบบน SW HIGH จริง
   else if(ratesDTD[1].close < g_DTD.swBoxLow - brkTol || ratesDTD[0].close < g_DTD.swBoxLow - (avgBarRange * 0.20))
      g_DTD.swBreakState = -1; // หลุดกรอบล่าง SW LOW จริง
   else if((ratesDTD[1].high > g_DTD.swBoxHigh && ratesDTD[1].close <= g_DTD.swBoxHigh) || (ratesDTD[0].high > g_DTD.swBoxHigh && ratesDTD[0].close <= g_DTD.swBoxHigh))
      g_DTD.swBreakState = 2;  // แหย่ไส้เบรกบนหลอก (Sweep SW HIGH)
   else if((ratesDTD[1].low < g_DTD.swBoxLow && ratesDTD[1].close >= g_DTD.swBoxLow) || (ratesDTD[0].low < g_DTD.swBoxLow && ratesDTD[0].close >= g_DTD.swBoxLow))
      g_DTD.swBreakState = -2; // แหย่ไส้หลุดล่างหลอก (Sweep SW LOW)

   // กำหนดโหมดตลาด 3 สภาวะ (SW / เทรนด์ขาขึ้น / เทรนด์ขาลง)
   if(isCompactRange || isBalancedMTF)
   {
      g_DTD.swBoxActive = true;
      if(g_DTD.swBreakState == 1)
      {
         g_DTD.marketRegime    = 1;
         g_DTD.regimeBadgeText = StringFormat("[โหมด: 🚀 เบรกกรอบ SW ขาขึ้น %s]", g_DTD.tfName);
         g_DTD.swStatusText    = StringFormat("🚀 เบรกกรอบ SW HIGH [%s] (%s) สำเร็จ! ➔ รอย่อ RETEST ขอบกล่อง + CF เพื่อกด BUY", g_DTD.tfName, DoubleToString(g_DTD.swBoxHigh, _Digits));
      }
      else if(g_DTD.swBreakState == -1)
      {
         g_DTD.marketRegime    = -1;
         g_DTD.regimeBadgeText = StringFormat("[โหมด: 🚀 หลุดกรอบ SW ขาลง %s]", g_DTD.tfName);
         g_DTD.swStatusText    = StringFormat("🚀 หลุดกรอบ SW LOW [%s] (%s) สำเร็จ! ➔ รอเด้ง RETEST ขอบกล่อง + CF เพื่อกด SELL", g_DTD.tfName, DoubleToString(g_DTD.swBoxLow, _Digits));
      }
      else if(g_DTD.swBreakState == 2)
      {
         g_DTD.marketRegime    = 0;
         g_DTD.regimeBadgeText = StringFormat("[โหมด: ⚠️ Sweep ขอบบน SW %s]", g_DTD.tfName);
         g_DTD.swStatusText    = StringFormat("⚠️ ระวังเบรกหลอก (Sweep SW HIGH %s)! ห้ามไล่ BUY • รอ CF ดัก SELL ย้อนเข้ากรอบ", DoubleToString(g_DTD.swBoxHigh, _Digits));
      }
      else if(g_DTD.swBreakState == -2)
      {
         g_DTD.marketRegime    = 0;
         g_DTD.regimeBadgeText = StringFormat("[โหมด: ⚠️ Sweep ขอบล่าง SW %s]", g_DTD.tfName);
         g_DTD.swStatusText    = StringFormat("⚠️ ระวังหลุดหลอก (Sweep SW LOW %s)! ห้ามไล่ SELL • รอ CF ดัก BUY ย้อนเข้ากรอบ", DoubleToString(g_DTD.swBoxLow, _Digits));
      }
      else
      {
         g_DTD.marketRegime    = 0;
         g_DTD.regimeBadgeText = StringFormat("[โหมด: ↔️ กรอบไซด์เวย์ SW %s]", g_DTD.tfName);
         g_DTD.swStatusText    = StringFormat("📦 ตลาดวิ่งในกรอบ SW [%s] (%s - %s) • รอเบรกหลุดกรอบ High/Low ก่อนเข้าเทรด", g_DTD.tfName, DoubleToString(g_DTD.swBoxLow, _Digits), DoubleToString(g_DTD.swBoxHigh, _Digits));
      }
   }
   else if(g_MarketBiasBuyPct >= 66)
   {
      g_DTD.marketRegime    = 1;
      g_DTD.swBoxActive     = false;
      g_DTD.regimeBadgeText = StringFormat("[โหมด: 📈 เทรนด์ขาขึ้น %s]", g_DTD.tfName);
      g_DTD.swStatusText    = StringFormat("📈 เทรนด์ขาขึ้นแข็งแกร่ง (%d%%) • เน้นดักย่อ RETEST + CF BUY ตามน้ำ", g_MarketBiasBuyPct);
   }
   else
   {
      g_DTD.marketRegime    = -1;
      g_DTD.swBoxActive     = false;
      g_DTD.regimeBadgeText = StringFormat("[โหมด: 📉 เทรนด์ขาลง %s]", g_DTD.tfName);
      g_DTD.swStatusText    = StringFormat("📉 เทรนด์ขาลงแข็งแกร่ง (%d%%) • เน้นดักเด้ง RETEST + CF SELL (ห้ามรับมีด)", g_MarketBiasSellPct);
   }

   // =========================================================================
   // 2. คำนวณแผน BUY อิสระแบบ Realtime (แยกแท่ง RETEST และแท่ง CF ออกจากกัน 100%)
   // =========================================================================
   bool buyHasShift = (ratesDTD[0].close >= highestHigh || ratesDTD[1].close >= highestHigh || highestBar >= 2);
   int buyLookback = MathMin(10, copiedDTD - 1);
   int buyRetestIdx = 1;
   double lowestPullbackPrice = ratesDTD[1].low;
   for(int b = 1; b <= buyLookback; b++)
   {
      if(ratesDTD[b].low <= lowestPullbackPrice)
      {
         lowestPullbackPrice = ratesDTD[b].low;
         buyRetestIdx = b;
      }
   }
   datetime lowestPullbackTime = ratesDTD[buyRetestIdx].time;

   // ค้นหาปลายไส้เป้าหมาย (buyTargetWickPrice) จากกลุ่มแท่งย่อทดสอบ (ไม่รวมแท่งที่จะใช้กลืนกิน เพื่อป้องกันบั๊กเทียบตัวเอง)
   double buyTargetWickPrice = ratesDTD[buyRetestIdx].high;
   datetime buyTargetWickTime = ratesDTD[buyRetestIdx].time;
   double buyShortestWickLen = 999999.0;
   int wickScanStart = (buyRetestIdx >= 2) ? 2 : 1;
   int wickScanEnd   = MathMin(buyRetestIdx + 2, copiedDTD - 1);
   for(int b = wickScanStart; b <= wickScanEnd; b++)
   {
      double bodyTop = MathMax(ratesDTD[b].open, ratesDTD[b].close);
      double upperWick = ratesDTD[b].high - bodyTop;
      if(upperWick < buyShortestWickLen && upperWick >= 0.0)
      {
         buyShortestWickLen = upperWick;
         buyTargetWickPrice = ratesDTD[b].high;
         buyTargetWickTime  = ratesDTD[b].time;
      }
   }

   // สแกนหาแท่งเทียนที่ปิดเนื้อกลืนกินชนะ buyTargetWickPrice ล่าสุดแบบ Realtime
   bool buyConfirmed = false;
   int  buyCFBar     = 1;
   int  maxCFCheck   = (buyRetestIdx >= 2) ? (buyRetestIdx - 1) : 1;
   for(int c = 1; c <= maxCFCheck && c <= 5; c++)
   {
      if(c < buyRetestIdx && ratesDTD[c].close > buyTargetWickPrice && ratesDTD[c].close > ratesDTD[c].open && ratesDTD[0].low >= lowestPullbackPrice)
      {
         buyConfirmed = true;
         buyCFBar     = c;
         break; // เอาแท่งคอนเฟิร์มที่สดใหม่ที่สุดเสมอ
      }
   }
   bool buyIsTestingNow = (!buyConfirmed && ratesDTD[0].close > buyTargetWickPrice && ratesDTD[0].close > ratesDTD[0].open);
   datetime buyConfirmBarTime  = buyConfirmed ? ratesDTD[buyCFBar].time : ratesDTD[0].time;
   double   buyConfirmBarPrice = buyConfirmed ? ratesDTD[buyCFBar].high : ratesDTD[0].high;

   double buyEntryPrice = curAsk;
   double buySLPrice = lowestPullbackPrice - buffer;
   if((buyEntryPrice - buySLPrice) < minSLPts * _Point)
      buySLPrice = buyEntryPrice - (minSLPts * _Point);

   double buySLDist = (buyEntryPrice - buySLPrice) / _Point;
   if(buySLDist <= 0.0) buySLDist = minSLPts;

   double buyTP1RPrice = buyEntryPrice + (buySLDist * _Point * 1.0);
   double buyTP2RPrice = buyEntryPrice + (buySLDist * _Point * 2.0);
   double buyTP3RPrice = buyEntryPrice + (buySLDist * _Point * InpDTD_TargetRR);

   double buyLossPerLot = buySLDist * ptValPerLot;
   double buyCalcLot = InpDefaultLot;
   if(buyLossPerLot > 0.0 && InpDTD_RiskMoney > 0.0)
      buyCalcLot = InpDTD_RiskMoney / buyLossPerLot;
   double buyRecommendedLot = CapLotByFreeMargin(buyCalcLot, ORDER_TYPE_BUY, curAsk, minLot, maxLot, stepLot);

   for(int z = 0; z < g_ZoneCount; z++)
   {
      if(!g_Zones[z].isActive || g_Zones[z].isDemand) continue;
      if(g_Zones[z].low > buyEntryPrice && g_Zones[z].low < buyTP3RPrice)
      {
         double frontRunTP = NormalizeDouble(g_Zones[z].low - (15.0 * _Point * tfMultiplier), _Digits);
         if(frontRunTP >= buyTP2RPrice + (40.0 * _Point * tfMultiplier))
            buyTP3RPrice = frontRunTP;
      }
   }

   // =========================================================================
   // 3. คำนวณแผน SELL อิสระแบบ Realtime (แยกแท่ง RETEST และแท่ง CF ออกจากกัน 100%)
   // =========================================================================
   bool sellHasShift = (ratesDTD[0].close <= lowestLow || ratesDTD[1].close <= lowestLow || lowestBar >= 2);
   int sellLookback = MathMin(10, copiedDTD - 1);
   int sellRetestIdx = 1;
   double highestPullbackPrice = ratesDTD[1].high;
   for(int b = 1; b <= sellLookback; b++)
   {
      if(ratesDTD[b].high >= highestPullbackPrice)
      {
         highestPullbackPrice = ratesDTD[b].high;
         sellRetestIdx = b;
      }
   }
   datetime highestPullbackTime = ratesDTD[sellRetestIdx].time;

   double sellTargetWickPrice = ratesDTD[sellRetestIdx].low;
   datetime sellTargetWickTime = ratesDTD[sellRetestIdx].time;
   double sellShortestWickLen = 999999.0;
   int sWickScanStart = (sellRetestIdx >= 2) ? 2 : 1;
   int sWickScanEnd   = MathMin(sellRetestIdx + 2, copiedDTD - 1);
   for(int b = sWickScanStart; b <= sWickScanEnd; b++)
   {
      double bodyBottom = MathMin(ratesDTD[b].open, ratesDTD[b].close);
      double lowerWick = bodyBottom - ratesDTD[b].low;
      if(lowerWick < sellShortestWickLen && lowerWick >= 0.0)
      {
         sellShortestWickLen = lowerWick;
         sellTargetWickPrice = ratesDTD[b].low;
         sellTargetWickTime  = ratesDTD[b].time;
      }
   }

   bool sellConfirmed = false;
   int  sellCFBar     = 1;
   int  sMaxCFCheck   = (sellRetestIdx >= 2) ? (sellRetestIdx - 1) : 1;
   for(int c = 1; c <= sMaxCFCheck && c <= 5; c++)
   {
      if(c < sellRetestIdx && ratesDTD[c].close < sellTargetWickPrice && ratesDTD[c].close < ratesDTD[c].open && ratesDTD[0].high <= highestPullbackPrice)
      {
         sellConfirmed = true;
         sellCFBar     = c;
         break; // เอาแท่งคอนเฟิร์มที่สดใหม่ที่สุดเสมอ
      }
   }
   bool sellIsTestingNow = (!sellConfirmed && ratesDTD[0].close < sellTargetWickPrice && ratesDTD[0].close < ratesDTD[0].open);
   datetime sellConfirmBarTime  = sellConfirmed ? ratesDTD[sellCFBar].time : ratesDTD[0].time;
   double   sellConfirmBarPrice = sellConfirmed ? ratesDTD[sellCFBar].low  : ratesDTD[0].low;

   // หากเกิดทั้ง BUY และ SELL ในช่วงสั้นๆ ให้ตัดสินจากแท่ง CF ที่เกิดสดใหม่ล่าสุด (Bar Index น้อยกว่าชนะทันที)
   if(buyConfirmed && sellConfirmed)
   {
      if(buyCFBar < sellCFBar)
         sellConfirmed = false;
      else if(sellCFBar < buyCFBar)
         buyConfirmed = false;
      else if(ratesDTD[0].close >= ratesDTD[0].open)
         sellConfirmed = false;
      else
         buyConfirmed = false;
   }

   double sellEntryPrice = curBid;
   double sellSLPrice = highestPullbackPrice + buffer;
   if((sellSLPrice - sellEntryPrice) < minSLPts * _Point)
      sellSLPrice = sellEntryPrice + (minSLPts * _Point);

   double sellSLDist = (sellSLPrice - sellEntryPrice) / _Point;
   if(sellSLDist <= 0.0) sellSLDist = minSLPts;

   double sellTP1RPrice = sellEntryPrice - (sellSLDist * _Point * 1.0);
   double sellTP2RPrice = sellEntryPrice - (sellSLDist * _Point * 2.0);
   double sellTP3RPrice = sellEntryPrice - (sellSLDist * _Point * InpDTD_TargetRR);

   double sellLossPerLot = sellSLDist * ptValPerLot;
   double sellCalcLot = InpDefaultLot;
   if(sellLossPerLot > 0.0 && InpDTD_RiskMoney > 0.0)
      sellCalcLot = InpDTD_RiskMoney / sellLossPerLot;
   double sellRecommendedLot = CapLotByFreeMargin(sellCalcLot, ORDER_TYPE_SELL, curBid, minLot, maxLot, stepLot);

   for(int z = 0; z < g_ZoneCount; z++)
   {
      if(!g_Zones[z].isActive || !g_Zones[z].isDemand) continue;
      if(g_Zones[z].high < sellEntryPrice && g_Zones[z].high > sellTP3RPrice)
      {
         double frontRunTP = NormalizeDouble(g_Zones[z].high + (15.0 * _Point * tfMultiplier), _Digits);
         if(frontRunTP <= sellTP2RPrice - (40.0 * _Point * tfMultiplier))
            sellTP3RPrice = frontRunTP;
      }
   }

   g_DTD.buyEngulfConfirmed   = buyConfirmed;
   g_DTD.buyShortestWickPrice = buyTargetWickPrice;
   g_DTD.buyShortestWickTime  = buyTargetWickTime;
   g_DTD.buyConfirmEntryPrice = buyEntryPrice;
   g_DTD.buyConfirmSLPrice    = buySLPrice;
   g_DTD.buyConfirmTP1RPrice  = buyTP1RPrice;
   g_DTD.buyConfirmTP2RPrice  = buyTP2RPrice;
   g_DTD.buyConfirmTP3RPrice  = buyTP3RPrice;
   g_DTD.buySlDistPoints      = buySLDist;
   g_DTD.buyRecommendedLot    = buyRecommendedLot;

   g_DTD.sellEngulfConfirmed   = sellConfirmed;
   g_DTD.sellShortestWickPrice = sellTargetWickPrice;
   g_DTD.sellShortestWickTime  = sellTargetWickTime;
   g_DTD.sellConfirmEntryPrice = sellEntryPrice;
   g_DTD.sellConfirmSLPrice    = sellSLPrice;
   g_DTD.sellConfirmTP1RPrice  = sellTP1RPrice;
   g_DTD.sellConfirmTP2RPrice  = sellTP2RPrice;
   g_DTD.sellConfirmTP3RPrice  = sellTP3RPrice;
   g_DTD.sellSlDistPoints      = sellSLDist;
   g_DTD.sellRecommendedLot    = sellRecommendedLot;

   // =========================================================================
   // 1B. ตรวจสอบสถานะการล็อกและปลดล็อก Realtime เมื่อแท่งเทียนกลับตัวสวนทาง
   // =========================================================================
   if(g_DTD.isLatched)
   {
      bool unlatch = false;
      string unlatchReason = "";

      if(g_DTD.latchedSide == 1)
      {
         if(curBid >= g_DTD.latchedTP3Price) { unlatch = true; unlatchReason = "แตะเป้าหมายหลัก TP3 สำเร็จ"; }
         else if(curBid <= g_DTD.latchedSLPrice) { unlatch = true; unlatchReason = "ราคาหลุดระดับ Stop Loss"; }
         else if(sellConfirmed && sellCFBar <= 2) { unlatch = true; unlatchReason = "แท่งเทียนพลิกกลับตัวเกิด CF SELL ใหม่แบบ Realtime"; }
      }
      else if(g_DTD.latchedSide == -1)
      {
         if(curAsk <= g_DTD.latchedTP3Price) { unlatch = true; unlatchReason = "แตะเป้าหมายหลัก TP3 สำเร็จ"; }
         else if(curAsk >= g_DTD.latchedSLPrice) { unlatch = true; unlatchReason = "ราคาหลุดระดับ Stop Loss"; }
         else if(buyConfirmed && buyCFBar <= 2) { unlatch = true; unlatchReason = "แท่งเทียนพลิกกลับตัวเกิด CF BUY ใหม่แบบ Realtime"; }
      }

      int expireSec = MathMax(900, tfSec * 15);
      if(!unlatch)
      {
         int htfDir = GetHTF_TrendDirection(scanTF);
         if(g_DTD.latchedSide == 1)
         {
            if(InpRequireM15_Alignment && htfDir == -1) { unlatch = true; unlatchReason = "เทรนด์แม่พลิกเป็นขาลง"; }
            else if(g_MarketBiasSellPct >= 70) { unlatch = true; unlatchReason = "น้ำหนักตลาดพลิกเป็น SELL"; }
            else if((ratesDTD[0].time - g_DTD.latchedTime) > expireSec && curBid < g_DTD.latchedEntryPrice) { unlatch = true; unlatchReason = "หมดเวลาถือแผนเดิม"; }
            else if(g_DTD.m1SwingLowPrice > 0.0 && curBid < g_DTD.m1SwingLowPrice) { unlatch = true; unlatchReason = "ราคาหลุด Swing Low"; }
         }
         else if(g_DTD.latchedSide == -1)
         {
            if(InpRequireM15_Alignment && htfDir == 1) { unlatch = true; unlatchReason = "เทรนด์แม่พลิกเป็นขาขึ้น"; }
            else if(g_MarketBiasBuyPct >= 70) { unlatch = true; unlatchReason = "น้ำหนักตลาดพลิกเป็น BUY"; }
            else if((ratesDTD[0].time - g_DTD.latchedTime) > expireSec && curAsk > g_DTD.latchedEntryPrice) { unlatch = true; unlatchReason = "หมดเวลาถือแผนเดิม"; }
            else if(g_DTD.m1SwingHighPrice > 0.0 && curAsk > g_DTD.m1SwingHighPrice) { unlatch = true; unlatchReason = "ราคาทะลุ Swing High"; }
         }
      }

      if(unlatch)
      {
         Print(">>> [DeungDang_Trade] 🔓 ปลดล็อกแผนเทรดเดิมแบบ Realtime! เหตุผล: ", unlatchReason);
         g_DTD.isLatched           = false;
         g_DTD.latchedSide         = 0;
         g_DTD.latchedTime         = 0;
         g_DTD.retestBarTime       = 0;
         g_DTD.confirmBarTime      = 0;
      }
      else
      {
         // อัปเดตตำแหน่งลูกศร RETEST และ CF ให้ขยับตามแท่งเทียนล่าสุดแบบ Realtime แม้กรอบ 1:3R จะล็อกอยู่!
         if(g_DTD.latchedSide == 1)
         {
            if(lowestPullbackTime >= g_DTD.latchedRetestTime)
            {
               g_DTD.latchedRetestTime  = lowestPullbackTime;
               g_DTD.latchedRetestPrice = lowestPullbackPrice;
            }
            if(buyConfirmed && buyConfirmBarTime >= g_DTD.latchedConfirmTime)
            {
               g_DTD.latchedConfirmTime  = buyConfirmBarTime;
               g_DTD.latchedConfirmPrice = buyConfirmBarPrice;
               g_DTD.latchedShortestWick = buyTargetWickPrice;
            }
         }
         else if(g_DTD.latchedSide == -1)
         {
            if(highestPullbackTime >= g_DTD.latchedRetestTime)
            {
               g_DTD.latchedRetestTime  = highestPullbackTime;
               g_DTD.latchedRetestPrice = highestPullbackPrice;
            }
            if(sellConfirmed && sellConfirmBarTime >= g_DTD.latchedConfirmTime)
            {
               g_DTD.latchedConfirmTime  = sellConfirmBarTime;
               g_DTD.latchedConfirmPrice = sellConfirmBarPrice;
               g_DTD.latchedShortestWick = sellTargetWickPrice;
            }
         }

         g_DTD.setupSide         = g_DTD.latchedSide;
         g_DTD.shortestWickPrice = g_DTD.latchedShortestWick;
         g_DTD.confirmEntryPrice = g_DTD.latchedEntryPrice;
         g_DTD.confirmSLPrice    = g_DTD.latchedSLPrice;
         g_DTD.confirmTP1RPrice  = g_DTD.latchedTP1Price;
         g_DTD.confirmTP2RPrice  = g_DTD.latchedTP2Price;
         g_DTD.confirmTP3RPrice  = g_DTD.latchedTP3Price;
         g_DTD.slDistPoints      = g_DTD.latchedSLDist;
         g_DTD.tp1RDistPoints    = g_DTD.latchedSLDist * 1.0;
         g_DTD.tp2RDistPoints    = g_DTD.latchedSLDist * 2.0;
         g_DTD.tp3RDistPoints    = g_DTD.latchedSLDist * InpDTD_TargetRR;
         g_DTD.retestBarTime     = g_DTD.latchedRetestTime;
         g_DTD.retestBarPrice    = g_DTD.latchedRetestPrice;
         g_DTD.confirmBarTime    = g_DTD.latchedConfirmTime;
         g_DTD.confirmBarPrice   = g_DTD.latchedConfirmPrice;
         g_DTD.lqLinePrice       = g_DTD.latchedLQPrice;
         g_DTD.lqLineTime        = g_DTD.latchedLQTime;
         g_DTD.lqIsSwept         = g_DTD.latchedLQSwept;
         g_DTD.latchedLot        = CapLotByFreeMargin(g_DTD.latchedLot, (g_DTD.latchedSide == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), (g_DTD.latchedSide == 1 ? curAsk : curBid), minLot, maxLot, stepLot);
         g_DTD.recommendedLot    = g_DTD.latchedLot;
         g_DTD.isEngulfConfirmed = true;

         if(g_DTD.latchedSide == 1)
         {
            g_DTD.buyEngulfConfirmed   = true;
            g_DTD.sellEngulfConfirmed  = false;
            g_DTD.buyConfirmEntryPrice = g_DTD.latchedEntryPrice;
            g_DTD.buyConfirmSLPrice    = g_DTD.latchedSLPrice;
            g_DTD.buyConfirmTP1RPrice  = g_DTD.latchedTP1Price;
            g_DTD.buyConfirmTP2RPrice  = g_DTD.latchedTP2Price;
            g_DTD.buyConfirmTP3RPrice  = g_DTD.latchedTP3Price;
            g_DTD.buySlDistPoints      = g_DTD.latchedSLDist;
            g_DTD.buyRecommendedLot    = g_DTD.latchedLot;
            g_DTD.statusText  = StringFormat("🎯 CF %s: 🟢 จบกลืนกิน BUY สำเร็จ! • รันตามแผน 1:3R", g_DTD.tfName);
            g_DTD.statusColor = C'0,255,136';
         }
         else
         {
            g_DTD.sellEngulfConfirmed   = true;
            g_DTD.buyEngulfConfirmed    = false;
            g_DTD.sellConfirmEntryPrice = g_DTD.latchedEntryPrice;
            g_DTD.sellConfirmSLPrice    = g_DTD.latchedSLPrice;
            g_DTD.sellConfirmTP1RPrice  = g_DTD.latchedTP1Price;
            g_DTD.sellConfirmTP2RPrice  = g_DTD.latchedTP2Price;
            g_DTD.sellConfirmTP3RPrice  = g_DTD.latchedTP3Price;
            g_DTD.sellSlDistPoints      = g_DTD.latchedSLDist;
            g_DTD.sellRecommendedLot    = g_DTD.latchedLot;
            g_DTD.statusText  = StringFormat("🎯 CF %s: 🔴 จบกลืนกิน SELL สำเร็จ! • รันตามแผน 1:3R", g_DTD.tfName);
            g_DTD.statusColor = C'255,80,90';
         }

         g_DTD.mmPlanText = StringFormat("💵 แผน MM (1R/2R/3R): SL %s | TP1 %s | TP2 %s | TP3 %s | Lot: %.2f",
                                         FormatMoneyOrPoints(g_DTD.slDistPoints),
                                         FormatMoneyOrPoints(g_DTD.tp1RDistPoints),
                                         FormatMoneyOrPoints(g_DTD.tp2RDistPoints),
                                         FormatMoneyOrPoints(g_DTD.tp3RDistPoints),
                                         g_DTD.recommendedLot);
         return;
      }
   }

   // =========================================================================
   // 4. SMART 3-REGIME CONTEXT ARBITRATOR (ประสานสมองกล SW / ขาขึ้น / ขาลง)
   // =========================================================================
   double zoneTol = (g_Asset.assetType == ASSET_CRYPTO) ? (curBid * 0.00035) : (g_Asset.assetType == ASSET_GOLD ? (60.0 * _Point * tfMultiplier) : (20.0 * _Point * tfMultiplier));
   double distDZ = 9999999.0;
   double distSZ = 9999999.0;
   for(int z = 0; z < g_ZoneCount; z++)
   {
      if(!g_Zones[z].isActive) continue;
      if(g_Zones[z].isDemand)
      {
         if(curBid >= g_Zones[z].low && curBid <= g_Zones[z].high) distDZ = 0.0;
         else if(curBid > g_Zones[z].high) { double d = curBid - g_Zones[z].high; if(d < distDZ) distDZ = d; }
      }
      else
      {
         if(curAsk >= g_Zones[z].low && curAsk <= g_Zones[z].high) distSZ = 0.0;
         else if(curAsk < g_Zones[z].low) { double d = g_Zones[z].low - curAsk; if(d < distSZ) distSZ = d; }
      }
   }

   bool inDZ = (distDZ <= zoneTol);
   bool inSZ = (distSZ <= zoneTol);
   if(distDZ == 0.0 && distSZ > 0.0) inSZ = false;
   if(distSZ == 0.0 && distDZ > 0.0) inDZ = false;

   int htfDir = GetHTF_TrendDirection(scanTF);
   bool htfAllowsBuy  = (!InpRequireM15_Alignment || htfDir >= 0 || buyConfirmed);
   bool htfAllowsSell = (!InpRequireM15_Alignment || htfDir <= 0 || sellConfirmed);

   // ลำดับความสำคัญแบบ Realtime: หากแท่งเทียนเพิ่งเกิดสัญญาณกลืนกิน CF ฝั่งไหน ให้ยึดฝั่งนั้นทันที 100%!
   int activeSide = 0;
   if(buyConfirmed && !sellConfirmed)
      activeSide = 1;
   else if(sellConfirmed && !buyConfirmed)
      activeSide = -1;
   else if(g_DTD.swBoxActive && g_DTD.swBreakState == 1)
      activeSide = 1;
   else if(g_DTD.swBoxActive && g_DTD.swBreakState == -1)
      activeSide = -1;
   else if(g_DTD.marketRegime == 1)
      activeSide = 1;
   else if(g_DTD.marketRegime == -1)
      activeSide = -1;
   else if(inDZ || (g_IsFakeoutTrap && g_FakeoutSide == 1))
      activeSide = 1;
   else if(inSZ || (g_IsFakeoutTrap && g_FakeoutSide == -1))
      activeSide = -1;
   else if(distDZ < distSZ)
      activeSide = 1;
   else if(distSZ < distDZ)
      activeSide = -1;
   else
      activeSide = (g_MarketBiasBuyPct >= 50) ? 1 : -1;

   g_DTD.setupSide = activeSide;

   // =========================================================================
   // 5. ซิงค์ค่าของฝั่งที่แอคทีฟเข้าสู่โครงสร้างหลัก g_DTD
   // =========================================================================
   if(activeSide == 1)
   {
      g_DTD.hasM1Shift        = buyHasShift;
      g_DTD.m1StructDir       = 1;
      g_DTD.m1ShiftBreakPrice = highestHigh;
      g_DTD.m1ShiftTime       = ratesDTD[highestBar].time;
      g_DTD.shortestWickPrice = buyTargetWickPrice;
      g_DTD.shortestWickTime  = buyTargetWickTime;
      g_DTD.isEngulfConfirmed = buyConfirmed;
      g_DTD.confirmEntryPrice = buyEntryPrice;
      g_DTD.confirmSLPrice    = buySLPrice;
      g_DTD.slDistPoints      = buySLDist;
      g_DTD.confirmTP1RPrice  = buyTP1RPrice;
      g_DTD.confirmTP2RPrice  = buyTP2RPrice;
      g_DTD.confirmTP3RPrice  = buyTP3RPrice;
      g_DTD.tp1RDistPoints    = buySLDist * 1.0;
      g_DTD.tp2RDistPoints    = buySLDist * 2.0;
      g_DTD.tp3RDistPoints    = (buyTP3RPrice > buyEntryPrice) ? ((buyTP3RPrice - buyEntryPrice) / _Point) : (buySLDist * InpDTD_TargetRR);
      g_DTD.recommendedLot    = buyRecommendedLot;
      g_DTD.retestBarTime     = lowestPullbackTime;
      g_DTD.retestBarPrice    = lowestPullbackPrice;
      g_DTD.confirmBarTime    = buyConfirmBarTime;
      g_DTD.confirmBarPrice   = buyConfirmBarPrice;
      g_DTD.lqLinePrice       = g_DTD.m1SwingLowPrice;
      g_DTD.lqLineTime        = g_DTD.m1SwingLowTime;
      g_DTD.lqIsSwept         = (lowestPullbackPrice <= g_DTD.m1SwingLowPrice || ratesDTD[0].low <= g_DTD.m1SwingLowPrice);

      if(buyConfirmed)
      {
         if(!g_DTD.isLatched && htfAllowsBuy)
         {
            g_DTD.isLatched           = true;
            g_DTD.latchedSide         = 1;
            g_DTD.latchedTime         = buyConfirmBarTime;
            g_DTD.latchedEntryPrice   = buyEntryPrice;
            g_DTD.latchedSLPrice      = buySLPrice;
            g_DTD.latchedTP1Price     = buyTP1RPrice;
            g_DTD.latchedTP2Price     = buyTP2RPrice;
            g_DTD.latchedTP3Price     = buyTP3RPrice;
            g_DTD.latchedSLDist       = buySLDist;
            g_DTD.latchedLot          = buyRecommendedLot;
            g_DTD.latchedShortestWick = buyTargetWickPrice;
            g_DTD.latchedRetestTime   = g_DTD.retestBarTime;
            g_DTD.latchedRetestPrice  = g_DTD.retestBarPrice;
            g_DTD.latchedConfirmTime  = g_DTD.confirmBarTime;
            g_DTD.latchedConfirmPrice = g_DTD.confirmBarPrice;
            g_DTD.latchedLQPrice      = g_DTD.lqLinePrice;
            g_DTD.latchedLQTime       = g_DTD.lqLineTime;
            g_DTD.latchedLQSwept      = g_DTD.lqIsSwept;
         }
         g_DTD.statusText  = StringFormat("🎯 CF %s: 🟢 จบกลืนกิน BUY สำเร็จ! (1R/2R/3R พร้อมลั่นไก)", g_DTD.tfName);
         g_DTD.statusColor = C'0,255,136';
      }
      else if(buyIsTestingNow)
      {
         g_DTD.statusText  = StringFormat("⚡ CF %s: 🟢 แท่งสดกำลังเบรกไส้ %s (รอจบแท่งคอนเฟิร์ม BUY)", g_DTD.tfName, DoubleToString(buyTargetWickPrice, _Digits));
         g_DTD.statusColor = clrOrange;
      }
      else
      {
         g_DTD.statusText  = StringFormat("🎯 CF %s: 🟢 รอแท่งปิดกลืนกินเหนือไส้ %s เพื่อ BUY", g_DTD.tfName, DoubleToString(buyTargetWickPrice, _Digits));
         g_DTD.statusColor = clrGold;
      }
   }
   else
   {
      g_DTD.hasM1Shift        = sellHasShift;
      g_DTD.m1StructDir       = -1;
      g_DTD.m1ShiftBreakPrice = lowestLow;
      g_DTD.m1ShiftTime       = ratesDTD[lowestBar].time;
      g_DTD.shortestWickPrice = sellTargetWickPrice;
      g_DTD.shortestWickTime  = sellTargetWickTime;
      g_DTD.isEngulfConfirmed = sellConfirmed;
      g_DTD.confirmEntryPrice = sellEntryPrice;
      g_DTD.confirmSLPrice    = sellSLPrice;
      g_DTD.slDistPoints      = sellSLDist;
      g_DTD.confirmTP1RPrice  = sellTP1RPrice;
      g_DTD.confirmTP2RPrice  = sellTP2RPrice;
      g_DTD.confirmTP3RPrice  = sellTP3RPrice;
      g_DTD.tp1RDistPoints    = sellSLDist * 1.0;
      g_DTD.tp2RDistPoints    = sellSLDist * 2.0;
      g_DTD.tp3RDistPoints    = (sellTP3RPrice < sellEntryPrice) ? ((sellEntryPrice - sellTP3RPrice) / _Point) : (sellSLDist * InpDTD_TargetRR);
      g_DTD.recommendedLot    = sellRecommendedLot;
      g_DTD.retestBarTime     = highestPullbackTime;
      g_DTD.retestBarPrice    = highestPullbackPrice;
      g_DTD.confirmBarTime    = sellConfirmBarTime;
      g_DTD.confirmBarPrice   = sellConfirmBarPrice;
      g_DTD.lqLinePrice       = g_DTD.m1SwingHighPrice;
      g_DTD.lqLineTime        = g_DTD.m1SwingHighTime;
      g_DTD.lqIsSwept         = (highestPullbackPrice >= g_DTD.m1SwingHighPrice || ratesDTD[0].high >= g_DTD.m1SwingHighPrice);

      if(sellConfirmed)
      {
         if(!g_DTD.isLatched && htfAllowsSell)
         {
            g_DTD.isLatched           = true;
            g_DTD.latchedSide         = -1;
            g_DTD.latchedTime         = sellConfirmBarTime;
            g_DTD.latchedEntryPrice   = sellEntryPrice;
            g_DTD.latchedSLPrice      = sellSLPrice;
            g_DTD.latchedTP1Price     = sellTP1RPrice;
            g_DTD.latchedTP2Price     = sellTP2RPrice;
            g_DTD.latchedTP3Price     = sellTP3RPrice;
            g_DTD.latchedSLDist       = sellSLDist;
            g_DTD.latchedLot          = sellRecommendedLot;
            g_DTD.latchedShortestWick = sellTargetWickPrice;
            g_DTD.latchedRetestTime   = g_DTD.retestBarTime;
            g_DTD.latchedRetestPrice  = g_DTD.retestBarPrice;
            g_DTD.latchedConfirmTime  = g_DTD.confirmBarTime;
            g_DTD.latchedConfirmPrice = g_DTD.confirmBarPrice;
            g_DTD.latchedLQPrice      = g_DTD.lqLinePrice;
            g_DTD.latchedLQTime       = g_DTD.lqLineTime;
            g_DTD.latchedLQSwept      = g_DTD.lqIsSwept;
         }
         g_DTD.statusText  = StringFormat("🎯 CF %s: 🔴 จบกลืนกิน SELL สำเร็จ! (1R/2R/3R พร้อมลั่นไก)", g_DTD.tfName);
         g_DTD.statusColor = C'255,80,90';
      }
      else if(sellIsTestingNow)
      {
         g_DTD.statusText  = StringFormat("⚡ CF %s: 🔴 แท่งสดกำลังทุบไส้ %s (รอจบแท่งคอนเฟิร์ม SELL)", g_DTD.tfName, DoubleToString(sellTargetWickPrice, _Digits));
         g_DTD.statusColor = clrOrange;
      }
      else
      {
         g_DTD.statusText  = StringFormat("🎯 CF %s: 🔴 รอแท่งปิดกลืนกินใต้ไส้ %s เพื่อ SELL", g_DTD.tfName, DoubleToString(sellTargetWickPrice, _Digits));
         g_DTD.statusColor = clrGold;
      }
   }

   g_DTD.mmPlanText = StringFormat("💵 แผน MM (1R/2R/3R): SL %s | TP1 %s | TP2 %s | TP3 %s | Lot: %.2f",
                                   FormatMoneyOrPoints(g_DTD.slDistPoints),
                                   FormatMoneyOrPoints(g_DTD.tp1RDistPoints),
                                   FormatMoneyOrPoints(g_DTD.tp2RDistPoints),
                                   FormatMoneyOrPoints(g_DTD.tp3RDistPoints),
                                   g_DTD.recommendedLot);
}

//| 14F. DRAW DTD M1 VISUALS (AJARN DEJ M1 SETUP & 1R/2R/3R TIERS)   |
//+------------------------------------------------------------------+
void DrawDTD_M1_Visuals()
{
   ObjectDelete(0, GUI_PREFIX + "DTD_LBL_UP_START");
   ObjectDelete(0, GUI_PREFIX + "DTD_LBL_DN_START");

   if(!InpUseDTD_CF_M1 || !InpDrawDTD_M1_Visuals || g_DTD.shortestWickPrice <= 0.0)
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_UP");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_UP");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_DOWN");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_DOWN");
      for(int k = 0; k < MAX_DTD_M1_SWINGS; k++)
      {
         ObjectDelete(0, GUI_PREFIX + "DTD_ZIGZAG_" + IntegerToString(k));
         ObjectDelete(0, GUI_PREFIX + "DTD_SWING_PT_" + IntegerToString(k));
      }
      ObjectDelete(0, GUI_PREFIX + "DTD_BREAK_UP");
      ObjectDelete(0, GUI_PREFIX + "DTD_BREAK_DN");
      ObjectDelete(0, GUI_PREFIX + "DTD_MARK_ENTRY");
      ObjectDelete(0, GUI_PREFIX + "DTD_WICK_LINE");
      ObjectDelete(0, GUI_PREFIX + "DTD_WICK_LBL");
      ObjectDelete(0, GUI_PREFIX + "DTD_PILL_WICK_BG");
      ObjectDelete(0, GUI_PREFIX + "DTD_PILL_WICK_TXT");
      ObjectDelete(0, GUI_PREFIX + "DTD_ARROW_RETEST");
      ObjectDelete(0, GUI_PREFIX + "DTD_STEM_RETEST");
      ObjectDelete(0, GUI_PREFIX + "DTD_BADGE_RETEST");
      ObjectDelete(0, GUI_PREFIX + "DTD_ARROW_CF");
      ObjectDelete(0, GUI_PREFIX + "DTD_STEM_CF");
      ObjectDelete(0, GUI_PREFIX + "DTD_BADGE_CF");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_BOX");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_HIGH_LINE");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_HIGH_LBL");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_LOW_LINE");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_LOW_LBL");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_MID_LINE");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_MID_LBL");
      ObjectDelete(0, GUI_PREFIX + "DTD_BOX_SL");
      ObjectDelete(0, GUI_PREFIX + "DTD_BOX_TP");
      ObjectDelete(0, GUI_PREFIX + "DTD_TP_TAG");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_TP1R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_TP1R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_TP2R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_TP2R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_TP3R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_TP3R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_SL");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_SL");
      return;
   }

   int tfSec = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   int forwardBars = 25;
   if(_Period == PERIOD_M1)       forwardBars = 35;
   else if(_Period <= PERIOD_M5)  forwardBars = 22;
   else if(_Period <= PERIOD_M15) forwardBars = 18;
   else if(_Period <= PERIOD_M30) forwardBars = 14;
   else                           forwardBars = 10;
   double tfMultiplier = 1.0;
   if(_Period == PERIOD_M5)       tfMultiplier = 1.5;
   else if(_Period == PERIOD_M15) tfMultiplier = 2.0;
   else if(_Period >= PERIOD_M30) tfMultiplier = 3.0;

   datetime tStart   = (g_DTD.isLatched && g_DTD.latchedTime > 0) ? g_DTD.latchedTime : ((g_DTD.shortestWickTime > 0) ? g_DTD.shortestWickTime : (TimeCurrent() - (tfSec * 4)));
   datetime tEnd     = TimeCurrent() + (tfSec * forwardBars);
   datetime tWickLbl = tEnd;
   string   tfTag    = (g_DTD.tfName != "") ? StringFormat(" [%s]", g_DTD.tfName) : "";

   // 0. วาดกรอบคุม High และ Low อัตโนมัติเมื่อตรวจพบตลาด Sideway (SW RANGE BOX - รองรับทุก TF)
   if(InpDrawDTD_SW_Box && g_DTD.swBoxActive && g_DTD.swBoxHigh > g_DTD.swBoxLow)
   {
      string swBox      = GUI_PREFIX + "DTD_SW_BOX";
      string swHighLine = GUI_PREFIX + "DTD_SW_HIGH_LINE";
      string swHighLbl  = GUI_PREFIX + "DTD_SW_HIGH_LBL";
      string swLowLine  = GUI_PREFIX + "DTD_SW_LOW_LINE";
      string swLowLbl   = GUI_PREFIX + "DTD_SW_LOW_LBL";
      string swMidLine  = GUI_PREFIX + "DTD_SW_MID_LINE";
      string swMidLbl   = GUI_PREFIX + "DTD_SW_MID_LBL";

      datetime tSWStart = (g_DTD.swBoxStartTime > 0) ? g_DTD.swBoxStartTime : (TimeCurrent() - (tfSec * 24));
      datetime tSWEnd   = TimeCurrent() + (tfSec * 8);
      datetime tSWMid   = tSWStart + (datetime)((tSWEnd - tSWStart) * 0.45);

      color boxCol = C'255,200,50'; // สีทองอำพันสำหรับกรอบ SW
      if(g_DTD.swBreakState == 1)       boxCol = C'0,255,150'; // เขียวเมื่อเบรกขึ้นจริง
      else if(g_DTD.swBreakState == -1) boxCol = C'255,90,110'; // แดงเมื่อหลุดลงจริง

      if(ObjectFind(0, swBox) < 0)
         ObjectCreate(0, swBox, OBJ_RECTANGLE, 0, tSWStart, g_DTD.swBoxHigh, tSWEnd, g_DTD.swBoxLow);
      ObjectSetInteger(0, swBox, OBJPROP_TIME, 0, tSWStart);
      ObjectSetDouble(0, swBox, OBJPROP_PRICE, 0, g_DTD.swBoxHigh);
      ObjectSetInteger(0, swBox, OBJPROP_TIME, 1, tSWEnd);
      ObjectSetDouble(0, swBox, OBJPROP_PRICE, 1, g_DTD.swBoxLow);
      ObjectSetInteger(0, swBox, OBJPROP_COLOR, boxCol);
      ObjectSetInteger(0, swBox, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, swBox, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, swBox, OBJPROP_FILL, false);
      ObjectSetInteger(0, swBox, OBJPROP_BACK, false);

      string txtSWHigh = StringFormat("📦 กรอบบน SW HIGH [%s]: %s (รอเบรกขึ้น + CF)", g_DTD.tfName, DoubleToString(g_DTD.swBoxHigh, _Digits));
      if(g_DTD.swBreakState == 1)
         txtSWHigh = StringFormat("🚀 เบรกกรอบบน SW HIGH [%s]: %s สำเร็จ! ➔ รอย่อ RETEST + CF BUY", g_DTD.tfName, DoubleToString(g_DTD.swBoxHigh, _Digits));
      else if(g_DTD.swBreakState == 2)
         txtSWHigh = StringFormat("⚠️ ระวังเบรกหลอก (Sweep SW HIGH [%s]: %s)! ห้ามไล่ BUY", g_DTD.tfName, DoubleToString(g_DTD.swBoxHigh, _Digits));

      datetime tSWLblAnchor = tSWStart + (datetime)(tfSec * 1);
      double swHighBase = g_DTD.swBoxHigh;
      if(g_DTD.m1SwingHighPrice > 0.0 && MathAbs(g_DTD.m1SwingHighPrice - g_DTD.swBoxHigh) <= g_DTD.avgBarRange * 0.85)
         swHighBase = MathMax(g_DTD.swBoxHigh, g_DTD.m1SwingHighPrice);
      double swHighLblPrice = swHighBase + (g_DTD.avgBarRange * 0.35);

      if(ObjectFind(0, swHighLbl) < 0)
         ObjectCreate(0, swHighLbl, OBJ_TEXT, 0, tSWLblAnchor, swHighLblPrice);
      ObjectSetInteger(0, swHighLbl, OBJPROP_TIME, 0, tSWLblAnchor);
      ObjectSetDouble(0, swHighLbl, OBJPROP_PRICE, 0, swHighLblPrice);
      ObjectSetString(0, swHighLbl, OBJPROP_TEXT, txtSWHigh);
      ObjectSetString(0, swHighLbl, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, swHighLbl, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, swHighLbl, OBJPROP_COLOR, (g_DTD.swBreakState == 1 ? C'0,255,150' : clrGold));
      ObjectSetInteger(0, swHighLbl, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, swHighLbl, OBJPROP_BACK, false);

      string txtSWLow = StringFormat("📦 กรอบล่าง SW LOW [%s]: %s (รอหลุดลง + CF)", g_DTD.tfName, DoubleToString(g_DTD.swBoxLow, _Digits));
      if(g_DTD.swBreakState == -1)
         txtSWLow = StringFormat("🚀 หลุดกรอบล่าง SW LOW [%s]: %s สำเร็จ! ➔ รอเด้ง RETEST + CF SELL", g_DTD.tfName, DoubleToString(g_DTD.swBoxLow, _Digits));
      else if(g_DTD.swBreakState == -2)
         txtSWLow = StringFormat("⚠️ ระวังหลุดหลอก (Sweep SW LOW [%s]: %s)! ห้ามไล่ SELL", g_DTD.tfName, DoubleToString(g_DTD.swBoxLow, _Digits));

      double swLowBase = g_DTD.swBoxLow;
      if(g_DTD.m1SwingLowPrice > 0.0 && MathAbs(g_DTD.m1SwingLowPrice - g_DTD.swBoxLow) <= g_DTD.avgBarRange * 0.85)
         swLowBase = MathMin(g_DTD.swBoxLow, g_DTD.m1SwingLowPrice);
      double swLowLblPrice = swLowBase - (g_DTD.avgBarRange * 0.35);

      if(ObjectFind(0, swLowLbl) < 0)
         ObjectCreate(0, swLowLbl, OBJ_TEXT, 0, tSWLblAnchor, swLowLblPrice);
      ObjectSetInteger(0, swLowLbl, OBJPROP_TIME, 0, tSWLblAnchor);
      ObjectSetDouble(0, swLowLbl, OBJPROP_PRICE, 0, swLowLblPrice);
      ObjectSetString(0, swLowLbl, OBJPROP_TEXT, txtSWLow);
      ObjectSetString(0, swLowLbl, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, swLowLbl, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, swLowLbl, OBJPROP_COLOR, (g_DTD.swBreakState == -1 ? C'255,95,115' : clrGold));
      ObjectSetInteger(0, swLowLbl, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, swLowLbl, OBJPROP_BACK, false);

      if(ObjectFind(0, swMidLine) < 0)
         ObjectCreate(0, swMidLine, OBJ_TREND, 0, tSWStart, g_DTD.swBoxMid, tSWEnd, g_DTD.swBoxMid);
      ObjectSetInteger(0, swMidLine, OBJPROP_TIME, 0, tSWStart);
      ObjectSetDouble(0, swMidLine, OBJPROP_PRICE, 0, g_DTD.swBoxMid);
      ObjectSetInteger(0, swMidLine, OBJPROP_TIME, 1, tSWEnd);
      ObjectSetDouble(0, swMidLine, OBJPROP_PRICE, 1, g_DTD.swBoxMid);
      ObjectSetInteger(0, swMidLine, OBJPROP_COLOR, C'180,190,205');
      ObjectSetInteger(0, swMidLine, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, swMidLine, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, swMidLine, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, swMidLine, OBJPROP_BACK, true);
      ObjectDelete(0, swHighLine);
      ObjectDelete(0, swLowLine);
      ObjectDelete(0, swMidLbl);
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_BOX");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_HIGH_LINE");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_HIGH_LBL");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_LOW_LINE");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_LOW_LBL");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_MID_LINE");
      ObjectDelete(0, GUI_PREFIX + "DTD_SW_MID_LBL");
   }

   // 1. เส้นแนวนอนและป้ายภาษาไทย "ขึ้น" (Swing High)
   if(g_DTD.m1SwingHighPrice > 0.0)
   {
      string lineUp = GUI_PREFIX + "DTD_LINE_UP";
      datetime tUpStart = (g_DTD.m1SwingHighTime > 0) ? g_DTD.m1SwingHighTime : (TimeCurrent() - (tfSec * 15));
      if(ObjectFind(0, lineUp) < 0)
         ObjectCreate(0, lineUp, OBJ_TREND, 0, tUpStart, g_DTD.m1SwingHighPrice, tEnd, g_DTD.m1SwingHighPrice);
      ObjectSetInteger(0, lineUp, OBJPROP_TIME, 0, tUpStart);
      ObjectSetDouble(0, lineUp, OBJPROP_PRICE, 0, g_DTD.m1SwingHighPrice);
      ObjectSetInteger(0, lineUp, OBJPROP_TIME, 1, tEnd);
      ObjectSetDouble(0, lineUp, OBJPROP_PRICE, 1, g_DTD.m1SwingHighPrice);
      ObjectSetInteger(0, lineUp, OBJPROP_COLOR, InpColorDTD_Up);
      ObjectSetInteger(0, lineUp, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lineUp, OBJPROP_WIDTH, InpDTD_LineThickness);
      ObjectSetInteger(0, lineUp, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineUp, OBJPROP_BACK, false);

      string lblUp = GUI_PREFIX + "DTD_LBL_UP";
      string txtUp = StringFormat("▲ ขึ้น%s (%s)", tfTag, DoubleToString(g_DTD.m1SwingHighPrice, _Digits));
      double upResolvedPrice = ResolveRightChartLabelPrice(g_DTD.m1SwingHighPrice, 1);
      if(ObjectFind(0, lblUp) < 0)
         ObjectCreate(0, lblUp, OBJ_TEXT, 0, tEnd, upResolvedPrice);
      ObjectSetInteger(0, lblUp, OBJPROP_TIME, 0, tEnd);
      ObjectSetDouble(0, lblUp, OBJPROP_PRICE, 0, upResolvedPrice);
      ObjectSetString(0, lblUp, OBJPROP_TEXT, txtUp);
      ObjectSetString(0, lblUp, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, lblUp, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, lblUp, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, lblUp, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
      ObjectSetInteger(0, lblUp, OBJPROP_BACK, false);
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_UP");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_UP");
   }

   // 2. เส้นแนวนอนและป้ายภาษาไทย "ลง" (Swing Low)
   if(g_DTD.m1SwingLowPrice > 0.0)
   {
      string lineDn = GUI_PREFIX + "DTD_LINE_DOWN";
      datetime tDnStart = (g_DTD.m1SwingLowTime > 0) ? g_DTD.m1SwingLowTime : (TimeCurrent() - (tfSec * 15));
      if(ObjectFind(0, lineDn) < 0)
         ObjectCreate(0, lineDn, OBJ_TREND, 0, tDnStart, g_DTD.m1SwingLowPrice, tEnd, g_DTD.m1SwingLowPrice);
      ObjectSetInteger(0, lineDn, OBJPROP_TIME, 0, tDnStart);
      ObjectSetDouble(0, lineDn, OBJPROP_PRICE, 0, g_DTD.m1SwingLowPrice);
      ObjectSetInteger(0, lineDn, OBJPROP_TIME, 1, tEnd);
      ObjectSetDouble(0, lineDn, OBJPROP_PRICE, 1, g_DTD.m1SwingLowPrice);
      ObjectSetInteger(0, lineDn, OBJPROP_COLOR, InpColorDTD_Down);
      ObjectSetInteger(0, lineDn, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lineDn, OBJPROP_WIDTH, InpDTD_LineThickness);
      ObjectSetInteger(0, lineDn, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineDn, OBJPROP_BACK, false);

      string lblDn = GUI_PREFIX + "DTD_LBL_DOWN";
      string txtDn = StringFormat("▼ ลง%s (%s)", tfTag, DoubleToString(g_DTD.m1SwingLowPrice, _Digits));
      double dnResolvedPrice = ResolveRightChartLabelPrice(g_DTD.m1SwingLowPrice, -1);
      if(ObjectFind(0, lblDn) < 0)
         ObjectCreate(0, lblDn, OBJ_TEXT, 0, tEnd, dnResolvedPrice);
      ObjectSetInteger(0, lblDn, OBJPROP_TIME, 0, tEnd);
      ObjectSetDouble(0, lblDn, OBJPROP_PRICE, 0, dnResolvedPrice);
      ObjectSetString(0, lblDn, OBJPROP_TEXT, txtDn);
      ObjectSetString(0, lblDn, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, lblDn, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, lblDn, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, lblDn, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, lblDn, OBJPROP_BACK, false);
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_DOWN");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_DOWN");
   }

   // 2A. เส้นประและป้าย "• • • • LQ • • • •" สีขาวสว่างบริสุทธิ์
   if(InpDrawDTD_LQ_Line && g_DTD.lqLinePrice > 0.0)
   {
      string lineLQ = GUI_PREFIX + "DTD_LINE_LQ";
      datetime tLQStart = (g_DTD.lqLineTime > 0) ? g_DTD.lqLineTime : (TimeCurrent() - (tfSec * 20));
      if(ObjectFind(0, lineLQ) < 0)
         ObjectCreate(0, lineLQ, OBJ_TREND, 0, tLQStart, g_DTD.lqLinePrice, tEnd, g_DTD.lqLinePrice);
      ObjectSetInteger(0, lineLQ, OBJPROP_TIME, 0, tLQStart);
      ObjectSetDouble(0, lineLQ, OBJPROP_PRICE, 0, g_DTD.lqLinePrice);
      ObjectSetInteger(0, lineLQ, OBJPROP_TIME, 1, tEnd);
      ObjectSetDouble(0, lineLQ, OBJPROP_PRICE, 1, g_DTD.lqLinePrice);
      ObjectSetInteger(0, lineLQ, OBJPROP_COLOR, C'255,100,120');
      ObjectSetInteger(0, lineLQ, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, lineLQ, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lineLQ, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineLQ, OBJPROP_BACK, false);

      string lblLQ = GUI_PREFIX + "DTD_LBL_LQ";
      datetime tLQLbl = TimeCurrent() + (datetime)(tfSec * 2);
      string txtLQ = g_DTD.lqIsSwept ? "• • LQ (SWEPT ⚡) • •" : "• • • LQ • • •";
      double lqRawPrice = (g_DTD.setupSide == 1) ? (g_DTD.lqLinePrice - (12.0 * _Point * tfMultiplier)) : (g_DTD.lqLinePrice + (12.0 * _Point * tfMultiplier));
      double lqLblPrice = ResolveRightChartLabelPrice(lqRawPrice, (g_DTD.setupSide == 1 ? -1 : 1));

      if(ObjectFind(0, lblLQ) < 0)
         ObjectCreate(0, lblLQ, OBJ_TEXT, 0, tLQLbl, lqLblPrice);
      ObjectSetInteger(0, lblLQ, OBJPROP_TIME, 0, tLQLbl);
      ObjectSetDouble(0, lblLQ, OBJPROP_PRICE, 0, lqLblPrice);
      ObjectSetString(0, lblLQ, OBJPROP_TEXT, txtLQ);
      ObjectSetString(0, lblLQ, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, lblLQ, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, lblLQ, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, lblLQ, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, lblLQ, OBJPROP_BACK, false);
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_LQ");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_LQ");
   }

   // 2B. เส้นโครงสร้างสวิงซิกแซก
   for(int k = 0; k < MAX_DTD_M1_SWINGS; k++)
   {
      string zgLine = GUI_PREFIX + "DTD_ZIGZAG_" + IntegerToString(k);
      string zgDot  = GUI_PREFIX + "DTD_SWING_PT_" + IntegerToString(k);
      ObjectDelete(0, zgDot);
      if(!InpDrawDTD_StructureLegs || k >= g_DTD.m1SwingCount - 1)
      {
         ObjectDelete(0, zgLine);
         continue;
      }
      datetime t1 = g_DTD.m1Swings[k].time;
      double   p1 = g_DTD.m1Swings[k].price;
      datetime t2 = g_DTD.m1Swings[k+1].time;
      double   p2 = g_DTD.m1Swings[k+1].price;
      if(t1 <= 0 || t2 <= 0 || p1 <= 0.0 || p2 <= 0.0) { ObjectDelete(0, zgLine); continue; }
      if(ObjectFind(0, zgLine) < 0)
         ObjectCreate(0, zgLine, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, zgLine, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0, zgLine, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(0, zgLine, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(0, zgLine, OBJPROP_PRICE, 1, p2);
      ObjectSetInteger(0, zgLine, OBJPROP_COLOR, clrWhiteSmoke);
      ObjectSetInteger(0, zgLine, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, zgLine, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, zgLine, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, zgLine, OBJPROP_BACK, false);
   }

   ObjectDelete(0, GUI_PREFIX + "DTD_BREAK_UP");
   ObjectDelete(0, GUI_PREFIX + "DTD_BREAK_DN");

   // 3. เส้นประแนวนอนเชื่อมจากแท่ง 1.RETEST ➔ แท่ง 2.CF ➔ จุดดักย่อ BUY / ดักเด้ง SELL
   string wickLine = GUI_PREFIX + "DTD_WICK_LINE";
   bool   isBuyWick = (g_DTD.setupSide == 1);
   bool   isCFDone  = (g_DTD.isEngulfConfirmed || g_DTD.isLatched);
   color  wickCol   = isCFDone ? (isBuyWick ? C'0,255,150' : C'255,85,105') : clrGold;
   datetime tWickLineStart = (g_DTD.retestBarTime > 0) ? g_DTD.retestBarTime : tStart;
   if(ObjectFind(0, wickLine) < 0)
      ObjectCreate(0, wickLine, OBJ_TREND, 0, tWickLineStart, g_DTD.shortestWickPrice, tEnd, g_DTD.shortestWickPrice);
   ObjectSetInteger(0, wickLine, OBJPROP_TIME, 0, tWickLineStart);
   ObjectSetDouble(0, wickLine, OBJPROP_PRICE, 0, g_DTD.shortestWickPrice);
   ObjectSetInteger(0, wickLine, OBJPROP_TIME, 1, tEnd);
   ObjectSetDouble(0, wickLine, OBJPROP_PRICE, 1, g_DTD.shortestWickPrice);
   ObjectSetInteger(0, wickLine, OBJPROP_COLOR, wickCol);
   ObjectSetInteger(0, wickLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, wickLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, wickLine, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, wickLine, OBJPROP_BACK, false);

   // 4. ป้ายไฮไลต์ทึบแสงบอก "แนว RETEST+CF (จุดดักย่อ BUY / เด้ง SELL)" วางในพื้นที่ว่างด้านขวาหลังแท่งปัจจุบัน ไม่บังแท่งเทียน 100%
   ObjectDelete(0, GUI_PREFIX + "DTD_WICK_LBL");
   string wickPill = GUI_PREFIX + "DTD_PILL_WICK";
   string lblTxt   = "";
   if(isCFDone)
   {
      lblTxt = isBuyWick
               ? StringFormat("🟢 แนว RETEST+CF [%s]: %s ➔ ย่อใกล้เส้น กด BUY!", g_DTD.tfName, DoubleToString(g_DTD.shortestWickPrice, _Digits))
               : StringFormat("🔴 แนว RETEST+CF [%s]: %s ➔ เด้งใกล้เส้น กด SELL!", g_DTD.tfName, DoubleToString(g_DTD.shortestWickPrice, _Digits));
   }
   else
   {
      lblTxt = isBuyWick
               ? StringFormat("⏳ แนวไส้ RETEST [%s]: %s ➔ รอ 2.CF ปิดเหนือเส้น", g_DTD.tfName, DoubleToString(g_DTD.shortestWickPrice, _Digits))
               : StringFormat("⏳ แนวไส้ RETEST [%s]: %s ➔ รอ 2.CF ปิดใต้เส้น", g_DTD.tfName, DoubleToString(g_DTD.shortestWickPrice, _Digits));
   }
   color wickBgCol     = !isCFDone ? C'145,88,12' : (isBuyWick ? C'10,105,55' : C'135,18,38');
   color wickBorderCol = !isCFDone ? clrGold      : (isBuyWick ? C'0,255,150' : C'255,95,115');
   int wpx = 0, wpy = 0, curBarX = 0, curBarY = 0;
   ChartTimePriceToXY(0, 0, TimeCurrent(), g_DTD.shortestWickPrice, curBarX, curBarY);
   int wickBoxX = -1, wickBoxY = -1, wickPillW = 268, wickPillH = 19;
   if(ChartTimePriceToXY(0, 0, tEnd, g_DTD.shortestWickPrice, wpx, wpy) && wpx > 0 && wpy > 0)
   {
      int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
      int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
      // วางป้ายในโซนพื้นที่ว่างทางขวาของแท่งเทียนปัจจุบันเสมอ (curBarX + 24 px) ไม่ให้ถอยกลับมาบังแท่งเทียน
      int boxX   = (curBarX > 0) ? (curBarX + 24) : (wpx - wickPillW - 4);
      if(chartW > wickPillW + 20)
      {
         if(boxX + wickPillW > chartW - 65) boxX = chartW - 65 - wickPillW;
         if(curBarX > 0 && boxX < curBarX + 10 && curBarX + 10 + wickPillW < chartW - 5)
            boxX = curBarX + 10;
         if(boxX < 6) boxX = 6;
      }
      int boxY = wpy - (wickPillH / 2);
      if(boxY < 4) boxY = 4;
      if(chartH > wickPillH + 10 && boxY + wickPillH > chartH - 4) boxY = chartH - wickPillH - 4;
      wickBoxX = boxX;
      wickBoxY = boxY;

      CreateRect(wickPill + "_BG", boxX, boxY, wickPillW, wickPillH, wickBgCol, wickBorderCol);
      ObjectSetInteger(0, wickPill + "_BG", OBJPROP_ZORDER, 34);
      CreateLabel(wickPill + "_TXT", boxX + 7, boxY + 2, lblTxt, clrWhite, 8, true);
      ObjectSetInteger(0, wickPill + "_TXT", OBJPROP_ZORDER, 39);
   }
   else
   {
      ObjectDelete(0, wickPill + "_BG");
      ObjectDelete(0, wickPill + "_TXT");
   }

   // 4B. ลูกศรชี้เป้า + ก้านชี้หลบกลุ่มแท่งเทียนข้างเคียง (±5 แท่ง) + ป้ายไฮไลต์ขนาดกะทัดรัด ไม่บังเนื้อเทียน 100%
   if(InpDrawDTD_CandleStickers)
   {
      double stemUnit = MathMax(g_DTD.avgBarRange * 0.55, 22.0 * _Point * tfMultiplier);
      bool   isBuyPlan = (g_DTD.setupSide == 1);
      color  planNeonCol = isBuyPlan ? C'0,255,150' : C'255,85,105';
      int    rtBoxX_Saved = -1, rtBoxY_Saved = -1, rtPillW_Saved = 104, rtPillH_Saved = 18;

      // --- แท่งที่ 1: ลูกศร + ก้านชี้ + กล่องไฮไลต์กะทัดรัด 1.RETEST ---
      if(g_DTD.retestBarTime > 0 && g_DTD.retestBarPrice > 0.0)
      {
         string arrowRetest = GUI_PREFIX + "DTD_ARROW_RETEST";
         string stemRetest  = GUI_PREFIX + "DTD_STEM_RETEST";
         string pillRetest  = GUI_PREFIX + "DTD_PILL_RETEST";
         ObjectDelete(0, GUI_PREFIX + "DTD_BADGE_RETEST");

         string arrSym      = isBuyPlan ? "▲" : "▼";
         string txtRetest   = StringFormat("%s 1.RETEST [%s]", arrSym, g_DTD.tfName);
         double rtTipPrice  = g_DTD.retestBarPrice;

         // สแกนหาจุดต่ำสุด/สูงสุดของกลุ่มแท่งเทียนข้างเคียง (±5 แท่ง) เพื่อดันกล่องป้ายออกไปวางในพื้นที่โล่งพ้นแท่งเทียนทั้งหมด
         int rtBarIdx = iBarShift(_Symbol, _Period, g_DTD.retestBarTime, false);
         double localMinLow  = rtTipPrice;
         double localMaxHigh = rtTipPrice;
         if(rtBarIdx >= 0)
         {
            int startB = MathMax(0, rtBarIdx - 5);
            int endB   = rtBarIdx + 5;
            for(int b = startB; b <= endB; b++)
            {
               double bLow  = iLow(_Symbol, _Period, b);
               double bHigh = iHigh(_Symbol, _Period, b);
               if(bLow > 0.0 && bLow < localMinLow)   localMinLow  = bLow;
               if(bHigh > 0.0 && bHigh > localMaxHigh) localMaxHigh = bHigh;
            }
         }

         double rtLblPrice  = isBuyPlan ? (MathMin(rtTipPrice, localMinLow) - stemUnit) : (MathMax(rtTipPrice, localMaxHigh) + stemUnit);
         ENUM_ANCHOR_POINT rtAnc = isBuyPlan ? ANCHOR_UPPER : ANCHOR_LOWER;

         // 1) หัวลูกศรสีเขียวนีออน (BUY) หรือสีแดงสว่าง (SELL) ชี้จี้ที่ปลายไส้แท่ง RETEST
         if(ObjectFind(0, arrowRetest) < 0)
            ObjectCreate(0, arrowRetest, OBJ_TEXT, 0, g_DTD.retestBarTime, rtTipPrice);
         ObjectSetInteger(0, arrowRetest, OBJPROP_TIME, 0, g_DTD.retestBarTime);
         ObjectSetDouble(0, arrowRetest, OBJPROP_PRICE, 0, rtTipPrice);
         ObjectSetString(0, arrowRetest, OBJPROP_TEXT, arrSym);
         ObjectSetString(0, arrowRetest, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, arrowRetest, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, arrowRetest, OBJPROP_COLOR, planNeonCol);
         ObjectSetInteger(0, arrowRetest, OBJPROP_ANCHOR, rtAnc);
         ObjectSetInteger(0, arrowRetest, OBJPROP_BACK, false);

         // 2) เส้นก้านชี้เป้าเชื่อมจากปลายไส้เทียนมายังกล่องป้ายไฮไลต์ในพื้นที่โล่ง
         if(ObjectFind(0, stemRetest) < 0)
            ObjectCreate(0, stemRetest, OBJ_TREND, 0, g_DTD.retestBarTime, rtTipPrice, g_DTD.retestBarTime, rtLblPrice);
         ObjectSetInteger(0, stemRetest, OBJPROP_TIME, 0, g_DTD.retestBarTime);
         ObjectSetDouble(0, stemRetest, OBJPROP_PRICE, 0, rtTipPrice);
         ObjectSetInteger(0, stemRetest, OBJPROP_TIME, 1, g_DTD.retestBarTime);
         ObjectSetDouble(0, stemRetest, OBJPROP_PRICE, 1, rtLblPrice);
         ObjectSetInteger(0, stemRetest, OBJPROP_COLOR, planNeonCol);
         ObjectSetInteger(0, stemRetest, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, stemRetest, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, stemRetest, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, stemRetest, OBJPROP_BACK, false);

         // 3) กล่องไฮไลต์ทึบแสงขนาดกะทัดรัด (กว้างเพียง 104 px ไม่ยื่นบังแท่งข้างเคียง)
         color rtBgCol     = isBuyPlan ? C'8,85,48'    : C'105,16,32';
         color rtBorderCol = isBuyPlan ? C'0,255,150'  : C'255,95,115';
         int px = 0, py = 0;
         if(ChartTimePriceToXY(0, 0, g_DTD.retestBarTime, rtLblPrice, px, py) && px > 0 && py > 0)
         {
            int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
            int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
            int pillW  = 104;
            int pillH  = 18;
            int boxX   = px - (pillW / 2);
            if(chartW > pillW + 20)
            {
               if(boxX < 6) boxX = 6;
               if(boxX + pillW > chartW - 65) boxX = chartW - 65 - pillW;
            }
            int boxY = isBuyPlan ? (py + 2) : (py - pillH - 2);
            // ป้องกันป้าย 1.RETEST ชนกับป้าย แนว RETEST+CF
            if(wickBoxX >= 0 && boxX < wickBoxX + wickPillW && boxX + pillW > wickBoxX && MathAbs(boxY - wickBoxY) < 20)
               boxY = isBuyPlan ? (wickBoxY + wickPillH + 3) : (wickBoxY - pillH - 3);
            if(boxY < 4) boxY = 4;
            if(chartH > pillH + 10 && boxY + pillH > chartH - 4) boxY = chartH - pillH - 4;
            rtBoxX_Saved  = boxX;
            rtBoxY_Saved  = boxY;
            rtPillW_Saved = pillW;
            rtPillH_Saved = pillH;

            CreateRect(pillRetest + "_BG", boxX, boxY, pillW, pillH, rtBgCol, rtBorderCol);
            ObjectSetInteger(0, pillRetest + "_BG", OBJPROP_ZORDER, 35);
            CreateLabel(pillRetest + "_TXT", boxX + 7, boxY + 1, txtRetest, clrWhite, 8, true);
            ObjectSetInteger(0, pillRetest + "_TXT", OBJPROP_ZORDER, 40);
         }
         else
         {
            ObjectDelete(0, pillRetest + "_BG");
            ObjectDelete(0, pillRetest + "_TXT");
         }
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "DTD_ARROW_RETEST");
         ObjectDelete(0, GUI_PREFIX + "DTD_STEM_RETEST");
         ObjectDelete(0, GUI_PREFIX + "DTD_BADGE_RETEST");
         ObjectDelete(0, GUI_PREFIX + "DTD_PILL_RETEST_BG");
         ObjectDelete(0, GUI_PREFIX + "DTD_PILL_RETEST_TXT");
      }

      // --- แท่งที่ 2: ลูกศร + ก้านชี้ + กล่องไฮไลต์กะทัดรัด 2.CF [TF] ★ ---
      if(g_DTD.confirmBarTime > 0 && g_DTD.confirmBarPrice > 0.0)
      {
         string arrowCF = GUI_PREFIX + "DTD_ARROW_CF";
         string stemCF  = GUI_PREFIX + "DTD_STEM_CF";
         string pillCF  = GUI_PREFIX + "DTD_PILL_CF";
         ObjectDelete(0, GUI_PREFIX + "DTD_BADGE_CF");

         bool   isConfirmedCF = (g_DTD.isEngulfConfirmed || g_DTD.isLatched);
         string cfArrSym = isBuyPlan ? "▼" : "▲";
         string txtCF    = isConfirmedCF
                           ? StringFormat("%s 2.CF [%s] ★", cfArrSym, g_DTD.tfName)
                           : StringFormat("%s 2.รอ CF [%s] ⚡", cfArrSym, g_DTD.tfName);
         double cfTipPrice = g_DTD.confirmBarPrice;

         // สแกนหาจุดสูงสุด/ต่ำสุดของกลุ่มแท่งเทียนข้างเคียง (±5 แท่ง) เพื่อดันกล่องป้าย 2.CF ออกไปวางเหนือ/ใต้กลุ่มแท่งเทียน
         int cfBarIdx = iBarShift(_Symbol, _Period, g_DTD.confirmBarTime, false);
         double cfLocalMinLow  = cfTipPrice;
         double cfLocalMaxHigh = cfTipPrice;
         if(cfBarIdx >= 0)
         {
            int startB = MathMax(0, cfBarIdx - 5);
            int endB   = cfBarIdx + 5;
            for(int b = startB; b <= endB; b++)
            {
               double bLow  = iLow(_Symbol, _Period, b);
               double bHigh = iHigh(_Symbol, _Period, b);
               if(bLow > 0.0 && bLow < cfLocalMinLow)   cfLocalMinLow  = bLow;
               if(bHigh > 0.0 && bHigh > cfLocalMaxHigh) cfLocalMaxHigh = bHigh;
            }
         }

         double cfLblPrice = isBuyPlan ? (MathMax(cfTipPrice, cfLocalMaxHigh) + stemUnit) : (MathMin(cfTipPrice, cfLocalMinLow) - stemUnit);
         ENUM_ANCHOR_POINT cfAnc = isBuyPlan ? ANCHOR_LOWER : ANCHOR_UPPER;
         color cfStemCol = isConfirmedCF ? planNeonCol : clrGold;

         // 1) หัวลูกศรชี้จี้ที่ตัวแท่ง CF โดยตรง
         if(ObjectFind(0, arrowCF) < 0)
            ObjectCreate(0, arrowCF, OBJ_TEXT, 0, g_DTD.confirmBarTime, cfTipPrice);
         ObjectSetInteger(0, arrowCF, OBJPROP_TIME, 0, g_DTD.confirmBarTime);
         ObjectSetDouble(0, arrowCF, OBJPROP_PRICE, 0, cfTipPrice);
         ObjectSetString(0, arrowCF, OBJPROP_TEXT, cfArrSym);
         ObjectSetString(0, arrowCF, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, arrowCF, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, arrowCF, OBJPROP_COLOR, cfStemCol);
         ObjectSetInteger(0, arrowCF, OBJPROP_ANCHOR, cfAnc);
         ObjectSetInteger(0, arrowCF, OBJPROP_BACK, false);

         // 2) เส้นก้านชี้เป้าเชื่อมจากตัวแท่ง CF มายังกล่องป้ายไฮไลต์ในพื้นที่โล่ง
         if(ObjectFind(0, stemCF) < 0)
            ObjectCreate(0, stemCF, OBJ_TREND, 0, g_DTD.confirmBarTime, cfTipPrice, g_DTD.confirmBarTime, cfLblPrice);
         ObjectSetInteger(0, stemCF, OBJPROP_TIME, 0, g_DTD.confirmBarTime);
         ObjectSetDouble(0, stemCF, OBJPROP_PRICE, 0, cfTipPrice);
         ObjectSetInteger(0, stemCF, OBJPROP_TIME, 1, g_DTD.confirmBarTime);
         ObjectSetDouble(0, stemCF, OBJPROP_PRICE, 1, cfLblPrice);
         ObjectSetInteger(0, stemCF, OBJPROP_COLOR, cfStemCol);
         ObjectSetInteger(0, stemCF, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, stemCF, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, stemCF, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, stemCF, OBJPROP_BACK, false);

         // 3) กล่องไฮไลต์ทึบแสงขนาดกะทัดรัด 2.CF (กว้าง 104-114 px ไม่บังแท่งเทียน)
         color cfBgCol     = !isConfirmedCF ? C'145,88,12' : (isBuyPlan ? C'14,135,68' : C'168,22,44');
         color cfBorderCol = clrGold;
         int px = 0, py = 0;
         if(ChartTimePriceToXY(0, 0, g_DTD.confirmBarTime, cfLblPrice, px, py) && px > 0 && py > 0)
         {
            int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
            int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
            int pillW  = isConfirmedCF ? 104 : 114;
            int pillH  = 18;
            int boxX   = px - (pillW / 2);
            if(chartW > pillW + 20)
            {
               if(boxX < 6) boxX = 6;
               if(boxX + pillW > chartW - 65) boxX = chartW - 65 - pillW;
            }
            int boxY = isBuyPlan ? (py - pillH - 2) : (py + 2);
            if(wickBoxX >= 0 && boxX < wickBoxX + wickPillW && boxX + pillW > wickBoxX && MathAbs(boxY - wickBoxY) < 20)
               boxY = isBuyPlan ? (wickBoxY - pillH - 3) : (wickBoxY + wickPillH + 3);
            if(rtBoxX_Saved >= 0 && boxX < rtBoxX_Saved + rtPillW_Saved && boxX + pillW > rtBoxX_Saved && MathAbs(boxY - rtBoxY_Saved) < 20)
               boxY = isBuyPlan ? (rtBoxY_Saved - pillH - 3) : (rtBoxY_Saved + rtPillH_Saved + 3);
            if(boxY < 4) boxY = 4;
            if(chartH > pillH + 10 && boxY + pillH > chartH - 4) boxY = chartH - pillH - 4;

            CreateRect(pillCF + "_BG", boxX, boxY, pillW, pillH, cfBgCol, cfBorderCol);
            ObjectSetInteger(0, pillCF + "_BG", OBJPROP_ZORDER, 35);
            CreateLabel(pillCF + "_TXT", boxX + 7, boxY + 1, txtCF, clrWhite, 8, true);
            ObjectSetInteger(0, pillCF + "_TXT", OBJPROP_ZORDER, 40);
         }
         else
         {
            ObjectDelete(0, pillCF + "_BG");
            ObjectDelete(0, pillCF + "_TXT");
         }
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "DTD_ARROW_CF");
         ObjectDelete(0, GUI_PREFIX + "DTD_STEM_CF");
         ObjectDelete(0, GUI_PREFIX + "DTD_BADGE_CF");
         ObjectDelete(0, GUI_PREFIX + "DTD_PILL_CF_BG");
         ObjectDelete(0, GUI_PREFIX + "DTD_PILL_CF_TXT");
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_ARROW_RETEST");
      ObjectDelete(0, GUI_PREFIX + "DTD_STEM_RETEST");
      ObjectDelete(0, GUI_PREFIX + "DTD_BADGE_RETEST");
      ObjectDelete(0, GUI_PREFIX + "DTD_PILL_RETEST_BG");
      ObjectDelete(0, GUI_PREFIX + "DTD_PILL_RETEST_TXT");
      ObjectDelete(0, GUI_PREFIX + "DTD_ARROW_CF");
      ObjectDelete(0, GUI_PREFIX + "DTD_STEM_CF");
      ObjectDelete(0, GUI_PREFIX + "DTD_BADGE_CF");
      ObjectDelete(0, GUI_PREFIX + "DTD_PILL_CF_BG");
      ObjectDelete(0, GUI_PREFIX + "DTD_PILL_CF_TXT");
   }
   // 5. สัญลักษณ์จุดลั่นไก (Entry Tick Mark สไตล์อาจารย์เดช)
   if(g_DTD.isEngulfConfirmed && g_DTD.confirmEntryPrice > 0.0)
   {
      string markName = GUI_PREFIX + "DTD_MARK_ENTRY";
      datetime tMark = (g_DTD.isLatched && g_DTD.latchedTime > 0) ? g_DTD.latchedTime : ((g_DTD.shortestWickTime > 0) ? g_DTD.shortestWickTime : TimeCurrent());
      if(ObjectFind(0, markName) < 0)
      {
         ObjectCreate(0, markName, OBJ_ARROW_CHECK, 0, tMark, g_DTD.confirmEntryPrice);
         ObjectSetInteger(0, markName, OBJPROP_COLOR, (g_DTD.setupSide == 1 ? C'0,255,136' : C'255,80,90'));
         ObjectSetInteger(0, markName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, markName, OBJPROP_ANCHOR, (g_DTD.setupSide == 1 ? ANCHOR_TOP : ANCHOR_BOTTOM));
      }
      else
      {
         ObjectSetInteger(0, markName, OBJPROP_TIME, 0, tMark);
         ObjectSetDouble(0, markName, OBJPROP_PRICE, 0, g_DTD.confirmEntryPrice);
         ObjectSetInteger(0, markName, OBJPROP_COLOR, (g_DTD.setupSide == 1 ? C'0,255,136' : C'255,80,90'));
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_MARK_ENTRY");
   }

   // 6. กล่อง TradingView Style 1R : 3R & เส้น Multi-Tier 1R, 2R, 3R
   if(g_DTD.confirmSLPrice > 0.0 && g_DTD.confirmTP3RPrice > 0.0)
   {
      datetime bStart = (g_DTD.isLatched && g_DTD.latchedTime > 0) ? g_DTD.latchedTime : ((g_DTD.shortestWickTime > 0) ? g_DTD.shortestWickTime : TimeCurrent());
      datetime bEnd   = TimeCurrent() + (tfSec * forwardBars);
      double curBidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(curBidPrice <= 0) curBidPrice = iClose(_Symbol, _Period, 0);

      // กล่อง SL (1R Risk Box) - สีเทาเข้ม Slate Grey สไตล์ TradingView
      string boxSL = GUI_PREFIX + "DTD_BOX_SL";
      double slTop = MathMax(g_DTD.confirmEntryPrice, g_DTD.confirmSLPrice);
      double slBtm = MathMin(g_DTD.confirmEntryPrice, g_DTD.confirmSLPrice);
      color slBorder = InpDTD_TradingViewStyle ? C'65,70,80' : C'180,40,50';
      color slBg     = InpDTD_TradingViewStyle ? C'40,43,50' : C'80,20,25';
      if(ObjectFind(0, boxSL) < 0)
      {
         ObjectCreate(0, boxSL, OBJ_RECTANGLE, 0, bStart, slTop, bEnd, slBtm);
         ObjectSetInteger(0, boxSL, OBJPROP_COLOR, slBorder);
         ObjectSetInteger(0, boxSL, OBJPROP_BGCOLOR, slBg);
         ObjectSetInteger(0, boxSL, OBJPROP_FILL, true);
         ObjectSetInteger(0, boxSL, OBJPROP_BACK, true);
      }
      else
      {
         ObjectSetInteger(0, boxSL, OBJPROP_TIME, 0, bStart);
         ObjectSetDouble(0, boxSL, OBJPROP_PRICE, 0, slTop);
         ObjectSetInteger(0, boxSL, OBJPROP_TIME, 1, bEnd);
         ObjectSetDouble(0, boxSL, OBJPROP_PRICE, 1, slBtm);
         ObjectSetInteger(0, boxSL, OBJPROP_COLOR, slBorder);
         ObjectSetInteger(0, boxSL, OBJPROP_BGCOLOR, slBg);
      }

      // กล่อง TP (3R Reward Box) - สีฟ้าซอฟต์ Soft Navy Blue สไตล์ TradingView
      string boxTP = GUI_PREFIX + "DTD_BOX_TP";
      double tpTop = MathMax(g_DTD.confirmEntryPrice, g_DTD.confirmTP3RPrice);
      double tpBtm = MathMin(g_DTD.confirmEntryPrice, g_DTD.confirmTP3RPrice);
      color tpBorder = InpDTD_TradingViewStyle ? C'40,90,160' : C'30,140,80';
      color tpBg     = InpDTD_TradingViewStyle ? C'25,55,100' : C'15,60,35';
      if(ObjectFind(0, boxTP) < 0)
      {
         ObjectCreate(0, boxTP, OBJ_RECTANGLE, 0, bStart, tpTop, bEnd, tpBtm);
         ObjectSetInteger(0, boxTP, OBJPROP_COLOR, tpBorder);
         ObjectSetInteger(0, boxTP, OBJPROP_BGCOLOR, tpBg);
         ObjectSetInteger(0, boxTP, OBJPROP_FILL, true);
         ObjectSetInteger(0, boxTP, OBJPROP_BACK, true);
      }
      else
      {
         ObjectSetInteger(0, boxTP, OBJPROP_TIME, 0, bStart);
         ObjectSetDouble(0, boxTP, OBJPROP_PRICE, 0, tpTop);
         ObjectSetInteger(0, boxTP, OBJPROP_TIME, 1, bEnd);
         ObjectSetDouble(0, boxTP, OBJPROP_PRICE, 1, tpBtm);
         ObjectSetInteger(0, boxTP, OBJPROP_COLOR, tpBorder);
         ObjectSetInteger(0, boxTP, OBJPROP_BGCOLOR, tpBg);
      }

      // ป้ายกำกับกล่อง TP
      string tpTag = GUI_PREFIX + "DTD_TP_TAG";
      if(!InpDTD_TradingViewStyle)
      {
         double tagPrice = (tpTop + tpBtm) * 0.50;
         datetime tagTime = bStart + (datetime)(tfSec * 1);
         if(ObjectFind(0, tpTag) < 0)
         {
            ObjectCreate(0, tpTag, OBJ_TEXT, 0, tagTime, tagPrice);
            ObjectSetString(0, tpTag, OBJPROP_TEXT, " 🎯 โซนเป้ากำไร 1:3R (REWARD) ");
            ObjectSetString(0, tpTag, OBJPROP_FONT, "Segoe UI Semibold");
            ObjectSetInteger(0, tpTag, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, tpTag, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, tpTag, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, tpTag, OBJPROP_BACK, false);
         }
         else
         {
            ObjectSetInteger(0, tpTag, OBJPROP_TIME, 0, tagTime);
            ObjectSetDouble(0, tpTag, OBJPROP_PRICE, 0, tagPrice);
            ObjectSetString(0, tpTag, OBJPROP_TEXT, " 🎯 โซนเป้ากำไร 1:3R (REWARD) ");
            ObjectSetInteger(0, tpTag, OBJPROP_COLOR, clrWhite);
         }
      }
      else
      {
         ObjectDelete(0, tpTag);
      }

      double chartPMax = ChartGetDouble(0, CHART_PRICE_MAX, 0);
      double chartPMin = ChartGetDouble(0, CHART_PRICE_MIN, 0);
      double vpSep     = (chartPMax > chartPMin) ? ((chartPMax - chartPMin) * 0.022) : (50.0 * _Point);

      // เส้น & ป้าย TP 1R (1:1) - ซ่อนในโหมด TradingView สไตล์ อ.เดช
      string lineTP1 = GUI_PREFIX + "DTD_LINE_TP1R";
      string lblTP1  = GUI_PREFIX + "DTD_LBL_TP1R";
      if(!InpDTD_TradingViewStyle && g_DTD.confirmTP1RPrice > 0.0)
      {
         if(ObjectFind(0, lineTP1) < 0)
         {
            ObjectCreate(0, lineTP1, OBJ_TREND, 0, bStart, g_DTD.confirmTP1RPrice, bEnd, g_DTD.confirmTP1RPrice);
            ObjectSetInteger(0, lineTP1, OBJPROP_COLOR, C'80,240,170');
            ObjectSetInteger(0, lineTP1, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, lineTP1, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lineTP1, OBJPROP_RAY_RIGHT, false);
         }
         else
         {
            ObjectSetInteger(0, lineTP1, OBJPROP_TIME, 0, bStart);
            ObjectSetDouble(0, lineTP1, OBJPROP_PRICE, 0, g_DTD.confirmTP1RPrice);
            ObjectSetInteger(0, lineTP1, OBJPROP_TIME, 1, bEnd);
            ObjectSetDouble(0, lineTP1, OBJPROP_PRICE, 1, g_DTD.confirmTP1RPrice);
         }
         double tp1SetupDist = (g_DTD.tp1RDistPoints > 0.0) ? g_DTD.tp1RDistPoints : (MathAbs(g_DTD.confirmTP1RPrice - g_DTD.confirmEntryPrice) / _Point);
         double tp1LblPrice  = ResolveRightChartLabelPrice(g_DTD.confirmTP1RPrice, 1);
         string tp1Txt       = StringFormat(" 🛡️ TP 1R (1:1): %s (+%s) ", DoubleToString(g_DTD.confirmTP1RPrice, _Digits), FormatMoneyOrPoints(tp1SetupDist));
         if(ObjectFind(0, lblTP1) < 0)
         {
            ObjectCreate(0, lblTP1, OBJ_TEXT, 0, bEnd, tp1LblPrice);
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
            ObjectSetDouble(0, lblTP1, OBJPROP_PRICE, 0, tp1LblPrice);
            ObjectSetString(0, lblTP1, OBJPROP_TEXT, tp1Txt);
            ObjectSetInteger(0, lblTP1, OBJPROP_COLOR, clrWhite);
            ObjectSetString(0, lblTP1, OBJPROP_FONT, "Segoe UI Black");
         }
      }
      else
      {
         ObjectDelete(0, lineTP1);
         ObjectDelete(0, lblTP1);
      }

      // เส้น & ป้าย TP 2R (1:2) - สไตล์ อ.เดช: เส้นแดงบาง ป้าย "TP 1 2R"
      if(g_DTD.confirmTP2RPrice > 0.0)
      {
         string lineTP2 = GUI_PREFIX + "DTD_LINE_TP2R";
         color tp2Col = InpDTD_TradingViewStyle ? C'255,100,120' : C'70,235,160';
         if(ObjectFind(0, lineTP2) < 0)
         {
            ObjectCreate(0, lineTP2, OBJ_TREND, 0, bStart, g_DTD.confirmTP2RPrice, bEnd, g_DTD.confirmTP2RPrice);
            ObjectSetInteger(0, lineTP2, OBJPROP_COLOR, tp2Col);
            ObjectSetInteger(0, lineTP2, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lineTP2, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lineTP2, OBJPROP_RAY_RIGHT, false);
         }
         else
         {
            ObjectSetInteger(0, lineTP2, OBJPROP_TIME, 0, bStart);
            ObjectSetDouble(0, lineTP2, OBJPROP_PRICE, 0, g_DTD.confirmTP2RPrice);
            ObjectSetInteger(0, lineTP2, OBJPROP_TIME, 1, bEnd);
            ObjectSetDouble(0, lineTP2, OBJPROP_PRICE, 1, g_DTD.confirmTP2RPrice);
            ObjectSetInteger(0, lineTP2, OBJPROP_COLOR, tp2Col);
         }

         string lblTP2 = GUI_PREFIX + "DTD_LBL_TP2R";
         double tp2SetupDist = (g_DTD.tp2RDistPoints > 0.0) ? g_DTD.tp2RDistPoints : (MathAbs(g_DTD.confirmTP2RPrice - g_DTD.confirmEntryPrice) / _Point);
         double tp2LblPrice  = ResolveRightChartLabelPrice(g_DTD.confirmTP2RPrice, 1);
         string tp2Txt       = InpDTD_TradingViewStyle ? " TP 1 2R " : StringFormat(" 🎯 TP 2R (1:2): %s (+%s) ", DoubleToString(g_DTD.confirmTP2RPrice, _Digits), FormatMoneyOrPoints(tp2SetupDist));
         color tp2LblCol     = InpDTD_TradingViewStyle ? C'255,120,135' : clrWhite;
         if(ObjectFind(0, lblTP2) < 0)
         {
            ObjectCreate(0, lblTP2, OBJ_TEXT, 0, bEnd, tp2LblPrice);
            ObjectSetString(0, lblTP2, OBJPROP_TEXT, tp2Txt);
            ObjectSetString(0, lblTP2, OBJPROP_FONT, InpDTD_TradingViewStyle ? "Segoe UI Semibold" : "Segoe UI Black");
            ObjectSetInteger(0, lblTP2, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, lblTP2, OBJPROP_COLOR, tp2LblCol);
            ObjectSetInteger(0, lblTP2, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, lblTP2, OBJPROP_BACK, false);
         }
         else
         {
            ObjectSetInteger(0, lblTP2, OBJPROP_TIME, 0, bEnd);
            ObjectSetDouble(0, lblTP2, OBJPROP_PRICE, 0, tp2LblPrice);
            ObjectSetString(0, lblTP2, OBJPROP_TEXT, tp2Txt);
            ObjectSetInteger(0, lblTP2, OBJPROP_COLOR, tp2LblCol);
            ObjectSetString(0, lblTP2, OBJPROP_FONT, InpDTD_TradingViewStyle ? "Segoe UI Semibold" : "Segoe UI Black");
         }
      }

      // เส้น & ป้าย TP 3R (1:3 - เป้าหลัก อ.เดช) - สไตล์ อ.เดช: เส้นแดงบาง ป้าย "TP 2 3R"
      if(g_DTD.confirmTP3RPrice > 0.0)
      {
         string lineTP3 = GUI_PREFIX + "DTD_LINE_TP3R";
         color tp3Col = InpDTD_TradingViewStyle ? C'255,100,120' : C'0,255,136';
         if(ObjectFind(0, lineTP3) < 0)
         {
            ObjectCreate(0, lineTP3, OBJ_TREND, 0, bStart, g_DTD.confirmTP3RPrice, bEnd, g_DTD.confirmTP3RPrice);
            ObjectSetInteger(0, lineTP3, OBJPROP_COLOR, tp3Col);
            ObjectSetInteger(0, lineTP3, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lineTP3, OBJPROP_WIDTH, InpDTD_TradingViewStyle ? 1 : 2);
            ObjectSetInteger(0, lineTP3, OBJPROP_RAY_RIGHT, false);
         }
         else
         {
            ObjectSetInteger(0, lineTP3, OBJPROP_TIME, 0, bStart);
            ObjectSetDouble(0, lineTP3, OBJPROP_PRICE, 0, g_DTD.confirmTP3RPrice);
            ObjectSetInteger(0, lineTP3, OBJPROP_TIME, 1, bEnd);
            ObjectSetDouble(0, lineTP3, OBJPROP_PRICE, 1, g_DTD.confirmTP3RPrice);
            ObjectSetInteger(0, lineTP3, OBJPROP_COLOR, tp3Col);
            ObjectSetInteger(0, lineTP3, OBJPROP_WIDTH, InpDTD_TradingViewStyle ? 1 : 2);
         }

         string lblTP3 = GUI_PREFIX + "DTD_LBL_TP3R";
         double tp3SetupDist = (g_DTD.tp3RDistPoints > 0.0) ? g_DTD.tp3RDistPoints : (MathAbs(g_DTD.confirmTP3RPrice - g_DTD.confirmEntryPrice) / _Point);
         double tp3LblPrice  = ResolveRightChartLabelPrice(g_DTD.confirmTP3RPrice, 1);
         string tp3Txt;
         if(InpDTD_TradingViewStyle)
         {
            tp3Txt = " TP 2 3R ";
         }
         else
         {
            string tp3PinSuffix = "★เป้าหลัก";
            if(chartPMax > 0.0 && g_DTD.setupSide == 1 && g_DTD.confirmTP3RPrice > chartPMax)
            {
               tp3LblPrice  = chartPMax - (vpSep * 0.90);
               tp3PinSuffix = "★เป้าหลัก [อยู่เหนือจอ ▲]";
            }
            else if(chartPMin > 0.0 && g_DTD.setupSide == -1 && g_DTD.confirmTP3RPrice < chartPMin)
            {
               tp3LblPrice  = chartPMin + (vpSep * 0.90);
               tp3PinSuffix = "★เป้าหลัก [อยู่ใต้จอ ▼]";
            }
            tp3Txt = StringFormat(" 🏆 TP 3R (1:3): %s (+%s) %s ", DoubleToString(g_DTD.confirmTP3RPrice, _Digits), FormatMoneyOrPoints(tp3SetupDist), tp3PinSuffix);
         }
         color tp3LblCol = InpDTD_TradingViewStyle ? C'255,120,135' : clrWhite;
         if(ObjectFind(0, lblTP3) < 0)
         {
            ObjectCreate(0, lblTP3, OBJ_TEXT, 0, bEnd, tp3LblPrice);
            ObjectSetString(0, lblTP3, OBJPROP_TEXT, tp3Txt);
            ObjectSetString(0, lblTP3, OBJPROP_FONT, InpDTD_TradingViewStyle ? "Segoe UI Semibold" : "Segoe UI Black");
            ObjectSetInteger(0, lblTP3, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, lblTP3, OBJPROP_COLOR, tp3LblCol);
            ObjectSetInteger(0, lblTP3, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, lblTP3, OBJPROP_BACK, false);
         }
         else
         {
            ObjectSetInteger(0, lblTP3, OBJPROP_TIME, 0, bEnd);
            ObjectSetDouble(0, lblTP3, OBJPROP_PRICE, 0, tp3LblPrice);
            ObjectSetString(0, lblTP3, OBJPROP_TEXT, tp3Txt);
            ObjectSetInteger(0, lblTP3, OBJPROP_COLOR, tp3LblCol);
            ObjectSetString(0, lblTP3, OBJPROP_FONT, InpDTD_TradingViewStyle ? "Segoe UI Semibold" : "Segoe UI Black");
         }
      }

      // เส้น & ป้าย SL (1R) - สไตล์ อ.เดช: เส้นแดงบาง ป้าย "SL: [ราคา]"
      string lineSL = GUI_PREFIX + "DTD_LINE_SL";
      color slLineCol = InpDTD_TradingViewStyle ? C'255,100,120' : C'255,80,90';
      if(ObjectFind(0, lineSL) < 0)
      {
         ObjectCreate(0, lineSL, OBJ_TREND, 0, bStart, g_DTD.confirmSLPrice, bEnd, g_DTD.confirmSLPrice);
         ObjectSetInteger(0, lineSL, OBJPROP_COLOR, slLineCol);
         ObjectSetInteger(0, lineSL, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, lineSL, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineSL, OBJPROP_RAY_RIGHT, false);
      }
      else
      {
         ObjectSetInteger(0, lineSL, OBJPROP_TIME, 0, bStart);
         ObjectSetDouble(0, lineSL, OBJPROP_PRICE, 0, g_DTD.confirmSLPrice);
         ObjectSetInteger(0, lineSL, OBJPROP_TIME, 1, bEnd);
         ObjectSetDouble(0, lineSL, OBJPROP_PRICE, 1, g_DTD.confirmSLPrice);
         ObjectSetInteger(0, lineSL, OBJPROP_COLOR, slLineCol);
      }

      string lblSL = GUI_PREFIX + "DTD_LBL_SL";
      double slSetupDist = (g_DTD.slDistPoints > 0.0) ? g_DTD.slDistPoints : (MathAbs(g_DTD.confirmEntryPrice - g_DTD.confirmSLPrice) / _Point);
      double slLblPrice  = ResolveRightChartLabelPrice(g_DTD.confirmSLPrice, -1);
      string slTxt;
      if(InpDTD_TradingViewStyle)
      {
         slTxt = StringFormat(" SL: %s ", DoubleToString(g_DTD.confirmSLPrice, _Digits));
      }
      else
      {
         string slPosTag = (g_DTD.setupSide == 1) ? "[ใต้ชุดคอนเฟิร์ม]" : "[เหนือชุดคอนเฟิร์ม]";
         slTxt = StringFormat(" 🛑 SL 1R: %s (-%s) %s ", DoubleToString(g_DTD.confirmSLPrice, _Digits), FormatMoneyOrPoints(slSetupDist), slPosTag);
      }
      if(ObjectFind(0, lblSL) < 0)
      {
         ObjectCreate(0, lblSL, OBJ_TEXT, 0, bEnd, slLblPrice);
         ObjectSetString(0, lblSL, OBJPROP_TEXT, slTxt);
         ObjectSetString(0, lblSL, OBJPROP_FONT, InpDTD_TradingViewStyle ? "Segoe UI Semibold" : "Segoe UI Black");
         ObjectSetInteger(0, lblSL, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblSL, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, lblSL, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, lblSL, OBJPROP_BACK, false);
      }
      else
      {
         ObjectSetInteger(0, lblSL, OBJPROP_TIME, 0, bEnd);
         ObjectSetDouble(0, lblSL, OBJPROP_PRICE, 0, slLblPrice);
         ObjectSetString(0, lblSL, OBJPROP_TEXT, slTxt);
         ObjectSetInteger(0, lblSL, OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, lblSL, OBJPROP_FONT, InpDTD_TradingViewStyle ? "Segoe UI Semibold" : "Segoe UI Black");
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_BOX_SL");
      ObjectDelete(0, GUI_PREFIX + "DTD_BOX_TP");
      ObjectDelete(0, GUI_PREFIX + "DTD_TP_TAG");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_TP1R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_TP1R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_TP2R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_TP2R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_TP3R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_TP3R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_SL");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_SL");
   }

   // 7. วาดเส้นคาดการณ์ฝั่งตรงข้าม (Dual-Directional Opposite Forecast Projection)
   bool allowOppChartDraw = (InpUseDualForecast && InpDrawDualForecastOnChart && !g_DTD.isEngulfConfirmed && !g_DTD.isLatched);
   if(allowOppChartDraw)
   {
      int oppSide = (g_DTD.setupSide == 1) ? -1 : 1;
      double oppWick = (oppSide == 1) ? g_DTD.buyShortestWickPrice : g_DTD.sellShortestWickPrice;
      double oppTP3  = (oppSide == 1) ? g_Forecast.buyTP3Price : g_Forecast.sellTP3Price;
      color  oppCol  = (oppSide == 1) ? C'50,225,140' : C'255,95,115';

      string oppLineWick = GUI_PREFIX + "DTD_OPP_WICK_LINE";
      string oppLblWick  = GUI_PREFIX + "DTD_OPP_WICK_LBL";
      string oppLineTP   = GUI_PREFIX + "DTD_OPP_TP3_LINE";
      string oppLblTP    = GUI_PREFIX + "DTD_OPP_TP3_LBL";

      double minOppSep = (g_Asset.assetType == ASSET_CRYPTO) ? (oppWick * 0.0010) : ((g_Asset.assetType == ASSET_GOLD) ? (150.0 * _Point) : (50.0 * _Point));
      double curBidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(curBidPrice <= 0) curBidPrice = iClose(_Symbol, _Period, 0);

      if(oppWick > 0.0 && MathAbs(oppWick - g_DTD.shortestWickPrice) >= minOppSep)
      {
         if(ObjectFind(0, oppLineWick) < 0)
         {
            ObjectCreate(0, oppLineWick, OBJ_TREND, 0, tStart, oppWick, tEnd, oppWick);
            ObjectSetInteger(0, oppLineWick, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, oppLineWick, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, oppLineWick, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, oppLineWick, OBJPROP_BACK, true);
         }
         ObjectSetInteger(0, oppLineWick, OBJPROP_TIME, 0, tStart);
         ObjectSetDouble(0, oppLineWick, OBJPROP_PRICE, 0, oppWick);
         ObjectSetInteger(0, oppLineWick, OBJPROP_TIME, 1, tEnd);
         ObjectSetDouble(0, oppLineWick, OBJPROP_PRICE, 1, oppWick);
         ObjectSetInteger(0, oppLineWick, OBJPROP_COLOR, oppCol);

         double wickPrice = ResolveRightChartLabelPrice(oppWick, (oppSide == 1 ? -1 : 1));
         string wickTxt   = StringFormat(" 🔮 แผนสำรอง %s: %s ", (oppSide == 1 ? "BUY" : "SELL"), DoubleToString(oppWick, _Digits));
         if(ObjectFind(0, oppLblWick) < 0)
         {
            ObjectCreate(0, oppLblWick, OBJ_TEXT, 0, tEnd, wickPrice);
            ObjectSetString(0, oppLblWick, OBJPROP_FONT, "Segoe UI Semibold");
            ObjectSetInteger(0, oppLblWick, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, oppLblWick, OBJPROP_ANCHOR, ANCHOR_LEFT);
         }
         ObjectSetInteger(0, oppLblWick, OBJPROP_TIME, 0, tEnd);
         ObjectSetDouble(0, oppLblWick, OBJPROP_PRICE, 0, wickPrice);
         ObjectSetString(0, oppLblWick, OBJPROP_TEXT, wickTxt);
         ObjectSetInteger(0, oppLblWick, OBJPROP_COLOR, oppCol);
      }
      else
      {
         ObjectDelete(0, oppLineWick);
         ObjectDelete(0, oppLblWick);
      }

      if(oppTP3 > 0.0 && MathAbs(oppTP3 - g_DTD.confirmTP3RPrice) >= minOppSep)
      {
         if(ObjectFind(0, oppLineTP) < 0)
         {
            ObjectCreate(0, oppLineTP, OBJ_TREND, 0, tStart, oppTP3, tEnd, oppTP3);
            ObjectSetInteger(0, oppLineTP, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, oppLineTP, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, oppLineTP, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, oppLineTP, OBJPROP_BACK, true);
         }
         ObjectSetInteger(0, oppLineTP, OBJPROP_TIME, 0, tStart);
         ObjectSetDouble(0, oppLineTP, OBJPROP_PRICE, 0, oppTP3);
         ObjectSetInteger(0, oppLineTP, OBJPROP_TIME, 1, tEnd);
         ObjectSetDouble(0, oppLineTP, OBJPROP_PRICE, 1, oppTP3);
         ObjectSetInteger(0, oppLineTP, OBJPROP_COLOR, oppCol);

         double oppTPPrice = ResolveRightChartLabelPrice(oppTP3, (oppSide == 1 ? 1 : -1));
         string oppTPTxt   = StringFormat(" 🔮 เป้าสำรอง %s 3R: %s ", 
                                         (oppSide == 1 ? "BUY" : "SELL"), 
                                         DoubleToString(oppTP3, _Digits));
         if(ObjectFind(0, oppLblTP) < 0)
         {
            ObjectCreate(0, oppLblTP, OBJ_TEXT, 0, tEnd, oppTPPrice);
            ObjectSetString(0, oppLblTP, OBJPROP_FONT, "Segoe UI Semibold");
            ObjectSetInteger(0, oppLblTP, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, oppLblTP, OBJPROP_ANCHOR, ANCHOR_LEFT);
         }
         ObjectSetInteger(0, oppLblTP, OBJPROP_TIME, 0, tEnd);
         ObjectSetDouble(0, oppLblTP, OBJPROP_PRICE, 0, oppTPPrice);
         ObjectSetString(0, oppLblTP, OBJPROP_TEXT, oppTPTxt);
         ObjectSetInteger(0, oppLblTP, OBJPROP_COLOR, oppCol);
      }
      else
      {
         ObjectDelete(0, oppLineTP);
         ObjectDelete(0, oppLblTP);
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_OPP_WICK_LINE");
      ObjectDelete(0, GUI_PREFIX + "DTD_OPP_WICK_LBL");
      ObjectDelete(0, GUI_PREFIX + "DTD_OPP_TP3_LINE");
      ObjectDelete(0, GUI_PREFIX + "DTD_OPP_TP3_LBL");
   }
}


//| 14G. INSTITUTIONAL MULTI-TIMEFRAME LIQUIDITY (LQ) SCANNER        |
//| สแกนหาจุดสะสมสภาพคล่องที่น่าสนใจ (BSL & SSL: EQH, EQL, IDM, PDH/L)|
//+------------------------------------------------------------------+
void ResetLQPool(SLQPool &p)
{
   p.isValid    = false;
   p.isBSL      = false;
   p.price      = 0.0;
   p.time       = 0;
   p.tfName     = "";
   p.poolType   = "";
   p.shortTag   = "";
   p.distPts    = 0.0;
   p.score      = 0;
   p.touches    = 1;
   p.isSweptNow = false;
}

void ScanInstitutionalLiquidity()
{
   ResetLQPool(g_LQ.bsl1);
   ResetLQPool(g_LQ.bsl2);
   ResetLQPool(g_LQ.ssl1);
   ResetLQPool(g_LQ.ssl2);
   g_LQ.hasSweepAlert = false;
   g_LQ.sweepSide     = 0;
   g_LQ.sweepPrice    = 0.0;
   g_LQ.sweepAlertStr = "";

   if(!InpUseLQ_Scanner)
   {
      g_LQ.hudBSLStr = "🧲 LQ บน (BSL): ปิดการใช้งาน";
      g_LQ.hudSSLStr = "🧲 LQ ล่าง (SSL): ปิดการใช้งาน";
      return;
   }

   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(curBid <= 0.0) curBid = iClose(_Symbol, _Period, 0);
   if(curAsk <= 0.0) curAsk = curBid;

   SLQPool bslCandidates[40];
   SLQPool sslCandidates[40];
   int bslCount = 0;
   int sslCount = 0;

   // 1. ตรวจสอบ Previous Day High (PDH) และ Previous Day Low (PDL)
   MqlRates d1Rates[];
   ArraySetAsSeries(d1Rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 3, d1Rates) >= 2)
   {
      double pdh = d1Rates[1].high;
      double pdl = d1Rates[1].low;
      datetime pdTime = d1Rates[1].time;

      if(pdh > curAsk + (10 * _Point) && bslCount < 40)
      {
         ResetLQPool(bslCandidates[bslCount]);
         bslCandidates[bslCount].isValid  = true;
         bslCandidates[bslCount].isBSL    = true;
         bslCandidates[bslCount].price    = pdh;
         bslCandidates[bslCount].time     = pdTime;
         bslCandidates[bslCount].tfName   = "D1";
         bslCandidates[bslCount].poolType = "PDH (ไฮเมื่อวาน)";
         bslCandidates[bslCount].shortTag = "PDH";
         bslCandidates[bslCount].distPts  = (pdh - curBid) / _Point;
         bslCandidates[bslCount].score    = 78;
         bslCount++;
      }
      if(pdl < curBid - (10 * _Point) && sslCount < 40)
      {
         ResetLQPool(sslCandidates[sslCount]);
         sslCandidates[sslCount].isValid  = true;
         sslCandidates[sslCount].isBSL    = false;
         sslCandidates[sslCount].price    = pdl;
         sslCandidates[sslCount].time     = pdTime;
         sslCandidates[sslCount].tfName   = "D1";
         sslCandidates[sslCount].poolType = "PDL (โลว์เมื่อวาน)";
         sslCandidates[sslCount].shortTag = "PDL";
         sslCandidates[sslCount].distPts  = (curBid - pdl) / _Point;
         sslCandidates[sslCount].score    = 78;
         sslCount++;
      }
   }

   // 2. สแกน Multi-Timeframe (M5, M15, M30, H1, H4) หา EQH, EQL, IDM และ Major Swings
   const ENUM_TIMEFRAMES scanTFs[5] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
   const string          scanTags[5]= {"M5", "M15", "M30", "H1", "H4"};
   const int             tfBaseScore[5] = {50, 65, 70, 75, 80};

   double eqTolPts = (g_Asset.assetType == ASSET_CRYPTO) ? ((curBid * 0.0008) / _Point) : (g_Asset.assetType == ASSET_GOLD ? 30.0 : 12.0);
   double idmDistPts = (g_Asset.assetType == ASSET_CRYPTO) ? ((curBid * 0.003) / _Point) : (g_Asset.assetType == ASSET_GOLD ? 160.0 : 40.0);

   for(int t = 0; t < 5; t++)
   {
      MqlRates tfRates[];
      ArraySetAsSeries(tfRates, true);
      int copied = CopyRates(_Symbol, scanTFs[t], 0, 90, tfRates);
      if(copied < 15) continue;

      bool isActiveTF = (scanTFs[t] == (ENUM_TIMEFRAMES)_Period);

      // เก็บสวิงย่อยใน TF นี้เพื่อตรวจจับ Equal Highs (EQH) / Equal Lows (EQL)
      double swingHighPrices[30];
      datetime swingHighTimes[30];
      int shCount = 0;

      double swingLowPrices[30];
      datetime swingLowTimes[30];
      int slCount = 0;

      for(int i = 2; i < copied - 3; i++)
      {
         bool isSH = (tfRates[i].high >= tfRates[i-1].high && tfRates[i].high >= tfRates[i-2].high &&
                      tfRates[i].high >= tfRates[i+1].high && tfRates[i].high >= tfRates[i+2].high);
         bool isSL = (tfRates[i].low <= tfRates[i-1].low && tfRates[i].low <= tfRates[i-2].low &&
                      tfRates[i].low <= tfRates[i+1].low && tfRates[i].low <= tfRates[i+2].low);

         if(isSH && shCount < 30)
         {
            // ตรวจสอบว่าสวิงไฮนี้ถูกทำลายไปแล้วหรือยังในแท่งถัดๆ มา (i-1 ถึง 2)
            bool broken = false;
            for(int k = i - 1; k >= 2; k--)
            {
               if(tfRates[k].high > tfRates[i].high + (5 * _Point))
               {
                  broken = true;
                  break;
               }
            }

            // ตรวจจับการ Sweep สดๆ ร้อนๆ บนแท่งที่ 0 หรือ 1 (แทงไส้ทะลุไฮแล้วปิดเนื้อกลับลงมาใต้ไฮ)
            if(!broken && (tfRates[0].high > tfRates[i].high || tfRates[1].high > tfRates[i].high) && tfRates[0].close < tfRates[i].high)
            {
               if(!g_LQ.hasSweepAlert || scanTFs[t] >= PERIOD_M15)
               {
                  g_LQ.hasSweepAlert = true;
                  g_LQ.sweepSide     = -1; // กวาด BSL บนแล้วทุบกลับ -> สัญญาณ SELL
                  g_LQ.sweepPrice    = tfRates[i].high;
                  g_LQ.sweepAlertStr = StringFormat("⚡ กวาด LQ บน (BSL %s [%s]) แล้วทิ้งไส้ทุบกลับ! ➔ จังหวะดัก SELL สวยงาม", DoubleToString(tfRates[i].high, _Digits), scanTags[t]);
               }
            }

            if(!broken && tfRates[i].high > curBid + (15 * _Point))
            {
               swingHighPrices[shCount] = tfRates[i].high;
               swingHighTimes[shCount]  = tfRates[i].time;
               shCount++;
            }
         }

         if(isSL && slCount < 30)
         {
            bool broken = false;
            for(int k = i - 1; k >= 2; k--)
            {
               if(tfRates[k].low < tfRates[i].low - (5 * _Point))
               {
                  broken = true;
                  break;
               }
            }

            // ตรวจจับการ Sweep สดๆ ร้อนๆ บนแท่งที่ 0 หรือ 1 (แทงไส้หลุดโลว์แล้วดึงกลับขึ้นมาเหนือโลว์)
            if(!broken && (tfRates[0].low < tfRates[i].low || tfRates[1].low < tfRates[i].low) && tfRates[0].close > tfRates[i].low)
            {
               if(!g_LQ.hasSweepAlert || scanTFs[t] >= PERIOD_M15)
               {
                  g_LQ.hasSweepAlert = true;
                  g_LQ.sweepSide     = 1; // กวาด SSL ล่างแล้วดึงกลับ -> สัญญาณ BUY
                  g_LQ.sweepPrice    = tfRates[i].low;
                  g_LQ.sweepAlertStr = StringFormat("⚡ กวาด LQ ล่าง (SSL %s [%s]) แล้วรูดไส้ดึงกลับ! ➔ จังหวะช้อน BUY สวยงาม", DoubleToString(tfRates[i].low, _Digits), scanTags[t]);
               }
            }

            if(!broken && tfRates[i].low < curBid - (15 * _Point))
            {
               swingLowPrices[slCount] = tfRates[i].low;
               swingLowTimes[slCount]  = tfRates[i].time;
               slCount++;
            }
         }
      }

      // ประเมินคะแนน BSL ของ TF นี้
      for(int h = 0; h < shCount && bslCount < 40; h++)
      {
         double p = swingHighPrices[h];
         int touches = 1;
         for(int h2 = 0; h2 < shCount; h2++)
         {
            if(h2 != h && MathAbs(swingHighPrices[h2] - p) <= eqTolPts * _Point)
               touches++;
         }

         // ตรวจว่าเป็น Inducement (IDM) ล่อเม่าหน้า Supply Zone หรือไม่
         bool isIDM = false;
         for(int z = 0; z < g_ZoneCount; z++)
         {
            if(!g_Zones[z].isActive || g_Zones[z].isDemand) continue;
            double distToSZ = (g_Zones[z].low - p) / _Point;
            if(distToSZ > 0.0 && distToSZ <= idmDistPts)
            {
               isIDM = true;
               break;
            }
         }

         double distPts = (p - curBid) / _Point;
         int score = tfBaseScore[t];
         if(isActiveTF) score += 20;
         string poolType = "Swing High";
         string shortTag = "Swing";

         if(touches >= 2)
         {
            score += 30;
            poolType = "EQH (ไฮคู่แฝด)";
            shortTag = "EQH★";
         }
         else if(isIDM)
         {
            score += 25;
            poolType = "IDM (ล่อเม่าหน้า Supply)";
            shortTag = "IDM🧲";
         }

         // โบนัสระยะทำการบนหน้าจอ (ปรับสเกลอัตโนมัติตามสินทรัพย์ Gold / Crypto / Forex)
         double nearMinPts   = (g_Asset.assetType == ASSET_CRYPTO) ? ((curBid * 0.0005) / _Point) : (g_Asset.assetType == ASSET_GOLD ? 40.0 : 15.0);
         double nearIdealPts = (g_Asset.assetType == ASSET_CRYPTO) ? ((curBid * 0.0080) / _Point) : (g_Asset.assetType == ASSET_GOLD ? 650.0 : 120.0);
         double nearMedPts   = (g_Asset.assetType == ASSET_CRYPTO) ? ((curBid * 0.0180) / _Point) : (g_Asset.assetType == ASSET_GOLD ? 1500.0 : 250.0);
         double nearFarPts   = (g_Asset.assetType == ASSET_CRYPTO) ? ((curBid * 0.0300) / _Point) : (g_Asset.assetType == ASSET_GOLD ? 2500.0 : 450.0);

         if(distPts >= nearMinPts && distPts <= nearIdealPts) score += 25;
         else if(distPts <= nearMedPts) score += 10;
         else if(distPts > nearFarPts) score -= 25;

         ResetLQPool(bslCandidates[bslCount]);
         bslCandidates[bslCount].isValid  = true;
         bslCandidates[bslCount].isBSL    = true;
         bslCandidates[bslCount].price    = p;
         bslCandidates[bslCount].time     = swingHighTimes[h];
         bslCandidates[bslCount].tfName   = scanTags[t];
         bslCandidates[bslCount].poolType = poolType;
         bslCandidates[bslCount].shortTag = shortTag;
         bslCandidates[bslCount].distPts  = distPts;
         bslCandidates[bslCount].score    = score;
         bslCandidates[bslCount].touches  = touches;
         bslCount++;
      }

      // ประเมินคะแนน SSL ของ TF นี้
      for(int l = 0; l < slCount && sslCount < 40; l++)
      {
         double p = swingLowPrices[l];
         int touches = 1;
         for(int l2 = 0; l2 < slCount; l2++)
         {
            if(l2 != l && MathAbs(swingLowPrices[l2] - p) <= eqTolPts * _Point)
               touches++;
         }

         // ตรวจว่าเป็น Inducement (IDM) ล่อเม่าหน้า Demand Zone หรือไม่
         bool isIDM = false;
         for(int z = 0; z < g_ZoneCount; z++)
         {
            if(!g_Zones[z].isActive || !g_Zones[z].isDemand) continue;
            double distToDZ = (p - g_Zones[z].high) / _Point;
            if(distToDZ > 0.0 && distToDZ <= idmDistPts)
            {
               isIDM = true;
               break;
            }
         }

         double distPts = (curBid - p) / _Point;
         int score = tfBaseScore[t];
         if(isActiveTF) score += 20;
         string poolType = "Swing Low";
         string shortTag = "Swing";

         if(touches >= 2)
         {
            score += 30;
            poolType = "EQL (โลว์คู่แฝด)";
            shortTag = "EQL★";
         }
         else if(isIDM)
         {
            score += 25;
            poolType = "IDM (ล่อเม่าหน้า Demand)";
            shortTag = "IDM🧲";
         }

         double nearMinPts   = (g_Asset.assetType == ASSET_CRYPTO) ? ((curBid * 0.0005) / _Point) : (g_Asset.assetType == ASSET_GOLD ? 40.0 : 15.0);
         double nearIdealPts = (g_Asset.assetType == ASSET_CRYPTO) ? ((curBid * 0.0080) / _Point) : (g_Asset.assetType == ASSET_GOLD ? 650.0 : 120.0);
         double nearMedPts   = (g_Asset.assetType == ASSET_CRYPTO) ? ((curBid * 0.0180) / _Point) : (g_Asset.assetType == ASSET_GOLD ? 1500.0 : 250.0);
         double nearFarPts   = (g_Asset.assetType == ASSET_CRYPTO) ? ((curBid * 0.0300) / _Point) : (g_Asset.assetType == ASSET_GOLD ? 2500.0 : 450.0);

         if(distPts >= nearMinPts && distPts <= nearIdealPts) score += 25;
         else if(distPts <= nearMedPts) score += 10;
         else if(distPts > nearFarPts) score -= 25;

         ResetLQPool(sslCandidates[sslCount]);
         sslCandidates[sslCount].isValid  = true;
         sslCandidates[sslCount].isBSL    = false;
         sslCandidates[sslCount].price    = p;
         sslCandidates[sslCount].time     = swingLowTimes[l];
         sslCandidates[sslCount].tfName   = scanTags[t];
         sslCandidates[sslCount].poolType = poolType;
         sslCandidates[sslCount].shortTag = shortTag;
         sslCandidates[sslCount].distPts  = distPts;
         sslCandidates[sslCount].score    = score;
         sslCandidates[sslCount].touches  = touches;
         sslCount++;
      }
   }

   // 3. คัดเลือก BSL อันดับ 1 และ 2 (คะแนนสูงสุด และไม่ซ้อนทับกัน)
   int bestBSLIdx = -1;
   int bestBSLScore = -999;
   for(int i = 0; i < bslCount; i++)
   {
      if(bslCandidates[i].isValid && bslCandidates[i].score > bestBSLScore)
      {
         bestBSLScore = bslCandidates[i].score;
         bestBSLIdx   = i;
      }
   }
   if(bestBSLIdx >= 0)
   {
      g_LQ.bsl1 = bslCandidates[bestBSLIdx];
      int secondIdx = -1;
      int secondScore = -999;
      for(int i = 0; i < bslCount; i++)
      {
         if(i != bestBSLIdx && bslCandidates[i].isValid &&
            MathAbs(bslCandidates[i].price - g_LQ.bsl1.price) > ((g_Asset.assetType == ASSET_CRYPTO) ? (curBid * 0.0010) : (45 * _Point)) &&
            bslCandidates[i].score > secondScore)
         {
            secondScore = bslCandidates[i].score;
            secondIdx   = i;
         }
      }
      if(secondIdx >= 0) g_LQ.bsl2 = bslCandidates[secondIdx];
   }

   // 4. คัดเลือก SSL อันดับ 1 และ 2 (คะแนนสูงสุด และไม่ซ้อนทับกัน)
   int bestSSLIdx = -1;
   int bestSSLScore = -999;
   for(int i = 0; i < sslCount; i++)
   {
      if(sslCandidates[i].isValid && sslCandidates[i].score > bestSSLScore)
      {
         bestSSLScore = sslCandidates[i].score;
         bestSSLIdx   = i;
      }
   }
   if(bestSSLIdx >= 0)
   {
      g_LQ.ssl1 = sslCandidates[bestSSLIdx];
      int secondIdx = -1;
      int secondScore = -999;
      for(int i = 0; i < sslCount; i++)
      {
         if(i != bestSSLIdx && sslCandidates[i].isValid &&
            MathAbs(sslCandidates[i].price - g_LQ.ssl1.price) > ((g_Asset.assetType == ASSET_CRYPTO) ? (curBid * 0.0010) : (45 * _Point)) &&
            sslCandidates[i].score > secondScore)
         {
            secondScore = sslCandidates[i].score;
            secondIdx   = i;
         }
      }
      if(secondIdx >= 0) g_LQ.ssl2 = sslCandidates[secondIdx];
   }

   // 5. สร้างข้อความสรุปสำหรับแสดงบน HUD Card 2
   if(g_LQ.bsl1.isValid)
   {
      string bslNext = g_LQ.bsl2.isValid ? StringFormat(" | ถัดไป: %s [%s•%s]", DoubleToString(g_LQ.bsl2.price, _Digits), g_LQ.bsl2.tfName, g_LQ.bsl2.shortTag) : "";
      g_LQ.hudBSLStr = StringFormat("🧲 LQ บน (BSL): %s [%s•%s] (+%s)%s",
                                    DoubleToString(g_LQ.bsl1.price, _Digits),
                                    g_LQ.bsl1.tfName,
                                    g_LQ.bsl1.shortTag,
                                    FormatMoneyOrPoints(g_LQ.bsl1.distPts),
                                    bslNext);
   }
   else
   {
      g_LQ.hudBSLStr = "🧲 LQ บน (BSL): ไม่พบคลัสเตอร์ SL ใกล้เคียง";
   }

   if(g_LQ.ssl1.isValid)
   {
      string sslNext = g_LQ.ssl2.isValid ? StringFormat(" | ถัดไป: %s [%s•%s]", DoubleToString(g_LQ.ssl2.price, _Digits), g_LQ.ssl2.tfName, g_LQ.ssl2.shortTag) : "";
      g_LQ.hudSSLStr = StringFormat("🧲 LQ ล่าง (SSL): %s [%s•%s] (-%s)%s",
                                    DoubleToString(g_LQ.ssl1.price, _Digits),
                                    g_LQ.ssl1.tfName,
                                    g_LQ.ssl1.shortTag,
                                    FormatMoneyOrPoints(g_LQ.ssl1.distPts),
                                    sslNext);
   }
   else
   {
      g_LQ.hudSSLStr = "🧲 LQ ล่าง (SSL): ไม่พบคลัสเตอร์ SL ใกล้เคียง";
   }
}

//+------------------------------------------------------------------+
//| 14H. DRAW INSTITUTIONAL LIQUIDITY POOLS ON CHART (BSL & SSL)     |
//+------------------------------------------------------------------+
void DrawLiquidityVisuals()
{
   if(!InpUseLQ_Scanner || !InpDrawLQ_OnChart)
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "LQ_");
      return;
   }

   int tfSec = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   int forwardBars = 6;
   if(_Period == PERIOD_M1)       forwardBars = 12;
   else if(_Period <= PERIOD_M5)  forwardBars = 8;
   else if(_Period <= PERIOD_M15) forwardBars = 6;
   else if(_Period <= PERIOD_M30) forwardBars = 5;
   else                           forwardBars = 4;

   datetime tEnd = TimeCurrent() + (tfSec * forwardBars);
   datetime tFallbackStart = TimeCurrent() - (tfSec * 35);
   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(curBid <= 0.0) curBid = iClose(_Symbol, _Period, 0);

   // 1. วาดเส้นและป้าย BSL อันดับ 1 (จุดดักกิน SL ฝั่ง Sell เหนือราคา)
   string bsl1Line = GUI_PREFIX + "LQ_BSL1_LINE";
   string bsl1Lbl  = GUI_PREFIX + "LQ_BSL1_LBL";
   if(g_LQ.bsl1.isValid)
   {
      datetime tStart = (g_LQ.bsl1.time > tFallbackStart) ? g_LQ.bsl1.time : tFallbackStart;
      if(ObjectFind(0, bsl1Line) < 0)
      {
         ObjectCreate(0, bsl1Line, OBJ_TREND, 0, tStart, g_LQ.bsl1.price, tEnd, g_LQ.bsl1.price);
         ObjectSetInteger(0, bsl1Line, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, bsl1Line, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, bsl1Line, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, bsl1Line, OBJPROP_BACK, true);
      }
      ObjectSetInteger(0, bsl1Line, OBJPROP_TIME, 0, tStart);
      ObjectSetDouble(0, bsl1Line, OBJPROP_PRICE, 0, g_LQ.bsl1.price);
      ObjectSetInteger(0, bsl1Line, OBJPROP_TIME, 1, tEnd);
      ObjectSetDouble(0, bsl1Line, OBJPROP_PRICE, 1, g_LQ.bsl1.price);
      ObjectSetInteger(0, bsl1Line, OBJPROP_COLOR, InpColorBSL_Pool);
      ObjectSetInteger(0, bsl1Line, OBJPROP_BACK, true);

      double lblPrice = ResolveRightChartLabelPrice(g_LQ.bsl1.price, 1);
      ENUM_ANCHOR_POINT ancBSL = ANCHOR_LEFT;

      string bslTxt = StringFormat(" 🧲 LQ บน (BSL %s•%s): %s (+%s) ",
                                   g_LQ.bsl1.tfName,
                                   g_LQ.bsl1.shortTag,
                                   DoubleToString(g_LQ.bsl1.price, _Digits),
                                   FormatMoneyOrPoints(g_LQ.bsl1.distPts));
      if(ObjectFind(0, bsl1Lbl) < 0)
      {
         ObjectCreate(0, bsl1Lbl, OBJ_TEXT, 0, tEnd, lblPrice);
         ObjectSetString(0, bsl1Lbl, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, bsl1Lbl, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, bsl1Lbl, OBJPROP_ANCHOR, ancBSL);
         ObjectSetInteger(0, bsl1Lbl, OBJPROP_BACK, false);
      }
      ObjectSetInteger(0, bsl1Lbl, OBJPROP_TIME, 0, tEnd);
      ObjectSetDouble(0, bsl1Lbl, OBJPROP_PRICE, 0, lblPrice);
      ObjectSetString(0, bsl1Lbl, OBJPROP_TEXT, bslTxt);
      ObjectSetInteger(0, bsl1Lbl, OBJPROP_COLOR, InpColorBSL_Pool);
      ObjectSetInteger(0, bsl1Lbl, OBJPROP_ANCHOR, ancBSL);
   }
   else
   {
      ObjectDelete(0, bsl1Line);
      ObjectDelete(0, bsl1Lbl);
   }

   // 2. วาดเส้นและป้าย SSL อันดับ 1 (จุดดักกิน SL ฝั่ง Buy ใต้ราคา)
   string ssl1Line = GUI_PREFIX + "LQ_SSL1_LINE";
   string ssl1Lbl  = GUI_PREFIX + "LQ_SSL1_LBL";
   if(g_LQ.ssl1.isValid)
   {
      datetime tStart = (g_LQ.ssl1.time > tFallbackStart) ? g_LQ.ssl1.time : tFallbackStart;
      if(ObjectFind(0, ssl1Line) < 0)
      {
         ObjectCreate(0, ssl1Line, OBJ_TREND, 0, tStart, g_LQ.ssl1.price, tEnd, g_LQ.ssl1.price);
         ObjectSetInteger(0, ssl1Line, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, ssl1Line, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, ssl1Line, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, ssl1Line, OBJPROP_BACK, true);
      }
      ObjectSetInteger(0, ssl1Line, OBJPROP_TIME, 0, tStart);
      ObjectSetDouble(0, ssl1Line, OBJPROP_PRICE, 0, g_LQ.ssl1.price);
      ObjectSetInteger(0, ssl1Line, OBJPROP_TIME, 1, tEnd);
      ObjectSetDouble(0, ssl1Line, OBJPROP_PRICE, 1, g_LQ.ssl1.price);
      ObjectSetInteger(0, ssl1Line, OBJPROP_COLOR, InpColorSSL_Pool);
      ObjectSetInteger(0, ssl1Line, OBJPROP_BACK, true);

      double lblPrice = ResolveRightChartLabelPrice(g_LQ.ssl1.price, -1);
      ENUM_ANCHOR_POINT ancSSL = ANCHOR_LEFT;

      string sslTxt = StringFormat(" 🧲 LQ ล่าง (SSL %s•%s): %s (-%s) ",
                                   g_LQ.ssl1.tfName,
                                   g_LQ.ssl1.shortTag,
                                   DoubleToString(g_LQ.ssl1.price, _Digits),
                                   FormatMoneyOrPoints(g_LQ.ssl1.distPts));
      if(ObjectFind(0, ssl1Lbl) < 0)
      {
         ObjectCreate(0, ssl1Lbl, OBJ_TEXT, 0, tEnd, lblPrice);
         ObjectSetString(0, ssl1Lbl, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, ssl1Lbl, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, ssl1Lbl, OBJPROP_ANCHOR, ancSSL);
         ObjectSetInteger(0, ssl1Lbl, OBJPROP_BACK, false);
      }
      ObjectSetInteger(0, ssl1Lbl, OBJPROP_TIME, 0, tEnd);
      ObjectSetDouble(0, ssl1Lbl, OBJPROP_PRICE, 0, lblPrice);
      ObjectSetString(0, ssl1Lbl, OBJPROP_TEXT, sslTxt);
      ObjectSetInteger(0, ssl1Lbl, OBJPROP_COLOR, InpColorSSL_Pool);
      ObjectSetInteger(0, ssl1Lbl, OBJPROP_ANCHOR, ancSSL);
   }
   else
   {
      ObjectDelete(0, ssl1Line);
      ObjectDelete(0, ssl1Lbl);
   }
}

//+------------------------------------------------------------------+
//| 14I. DUAL-DIRECTIONAL PRICE FORECAST ENGINE (BUY & SELL ROADMAP) |
//| คำนวณแผนคาดการณ์ราคาทั้งฝั่ง BUY และ SELL พร้อมกันตลอด 24 ชม.    |
//+------------------------------------------------------------------+
void CalculateDualPriceForecast()
{
   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(curBid <= 0.0) curBid = iClose(_Symbol, _Period, 0);
   if(curAsk <= 0.0) curAsk = curBid;

   // 1. คำนวณโอกาสความน่าจะเป็น (Probability %) ของทั้งฝั่ง BUY และ SELL
   int buyScore  = g_MarketBiasBuyPct;
   int sellScore = g_MarketBiasSellPct;

   int m15Dir = GetM15_TrendDirection();
   if(m15Dir == 1)  { buyScore += 10; sellScore -= 10; }
   if(m15Dir == -1) { sellScore += 10; buyScore -= 10; }

   if(g_DTD.buyEngulfConfirmed && !g_DTD.sellEngulfConfirmed)  { buyScore += 12; sellScore -= 12; }
   if(g_DTD.sellEngulfConfirmed && !g_DTD.buyEngulfConfirmed)  { sellScore += 12; buyScore -= 12; }

   if(g_LQ.hasSweepAlert)
   {
      if(g_LQ.sweepSide == 1)  { buyScore += 15; sellScore -= 15; }
      if(g_LQ.sweepSide == -1) { sellScore += 15; buyScore -= 15; }
   }

   if(buyScore < 10)  buyScore = 10;
   if(buyScore > 90)  buyScore = 90;
   sellScore = 100 - buyScore;

   g_Forecast.buyProbPct  = buyScore;
   g_Forecast.sellProbPct = sellScore;

   // 2. สร้างแผนคาดการณ์ฝั่ง BUY (Bullish Forecast - เชื่อมตรงกับสถาปัตยกรรมหลัก g_DTD ซิงค์ตรงกัน 100%)
   g_Forecast.buyIsReady = (g_DTD.buyEngulfConfirmed || (g_DTD.isLatched && g_DTD.latchedSide == 1));
   if(g_DTD.isLatched && g_DTD.latchedSide == 1)
   {
      g_Forecast.buyPullbackPrice = g_DTD.latchedShortestWick;
      g_Forecast.buyEntryPrice    = g_DTD.latchedEntryPrice;
      g_Forecast.buySLPrice       = g_DTD.latchedSLPrice;
      g_Forecast.buySLDistPts     = g_DTD.latchedSLDist;
      g_Forecast.buyTP1Price      = g_DTD.latchedTP1Price;
      g_Forecast.buyTP2Price      = g_DTD.latchedTP2Price;
      g_Forecast.buyTP3Price      = g_DTD.latchedTP3Price;
      g_Forecast.buyLot           = g_DTD.latchedLot;
   }
   else if(g_DTD.isEngulfConfirmed && g_DTD.setupSide == 1)
   {
      g_Forecast.buyPullbackPrice = g_DTD.shortestWickPrice;
      g_Forecast.buyEntryPrice    = g_DTD.confirmEntryPrice;
      g_Forecast.buySLPrice       = g_DTD.confirmSLPrice;
      g_Forecast.buySLDistPts     = g_DTD.slDistPoints;
      g_Forecast.buyTP1Price      = g_DTD.confirmTP1RPrice;
      g_Forecast.buyTP2Price      = g_DTD.confirmTP2RPrice;
      g_Forecast.buyTP3Price      = g_DTD.confirmTP3RPrice;
      g_Forecast.buyLot           = g_DTD.recommendedLot;
   }
   else
   {
      g_Forecast.buyPullbackPrice = (g_DTD.buyShortestWickPrice > 0.0) ? g_DTD.buyShortestWickPrice : curAsk;
      g_Forecast.buyEntryPrice    = g_Forecast.buyPullbackPrice;
      g_Forecast.buySLPrice       = (g_DTD.buyConfirmSLPrice > 0.0 && g_DTD.buyConfirmSLPrice < g_Forecast.buyEntryPrice) ? g_DTD.buyConfirmSLPrice : (g_Forecast.buyEntryPrice - g_Asset.slPoints * _Point);
      g_Forecast.buySLDistPts     = MathMax(10.0, (g_Forecast.buyEntryPrice - g_Forecast.buySLPrice) / _Point);
      g_Forecast.buyTP1Price      = g_Forecast.buyEntryPrice + (g_Forecast.buySLDistPts * _Point * 1.0);
      g_Forecast.buyTP2Price      = g_Forecast.buyEntryPrice + (g_Forecast.buySLDistPts * _Point * 2.0);
      g_Forecast.buyTP3Price      = g_Forecast.buyEntryPrice + (g_Forecast.buySLDistPts * _Point * InpDTD_TargetRR);
      g_Forecast.buyLot           = (g_DTD.buyRecommendedLot > 0.0) ? g_DTD.buyRecommendedLot : g_CurrentLot;
   }
   if(g_Forecast.buyTP3Price <= g_Forecast.buyTP2Price)
      g_Forecast.buyTP3Price = g_Forecast.buyEntryPrice + (g_Forecast.buySLDistPts * _Point * InpDTD_TargetRR);

   string buyStateTag = g_Forecast.buyIsReady ? "★CF" : "รอCF";
   g_Forecast.buyPlanLine1 = StringFormat("🟢 BUY(%d%%)[%s] เข้า %s | SL %s | Lot %.2f",
                                          g_Forecast.buyProbPct,
                                          buyStateTag,
                                          DoubleToString(g_Forecast.buyEntryPrice, _Digits),
                                          DoubleToString(g_Forecast.buySLPrice, _Digits),
                                          g_Forecast.buyLot);
   g_Forecast.buyPlanLine2 = StringFormat("   🎯 เป้าขาขึ้น: TP1 %s ➔ TP2 %s ➔ TP3 %s",
                                          DoubleToString(g_Forecast.buyTP1Price, _Digits),
                                          DoubleToString(g_Forecast.buyTP2Price, _Digits),
                                          DoubleToString(g_Forecast.buyTP3Price, _Digits));
   g_Forecast.buyPlanLine3 = g_LQ.bsl1.isValid
                             ? StringFormat("   ↳ 🧲 แม่เหล็กดึงดูดขาขึ้น: BSL %s [%s] (+%s)", DoubleToString(g_LQ.bsl1.price, _Digits), g_LQ.bsl1.tfName, FormatMoneyOrPoints(g_LQ.bsl1.distPts))
                             : "   ↳ 🧲 แม่เหล็กดึงดูดขาขึ้น: รอสแกนจุดสะสมสภาพคล่อง BSL";

   // 3. สร้างแผนคาดการณ์ฝั่ง SELL (Bearish Forecast - เชื่อมตรงกับสถาปัตยกรรมหลัก g_DTD ซิงค์ตรงกัน 100%)
   g_Forecast.sellIsReady = (g_DTD.sellEngulfConfirmed || (g_DTD.isLatched && g_DTD.latchedSide == -1));
   if(g_DTD.isLatched && g_DTD.latchedSide == -1)
   {
      g_Forecast.sellPullbackPrice = g_DTD.latchedShortestWick;
      g_Forecast.sellEntryPrice    = g_DTD.latchedEntryPrice;
      g_Forecast.sellSLPrice       = g_DTD.latchedSLPrice;
      g_Forecast.sellSLDistPts     = g_DTD.latchedSLDist;
      g_Forecast.sellTP1Price      = g_DTD.latchedTP1Price;
      g_Forecast.sellTP2Price      = g_DTD.latchedTP2Price;
      g_Forecast.sellTP3Price      = g_DTD.latchedTP3Price;
      g_Forecast.sellLot           = g_DTD.latchedLot;
   }
   else if(g_DTD.isEngulfConfirmed && g_DTD.setupSide == -1)
   {
      g_Forecast.sellPullbackPrice = g_DTD.shortestWickPrice;
      g_Forecast.sellEntryPrice    = g_DTD.confirmEntryPrice;
      g_Forecast.sellSLPrice       = g_DTD.confirmSLPrice;
      g_Forecast.sellSLDistPts     = g_DTD.slDistPoints;
      g_Forecast.sellTP1Price      = g_DTD.confirmTP1RPrice;
      g_Forecast.sellTP2Price      = g_DTD.confirmTP2RPrice;
      g_Forecast.sellTP3Price      = g_DTD.confirmTP3RPrice;
      g_Forecast.sellLot           = g_DTD.recommendedLot;
   }
   else
   {
      g_Forecast.sellPullbackPrice = (g_DTD.sellShortestWickPrice > 0.0) ? g_DTD.sellShortestWickPrice : curBid;
      g_Forecast.sellEntryPrice    = g_Forecast.sellPullbackPrice;
      g_Forecast.sellSLPrice       = (g_DTD.sellConfirmSLPrice > g_Forecast.sellEntryPrice) ? g_DTD.sellConfirmSLPrice : (g_Forecast.sellEntryPrice + g_Asset.slPoints * _Point);
      g_Forecast.sellSLDistPts     = MathMax(10.0, (g_Forecast.sellSLPrice - g_Forecast.sellEntryPrice) / _Point);
      g_Forecast.sellTP1Price      = g_Forecast.sellEntryPrice - (g_Forecast.sellSLDistPts * _Point * 1.0);
      g_Forecast.sellTP2Price      = g_Forecast.sellEntryPrice - (g_Forecast.sellSLDistPts * _Point * 2.0);
      g_Forecast.sellTP3Price      = g_Forecast.sellEntryPrice - (g_Forecast.sellSLDistPts * _Point * InpDTD_TargetRR);
      g_Forecast.sellLot           = (g_DTD.sellRecommendedLot > 0.0) ? g_DTD.sellRecommendedLot : g_CurrentLot;
   }
   if(g_Forecast.sellTP3Price >= g_Forecast.sellTP2Price)
      g_Forecast.sellTP3Price = g_Forecast.sellEntryPrice - (g_Forecast.sellSLDistPts * _Point * InpDTD_TargetRR);

   string sellStateTag = g_Forecast.sellIsReady ? "★CF" : "รอCF";
   g_Forecast.sellPlanLine1 = StringFormat("🔴 SELL(%d%%)[%s] เข้า %s | SL %s | Lot %.2f",
                                           g_Forecast.sellProbPct,
                                           sellStateTag,
                                           DoubleToString(g_Forecast.sellEntryPrice, _Digits),
                                           DoubleToString(g_Forecast.sellSLPrice, _Digits),
                                           g_Forecast.sellLot);
   g_Forecast.sellPlanLine2 = StringFormat("   🎯 เป้าขาลง: TP1 %s ➔ TP2 %s ➔ TP3 %s",
                                           DoubleToString(g_Forecast.sellTP1Price, _Digits),
                                           DoubleToString(g_Forecast.sellTP2Price, _Digits),
                                           DoubleToString(g_Forecast.sellTP3Price, _Digits));
   g_Forecast.sellPlanLine3 = g_LQ.ssl1.isValid
                              ? StringFormat("   ↳ 🧲 แม่เหล็กดึงดูดขาลง: SSL %s [%s] (-%s)", DoubleToString(g_LQ.ssl1.price, _Digits), g_LQ.ssl1.tfName, FormatMoneyOrPoints(g_LQ.ssl1.distPts))
                              : "   ↳ 🧲 แม่เหล็กดึงดูดขาลง: รอสแกนจุดสะสมสภาพคล่อง SSL";
}
//+------------------------------------------------------------------+
//| 15. SYNCHRONIZE ZONE-ANCHORED SHARED SL                          |
//+------------------------------------------------------------------+
void SynchronizeSharedSL()
{
   // ปิดการทำงานถาวรตามคำสั่งเด็ดขาดของคุณเอ้ ห้ามแตะต้อง ดึง หรือซิงค์ SL ของออเดอร์เด็ดขาด
   return;
   int openCount = 0;
   double masterSL = 0.0;
   ulong firstTicket = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || m_position.Magic() == 0))
         {
            openCount++;
            if(firstTicket == 0 || m_position.Ticket() < firstTicket)
            {
               firstTicket = m_position.Ticket();
               masterSL = m_position.StopLoss();
            }
         }
      }
   }

   if(openCount > 1 && masterSL > 0.0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || m_position.Magic() == 0))
            {
               if(MathAbs(m_position.StopLoss() - masterSL) > 2 * _Point)
               {
                  m_trade.PositionModify(m_position.Ticket(), masterSL, m_position.TakeProfit());
               }
            }
         }
      }
   }

   if(openCount == 0) g_ZoneSharedSL = 0.0;
   else if(masterSL > 0.0) g_ZoneSharedSL = masterSL;
}

//+------------------------------------------------------------------+
//| 16. MANUAL TRADING ACTIONS (BUY, SELL, BE, CLOSE ALL)            |
//+------------------------------------------------------------------+
void ExecuteManualTrade(ENUM_ORDER_TYPE orderType)
{
   m_symbol.RefreshRates();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
   {
      ask = m_symbol.Ask();
      bid = m_symbol.Bid();
   }
   if(ask <= 0.0 || bid <= 0.0)
   {
      Print(">>> [DeungDang_Trade] ⚠️ ไม่สามารถอ่านราคาตลาดได้! Ask: ", ask, " Bid: ", bid);
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

      // 1. ตรวจสอบ SL สำหรับ BUY (ต้องอยู่ใต้ราคา Bid เสมอ)
      if(InpUseDTD_CF_M1 && g_DTD.buyConfirmSLPrice > 0.0 && g_DTD.buyConfirmSLPrice < bid - minStopDist)
         sl = g_DTD.buyConfirmSLPrice;
      else if(InpUseDTD_CF_M1 && g_DTD.setupSide == 1 && g_DTD.confirmSLPrice > 0.0 && g_DTD.confirmSLPrice < bid - minStopDist)
         sl = g_DTD.confirmSLPrice;
      else if(g_WaveSide == 1 && g_TargetSL > 0.0 && g_TargetSL < bid - minStopDist)
         sl = g_TargetSL;
      else
         sl = bid - (g_Asset.slPoints * _Point);

      // 2. ตรวจสอบ TP สำหรับ BUY (ต้องอยู่เหนือราคา Ask เสมอ)
      if(InpUseDTD_CF_M1 && g_DTD.buyConfirmTP3RPrice > ask + minStopDist)
         tp = g_DTD.buyConfirmTP3RPrice;
      else if(InpUseDTD_CF_M1 && g_DTD.setupSide == 1 && g_DTD.confirmTP3RPrice > ask + minStopDist)
         tp = g_DTD.confirmTP3RPrice;
      else if(g_WaveSide == 1 && g_TargetTP1 > ask + minStopDist)
         tp = g_TargetTP1;
      else
         tp = ask + (g_Asset.tp1Points * _Point);

      // 3. Shared SL กรณีมีไม้เดิมในโซน
      if(g_ZoneSharedSL > 0.0 && g_ZoneSharedSL < bid - minStopDist)
         sl = g_ZoneSharedSL;

      // 4. เกราะความปลอดภัยขั้นสูงสุด ป้องกัน Invalid Stops 100%
      if(sl >= bid - minStopDist || sl <= 0.0)
         sl = bid - (g_Asset.slPoints * _Point);
      if(tp <= ask + minStopDist || tp <= 0.0)
         tp = ask + (g_Asset.tp1Points * _Point);

      sl    = NormalizeDouble(sl, _Digits);
      tp    = NormalizeDouble(tp, _Digits);
      price = NormalizeDouble(price, _Digits);

      double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN); if(minL <= 0) minL = 0.01;
      double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX); if(maxL <= 0) maxL = 100.0;
      double stpL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); if(stpL <= 0) stpL = 0.01;
      double safeLot = CapLotByFreeMargin(g_CurrentLot, ORDER_TYPE_BUY, price, minL, maxL, stpL);
      if(safeLot < g_CurrentLot)
      {
         Print(">>> [DeungDang_Trade] 🛡️ ปรับลดขนาด Lot อัตโนมัติจาก ", g_CurrentLot, " เป็น ", safeLot, " เพื่อให้พอกับ Free Margin จริงในพอร์ต!");
         g_CurrentLot = safeLot;
      }

      Print(">>> [DeungDang_Trade] ⚡ กำลังส่งคำสั่ง BUY: Lot=", g_CurrentLot, " Price=", price, " SL=", sl, " TP=", tp);

      if(m_trade.Buy(g_CurrentLot, _Symbol, price, sl, tp, "DeungDang_Buy"))
      {
         Print(">>> [DeungDang_Trade] 🟢 เปิดไม้ BUY สำเร็จ! Ticket: ", m_trade.ResultOrder(), " Lot: ", g_CurrentLot, " Price: ", price, " SL: ", sl, " TP: ", tp);
         if(g_ZoneSharedSL == 0.0) g_ZoneSharedSL = sl;
      }
      else
      {
         Print(">>> [DeungDang_Trade] ⚠️ เปิดไม้ BUY ไม่สำเร็จ! Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      price = bid;

      // 1. ตรวจสอบ SL สำหรับ SELL (ต้องอยู่เหนือราคา Ask เสมอ)
      if(InpUseDTD_CF_M1 && g_DTD.sellConfirmSLPrice > ask + minStopDist)
         sl = g_DTD.sellConfirmSLPrice;
      else if(InpUseDTD_CF_M1 && g_DTD.setupSide == -1 && g_DTD.confirmSLPrice > ask + minStopDist)
         sl = g_DTD.confirmSLPrice;
      else if(g_WaveSide == -1 && g_TargetSL > ask + minStopDist)
         sl = g_TargetSL;
      else
         sl = ask + (g_Asset.slPoints * _Point);

      // 2. ตรวจสอบ TP สำหรับ SELL (ต้องอยู่ใต้ราคา Bid เสมอ)
      if(InpUseDTD_CF_M1 && g_DTD.sellConfirmTP3RPrice > 0.0 && g_DTD.sellConfirmTP3RPrice < bid - minStopDist)
         tp = g_DTD.sellConfirmTP3RPrice;
      else if(InpUseDTD_CF_M1 && g_DTD.setupSide == -1 && g_DTD.confirmTP3RPrice > 0.0 && g_DTD.confirmTP3RPrice < bid - minStopDist)
         tp = g_DTD.confirmTP3RPrice;
      else if(g_WaveSide == -1 && g_TargetTP1 > 0.0 && g_TargetTP1 < bid - minStopDist)
         tp = g_TargetTP1;
      else
         tp = bid - (g_Asset.tp1Points * _Point);

      // 3. Shared SL กรณีมีไม้เดิมในโซน
      if(g_ZoneSharedSL > ask + minStopDist)
         sl = g_ZoneSharedSL;

      // 4. เกราะความปลอดภัยขั้นสูงสุด ป้องกัน Invalid Stops 100%
      if(sl <= ask + minStopDist || sl <= 0.0)
         sl = ask + (g_Asset.slPoints * _Point);
      if(tp >= bid - minStopDist || tp <= 0.0)
         tp = bid - (g_Asset.tp1Points * _Point);

      sl    = NormalizeDouble(sl, _Digits);
      tp    = NormalizeDouble(tp, _Digits);
      price = NormalizeDouble(price, _Digits);

      double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN); if(minL <= 0) minL = 0.01;
      double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX); if(maxL <= 0) maxL = 100.0;
      double stpL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); if(stpL <= 0) stpL = 0.01;
      double safeLot = CapLotByFreeMargin(g_CurrentLot, ORDER_TYPE_SELL, price, minL, maxL, stpL);
      if(safeLot < g_CurrentLot)
      {
         Print(">>> [DeungDang_Trade] 🛡️ ปรับลดขนาด Lot อัตโนมัติจาก ", g_CurrentLot, " เป็น ", safeLot, " เพื่อให้พอกับ Free Margin จริงในพอร์ต!");
         g_CurrentLot = safeLot;
      }

      Print(">>> [DeungDang_Trade] ⚡ กำลังส่งคำสั่ง SELL: Lot=", g_CurrentLot, " Price=", price, " SL=", sl, " TP=", tp);

      if(m_trade.Sell(g_CurrentLot, _Symbol, price, sl, tp, "DeungDang_Sell"))
      {
         Print(">>> [DeungDang_Trade] 🔴 เปิดไม้ SELL สำเร็จ! Ticket: ", m_trade.ResultOrder(), " Lot: ", g_CurrentLot, " Price: ", price, " SL: ", sl, " TP: ", tp);
         if(g_ZoneSharedSL == 0.0) g_ZoneSharedSL = sl;
      }
      else
      {
         Print(">>> [DeungDang_Trade] ⚠️ เปิดไม้ SELL ไม่สำเร็จ! Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
      }
   }
}

void ExecuteBreakEven()
{
   m_symbol.RefreshRates();
   int modified = 0;
   int totalFound = 0;
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = MathMax((double)stopsLevel * _Point, 15.0 * _Point);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || m_position.Magic() == 0))
         {
            totalFound++;
            double openP = m_position.PriceOpen();
            double curP  = m_position.PriceCurrent();
            double beSL  = openP;

            if(m_position.PositionType() == POSITION_TYPE_BUY)
            {
               beSL = NormalizeDouble(openP + (g_Asset.beBuffer * _Point), _Digits);
               if(curP - beSL >= minDist && m_position.StopLoss() < beSL)
               {
                  if(m_trade.PositionModify(m_position.Ticket(), beSL, m_position.TakeProfit()))
                     modified++;
               }
            }
            else if(m_position.PositionType() == POSITION_TYPE_SELL)
            {
               beSL = NormalizeDouble(openP - (g_Asset.beBuffer * _Point), _Digits);
               if(beSL - curP >= minDist && (m_position.StopLoss() > beSL || m_position.StopLoss() == 0.0))
               {
                  if(m_trade.PositionModify(m_position.Ticket(), beSL, m_position.TakeProfit()))
                     modified++;
               }
            }
         }
      }
   }
   Print(">>> [DeungDang_Trade] 🛡️ ขยับบังหน้าทุน (BE) เรียบร้อย: ", modified, "/", totalFound, " ไม้");
   if(totalFound == 0)
      Print(">>> [DeungDang_Trade] ", "ℹ️ [DeungDang_Trade] ไม่มีไม้ที่กำลังถืออยู่ (0 positions)");
   else if(modified > 0)
      Print(">>> [DeungDang_Trade] ", StringFormat("🛡️ [DeungDang_Trade] ขยับบังหน้าทุน (BE) สำเร็จ (%d ไม้)", modified));
   else
      Print(">>> [DeungDang_Trade] ", StringFormat("ℹ️ [DeungDang_Trade] ไม้ทั้งหมดมี SL บังทุนอยู่แล้ว หรือกำไรยังไม่พ้นระยะบังทุน (%d ไม้)", totalFound));
}

void ExecutePartialClose(double pct = 0.80)
{
   m_symbol.RefreshRates();
   int closed = 0;
   int totalFound = 0;
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(minLot <= 0.0) minLot = 0.01;
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0.0) lotStep = 0.01;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || m_position.Magic() == 0))
         {
            totalFound++;
            double vol = m_position.Volume();
            double closeVol = MathFloor((vol * pct) / lotStep) * lotStep;

            if(closeVol >= minLot && (vol - closeVol) >= minLot)
            {
               if(m_trade.PositionClosePartial(m_position.Ticket(), closeVol))
                  closed++;
            }
            else
            {
               if(m_trade.PositionClose(m_position.Ticket()))
                  closed++;
            }
         }
      }
   }
   ExecuteBreakEven();
   Print(">>> [DeungDang_Trade] 💰 ปิดแบ่งกำไร 80% เรียบร้อย: ", closed, "/", totalFound, " ไม้ + ดึงบังทุน BE ทันที!");
   if(totalFound == 0)
      Print(">>> [DeungDang_Trade] ", "ℹ️ [DeungDang_Trade] ไม่มีไม้ที่กำลังถืออยู่ (0 positions)");
   else
      Print(">>> [DeungDang_Trade] ", StringFormat("💰 [DeungDang_Trade] ปิดแบ่งกำไร 80%% สำเร็จ (%d ไม้) + ขยับบังทุนเรียบร้อย", closed));
}

datetime g_LastVoiceAlertTime = 0;
int      g_LastVoiceAlertSide = 0; // 1 = Buy, -1 = Sell

void CheckVoiceAlerts()
{
   if(!InpEnableVoiceAlert) return;

   int currentVoiceSide = 0;
   if(g_IsFailedLow && g_WaveSide == 1)
      currentVoiceSide = 1;
   else if(g_IsFailedHigh && g_WaveSide == -1)
      currentVoiceSide = -1;

   // หากรอบคลื่นหลุดทรง หรือกลับเข้าสู่สภาวะปกติ ให้รีเซ็ตสถานะฝั่งเสียง เพื่อให้รอบคลื่นถัดไปส่งเสียงเตือนได้ทันที
   if(currentVoiceSide == 0)
   {
      g_LastVoiceAlertSide = 0;
      return;
   }

   datetime curTime = TimeCurrent();
   if(curTime - g_LastVoiceAlertTime < 45) return;

   if(currentVoiceSide != g_LastVoiceAlertSide)
   {
      if(currentVoiceSide == 1)
      {
         if(!PlaySound("::Files\\triam_buy.wav"))
            PlaySound("triam_buy.wav");
         Print(">>> [DeungDang_Trade] 📢 เสียงเตือน: \"เตรียม Buy นะๆ\" 🟢");
      }
      else if(currentVoiceSide == -1)
      {
         if(!PlaySound("::Files\\triam_sell.wav"))
            PlaySound("triam_sell.wav");
         Print(">>> [DeungDang_Trade] 📢 เสียงเตือน: \"เตรียม Sell นะๆ\" 🔴");
      }
      g_LastVoiceAlertTime = curTime;
      g_LastVoiceAlertSide = currentVoiceSide;
   }
}

void ExecuteCloseAll()
{
   int closed = 0;
   int totalFound = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicNumber || m_position.Magic() == 0))
         {
            totalFound++;
            if(m_trade.PositionClose(m_position.Ticket()))
               closed++;
         }
      }
   }
   g_ZoneSharedSL = 0.0;
   Print(">>> [DeungDang_Trade] ❌ ปิดหมดทุกไม้เรียบร้อย: ", closed, "/", totalFound, " ไม้");
   if(totalFound == 0)
      Print(">>> [DeungDang_Trade] ", "ℹ️ [DeungDang_Trade] ไม่มีไม้ที่กำลังถืออยู่ (0 positions)");
   else
      Print(">>> [DeungDang_Trade] ", StringFormat("❌ [DeungDang_Trade] ปิดหมดทุกไม้เรียบร้อย (%d ไม้)", closed));
}

//+------------------------------------------------------------------+
//| DRAW SWING PINPOINT POINTER ARROW & SNUG LABEL                   |
//+------------------------------------------------------------------+
void DrawSwingPinAndLabel(int index, bool isHigh, datetime t, double price, string labelStr, ENUM_SWING_TYPE labelType, color col)
{
   string arrowName = GUI_PREFIX + (isHigh ? "SW_AR_H_" : "SW_AR_L_") + IntegerToString(index);
   string textName  = GUI_PREFIX + (isHigh ? "SW_T_H_" : "SW_T_L_") + IntegerToString(index);

   // 1. Plant Down/Up Arrow DIRECTLY at the exact candle wick tip!
   ENUM_OBJECT arrowType = isHigh ? OBJ_ARROW_DOWN : OBJ_ARROW_UP;
   if(ObjectFind(0, arrowName) < 0)
   {
      ObjectCreate(0, arrowName, arrowType, 0, t, price);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, col);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   }
   else
   {
      if(ObjectGetInteger(0, arrowName, OBJPROP_TIME) != t) ObjectSetInteger(0, arrowName, OBJPROP_TIME, t);
      if(ObjectGetDouble(0, arrowName, OBJPROP_PRICE) != price) ObjectSetDouble(0, arrowName, OBJPROP_PRICE, price);
      if((color)ObjectGetInteger(0, arrowName, OBJPROP_COLOR) != col) ObjectSetInteger(0, arrowName, OBJPROP_COLOR, col);
   }

   // 2. Snug Text Label right above (for High) or below (for Low)
   double offset = 0.0;
   if(g_Asset.assetType == ASSET_CRYPTO)
      offset = price * 0.00035; // Snug ~$25-30 on BTC ($85,000)
   else if(g_Asset.assetType == ASSET_GOLD)
      offset = 18 * _Point;    // Snug ~$1.8 on Gold ($2,700)
   else
      offset = 12 * _Point;    // Snug ~1.2 pips on Forex

   double drawPrice = isHigh ? (price + offset) : (price - offset);

   string dispText = "";
   if(isHigh)
   {
      string typeDesc = (labelType == SWING_HH) ? "Weak High" : "Strong High";
      dispText = StringFormat("▼ %s • %s", labelStr, typeDesc);
   }
   else
   {
      string typeDesc = (labelType == SWING_HL) ? "Strong Low" : "Weak Low";
      dispText = StringFormat("▲ %s • %s", labelStr, typeDesc);
   }
   dispText = " " + dispText + " ";
   ENUM_ANCHOR_POINT anc = isHigh ? ANCHOR_LOWER : ANCHOR_UPPER;

   if(ObjectFind(0, textName) < 0)
   {
      ObjectCreate(0, textName, OBJ_TEXT, 0, t, drawPrice);
      ObjectSetString(0, textName, OBJPROP_TEXT, dispText);
      ObjectSetString(0, textName, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, textName, OBJPROP_COLOR, col);
      ObjectSetInteger(0, textName, OBJPROP_ANCHOR, anc);
      ObjectSetInteger(0, textName, OBJPROP_BACK, false);
      ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
   }
   else
   {
      if(ObjectGetInteger(0, textName, OBJPROP_TIME) != t) ObjectSetInteger(0, textName, OBJPROP_TIME, t);
      if(ObjectGetDouble(0, textName, OBJPROP_PRICE) != drawPrice) ObjectSetDouble(0, textName, OBJPROP_PRICE, drawPrice);
      if(ObjectGetString(0, textName, OBJPROP_TEXT) != dispText) ObjectSetString(0, textName, OBJPROP_TEXT, dispText);
      if((color)ObjectGetInteger(0, textName, OBJPROP_COLOR) != col) ObjectSetInteger(0, textName, OBJPROP_COLOR, col);
      if(ObjectGetInteger(0, textName, OBJPROP_ANCHOR) != anc) ObjectSetInteger(0, textName, OBJPROP_ANCHOR, anc);
   }
}

//+------------------------------------------------------------------+
//| DRAW STRUCTURE BREAKS (BOS & CHOCH)                              |
//+------------------------------------------------------------------+
void DrawStructureBreaks()
{
   if(!InpShowSMC_BOS)
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "SMC_BOS_");
      return;
   }

   int maxDrawBOS = 4;
   for(int i = MathMin(g_BOS_Count, maxDrawBOS); i < 15; i++)
   {
      ObjectDelete(0, GUI_PREFIX + "SMC_BOS_L_" + IntegerToString(i));
      ObjectDelete(0, GUI_PREFIX + "SMC_BOS_T_" + IntegerToString(i));
   }

   for(int i = 0; i < g_BOS_Count && i < maxDrawBOS; i++)
   {
      if(!g_BOS_Lines[i].isActive) continue;
      string lineName = GUI_PREFIX + "SMC_BOS_L_" + IntegerToString(i);
      string textName = GUI_PREFIX + "SMC_BOS_T_" + IntegerToString(i);

      if(ObjectFind(0, lineName) < 0)
      {
         ObjectCreate(0, lineName, OBJ_TREND, 0, g_BOS_Lines[i].timeStart, g_BOS_Lines[i].price, g_BOS_Lines[i].timeEnd, g_BOS_Lines[i].price);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, g_BOS_Lines[i].col);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, lineName, OBJPROP_TIME, 0) != g_BOS_Lines[i].timeStart) ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, g_BOS_Lines[i].timeStart);
         if(ObjectGetDouble(0, lineName, OBJPROP_PRICE, 0) != g_BOS_Lines[i].price) ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, g_BOS_Lines[i].price);
         if(ObjectGetInteger(0, lineName, OBJPROP_TIME, 1) != g_BOS_Lines[i].timeEnd) ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, g_BOS_Lines[i].timeEnd);
         if(ObjectGetDouble(0, lineName, OBJPROP_PRICE, 1) != g_BOS_Lines[i].price) ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, g_BOS_Lines[i].price);
         if((color)ObjectGetInteger(0, lineName, OBJPROP_COLOR) != g_BOS_Lines[i].col) ObjectSetInteger(0, lineName, OBJPROP_COLOR, g_BOS_Lines[i].col);
      }

      datetime midTime = g_BOS_Lines[i].timeStart + (datetime)((g_BOS_Lines[i].timeEnd - g_BOS_Lines[i].timeStart) / 2);
      string badgeText = (g_BOS_Lines[i].tag == "CHoCH") ? " CHoCH 🔄 " : " BOS ➔ ";

      if(ObjectFind(0, textName) < 0)
      {
         ObjectCreate(0, textName, OBJ_TEXT, 0, midTime, g_BOS_Lines[i].price);
         ObjectSetString(0, textName, OBJPROP_TEXT, badgeText);
         ObjectSetString(0, textName, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, textName, OBJPROP_COLOR, g_BOS_Lines[i].col);
         ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, textName, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, textName, OBJPROP_TIME) != midTime) ObjectSetInteger(0, textName, OBJPROP_TIME, midTime);
         if(ObjectGetDouble(0, textName, OBJPROP_PRICE) != g_BOS_Lines[i].price) ObjectSetDouble(0, textName, OBJPROP_PRICE, g_BOS_Lines[i].price);
         if(ObjectGetString(0, textName, OBJPROP_TEXT) != badgeText) ObjectSetString(0, textName, OBJPROP_TEXT, badgeText);
         if((color)ObjectGetInteger(0, textName, OBJPROP_COLOR) != g_BOS_Lines[i].col) ObjectSetInteger(0, textName, OBJPROP_COLOR, g_BOS_Lines[i].col);
      }
      ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, textName, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| 16.1 CHECK IF SPECIFIC TIMEFRAME EMA 14 IS ENABLED               |
//+------------------------------------------------------------------+
bool IsEMA14Enabled(int index)
{
   switch(index)
   {
      case 0: return InpShowEMA14_M1;
      case 1: return InpShowEMA14_M5;
      case 2: return InpShowEMA14_M15;
      case 3: return InpShowEMA14_M30;
      case 4: return InpShowEMA14_H1;
      case 5: return InpShowEMA14_H4;
      case 6: return InpShowEMA14_D1;
   }
   return false;
}

//+------------------------------------------------------------------+
//| DRAW MULTI-TF EMA 14 DOTTED LINES (M1 TO D1 - สไตล์พี่ชนัฐ 100%) |
//+------------------------------------------------------------------+
void DrawMultiTF_EMA14_Lines()
{
   if(!InpShowMultiTF_EMA14)
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "EMA14_");
      return;
   }

   datetime tStart   = TimeCurrent() - (PeriodSeconds() * 60);
   datetime tBaseEnd = TimeCurrent() + (PeriodSeconds() * 6);
   int secPerBar     = PeriodSeconds();
   double minSep     = GetChartMinLabelSepPrice();

   for(int i = 0; i < NUM_EMA14_TFS; i++)
   {
      string lineName = GUI_PREFIX + "EMA14_LINE_" + g_EMA14_Tags[i];
      string lblName  = GUI_PREFIX + "EMA14_LBL_"  + g_EMA14_Tags[i];

      if(!IsEMA14Enabled(i) || g_EMA14_Vals[i] <= 0)
      {
         ObjectDelete(0, lineName);
         ObjectDelete(0, lblName);
         continue;
      }

      double val = g_EMA14_Vals[i];
      color tfCol = InpUseTF_Colors_EMA14 ? g_EMA14_Cols[i] : InpColorEMA14_Lines;

      // Stagger line ends and label positions horizontally so labels never collide with DTD M1 labels
      double emaColTol  = (g_Asset.assetType == ASSET_CRYPTO) ? (val * 0.00045) : ((g_Asset.assetType == ASSET_GOLD) ? (30.0 * _Point) : (15.0 * _Point));
      bool nearDTDLine  = (MathAbs(val - g_DTD.shortestWickPrice) <= emaColTol ||
                           MathAbs(val - g_DTD.confirmSLPrice)    <= emaColTol ||
                           MathAbs(val - g_DTD.confirmTP1RPrice)  <= emaColTol ||
                           MathAbs(val - g_DTD.confirmTP2RPrice)  <= emaColTol ||
                           MathAbs(val - g_DTD.confirmTP3RPrice)  <= emaColTol);

      // Horizontal tier offset: check collision with earlier enabled EMAs
      int hColCount = 0;
      for(int k = 0; k < i; k++)
      {
         if(IsEMA14Enabled(k) && g_EMA14_Vals[k] > 0)
         {
            if(MathAbs(val - g_EMA14_Vals[k]) < minSep)
               hColCount++;
         }
      }

      datetime tLineEnd = tBaseEnd + (datetime)(secPerBar * 2);
      datetime tLbl     = tLineEnd + (datetime)(secPerBar * 1);

      // 1. Draw horizontal dotted EMA 14 level line
      if(ObjectFind(0, lineName) < 0)
      {
         ObjectCreate(0, lineName, OBJ_TREND, 0, tStart, val, tLineEnd, val);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, tfCol);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, lineName, OBJPROP_TIME, 0) != tStart) ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, tStart);
         if(ObjectGetDouble(0, lineName, OBJPROP_PRICE, 0) != val) ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, val);
         if(ObjectGetInteger(0, lineName, OBJPROP_TIME, 1) != tLineEnd) ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, tLineEnd);
         if(ObjectGetDouble(0, lineName, OBJPROP_PRICE, 1) != val) ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, val);
         if((color)ObjectGetInteger(0, lineName, OBJPROP_COLOR) != tfCol) ObjectSetInteger(0, lineName, OBJPROP_COLOR, tfCol);
      }

      // 2. Draw label strictly attached at the right tip of the line (Exact 100% true price, zero vertical displacement)
      string valStr  = DoubleToString(val, _Digits);
      string icon    = InpUseTF_Colors_EMA14 ? g_EMA14_Icons[i] : "●";
      string expText = StringFormat(" %s EMA 14 [%s]: %s ", icon, g_EMA14_Tags[i], valStr);

      double lblVal  = ResolveRightChartLabelPrice(val, 0);
      if(ObjectFind(0, lblName) < 0)
      {
         ObjectCreate(0, lblName, OBJ_TEXT, 0, tLbl, lblVal);
         ObjectSetString(0, lblName, OBJPROP_TEXT, expText);
         ObjectSetString(0, lblName, OBJPROP_FONT, "Segoe UI Semibold");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, tfCol);
         ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
      }
      else
      {
         if(ObjectGetInteger(0, lblName, OBJPROP_TIME) != tLbl) ObjectSetInteger(0, lblName, OBJPROP_TIME, tLbl);
         if(ObjectGetDouble(0, lblName, OBJPROP_PRICE) != lblVal) ObjectSetDouble(0, lblName, OBJPROP_PRICE, lblVal);
         if(ObjectGetString(0, lblName, OBJPROP_TEXT) != expText) ObjectSetString(0, lblName, OBJPROP_TEXT, expText);
         if((color)ObjectGetInteger(0, lblName, OBJPROP_COLOR) != tfCol) ObjectSetInteger(0, lblName, OBJPROP_COLOR, tfCol);
      }
   }
}

//+------------------------------------------------------------------+
//| 17. DRAW OBJECTS ON CHART                                        |
//+------------------------------------------------------------------+
void DrawVisualsOnChart()
{
   // 0. Recalculate & Draw Standard Fibonacci with change guards
   DrawStandardFibonacci();
   ResetChartRightLabelRegistry();

   // 1. Draw Speedlines (Zero-Ray Snug Boundaries: ไม่พุ่งทะลุขอบจอ ไม่ดิ่งหน้าผา)
   if(g_HasUpSpeedline)
   {
      string name = GUI_PREFIX + "SL_UP";
      double slope = (g_UpSL_Price2 - g_UpSL_Price1) / (double)MathMax((long)(g_UpSL_Time2 - g_UpSL_Time1), 1);
      datetime tEnd = g_IsUpSL_Broken ? TimeCurrent() : (TimeCurrent() + (PeriodSeconds() * 3));
      double   pEnd = g_UpSL_Price1 + (slope * (double)(tEnd - g_UpSL_Time1));

      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_TREND, 0, g_UpSL_Time1, g_UpSL_Price1, tEnd, pEnd);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSpeedlineUp);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, g_IsUpSL_Broken ? 1 : 2);
         ObjectSetInteger(0, name, OBJPROP_STYLE, g_IsUpSL_Broken ? STYLE_DASH : STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, name, OBJPROP_TIME, 0) != g_UpSL_Time1) ObjectSetInteger(0, name, OBJPROP_TIME, 0, g_UpSL_Time1);
         if(ObjectGetDouble(0, name, OBJPROP_PRICE, 0) != g_UpSL_Price1) ObjectSetDouble(0, name, OBJPROP_PRICE, 0, g_UpSL_Price1);
         if(ObjectGetInteger(0, name, OBJPROP_TIME, 1) != tEnd) ObjectSetInteger(0, name, OBJPROP_TIME, 1, tEnd);
         if(ObjectGetDouble(0, name, OBJPROP_PRICE, 1) != pEnd) ObjectSetDouble(0, name, OBJPROP_PRICE, 1, pEnd);
         if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != InpColorSpeedlineUp) ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSpeedlineUp);
         int expW = g_IsUpSL_Broken ? 1 : 2;
         if(ObjectGetInteger(0, name, OBJPROP_WIDTH) != expW) ObjectSetInteger(0, name, OBJPROP_WIDTH, expW);
         ENUM_LINE_STYLE expS = g_IsUpSL_Broken ? STYLE_DASH : STYLE_SOLID;
         if(ObjectGetInteger(0, name, OBJPROP_STYLE) != expS) ObjectSetInteger(0, name, OBJPROP_STYLE, expS);
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "SL_UP");
   }

   if(g_HasDnSpeedline)
   {
      string name = GUI_PREFIX + "SL_DN";
      double slope = (g_DnSL_Price2 - g_DnSL_Price1) / (double)MathMax((long)(g_DnSL_Time2 - g_DnSL_Time1), 1);
      datetime tEnd = g_IsDnSL_Broken ? TimeCurrent() : (TimeCurrent() + (PeriodSeconds() * 3));
      double   pEnd = g_DnSL_Price1 + (slope * (double)(tEnd - g_DnSL_Time1));

      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_TREND, 0, g_DnSL_Time1, g_DnSL_Price1, tEnd, pEnd);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSpeedlineDn);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, g_IsDnSL_Broken ? 1 : 2);
         ObjectSetInteger(0, name, OBJPROP_STYLE, g_IsDnSL_Broken ? STYLE_DASH : STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, name, OBJPROP_TIME, 0) != g_DnSL_Time1) ObjectSetInteger(0, name, OBJPROP_TIME, 0, g_DnSL_Time1);
         if(ObjectGetDouble(0, name, OBJPROP_PRICE, 0) != g_DnSL_Price1) ObjectSetDouble(0, name, OBJPROP_PRICE, 0, g_DnSL_Price1);
         if(ObjectGetInteger(0, name, OBJPROP_TIME, 1) != tEnd) ObjectSetInteger(0, name, OBJPROP_TIME, 1, tEnd);
         if(ObjectGetDouble(0, name, OBJPROP_PRICE, 1) != pEnd) ObjectSetDouble(0, name, OBJPROP_PRICE, 1, pEnd);
         if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != InpColorSpeedlineDn) ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSpeedlineDn);
         int expW = g_IsDnSL_Broken ? 1 : 2;
         if(ObjectGetInteger(0, name, OBJPROP_WIDTH) != expW) ObjectSetInteger(0, name, OBJPROP_WIDTH, expW);
         ENUM_LINE_STYLE expS = g_IsDnSL_Broken ? STYLE_DASH : STYLE_SOLID;
         if(ObjectGetInteger(0, name, OBJPROP_STYLE) != expS) ObjectSetInteger(0, name, OBJPROP_STYLE, expS);
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "SL_DN");
   }

   // 2. Draw Wave A-B-C Labels & Connecting Dash Lines (กำนันบอล)
   if(g_WaveFormed)
   {
      string lineAB = GUI_PREFIX + "WAVE_LINE_AB";
      color colAB   = (g_WaveSide == -1) ? C'255,80,100' : C'60,180,255';
      if(ObjectFind(0, lineAB) < 0)
      {
         ObjectCreate(0, lineAB, OBJ_TREND, 0, g_WaveA_Time, g_WaveA_Price, g_WaveB_Time, g_WaveB_Price);
         ObjectSetInteger(0, lineAB, OBJPROP_COLOR, colAB);
         ObjectSetInteger(0, lineAB, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, lineAB, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineAB, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineAB, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0) != g_WaveA_Time) ObjectSetInteger(0, lineAB, OBJPROP_TIME, 0, g_WaveA_Time);
         if(ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0) != g_WaveA_Price) ObjectSetDouble(0, lineAB, OBJPROP_PRICE, 0, g_WaveA_Price);
         if(ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1) != g_WaveB_Time) ObjectSetInteger(0, lineAB, OBJPROP_TIME, 1, g_WaveB_Time);
         if(ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1) != g_WaveB_Price) ObjectSetDouble(0, lineAB, OBJPROP_PRICE, 1, g_WaveB_Price);
         if((color)ObjectGetInteger(0, lineAB, OBJPROP_COLOR) != colAB) ObjectSetInteger(0, lineAB, OBJPROP_COLOR, colAB);
      }

      if(g_WaveC_Time > g_WaveB_Time && g_WaveC_Price > 0)
      {
         string lineBC = GUI_PREFIX + "WAVE_LINE_BC";
         if(ObjectFind(0, lineBC) < 0)
         {
            ObjectCreate(0, lineBC, OBJ_TREND, 0, g_WaveB_Time, g_WaveB_Price, g_WaveC_Time, g_WaveC_Price);
            ObjectSetInteger(0, lineBC, OBJPROP_COLOR, clrGold);
            ObjectSetInteger(0, lineBC, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, lineBC, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lineBC, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lineBC, OBJPROP_BACK, true);
         }
         else
         {
            if(ObjectGetInteger(0, lineBC, OBJPROP_TIME, 0) != g_WaveB_Time) ObjectSetInteger(0, lineBC, OBJPROP_TIME, 0, g_WaveB_Time);
            if(ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 0) != g_WaveB_Price) ObjectSetDouble(0, lineBC, OBJPROP_PRICE, 0, g_WaveB_Price);
            if(ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1) != g_WaveC_Time) ObjectSetInteger(0, lineBC, OBJPROP_TIME, 1, g_WaveC_Time);
            if(ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1) != g_WaveC_Price) ObjectSetDouble(0, lineBC, OBJPROP_PRICE, 1, g_WaveC_Price);
         }
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_BC");
      }

      string lblA = (g_WaveSide == -1) ? "◆ คลื่น A (ยอดกวาดเหยื่อ)" : "◆ คลื่น A (ก้นกวาดเหยื่อ)";
      string nameA = GUI_PREFIX + "WAVE_A";
      color colA = (g_WaveSide == -1) ? clrCrimson : clrDeepSkyBlue;
      ENUM_ANCHOR_POINT ancA = (g_WaveSide == -1) ? ANCHOR_LOWER : ANCHOR_UPPER;
      if(ObjectFind(0, nameA) < 0)
      {
         ObjectCreate(0, nameA, OBJ_TEXT, 0, g_WaveA_Time, g_WaveA_Price);
         ObjectSetString(0, nameA, OBJPROP_TEXT, lblA);
         ObjectSetInteger(0, nameA, OBJPROP_COLOR, colA);
         ObjectSetInteger(0, nameA, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, nameA, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, nameA, OBJPROP_ANCHOR, ancA);
         ObjectSetInteger(0, nameA, OBJPROP_BACK, false);
      }
      else
      {
         if(ObjectGetInteger(0, nameA, OBJPROP_TIME) != g_WaveA_Time) ObjectSetInteger(0, nameA, OBJPROP_TIME, g_WaveA_Time);
         if(ObjectGetDouble(0, nameA, OBJPROP_PRICE) != g_WaveA_Price) ObjectSetDouble(0, nameA, OBJPROP_PRICE, g_WaveA_Price);
         if(ObjectGetString(0, nameA, OBJPROP_TEXT) != lblA) ObjectSetString(0, nameA, OBJPROP_TEXT, lblA);
         if((color)ObjectGetInteger(0, nameA, OBJPROP_COLOR) != colA) ObjectSetInteger(0, nameA, OBJPROP_COLOR, colA);
         if(ObjectGetInteger(0, nameA, OBJPROP_ANCHOR) != ancA) ObjectSetInteger(0, nameA, OBJPROP_ANCHOR, ancA);
      }

      string lblB = (g_WaveSide == -1) ? "▼ คลื่น B (ทุบทะลุสปีดไลน์)" : "▲ คลื่น B (ดีดทะลุสปีดไลน์)";
      string nameB = GUI_PREFIX + "WAVE_B";
      ENUM_ANCHOR_POINT ancB = (g_WaveSide == -1) ? ANCHOR_UPPER : ANCHOR_LOWER;
      if(ObjectFind(0, nameB) < 0)
      {
         ObjectCreate(0, nameB, OBJ_TEXT, 0, g_WaveB_Time, g_WaveB_Price);
         ObjectSetString(0, nameB, OBJPROP_TEXT, lblB);
         ObjectSetInteger(0, nameB, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, nameB, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, nameB, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, nameB, OBJPROP_ANCHOR, ancB);
         ObjectSetInteger(0, nameB, OBJPROP_BACK, false);
      }
      else
      {
         if(ObjectGetInteger(0, nameB, OBJPROP_TIME) != g_WaveB_Time) ObjectSetInteger(0, nameB, OBJPROP_TIME, g_WaveB_Time);
         if(ObjectGetDouble(0, nameB, OBJPROP_PRICE) != g_WaveB_Price) ObjectSetDouble(0, nameB, OBJPROP_PRICE, g_WaveB_Price);
         if(ObjectGetString(0, nameB, OBJPROP_TEXT) != lblB) ObjectSetString(0, nameB, OBJPROP_TEXT, lblB);
         if(ObjectGetInteger(0, nameB, OBJPROP_ANCHOR) != ancB) ObjectSetInteger(0, nameB, OBJPROP_ANCHOR, ancB);
      }

      string lblC = (g_WaveSide == -1) ? "🎯 คลื่น C (ยอดเตี้ยลง - ขาดการเบรกไฮ)" : "🎯 คลื่น C (ก้นยกตัว - ขาดการหลุดโล)";
      string nameC = GUI_PREFIX + "WAVE_C";
      ENUM_ANCHOR_POINT ancC = (g_WaveSide == -1) ? ANCHOR_LOWER : ANCHOR_UPPER;
      if(ObjectFind(0, nameC) < 0)
      {
         ObjectCreate(0, nameC, OBJ_TEXT, 0, g_WaveC_Time, g_WaveC_Price);
         ObjectSetString(0, nameC, OBJPROP_TEXT, lblC);
         ObjectSetInteger(0, nameC, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, nameC, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, nameC, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, nameC, OBJPROP_ANCHOR, ancC);
         ObjectSetInteger(0, nameC, OBJPROP_BACK, false);
      }
      else
      {
         if(ObjectGetInteger(0, nameC, OBJPROP_TIME) != g_WaveC_Time) ObjectSetInteger(0, nameC, OBJPROP_TIME, g_WaveC_Time);
         if(ObjectGetDouble(0, nameC, OBJPROP_PRICE) != g_WaveC_Price) ObjectSetDouble(0, nameC, OBJPROP_PRICE, g_WaveC_Price);
         if(ObjectGetString(0, nameC, OBJPROP_TEXT) != lblC) ObjectSetString(0, nameC, OBJPROP_TEXT, lblC);
         if(ObjectGetInteger(0, nameC, OBJPROP_ANCHOR) != ancC) ObjectSetInteger(0, nameC, OBJPROP_ANCHOR, ancC);
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "WAVE_A");
      ObjectDelete(0, GUI_PREFIX + "WAVE_B");
      ObjectDelete(0, GUI_PREFIX + "WAVE_C");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_AB");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_BC");
      ObjectDelete(0, GUI_PREFIX + "WAVE_LINE_CD");
      ObjectDelete(0, GUI_PREFIX + "WAVE_D_1618");
      ObjectDelete(0, GUI_PREFIX + "WAVE_D_LBL");
   }

   // 2.5 Draw Wave D Extension Targets (EP เสริม 4)
   string lineCD = GUI_PREFIX + "WAVE_LINE_CD";
   string lineD2 = GUI_PREFIX + "WAVE_D_1618";
   string lblD   = GUI_PREFIX + "WAVE_D_LBL";

   if(g_HasWave_D && InpDrawWave_D_Lines && g_WaveC_Time > 0 && g_WaveC_Price > 0)
   {
      datetime tTarget = TimeCurrent() + (PeriodSeconds() * 18);

      if(ObjectFind(0, lineCD) < 0)
      {
         ObjectCreate(0, lineCD, OBJ_TREND, 0, g_WaveC_Time, g_WaveC_Price, tTarget, g_WaveD_1618);
         ObjectSetInteger(0, lineCD, OBJPROP_COLOR, InpColorWave_D_Target);
         ObjectSetInteger(0, lineCD, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineCD, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineCD, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineCD, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, lineCD, OBJPROP_TIME, 0) != g_WaveC_Time) ObjectSetInteger(0, lineCD, OBJPROP_TIME, 0, g_WaveC_Time);
         if(ObjectGetDouble(0, lineCD, OBJPROP_PRICE, 0) != g_WaveC_Price) ObjectSetDouble(0, lineCD, OBJPROP_PRICE, 0, g_WaveC_Price);
         if(ObjectGetInteger(0, lineCD, OBJPROP_TIME, 1) != tTarget) ObjectSetInteger(0, lineCD, OBJPROP_TIME, 1, tTarget);
         if(ObjectGetDouble(0, lineCD, OBJPROP_PRICE, 1) != g_WaveD_1618) ObjectSetDouble(0, lineCD, OBJPROP_PRICE, 1, g_WaveD_1618);
         if((color)ObjectGetInteger(0, lineCD, OBJPROP_COLOR) != InpColorWave_D_Target) ObjectSetInteger(0, lineCD, OBJPROP_COLOR, InpColorWave_D_Target);
      }

      datetime tLineStart = g_WaveC_Time;
      datetime tLineEnd   = TimeCurrent() + (PeriodSeconds() * 30);
      datetime tLbl       = TimeCurrent() + (PeriodSeconds() * 6);

      if(ObjectFind(0, lineD2) < 0)
      {
         ObjectCreate(0, lineD2, OBJ_TREND, 0, tLineStart, g_WaveD_1618, tLineEnd, g_WaveD_1618);
         ObjectSetInteger(0, lineD2, OBJPROP_COLOR, InpColorWave_D_Target);
         ObjectSetInteger(0, lineD2, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetInteger(0, lineD2, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, lineD2, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, lineD2, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, lineD2, OBJPROP_TIME, 0) != tLineStart) ObjectSetInteger(0, lineD2, OBJPROP_TIME, 0, tLineStart);
         if(ObjectGetDouble(0, lineD2, OBJPROP_PRICE, 0) != g_WaveD_1618) ObjectSetDouble(0, lineD2, OBJPROP_PRICE, 0, g_WaveD_1618);
         if(ObjectGetInteger(0, lineD2, OBJPROP_TIME, 1) != tLineEnd) ObjectSetInteger(0, lineD2, OBJPROP_TIME, 1, tLineEnd);
         if(ObjectGetDouble(0, lineD2, OBJPROP_PRICE, 1) != g_WaveD_1618) ObjectSetDouble(0, lineD2, OBJPROP_PRICE, 1, g_WaveD_1618);
      }

      double curPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ptsToD   = MathAbs(g_WaveD_1618 - curPrice) / _Point;
      string dText    = StringFormat("  🎯 [EP4] ขา D (161.8%%) %s (+%s)", DoubleToString(g_WaveD_1618, _Digits), FormatMoneyOrPoints(ptsToD));
      double dLblPrice = ResolveRightChartLabelPrice(g_WaveD_1618, (g_WaveSide == 1 ? 1 : -1));

      if(ObjectFind(0, lblD) < 0)
      {
         ObjectCreate(0, lblD, OBJ_TEXT, 0, tLbl, dLblPrice);
         ObjectSetString(0, lblD, OBJPROP_TEXT, dText);
         ObjectSetInteger(0, lblD, OBJPROP_COLOR, InpColorWave_D_Target);
         ObjectSetInteger(0, lblD, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, lblD, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, lblD, OBJPROP_ANCHOR, (g_WaveSide == 1 ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER));
         ObjectSetInteger(0, lblD, OBJPROP_BACK, false);
      }
      else
      {
         if(ObjectGetInteger(0, lblD, OBJPROP_TIME) != tLbl) ObjectSetInteger(0, lblD, OBJPROP_TIME, tLbl);
         if(ObjectGetDouble(0, lblD, OBJPROP_PRICE) != dLblPrice) ObjectSetDouble(0, lblD, OBJPROP_PRICE, dLblPrice);
         if(ObjectGetString(0, lblD, OBJPROP_TEXT) != dText) ObjectSetString(0, lblD, OBJPROP_TEXT, dText);
      }
   }
   else
   {
      ObjectDelete(0, lineCD);
      ObjectDelete(0, lineD2);
      ObjectDelete(0, lblD);
   }

   // 2.6 Draw Fakeout Trap Alert (EP เสริม 4)
   string trapIconName = GUI_PREFIX + "TRAP_ICON";
   if(g_IsFakeoutTrap && InpUseFakeoutTrapRadar && g_FakeoutTime > 0 && g_FakeoutPrice > 0)
   {
      string trapIcon = (g_FakeoutSide == 1) ? "👆 [EP4] กลับตัวลงหลอก! (Bear Trap -> กด BUY)" : "👇 [EP4] กลับตัวขึ้นหลอก! (Bull Trap -> กด SELL)";
      color trapCol   = (g_FakeoutSide == 1) ? C'50,255,150' : C'255,80,100';
      ENUM_ANCHOR_POINT trapAnc = (g_FakeoutSide == 1) ? ANCHOR_UPPER : ANCHOR_LOWER;

      if(ObjectFind(0, trapIconName) < 0)
      {
         ObjectCreate(0, trapIconName, OBJ_TEXT, 0, g_FakeoutTime, g_FakeoutPrice);
         ObjectSetString(0, trapIconName, OBJPROP_TEXT, trapIcon);
         ObjectSetInteger(0, trapIconName, OBJPROP_COLOR, trapCol);
         ObjectSetInteger(0, trapIconName, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, trapIconName, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, trapIconName, OBJPROP_ANCHOR, trapAnc);
         ObjectSetInteger(0, trapIconName, OBJPROP_BACK, false);
      }
      else
      {
         if(ObjectGetInteger(0, trapIconName, OBJPROP_TIME) != g_FakeoutTime) ObjectSetInteger(0, trapIconName, OBJPROP_TIME, g_FakeoutTime);
         if(ObjectGetDouble(0, trapIconName, OBJPROP_PRICE) != g_FakeoutPrice) ObjectSetDouble(0, trapIconName, OBJPROP_PRICE, g_FakeoutPrice);
         if(ObjectGetString(0, trapIconName, OBJPROP_TEXT) != trapIcon) ObjectSetString(0, trapIconName, OBJPROP_TEXT, trapIcon);
         if((color)ObjectGetInteger(0, trapIconName, OBJPROP_COLOR) != trapCol) ObjectSetInteger(0, trapIconName, OBJPROP_COLOR, trapCol);
         if(ObjectGetInteger(0, trapIconName, OBJPROP_ANCHOR) != trapAnc) ObjectSetInteger(0, trapIconName, OBJPROP_ANCHOR, trapAnc);
      }
   }
   else
   {
      ObjectDelete(0, trapIconName);
   }

   // 3. Draw Samurai Exact Wicks Channel
   if(InpEnableLRLChannel && g_LRL.curMid > 0)
   {
      string nameUp = GUI_PREFIX + "LRL_UP";
      if(ObjectFind(0, nameUp) < 0)
      {
         ObjectCreate(0, nameUp, OBJ_TREND, 0, g_LRL.tStart, g_LRL.pStartUp, g_LRL.tEnd, g_LRL.pEndUp);
         ObjectSetInteger(0, nameUp, OBJPROP_COLOR, C'255,80,90');
         ObjectSetInteger(0, nameUp, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, nameUp, OBJPROP_RAY_RIGHT, false);
      }
      else
      {
         if(ObjectGetInteger(0, nameUp, OBJPROP_TIME, 0) != g_LRL.tStart) ObjectSetInteger(0, nameUp, OBJPROP_TIME, 0, g_LRL.tStart);
         if(ObjectGetDouble(0, nameUp, OBJPROP_PRICE, 0) != g_LRL.pStartUp) ObjectSetDouble(0, nameUp, OBJPROP_PRICE, 0, g_LRL.pStartUp);
         if(ObjectGetInteger(0, nameUp, OBJPROP_TIME, 1) != g_LRL.tEnd) ObjectSetInteger(0, nameUp, OBJPROP_TIME, 1, g_LRL.tEnd);
         if(ObjectGetDouble(0, nameUp, OBJPROP_PRICE, 1) != g_LRL.pEndUp) ObjectSetDouble(0, nameUp, OBJPROP_PRICE, 1, g_LRL.pEndUp);
      }

      string nameMid = GUI_PREFIX + "LRL_MID";
      if(ObjectFind(0, nameMid) < 0)
      {
         ObjectCreate(0, nameMid, OBJ_TREND, 0, g_LRL.tStart, g_LRL.pStartMid, g_LRL.tEnd, g_LRL.pEndMid);
         ObjectSetInteger(0, nameMid, OBJPROP_COLOR, clrAqua);
         ObjectSetInteger(0, nameMid, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, nameMid, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, nameMid, OBJPROP_RAY_RIGHT, false);
      }
      else
      {
         if(ObjectGetInteger(0, nameMid, OBJPROP_TIME, 0) != g_LRL.tStart) ObjectSetInteger(0, nameMid, OBJPROP_TIME, 0, g_LRL.tStart);
         if(ObjectGetDouble(0, nameMid, OBJPROP_PRICE, 0) != g_LRL.pStartMid) ObjectSetDouble(0, nameMid, OBJPROP_PRICE, 0, g_LRL.pStartMid);
         if(ObjectGetInteger(0, nameMid, OBJPROP_TIME, 1) != g_LRL.tEnd) ObjectSetInteger(0, nameMid, OBJPROP_TIME, 1, g_LRL.tEnd);
         if(ObjectGetDouble(0, nameMid, OBJPROP_PRICE, 1) != g_LRL.pEndMid) ObjectSetDouble(0, nameMid, OBJPROP_PRICE, 1, g_LRL.pEndMid);
      }

      string nameDn = GUI_PREFIX + "LRL_DN";
      if(ObjectFind(0, nameDn) < 0)
      {
         ObjectCreate(0, nameDn, OBJ_TREND, 0, g_LRL.tStart, g_LRL.pStartDn, g_LRL.tEnd, g_LRL.pEndDn);
         ObjectSetInteger(0, nameDn, OBJPROP_COLOR, C'50,220,120');
         ObjectSetInteger(0, nameDn, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, nameDn, OBJPROP_RAY_RIGHT, false);
      }
      else
      {
         if(ObjectGetInteger(0, nameDn, OBJPROP_TIME, 0) != g_LRL.tStart) ObjectSetInteger(0, nameDn, OBJPROP_TIME, 0, g_LRL.tStart);
         if(ObjectGetDouble(0, nameDn, OBJPROP_PRICE, 0) != g_LRL.pStartDn) ObjectSetDouble(0, nameDn, OBJPROP_PRICE, 0, g_LRL.pStartDn);
         if(ObjectGetInteger(0, nameDn, OBJPROP_TIME, 1) != g_LRL.tEnd) ObjectSetInteger(0, nameDn, OBJPROP_TIME, 1, g_LRL.tEnd);
         if(ObjectGetDouble(0, nameDn, OBJPROP_PRICE, 1) != g_LRL.pEndDn) ObjectSetDouble(0, nameDn, OBJPROP_PRICE, 1, g_LRL.pEndDn);
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "LRL_UP");
      ObjectDelete(0, GUI_PREFIX + "LRL_MID");
      ObjectDelete(0, GUI_PREFIX + "LRL_DN");
   }

   // 4. Draw Multi-Timeframe Demand & Supply Zones (Flagship EA Master Engine - Stable In-Place Rendering)
   static int s_prevDrawnZoneCount = 0;
   int drawnZones = 0;
   int tfSec = PeriodSeconds((ENUM_TIMEFRAMES)_Period);

   for(int i = 0; i < g_ZoneCount; i++)
   {
      if(!g_Zones[i].isActive) continue;
      string boxName = GUI_PREFIX + "ZONE_" + IntegerToString(drawnZones);
      string lblName = GUI_PREFIX + "ZONE_TAG_" + IntegerToString(drawnZones);

      datetime t2 = TimeCurrent() + (tfSec * 25);

      if(ObjectFind(0, boxName) < 0)
      {
         ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, g_Zones[i].time, g_Zones[i].high, t2, g_Zones[i].low);
         ObjectSetInteger(0, boxName, OBJPROP_COLOR, g_Zones[i].boxColor);
         ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
         ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, boxName, OBJPROP_TIME, 0) != g_Zones[i].time) ObjectSetInteger(0, boxName, OBJPROP_TIME, 0, g_Zones[i].time);
         if(ObjectGetDouble(0, boxName, OBJPROP_PRICE, 0) != g_Zones[i].high) ObjectSetDouble(0, boxName, OBJPROP_PRICE, 0, g_Zones[i].high);
         if(ObjectGetInteger(0, boxName, OBJPROP_TIME, 1) != t2) ObjectSetInteger(0, boxName, OBJPROP_TIME, 1, t2);
         if(ObjectGetDouble(0, boxName, OBJPROP_PRICE, 1) != g_Zones[i].low) ObjectSetDouble(0, boxName, OBJPROP_PRICE, 1, g_Zones[i].low);
         if((color)ObjectGetInteger(0, boxName, OBJPROP_COLOR) != g_Zones[i].boxColor) ObjectSetInteger(0, boxName, OBJPROP_COLOR, g_Zones[i].boxColor);
      }

      // Center text vertically inside zone box, placed with horizontal stagger
      double labelPrice  = (g_Zones[i].high + g_Zones[i].low) / 2.0;
      datetime safeRight = TimeCurrent() - (tfSec * (14 + (drawnZones * 4)));
      datetime labelTime = MathMax(g_Zones[i].time + (tfSec * 2), safeRight);
      string tagText     = " " + (g_Zones[i].isDemand ? "Demand " : "Supply ") + g_Zones[i].tfName + " ";

      if(ObjectFind(0, lblName) < 0)
      {
         ObjectCreate(0, lblName, OBJ_TEXT, 0, labelTime, labelPrice);
         ObjectSetString(0, lblName, OBJPROP_TEXT, tagText);
         ObjectSetString(0, lblName, OBJPROP_FONT, "Segoe UI Bold");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
      }
      else
      {
         if(ObjectGetInteger(0, lblName, OBJPROP_TIME) != labelTime) ObjectSetInteger(0, lblName, OBJPROP_TIME, labelTime);
         if(ObjectGetDouble(0, lblName, OBJPROP_PRICE) != labelPrice) ObjectSetDouble(0, lblName, OBJPROP_PRICE, labelPrice);
         if(ObjectGetString(0, lblName, OBJPROP_TEXT) != tagText) ObjectSetString(0, lblName, OBJPROP_TEXT, tagText);
      }
      drawnZones++;
   }

   // Cleanup only unused zone boxes from previous cycle
   for(int i = drawnZones; i < s_prevDrawnZoneCount; i++)
   {
      ObjectDelete(0, GUI_PREFIX + "ZONE_" + IntegerToString(i));
      ObjectDelete(0, GUI_PREFIX + "ZONE_TAG_" + IntegerToString(i));
   }
   s_prevDrawnZoneCount = drawnZones;

   // 5. Draw Hidden Blade Lines (Clean Fresh Blades Only - Stable In-Place Rendering)
   static int s_prevBladeCount = 0;
   int drawnBlades = 0;
   for(int i = 0; i < g_BladeCount && i < 2; i++)
   {
      string name = GUI_PREFIX + "BLADE_" + IntegerToString(drawnBlades);
      string lbl  = GUI_PREFIX + "BLADE_LBL_" + IntegerToString(drawnBlades);
      datetime tEnd = TimeCurrent() + (PeriodSeconds() * 35);
      datetime tTag = MathMax(g_Blades[i].time, TimeCurrent() - (PeriodSeconds() * 15));
      string bladeTxt = "🗡️ Hidden Blade 50% [" + g_Blades[i].tfName + "]";

      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_TREND, 0, g_Blades[i].time, g_Blades[i].price50, tEnd, g_Blades[i].price50);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorHiddenBlade);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      }
      else
      {
         if(ObjectGetInteger(0, name, OBJPROP_TIME, 0) != g_Blades[i].time) ObjectSetInteger(0, name, OBJPROP_TIME, 0, g_Blades[i].time);
         if(ObjectGetDouble(0, name, OBJPROP_PRICE, 0) != g_Blades[i].price50) ObjectSetDouble(0, name, OBJPROP_PRICE, 0, g_Blades[i].price50);
         if(ObjectGetInteger(0, name, OBJPROP_TIME, 1) != tEnd) ObjectSetInteger(0, name, OBJPROP_TIME, 1, tEnd);
         if(ObjectGetDouble(0, name, OBJPROP_PRICE, 1) != g_Blades[i].price50) ObjectSetDouble(0, name, OBJPROP_PRICE, 1, g_Blades[i].price50);
      }

      if(ObjectFind(0, lbl) < 0)
      {
         ObjectCreate(0, lbl, OBJ_TEXT, 0, tTag, g_Blades[i].price50);
         ObjectSetString(0, lbl, OBJPROP_TEXT, bladeTxt);
         ObjectSetInteger(0, lbl, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
      }
      else
      {
         if(ObjectGetInteger(0, lbl, OBJPROP_TIME) != tTag) ObjectSetInteger(0, lbl, OBJPROP_TIME, tTag);
         if(ObjectGetDouble(0, lbl, OBJPROP_PRICE) != g_Blades[i].price50) ObjectSetDouble(0, lbl, OBJPROP_PRICE, g_Blades[i].price50);
         if(ObjectGetString(0, lbl, OBJPROP_TEXT) != bladeTxt) ObjectSetString(0, lbl, OBJPROP_TEXT, bladeTxt);
      }
      drawnBlades++;
   }

   for(int i = drawnBlades; i < s_prevBladeCount; i++)
   {
      ObjectDelete(0, GUI_PREFIX + "BLADE_" + IntegerToString(i));
      ObjectDelete(0, GUI_PREFIX + "BLADE_LBL_" + IntegerToString(i));
   }
   s_prevBladeCount = drawnBlades;

   // 6. Draw ICT Unicorn Box (Stable In-Place Rendering)
   if(g_HasUnicorn)
   {
      color boxColor = (g_UnicornSide == 1) ? C'0,120,60' : ((g_UnicornSide == -1) ? C'160,30,40' : InpColorUnicorn);
      color lblColor = (g_UnicornSide == 1) ? C'0,255,136' : ((g_UnicornSide == -1) ? C'255,80,90' : C'220,180,255');
      string lblTxt  = (g_UnicornSide == 1) ? "🦄 ICT Unicorn [ 🟢 BUY ] (Breaker Block + Bullish FVG)" 
                                            : ((g_UnicornSide == -1) ? "🦄 ICT Unicorn [ 🔴 SELL ] (Breaker Block + Bearish FVG)" 
                                                                     : "🦄 ICT Unicorn (Breaker Block + FVG)");

      string name = GUI_PREFIX + "UNICORN_BOX";
      datetime tStart = TimeCurrent() - (PeriodSeconds() * 10);
      datetime tEnd   = TimeCurrent() + (PeriodSeconds() * 25);

      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, tStart, g_UnicornHigh, tEnd, g_UnicornLow);
         ObjectSetInteger(0, name, OBJPROP_COLOR, boxColor);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
      }
      else
      {
         if(ObjectGetInteger(0, name, OBJPROP_TIME, 0) != tStart) ObjectSetInteger(0, name, OBJPROP_TIME, 0, tStart);
         if(ObjectGetDouble(0, name, OBJPROP_PRICE, 0) != g_UnicornHigh) ObjectSetDouble(0, name, OBJPROP_PRICE, 0, g_UnicornHigh);
         if(ObjectGetInteger(0, name, OBJPROP_TIME, 1) != tEnd) ObjectSetInteger(0, name, OBJPROP_TIME, 1, tEnd);
         if(ObjectGetDouble(0, name, OBJPROP_PRICE, 1) != g_UnicornLow) ObjectSetDouble(0, name, OBJPROP_PRICE, 1, g_UnicornLow);
         if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != boxColor) ObjectSetInteger(0, name, OBJPROP_COLOR, boxColor);
      }

      string lbl = GUI_PREFIX + "UNICORN_LBL";
      if(ObjectFind(0, lbl) < 0)
      {
         ObjectCreate(0, lbl, OBJ_TEXT, 0, tStart, g_UnicornHigh);
         ObjectSetString(0, lbl, OBJPROP_TEXT, lblTxt);
         ObjectSetInteger(0, lbl, OBJPROP_COLOR, lblColor);
         ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
      }
      else
      {
         if(ObjectGetInteger(0, lbl, OBJPROP_TIME) != tStart) ObjectSetInteger(0, lbl, OBJPROP_TIME, tStart);
         if(ObjectGetDouble(0, lbl, OBJPROP_PRICE) != g_UnicornHigh) ObjectSetDouble(0, lbl, OBJPROP_PRICE, g_UnicornHigh);
         if(ObjectGetString(0, lbl, OBJPROP_TEXT) != lblTxt) ObjectSetString(0, lbl, OBJPROP_TEXT, lblTxt);
         if((color)ObjectGetInteger(0, lbl, OBJPROP_COLOR) != lblColor) ObjectSetInteger(0, lbl, OBJPROP_COLOR, lblColor);
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "UNICORN_BOX");
      ObjectDelete(0, GUI_PREFIX + "UNICORN_LBL");
   }

   // 7. Dynamic Target Lines
   if(g_TargetSL > 0)
   {
      string name = GUI_PREFIX + "LINE_SL";
      string slTxt = StringFormat("🛑 SL: %s", DoubleToString(g_TargetSL, _Digits));
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, g_TargetSL);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrCrimson);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetString(0, name, OBJPROP_TEXT, slTxt);
      }
      else
      {
         if(ObjectGetDouble(0, name, OBJPROP_PRICE) != g_TargetSL) ObjectSetDouble(0, name, OBJPROP_PRICE, g_TargetSL);
         if(ObjectGetString(0, name, OBJPROP_TEXT) != slTxt) ObjectSetString(0, name, OBJPROP_TEXT, slTxt);
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "LINE_SL");
   }

   if(g_TargetTP1 > 0)
   {
      string name = GUI_PREFIX + "LINE_TP1";
      string tp1Txt = StringFormat("🏆 TP1 (จุด B): %s", DoubleToString(g_TargetTP1, _Digits));
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, g_TargetTP1);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrLimeGreen);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetString(0, name, OBJPROP_TEXT, tp1Txt);
      }
      else
      {
         if(ObjectGetDouble(0, name, OBJPROP_PRICE) != g_TargetTP1) ObjectSetDouble(0, name, OBJPROP_PRICE, g_TargetTP1);
         if(ObjectGetString(0, name, OBJPROP_TEXT) != tp1Txt) ObjectSetString(0, name, OBJPROP_TEXT, tp1Txt);
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "LINE_TP1");
   }

   if(g_TargetTP2 > 0)
   {
      string name = GUI_PREFIX + "LINE_TP2";
      string tp2Txt = StringFormat("🏆 TP2 (Fibo 161.8%%): %s", DoubleToString(g_TargetTP2, _Digits));
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, g_TargetTP2);
         ObjectSetInteger(0, name, OBJPROP_COLOR, C'50,225,130');
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetString(0, name, OBJPROP_TEXT, tp2Txt);
      }
      else
      {
         if(ObjectGetDouble(0, name, OBJPROP_PRICE) != g_TargetTP2) ObjectSetDouble(0, name, OBJPROP_PRICE, g_TargetTP2);
         if(ObjectGetString(0, name, OBJPROP_TEXT) != tp2Txt) ObjectSetString(0, name, OBJPROP_TEXT, tp2Txt);
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "LINE_TP2");
   }

   // 8. Swing Labels & Pinpoint Arrows (Weak High / Strong High / Strong Low / Weak Low)
   int drawnH = 0;
   int drawnL = 0;
   int lastBarH = -999;
   int lastBarL = -999;

   for(int i = 0; i < g_SwingCount; i++)
   {
      // ป้องกันป้าย HH/HL/LH/LL ชนทับกับป้าย คลื่น A / คลื่น B / คลื่น C และป้าย 1.RETEST / 2.CF
      if(g_WaveFormed)
      {
         int waveProxSec = tfSec * 8;
         if(MathAbs((long)(g_Swings[i].time - g_WaveA_Time)) <= waveProxSec ||
            MathAbs((long)(g_Swings[i].time - g_WaveB_Time)) <= waveProxSec ||
            MathAbs((long)(g_Swings[i].time - g_WaveC_Time)) <= waveProxSec)
         {
            continue;
         }
      }
      if(InpUseDTD_CF_M1 && InpDrawDTD_CandleStickers)
      {
         int dtdProxSec = tfSec * 4;
         if((g_DTD.retestBarTime > 0 && MathAbs((long)(g_Swings[i].time - g_DTD.retestBarTime)) <= dtdProxSec) ||
            (g_DTD.confirmBarTime > 0 && MathAbs((long)(g_Swings[i].time - g_DTD.confirmBarTime)) <= dtdProxSec))
         {
            continue;
         }
      }

      if(g_Swings[i].isHigh && drawnH < 3)
      {
         // Enforce minimum 8 bars distance between successive swing highs to avoid clutter
         if(lastBarH == -999 || MathAbs(g_Swings[i].bar - lastBarH) >= 8)
         {
            color col = (g_Swings[i].labelType == SWING_HH) ? clrLime : clrTomato;
            DrawSwingPinAndLabel(drawnH, true, g_Swings[i].time, g_Swings[i].price, g_Swings[i].labelStr, g_Swings[i].labelType, col);
            lastBarH = g_Swings[i].bar;
            drawnH++;
         }
      }
      else if(!g_Swings[i].isHigh && drawnL < 3)
      {
         // Enforce minimum 8 bars distance between successive swing lows to avoid clutter
         if(lastBarL == -999 || MathAbs(g_Swings[i].bar - lastBarL) >= 8)
         {
            color col = (g_Swings[i].labelType == SWING_HL) ? clrLime : clrTomato;
            DrawSwingPinAndLabel(drawnL, false, g_Swings[i].time, g_Swings[i].price, g_Swings[i].labelStr, g_Swings[i].labelType, col);
            lastBarL = g_Swings[i].bar;
            drawnL++;
         }
      }
      if(drawnH >= 3 && drawnL >= 3) break;
   }

   // Cleanup unused arrows & text labels
   for(int i = drawnH; i < 8; i++)
   {
      ObjectDelete(0, GUI_PREFIX + "SW_AR_H_" + IntegerToString(i));
      ObjectDelete(0, GUI_PREFIX + "SW_T_H_" + IntegerToString(i));
      ObjectDelete(0, GUI_PREFIX + "SW_H_" + IntegerToString(i));
   }
   for(int i = drawnL; i < 8; i++)
   {
      ObjectDelete(0, GUI_PREFIX + "SW_AR_L_" + IntegerToString(i));
      ObjectDelete(0, GUI_PREFIX + "SW_T_L_" + IntegerToString(i));
      ObjectDelete(0, GUI_PREFIX + "SW_L_" + IntegerToString(i));
   }

   // 9. Structure Break Lines & Badges (BOS / CHoCH)
   DrawStructureBreaks();

   // 10. DTD M1 Confirmation Visuals & 1R:3R TradingView Box (First priority on right chart)
   DrawDTD_M1_Visuals();

   // 11. Institutional Multi-Timeframe Liquidity (BSL & SSL) Visuals
   DrawLiquidityVisuals();

   // 12. CME Options Walls & Open Interest Matrix (Red Resistance & Blue Support)
   DrawCME_OptionsWalls();

   // 13. Multi-TF EMA 14 Dotted Lines (H1 & H4)
   DrawMultiTF_EMA14_Lines();

   // 14. Gann Equilibrium Grid & Zero Origin Line (ตารางตาข่ายสมดุลราคาและเวลา 45°)
   DrawGannEquilibriumGrid();
}

//+------------------------------------------------------------------+
//| 18. CLEANUP ALL VISUAL OBJECTS                                   |
//+------------------------------------------------------------------+
void CleanupVisuals()
{
   ObjectsDeleteAll(0, GUI_PREFIX);
}

//+------------------------------------------------------------------+
//| 19. SUBWINDOW & HUD HELPER FUNCTIONS                             |
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
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
   }
   if(ObjectGetInteger(0, name, OBJPROP_XDISTANCE) != x) ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   if(ObjectGetInteger(0, name, OBJPROP_YDISTANCE) != y) ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   if(ObjectGetInteger(0, name, OBJPROP_XSIZE) != w) ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   if(ObjectGetInteger(0, name, OBJPROP_YSIZE) != h) ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   if((color)ObjectGetInteger(0, name, OBJPROP_BGCOLOR) != bgCol) ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgCol);
   if((color)ObjectGetInteger(0, name, OBJPROP_BORDER_COLOR) != bgCol) ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bgCol);
   if(ObjectGetInteger(0, name, OBJPROP_ZORDER) != 10) ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
   if(ObjectGetInteger(0, name, OBJPROP_BACK) != 0) ObjectSetInteger(0, name, OBJPROP_BACK, false);
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
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 50);
   }
   if(ObjectGetInteger(0, name, OBJPROP_XDISTANCE) != x) ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   if(ObjectGetInteger(0, name, OBJPROP_YDISTANCE) != y) ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   if(ObjectGetString(0, name, OBJPROP_TEXT) != text) ObjectSetString(0, name, OBJPROP_TEXT, text);
   if(ObjectGetString(0, name, OBJPROP_FONT) != font) ObjectSetString(0, name, OBJPROP_FONT, font);
   if(ObjectGetInteger(0, name, OBJPROP_FONTSIZE) != fontSize) ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != col) ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   if(ObjectGetInteger(0, name, OBJPROP_ANCHOR) != anchor) ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   if(ObjectGetInteger(0, name, OBJPROP_ZORDER) != 50) ObjectSetInteger(0, name, OBJPROP_ZORDER, 50);
   if(ObjectGetInteger(0, name, OBJPROP_BACK) != 0) ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

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
   if(ObjectGetInteger(0, name, OBJPROP_XDISTANCE) != x) ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   if(ObjectGetInteger(0, name, OBJPROP_YDISTANCE) != y) ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   if(ObjectGetString(0, name, OBJPROP_TEXT) != text) ObjectSetString(0, name, OBJPROP_TEXT, text);
   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != clr) ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   if(ObjectGetInteger(0, name, OBJPROP_FONTSIZE) != fontSize) ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   string targetFont = isBold ? "Segoe UI Black" : "Segoe UI Semibold";
   if(ObjectGetString(0, name, OBJPROP_FONT) != targetFont) ObjectSetString(0, name, OBJPROP_FONT, targetFont);
   if(ObjectGetInteger(0, name, OBJPROP_ZORDER) != 50) ObjectSetInteger(0, name, OBJPROP_ZORDER, 50);
   if(ObjectGetInteger(0, name, OBJPROP_BACK) != 0) ObjectSetInteger(0, name, OBJPROP_BACK, false);
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
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   }
   if(ObjectGetInteger(0, name, OBJPROP_XDISTANCE) != x) ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   if(ObjectGetInteger(0, name, OBJPROP_YDISTANCE) != y) ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   if(ObjectGetInteger(0, name, OBJPROP_XSIZE) != w) ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   if(ObjectGetInteger(0, name, OBJPROP_YSIZE) != h) ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   if((color)ObjectGetInteger(0, name, OBJPROP_BGCOLOR) != bgClr) ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   if((color)ObjectGetInteger(0, name, OBJPROP_BORDER_COLOR) != borderClr) ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
   if(ObjectGetInteger(0, name, OBJPROP_BORDER_TYPE) != BORDER_FLAT) ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   if(ObjectGetInteger(0, name, OBJPROP_ZORDER) != 0) ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   if(ObjectGetInteger(0, name, OBJPROP_BACK) != 0) ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color bgClr, color txtClr, int fontSize = 9)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 200);
   }
   if(ObjectGetInteger(0, name, OBJPROP_XDISTANCE) != x) ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   if(ObjectGetInteger(0, name, OBJPROP_YDISTANCE) != y) ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   if(ObjectGetInteger(0, name, OBJPROP_XSIZE) != w) ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   if(ObjectGetInteger(0, name, OBJPROP_YSIZE) != h) ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   if(ObjectGetString(0, name, OBJPROP_TEXT) != text) ObjectSetString(0, name, OBJPROP_TEXT, text);
   if((color)ObjectGetInteger(0, name, OBJPROP_BGCOLOR) != bgClr) ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != txtClr) ObjectSetInteger(0, name, OBJPROP_COLOR, txtClr);
   if(ObjectGetInteger(0, name, OBJPROP_FONTSIZE) != fontSize) ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   if(ObjectGetString(0, name, OBJPROP_FONT) != "Segoe UI Black") ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI Black");
   if(ObjectGetInteger(0, name, OBJPROP_ZORDER) != 200) ObjectSetInteger(0, name, OBJPROP_ZORDER, 200);
   if(ObjectGetInteger(0, name, OBJPROP_BACK) != 0) ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| THAI COMBINING MARKS & VISUAL LENGTH CALCULATOR                  |
//+------------------------------------------------------------------+
int GetVisualTextLen(string text)
{
   int len = StringLen(text);
   int visualLen = 0;
   for(int i = 0; i < len; i++)
   {
      ushort ch = StringGetCharacter(text, i);
      // Thai combining vowels & tone marks (do not consume horizontal column width)
      if((ch >= 0x0E31 && ch <= 0x0E3A) || (ch >= 0x0E47 && ch <= 0x0E4E))
         continue;
      if(ch >= 0xD800 && ch <= 0xDBFF)
         continue;
      visualLen++;
   }
   return visualLen;
}

//+------------------------------------------------------------------+
//| SMART MULTI-LINE TEXT SPLITTER & WRAPPING ENGINE (AUTO-WRAP)     |
//+------------------------------------------------------------------+
int FindBestSplitPos(string text, int maxLen)
{
   if(GetVisualTextLen(text) <= maxLen) return StringLen(text);
   
   int bestPos = -1;
   int minRange = (int)(maxLen * 0.70);
   
   string nextLineDelims[] = {" ➔ ", "➔", " • ", " - "};
   for(int d = 0; d < ArraySize(nextLineDelims); d++)
   {
      int pos = StringFind(text, nextLineDelims[d]);
      while(pos >= 0)
      {
         int vLen = GetVisualTextLen(StringSubstr(text, 0, pos));
         if(vLen >= minRange && vLen <= maxLen)
         {
            if(pos > bestPos) bestPos = pos;
         }
         pos = StringFind(text, nextLineDelims[d], pos + 1);
      }
   }
   
   string midDelims[] = {" | ", ", "};
   for(int m = 0; m < ArraySize(midDelims); m++)
   {
      int pos = StringFind(text, midDelims[m]);
      while(pos >= 0)
      {
         int splitPt = pos + StringLen(midDelims[m]);
         int vLen = GetVisualTextLen(StringSubstr(text, 0, splitPt));
         if(vLen >= minRange && vLen <= maxLen)
         {
            if(splitPt > bestPos) bestPos = splitPt;
         }
         pos = StringFind(text, midDelims[m], pos + 1);
      }
   }

   string parenDelims[] = {" (", " ["};
   for(int p = 0; p < ArraySize(parenDelims); p++)
   {
      int pos = StringFind(text, parenDelims[p]);
      while(pos >= 0)
      {
         int vLen = GetVisualTextLen(StringSubstr(text, 0, pos));
         if(vLen >= minRange && vLen <= maxLen)
         {
            if(pos > bestPos) bestPos = pos;
         }
         pos = StringFind(text, parenDelims[p], pos + 1);
      }
   }
   
   int posSpace = StringFind(text, " ");
   while(posSpace >= 0)
   {
      int vLen = GetVisualTextLen(StringSubstr(text, 0, posSpace));
      if(vLen >= minRange && vLen <= maxLen)
      {
         if(posSpace > bestPos) bestPos = posSpace;
      }
      posSpace = StringFind(text, " ", posSpace + 1);
   }
   
   if(bestPos > 0) return bestPos;

   int fallbackMin = (int)(maxLen * 0.50);
   posSpace = StringFind(text, " ");
   while(posSpace >= 0)
   {
      int vLen = GetVisualTextLen(StringSubstr(text, 0, posSpace));
      if(vLen >= fallbackMin && vLen <= maxLen)
      {
         if(posSpace > bestPos) bestPos = posSpace;
      }
      posSpace = StringFind(text, " ", posSpace + 1);
   }

   if(bestPos > 0) return bestPos;
   
   return StringLen(text);
}

void SplitTextToLines(string fullText, int maxLen, string &l1, string &l2, string &l3)
{
   l1 = ""; l2 = ""; l3 = "";
   StringTrimLeft(fullText);
   StringTrimRight(fullText);
   
   if(GetVisualTextLen(fullText) <= maxLen)
   {
      l1 = fullText;
      return;
   }
   
   int split1 = FindBestSplitPos(fullText, maxLen);
   l1 = StringSubstr(fullText, 0, split1);
   string rem1 = StringSubstr(fullText, split1);
   StringTrimLeft(rem1);
   StringTrimRight(rem1);
   
   if(GetVisualTextLen(rem1) <= maxLen)
   {
      l2 = rem1;
      return;
   }
   
   int split2 = FindBestSplitPos(rem1, maxLen);
   l2 = StringSubstr(rem1, 0, split2);
   string rem2 = StringSubstr(rem1, split2);
   StringTrimLeft(rem2);
   StringTrimRight(rem2);
   l3 = rem2;
}

void RenderWrappedLabel(string prefix, int x, int &y, string fullText, color clr, int fontSize = 8, bool isBold = false, int maxLen = 56, int lineSpacing = 16)
{
   if(StringLen(fullText) == 0)
   {
      ObjectDelete(0, prefix + "_A");
      ObjectDelete(0, prefix + "_B");
      ObjectDelete(0, prefix + "_C");
      ObjectDelete(0, prefix);
      return;
   }
   string l1, l2, l3;
   SplitTextToLines(fullText, maxLen, l1, l2, l3);
   
   // Line 1
   CreateLabel(prefix + "_A", x, y, l1, clr, fontSize, isBold);
   y += lineSpacing;
   
   // Line 2
   if(StringLen(l2) > 0)
   {
      string displayL2 = "  " + l2;
      CreateLabel(prefix + "_B", x, y, displayL2, clr, fontSize, false);
      y += lineSpacing;
   }
   else
   {
      ObjectDelete(0, prefix + "_B");
   }
   
   // Line 3
   if(StringLen(l3) > 0)
   {
      string displayL3 = "  " + l3;
      CreateLabel(prefix + "_C", x, y, displayL3, clr, fontSize, false);
      y += lineSpacing;
   }
   else
   {
      ObjectDelete(0, prefix + "_C");
   }
   
   // Delete legacy un-suffixed object if present
   ObjectDelete(0, prefix);
}

void RenderDashboard()
{
   int baseX = InpHUD_X;
   int baseY = InpHUD_Y;
   int w     = 400;

   // ONE-TIME CLEANUP ON FIRST TICK TO REMOVE ANY INVERTED-ZORDER OBJECTS
   static bool s_CleanedLegacy = false;
   if(!s_CleanedLegacy)
   {
      ObjectsDeleteAll(0, GUI_PREFIX);
      s_CleanedLegacy = true;
   }

   // Always purge legacy Card 2 objects from old 3-card layout
   ObjectsDeleteAll(0, GUI_PREFIX + "C2_");
   ObjectDelete(0, GUI_PREFIX + "BTN_MIN_C2");

   // IF DASHBOARD IS COLLAPSED (MASTER HIDE TOGGLE)
   if(!g_Dashboard_Visible)
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "DASH_");
      ObjectsDeleteAll(0, GUI_PREFIX + "L_");
      ObjectsDeleteAll(0, GUI_PREFIX + "C1_");
      ObjectsDeleteAll(0, GUI_PREFIX + "C2_");
      ObjectsDeleteAll(0, GUI_PREFIX + "C3_");
      ObjectsDeleteAll(0, GUI_PREFIX + "LOT_");
      ObjectsDeleteAll(0, GUI_PREFIX + "BTN_");

      CreateButton(GUI_PREFIX + "BTN_SHOW_DASH", baseX, baseY, 210, 30, "📊 แสดงแดชบอร์ด [คลิก]", C'18,32,54', clrGold, 9);
      return;
   }

   ObjectDelete(0, GUI_PREFIX + "BTN_SHOW_DASH");

   // Header & Subtitle
   CreateRect(GUI_PREFIX + "DASH_BG", baseX, baseY, w, 38, C'12,18,28', C'35,50,75');
   string assetClean = g_Asset.name;
   int pParen = StringFind(assetClean, "(");
   if(pParen > 0) assetClean = StringSubstr(assetClean, 0, pParen);
   StringTrimRight(assetClean);
   string titleStr = "DeungDang_Trade V" + APP_VERSION + " ● " + _Symbol + " [" + GetCleanTFName((ENUM_TIMEFRAMES)_Period) + "] - " + assetClean;
   CreateLabel(GUI_PREFIX + "L_TITLE", baseX + 14, baseY + 6, titleStr, clrGold, 9, true);
   string dtdSub = StringFormat("กำนันบอล + อ.เดช CF %s (1:3R) + พี่ชนัฐ + SAMURAI MTF 36 แท่ง", g_DTD.tfName);
   CreateLabel(GUI_PREFIX + "L_SUBTITLE", baseX + 14, baseY + 21, dtdSub, C'140,165,195', 7, false);

   // Master Dashboard Collapse Button
   CreateButton(GUI_PREFIX + "BTN_HIDE_DASH", baseX + w - 66, baseY + 7, 56, 24, "◀ พับเก็บ", C'140,40,50', clrWhite, 8);

   int curY = baseY + 42;

   // --------------------------------------------------------------
   // PRE-CALCULATE DATA SHARED BETWEEN CARDS
   // --------------------------------------------------------------
   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(curBid <= 0) curBid = iClose(_Symbol, _Period, 0);
   if(curAsk <= 0) curAsk = curBid;

   // 1. Demand & Supply nearest calculation
   string nearDZShort = "ไม่มี";
   string nearSZShort = "ไม่มี";
   double minDZDist = 9999999.0;
   double minSZDist = 9999999.0;
   double bestInDZ_Span = 9999999.0;
   double bestInSZ_Span = 9999999.0;

   for(int z = 0; z < g_ZoneCount; z++)
   {
      if(!g_Zones[z].isActive) continue;
      double span = g_Zones[z].high - g_Zones[z].low;

      if(g_Zones[z].isDemand)
      {
         if(curBid >= g_Zones[z].low && curBid <= g_Zones[z].high)
         {
            if(minDZDist > 0.0 || span < bestInDZ_Span)
            {
               minDZDist = 0.0;
               bestInDZ_Span = span;
               nearDZShort = StringFormat("%s [%s] (★ในโซน)", DoubleToString(g_Zones[z].high, _Digits), g_Zones[z].tfName);
            }
         }
         else if(curBid > g_Zones[z].high)
         {
            double d = curBid - g_Zones[z].high;
            if(minDZDist > 0.0 && d < minDZDist)
            {
               minDZDist = d;
               nearDZShort = StringFormat("%s [%s] (-%s)", DoubleToString(g_Zones[z].high, _Digits), g_Zones[z].tfName, FormatMoneyOrPoints(d / _Point));
            }
         }
      }
      else if(!g_Zones[z].isDemand)
      {
         if(curAsk >= g_Zones[z].low && curAsk <= g_Zones[z].high)
         {
            if(minSZDist > 0.0 || span < bestInSZ_Span)
            {
               minSZDist = 0.0;
               bestInSZ_Span = span;
               nearSZShort = StringFormat("%s [%s] (★ในโซน)", DoubleToString(g_Zones[z].low, _Digits), g_Zones[z].tfName);
            }
         }
         else if(curAsk < g_Zones[z].low)
         {
            double d = g_Zones[z].low - curAsk;
            if(minSZDist > 0.0 && d < minSZDist)
            {
               minSZDist = d;
               nearSZShort = StringFormat("%s [%s] (+%s)", DoubleToString(g_Zones[z].low, _Digits), g_Zones[z].tfName, FormatMoneyOrPoints(d / _Point));
            }
         }
      }
   }

   // If no SMC Demand Zone within range, check for CME Put Wall or SSL Support Confluence
   if(nearDZShort == "ไม่มี")
   {
      if(g_CME_NearSupStrike > 0.0 && curBid > g_CME_NearSupStrike)
      {
         nearDZShort = StringFormat("ไม่มี (มีด่าน CME %.0f)", g_CME_NearSupStrike);
      }
      else if(g_LQ.ssl1.price > 0.0 && curBid > g_LQ.ssl1.price)
      {
         nearDZShort = StringFormat("ไม่มี (มีด่าน SSL %s)", DoubleToString(g_LQ.ssl1.price, _Digits));
      }
   }

   // 2. Anti-Chasing Guard evaluation (Dynamic asset-scaled threshold)
   bool isRunaway = false;
   if(InpUseDTD_CF_M1 && g_DTD.isEngulfConfirmed)
   {
      double entryRef = (g_DTD.confirmEntryPrice > 0.0) ? g_DTD.confirmEntryPrice : g_DTD.latchedEntryPrice;
      double tp1Ref   = (g_DTD.confirmTP1RPrice > 0.0) ? g_DTD.confirmTP1RPrice : g_DTD.latchedTP1Price;
      double runawayLimit = GetAntiChasingThreshold(g_DTD.slDistPoints);
      if(g_DTD.setupSide == 1)
      {
         double pnlPts = (curBid - entryRef) / _Point;
         bool isHitTP1 = (tp1Ref > 0.0 && curBid >= tp1Ref);
         if(pnlPts > runawayLimit && !isHitTP1) isRunaway = true;
      }
      else if(g_DTD.setupSide == -1)
      {
         double pnlPts = (entryRef - curAsk) / _Point;
         bool isHitTP1 = (tp1Ref > 0.0 && curAsk <= tp1Ref);
         if(pnlPts > runawayLimit && !isHitTP1) isRunaway = true;
      }
   }

   // ==============================================================
   // CARD 1: เรดาร์สภาพตลาด & โซนสำคัญ (MARKET & QUANT RADAR)
   // ==============================================================
   string sessShort  = g_SessionName;
   StringReplace(sessShort, " Overlap", "");
   StringReplace(sessShort, " (Prime)", "");

   long curSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double refBidForSpread = curBid;
   long maxNormSpread = (g_Asset.assetType == ASSET_CRYPTO) ? (long)MathRound((refBidForSpread * 0.0006) / _Point) : ((g_Asset.assetType == ASSET_GOLD) ? 50 : 25);
   bool isSpreadOK = (curSpread <= maxNormSpread);
   string spreadValTxt = (g_Asset.assetType == ASSET_CRYPTO) ? StringFormat("%d pts ($%.2f)", curSpread, curSpread * _Point) : StringFormat("%d pts", curSpread);

   // Synchronized Structure & Action row (2-Line Full Continuation ↳ — Zero Truncation)
   string sigCombined1 = "📢 โครงสร้าง: รอกราฟฟอร์มตัวในสปีดไลน์...";
   string sigCombined2 = "   ↳ รอแท่งเทียนเลือกทิศทางเบรกกรอบหรือเข้าโซนสำคัญ";
   color  sigCombClr   = clrSilver;

   if(isRunaway)
   {
      if(g_DTD.setupSide == 1)
      {
         sigCombined1 = "📢 โครงสร้าง: แท่ง BUY วิ่งทำกำไรไกลแล้ว!";
         sigCombined2 = StringFormat("   ↳ ห้ามไล่ยอดดอย! รอย่อรีเทสต์เส้นไส้สั้น (%s)", DoubleToString(g_DTD.shortestWickPrice, _Digits));
      }
      else
      {
         sigCombined1 = "📢 โครงสร้าง: แท่ง SELL ทุบทำกำไรไกลแล้ว!";
         sigCombined2 = StringFormat("   ↳ ห้ามไล่ก้นเหว! รอเด้งรีเทสต์เส้นไส้สั้น (%s)", DoubleToString(g_DTD.shortestWickPrice, _Digits));
      }
      sigCombClr = clrGold;
   }
   else if(g_DTD.swBoxActive && g_DTD.swBreakState != 0)
   {
      if(g_DTD.swBreakState == 1)
      {
         sigCombined1 = StringFormat("📢 🚀 เบรกกรอบบน SW HIGH [%s] (%s) สำเร็จ!", g_DTD.tfName, DoubleToString(g_DTD.swBoxHigh, _Digits));
         sigCombined2 = "   ↳ รอย่อ RETEST + แท่งกลืนกิน CF เพื่อกด BUY";
         sigCombClr   = C'0,255,150';
      }
      else if(g_DTD.swBreakState == -1)
      {
         sigCombined1 = StringFormat("📢 🚀 หลุดกรอบล่าง SW LOW [%s] (%s) สำเร็จ!", g_DTD.tfName, DoubleToString(g_DTD.swBoxLow, _Digits));
         sigCombined2 = "   ↳ รอเด้ง RETEST + แท่งกลืนกิน CF เพื่อกด SELL";
         sigCombClr   = C'255,95,115';
      }
      else if(g_DTD.swBreakState == 2)
      {
         sigCombined1 = StringFormat("📢 ⚠️ ระวังเบรกบนหลอก! (Sweep SW HIGH [%s]: %s)", g_DTD.tfName, DoubleToString(g_DTD.swBoxHigh, _Digits));
         sigCombined2 = "   ↳ แหย่ไส้แล้วดึงกลับเข้ากรอบ ห้ามไล่ BUY เด็ดขาด";
         sigCombClr   = clrGold;
      }
      else
      {
         sigCombined1 = StringFormat("📢 ⚠️ ระวังหลุดล่างหลอก! (Sweep SW LOW [%s]: %s)", g_DTD.tfName, DoubleToString(g_DTD.swBoxLow, _Digits));
         sigCombined2 = "   ↳ แหย่ไส้แล้วดึงกลับเข้ากรอบ ห้ามไล่ SELL เด็ดขาด";
         sigCombClr   = clrGold;
      }
   }
   else if(g_DTD.swBoxActive && g_DTD.marketRegime == 0)
   {
      sigCombined1 = StringFormat("📢 🟡 ตลาดวิ่งในกรอบ SW [%s] (%s - %s)", g_DTD.tfName, DoubleToString(g_DTD.swBoxLow, _Digits), DoubleToString(g_DTD.swBoxHigh, _Digits));
      sigCombined2 = "   ↳ รอเบรกหลุดกรอบ + ย่อรีเทสต์ CF จึงออกไม้";
      sigCombClr   = clrGold;
   }
   else if(g_IsFakeoutTrap)
   {
      sigCombined1 = (g_FakeoutSide == 1) ? "📢 โครงสร้าง: ⚡ ตรวจพบกลับตัวลงหลอก (Sweep SL)" : "📢 โครงสร้าง: ⚡ ตรวจพบกลับตัวขึ้นหลอก (Sweep SL)";
      sigCombined2 = (g_FakeoutSide == 1) ? "   ↳ กวาดกิน SL ฝั่ง Buy แล้วดึงกลับ ➔ ดักช้อน BUY!" : "   ↳ กวาดกิน SL ฝั่ง Sell แล้วทุบกลับ ➔ ดักทุบ SELL!";
      sigCombClr   = (g_FakeoutSide == 1) ? C'50,255,150' : C'255,80,100';
   }
   else if(g_IsFailedHigh && g_WaveSide == -1)
   {
      sigCombined1 = "📢 โครงสร้าง: ปริ้นสปีดขาขึ้น + ขาดการเบรกไฮ";
      sigCombined2 = "   ↳ เสียทรงขาขึ้นแล้ว ➔ เตรียมหาจังหวะกด SELL 🔴";
      sigCombClr   = C'255,100,120';
   }
   else if(g_IsFailedLow && g_WaveSide == 1)
   {
      sigCombined1 = "📢 โครงสร้าง: ปริ้นสปีดขาลง + ขาดการหลุดโล";
      sigCombined2 = "   ↳ เสียทรงขาลงแล้ว ➔ เตรียมหาจังหวะกด BUY 🟢";
      sigCombClr   = C'80,250,160';
   }
   else if(InpUseDTD_CF_M1 && g_DTD.isEngulfConfirmed)
   {
      if(g_DTD.setupSide == -1)
      {
         sigCombined1 = StringFormat("📢 โครงสร้าง: จบแท่งกลืนกิน CF %s (SELL 🔴) สำเร็จ!", g_DTD.tfName);
         sigCombined2 = "   ↳ ดูจุดเข้า SL และเป้า TP 1:3R ในการ์ด 2 ด้านล่าง";
      }
      else
      {
         sigCombined1 = StringFormat("📢 โครงสร้าง: จบแท่งกลืนกิน CF %s (BUY 🟢) สำเร็จ!", g_DTD.tfName);
         sigCombined2 = "   ↳ ดูจุดเข้า SL และเป้า TP 1:3R ในการ์ด 2 ด้านล่าง";
      }
      sigCombClr = (g_DTD.setupSide == 1) ? C'80,250,160' : C'255,100,120';
   }
   else if(g_WaveCycleCompleted)
   {
      sigCombined1 = "📢 โครงสร้าง: จบวงรอบคลื่นสมบูรณ์แล้ว";
      sigCombined2 = "   ↳ นั่งทับมือ รอให้กราฟสร้างกรอบสวิงชุดใหม่ 🟡";
      sigCombClr   = clrGold;
   }
   else if(g_HasUnicorn && g_UnicornSide != 0)
   {
      sigCombined1 = (g_UnicornSide == 1) ? "📢 โครงสร้าง: ตรวจพบโซนเด้ง ICT Unicorn (BUY 🟢)" : "📢 โครงสร้าง: ตรวจพบโซนย่อ ICT Unicorn (SELL 🔴)";
      sigCombined2 = "   ↳ โซนซ้อนทับ Breaker Block + FVG ความแม่นยำสูง";
      sigCombClr   = (g_UnicornSide == 1) ? C'80,250,160' : C'255,100,120';
   }
   else if(g_HasUpSpeedline && !g_IsUpSL_Broken)
   {
      sigCombined1 = "📢 โครงสร้าง: กราฟไต่เกาะสปีดไลน์ขาขึ้นแข็งแกร่ง";
      sigCombined2 = "   ↳ รอจังหวะย่อ RETEST + แท่งคอนเฟิร์ม CF เพื่อ BUY 🟢";
      sigCombClr   = C'80,250,160';
   }
   else if(g_HasDnSpeedline && !g_IsDnSL_Broken)
   {
      sigCombined1 = "📢 โครงสร้าง: กราฟไหลเกาะสปีดไลน์ขาลงต่อเนื่อง";
      sigCombined2 = "   ↳ รอจังหวะเด้ง RETEST + แท่งคอนเฟิร์ม CF เพื่อ SELL 🔴";
      sigCombClr   = C'255,100,120';
   }

   bool showCME = (InpUseCME_OI && g_Asset.assetType == ASSET_GOLD && (g_CME_NearResStrike > 0 || g_CME_NearSupStrike > 0));

   // Wave energy + Channel status (2-Line Continuation ↳)
   string uTag = (!g_HasUnicorn) ? "🦄 รอเบรก Gap (ICT Unicorn)" : ((g_UnicornSide == 1) ? "🦄 ICT Unicorn BUY!" : ((g_UnicornSide == -1) ? "🦄 ICT Unicorn SELL!" : "🦄 ICT Unicorn"));
   string velUnit = (g_Asset.assetType == ASSET_CRYPTO) ? StringFormat("$%.1f/วิ", MathAbs(g_GannEnergy.velocityPtsSec * _Point)) : StringFormat("%.1f จุด/วิ", g_GannEnergy.velocityPtsSec);
   string quantWaveStr1 = StringFormat("⚡ คลื่น: สปีด %s (%s)", velUnit, g_GannEnergy.energyStatus);
   string quantWaveStr2 = StringFormat("   ↳ มุมสโลป %+.1f° | %s", g_LRL.angle, uTag);

   int cardH1 = 22;
   if(g_Card1_Expanded)
   {
      int rows = 8;
      if(showCME) rows++;
      cardH1 = 22 + (rows * 15) + 8;
   }

   CreateRect(GUI_PREFIX + "C1_BG", baseX, curY, w, cardH1, C'14,20,32', C'32,48,72');
   CreateLabel(GUI_PREFIX + "C1_TITLE", baseX + 12, curY + 4, "🌐 1. เรดาร์สภาพตลาด & โซนสำคัญ (MARKET & QUANT RADAR)", clrLightSkyBlue, 8, true);
   CreateButton(GUI_PREFIX + "BTN_MIN_C1", baseX + w - 24, curY + 3, 18, 16, (g_Card1_Expanded ? "—" : "+"), C'35,50,70', clrSilver, 8);

   if(g_Card1_Expanded)
   {
      int lineY = curY + 20;

      // Row 1: MTF 6-TF Badges + Market Bias
      CreateLabel(GUI_PREFIX + "C1_L_SAM_T", baseX + 12, lineY, "⚔️ MTF:", C'180,205,230', 8, false);
      const string s6_tfNames[6] = {"M1", "M5", "M15", "M30", "H1", "H4"};
      int s6_x = baseX + 60;
      for(int k = 0; k < 6; k++)
      {
         string tfSym = g_SamuraiMTF.isBullish[k] ? "▲" : (g_SamuraiMTF.isBearish[k] ? "▼" : "━");
         color  tfCol = g_SamuraiMTF.isBullish[k] ? C'50,225,130' : (g_SamuraiMTF.isBearish[k] ? C'255,80,90' : clrGold);
         string tfStr = StringFormat("%s:%s", s6_tfNames[k], tfSym);
         CreateLabel(GUI_PREFIX + "C1_L_SAM_" + s6_tfNames[k], s6_x, lineY, tfStr, tfCol, 8, true);
         s6_x += (k < 2 ? 36 : (k < 4 ? 42 : 36));
      }
      CreateLabel(GUI_PREFIX + "C1_L_BIAS_SEP", s6_x + 2, lineY, "|", clrDarkGray, 8, false);

      string biasTxt  = (g_MarketBiasBuyPct >= 50) ? StringFormat("🟢 BUY %d%%", g_MarketBiasBuyPct) : StringFormat("🔴 SELL %d%%", g_MarketBiasSellPct);
      color  biasCol  = (g_MarketBiasBuyPct >= 50) ? C'50,225,130' : C'255,100,120';
      CreateLabel(GUI_PREFIX + "C1_L_BIAS_VAL", s6_x + 12, lineY, biasTxt, biasCol, 8, true);
      lineY += 15;

      // Row 2: Session + Spread
      string sessSpreadStr = StringFormat("🌐 เซสชัน: %s | ⚡ Spread: %s (%s)", sessShort, spreadValTxt, (isSpreadOK ? "ปกติ 🟢" : "ถ่าง ⚠️"));
      CreateLabel(GUI_PREFIX + "C1_L_SESSSPR", baseX + 12, lineY, sessSpreadStr, (isSpreadOK ? clrPaleGreen : clrOrange), 8, false);
      lineY += 15;

      // Row 3 & 4: Structure & Action (2-Line Full Display)
      CreateLabel(GUI_PREFIX + "C1_L_SIG",   baseX + 12, lineY, sigCombined1, sigCombClr, 8, true);
      lineY += 14;
      CreateLabel(GUI_PREFIX + "C1_L_SIG_B", baseX + 12, lineY, sigCombined2, sigCombClr, 8, false);
      lineY += 15;

      // Row 5 & 6: Demand DZ & Supply SZ (แยก 2 บรรทัด ↳ ไม่ล้นขอบการ์ด 100%)
      CreateLabel(GUI_PREFIX + "C1_L_DZ_T",   baseX + 12,  lineY, "🏛️ โซนรับ Demand (DZ):", clrGold, 8, false);
      CreateLabel(GUI_PREFIX + "C1_L_DZ_V",   baseX + 148, lineY, nearDZShort, C'50,225,130', 8, true);
      lineY += 14;
      CreateLabel(GUI_PREFIX + "C1_L_SZ_SEP", baseX + 12,  lineY, "   ↳ โซนต้าน Supply (SZ):", C'190,205,225', 8, false);
      CreateLabel(GUI_PREFIX + "C1_L_SZ_V",   baseX + 148, lineY, nearSZShort, C'255,100,120', 8, true);
      lineY += 15;

      // Row 7 & 8: Institutional Liquidity BSL & SSL (แยก 2 บรรทัด ↳ ไม่ล้นขอบการ์ด 100%)
      if(InpUseLQ_Scanner)
      {
         string bslLine = g_LQ.bsl1.isValid ? StringFormat("🧲 ดักกิน SL ฝั่ง Sell (BSL บน): %s [%s] (+%s)", DoubleToString(g_LQ.bsl1.price, _Digits), g_LQ.bsl1.tfName, FormatMoneyOrPoints(g_LQ.bsl1.distPts)) : "🧲 ดักกิน SL ฝั่ง Sell (BSL บน): ไม่พบในระยะ";
         string sslLine = g_LQ.ssl1.isValid ? StringFormat("   ↳ ดักกิน SL ฝั่ง Buy (SSL ล่าง): %s [%s] (-%s)", DoubleToString(g_LQ.ssl1.price, _Digits), g_LQ.ssl1.tfName, FormatMoneyOrPoints(g_LQ.ssl1.distPts)) : "   ↳ ดักกิน SL ฝั่ง Buy (SSL ล่าง): ไม่พบในระยะ";
         CreateLabel(GUI_PREFIX + "C1_L_LQ_B", baseX + 12, lineY, bslLine, C'255,130,150', 8, false);
         lineY += 14;
         CreateLabel(GUI_PREFIX + "C1_L_LQ_S", baseX + 12, lineY, sslLine, C'80,245,170', 8, false);
         ObjectDelete(0, GUI_PREFIX + "C1_L_LQ");
         lineY += 15;
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "C1_L_LQ");
         ObjectDelete(0, GUI_PREFIX + "C1_L_LQ_B");
         ObjectDelete(0, GUI_PREFIX + "C1_L_LQ_S");
      }

      // Row 7: CME Options Walls
      if(showCME)
      {
         CreateLabel(GUI_PREFIX + "C1_L_CME_T",   baseX + 12,  lineY, "🏛️ CME OI :", clrGold, 8, true);
         CreateLabel(GUI_PREFIX + "C1_L_CME_RES", baseX + 84,  lineY, g_CME_NearResStr, InpColorCME_Resistance, 8, true);
         CreateLabel(GUI_PREFIX + "C1_L_CME_SEP", baseX + 224, lineY, "|", clrDarkGray, 8, false);
         CreateLabel(GUI_PREFIX + "C1_L_CME_SUP", baseX + 236, lineY, g_CME_NearSupStr, InpColorCME_Support, 8, true);
         lineY += 15;
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "C1_L_CME_T");
         ObjectDelete(0, GUI_PREFIX + "C1_L_CME_RES");
         ObjectDelete(0, GUI_PREFIX + "C1_L_CME_SEP");
         ObjectDelete(0, GUI_PREFIX + "C1_L_CME_SUP");
      }

      // Row 8 & 9: Wave Speed + Samurai Angle + ICT Unicorn (2-Line Full Display)
      CreateLabel(GUI_PREFIX + "C1_L_WAVE",   baseX + 12, lineY, quantWaveStr1, C'160,220,255', 8, false);
      lineY += 14;
      CreateLabel(GUI_PREFIX + "C1_L_WAVE_B", baseX + 12, lineY, quantWaveStr2, C'140,205,245', 8, false);
      lineY += 15;

      cardH1 = (lineY - curY) + 6;
      if(ObjectGetInteger(0, GUI_PREFIX + "C1_BG", OBJPROP_YSIZE) != cardH1)
         ObjectSetInteger(0, GUI_PREFIX + "C1_BG", OBJPROP_YSIZE, cardH1);
   }
   else
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "C1_L");
   }

   curY += cardH1 + 6;

   // ==============================================================
   // CARD 2: ซิกแนล อ.เดช & แผงสั่งการ 1:3R (SIGNAL COCKPIT)
   // ==============================================================
   color card3BgCol     = C'20,18,30';
   color card3BorderCol = C'50,40,75';
   color card3TitleCol  = C'255,180,220';
   string card3Title    = "🎯 2. ซิกแนล อ.เดช & แผงสั่งการ 1:3R (SIGNAL COCKPIT)";
   string card3SigDesc1 = "⏳ รอกราฟฟอร์มตัวเลือกข้าง...";
   string card3SigDesc2 = "   ↳ รอแท่งเทียนสร้างโครงสร้างและเกณฑ์ไส้สั้นสุด";
   color card3SigCol    = clrSilver;

   if(InpUseDTD_CF_M1 && g_DTD.isEngulfConfirmed)
   {
      double entryRef = (g_DTD.confirmEntryPrice > 0.0) ? g_DTD.confirmEntryPrice : g_DTD.latchedEntryPrice;
      double tp1Ref   = (g_DTD.confirmTP1RPrice > 0.0) ? g_DTD.confirmTP1RPrice : g_DTD.latchedTP1Price;
      double tp2Ref   = (g_DTD.confirmTP2RPrice > 0.0) ? g_DTD.confirmTP2RPrice : g_DTD.latchedTP2Price;
      double tp3Ref   = (g_DTD.confirmTP3RPrice > 0.0) ? g_DTD.confirmTP3RPrice : g_DTD.latchedTP3Price;
      double wickRef  = (g_DTD.shortestWickPrice > 0.0) ? g_DTD.shortestWickPrice : g_DTD.latchedShortestWick;

      if(g_DTD.setupSide == 1)
      {
         double pnlPts     = (curBid - entryRef) / _Point;
         double retestDist = (curBid - wickRef) / _Point;
         bool isHitTP3     = (tp3Ref > 0.0 && curBid >= tp3Ref);
         bool isHitTP2     = (tp2Ref > 0.0 && curBid >= tp2Ref);
         bool isHitTP1     = (tp1Ref > 0.0 && curBid >= tp1Ref);
         bool isRetesting  = (MathAbs(retestDist) <= 40.0);
         double runawayLimit = GetAntiChasingThreshold(g_DTD.slDistPoints);
         bool isRunawayNow = (pnlPts > runawayLimit && !isHitTP1);

         if(isHitTP3)
         {
            card3BgCol = C'10,35,25'; card3BorderCol = C'0,255,180'; card3TitleCol = C'0,255,200';
            card3Title    = StringFormat("🏆 2. [ บรรลุเป้าหมาย 3R สำเร็จ! (+%.0f pts) ]", pnlPts);
            card3SigDesc1 = "🎉 ชนเป้าหลัก 3R ครบสูตรสำเร็จ!";
            card3SigDesc2 = "   ↳ พิจารณาปิดทำกำไรเข้าพอร์ต หรือล็อกรันเทรนด์";
            card3SigCol   = C'0,255,136';
         }
         else if(isHitTP2)
         {
            card3BgCol = C'10,32,22'; card3BorderCol = C'0,230,160'; card3TitleCol = C'50,255,180';
            card3Title    = StringFormat("🎯 2. [ บรรลุเป้า TP 2R (+%.0f pts) ➔ ล็อกกำไรใต้ 1R ]", pnlPts);
            card3SigDesc1 = "🚀 กำไรทะลุเป้า 2R แล้ว!";
            card3SigDesc2 = "   ↳ เลื่อน SL ล็อกกำไรใต้ฐาน TP1 เพื่อรันสู่เป้า TP3";
            card3SigCol   = C'50,255,180';
         }
         else if(isHitTP1)
         {
            card3BgCol = C'12,28,20'; card3BorderCol = C'40,210,120'; card3TitleCol = C'100,245,160';
            card3Title    = StringFormat("🛡️ 2. [ บรรลุเป้า TP 1R (+%.0f pts) ➔ บังหน้าทุนทันที! ]", pnlPts);
            card3SigDesc1 = "💎 กำไรแตะเป้า 1:1R เรียบร้อยแล้ว!";
            card3SigDesc2 = "   ↳ กดปุ่ม [ 🛡️ บังทุน ] ล็อกหน้าทุน ตัดความเสี่ยงเป็น 0";
            card3SigCol   = C'100,255,160';
         }
         else if(isRetesting)
         {
            card3BgCol = C'10,35,28'; card3BorderCol = C'0,255,200'; card3TitleCol = C'0,255,220';
            card3Title    = "🎯 2. [ 🟢 จังหวะย่อรีเทสต์! • จุดขึ้นรถ BUY ราคาดีที่สุด ]";
            card3SigDesc1 = StringFormat("🔥 ราคาย่อแตะแนวไส้สั้นสุด %s พอดี!", DoubleToString(wickRef, _Digits));
            card3SigDesc2 = "   ↳ ได้เปรียบระยะ SL สั้นมาก สามารถลั่นไก BUY ได้เลย!";
            card3SigCol   = C'0,255,200';
         }
         else if(g_DTD.swBoxActive && g_DTD.swBreakState == 2)
         {
            card3BgCol = C'36,26,12'; card3BorderCol = C'240,175,40'; card3TitleCol = clrGold;
            card3Title    = "⚠️ 2. [ ระวังเบรกบนหลอก! • ห้ามไล่ BUY ที่ยอดกรอบ SW ]";
            card3SigDesc1 = StringFormat("⚠️ กราฟแหย่ไส้กวาด SW HIGH (%s) แล้วดึงกลับเข้ากรอบ!", DoubleToString(g_DTD.swBoxHigh, _Digits));
            card3SigDesc2 = StringFormat("   ↳ ห้ามไล่ BUY เด็ดขาด! รอย่อใกล้แนว %s ค่อยดัก BUY", DoubleToString(wickRef, _Digits));
            card3SigCol   = clrGold;
         }
         else if(isRunawayNow || (curBid - wickRef) > (g_DTD.avgBarRange * 0.85))
         {
            card3BgCol = C'24,30,18'; card3BorderCol = C'220,175,45'; card3TitleCol = clrGold;
            card3Title    = "⏳ 2. [ ยืนยัน CF ขาขึ้นแล้ว • รอย่อใกล้แนว RETEST+CF ]";
            card3SigDesc1 = StringFormat("✋ ยืนยัน 2.CF [%s] แล้ว แต่ราคาอยู่ห่างแนวเข้า (ห้ามไล่ดอย!)", g_DTD.tfName);
            card3SigDesc2 = StringFormat("   ↳ รอย่อลงใกล้แนว RETEST+CF (%s) ค่อยกด BUY คุ้ม SL กว่า!", DoubleToString(wickRef, _Digits));
            card3SigCol   = clrGold;
         }
         else
         {
            card3BgCol = C'10,32,22'; card3BorderCol = C'0,255,180'; card3TitleCol = C'0,255,200';
            card3Title    = "🟢 2. [ จบแท่งกลืนกิน BUY • พร้อมลั่นไก 1:3R! ]";
            card3SigDesc1 = StringFormat("🚀 จบแท่งกลืนกิน %s ใกล้แนวเข้า ➔ กด BUY ได้ทันที!", g_DTD.tfName);
            card3SigDesc2 = StringFormat("   ↳ ตั้ง SL ใต้ชุดคอนเฟิร์ม (%s) เพื่อลุ้นเป้า 1:3R!", DoubleToString(g_Forecast.buySLPrice, _Digits));
            card3SigCol   = C'50,255,180';
         }
      }
      else
      {
         double pnlPts     = (entryRef - curAsk) / _Point;
         double retestDist = (wickRef - curAsk) / _Point;
         bool isHitTP3     = (tp3Ref > 0.0 && curAsk <= tp3Ref);
         bool isHitTP2     = (tp2Ref > 0.0 && curAsk <= tp2Ref);
         bool isHitTP1     = (tp1Ref > 0.0 && curAsk <= tp1Ref);
         bool isRetesting  = (MathAbs(retestDist) <= 40.0);
         double runawayLimit = GetAntiChasingThreshold(g_DTD.slDistPoints);
         bool isRunawayNow = (pnlPts > runawayLimit && !isHitTP1);

         if(isHitTP3)
         {
            card3BgCol = C'38,12,18'; card3BorderCol = C'255,50,90'; card3TitleCol = C'255,80,110';
            card3Title    = StringFormat("🏆 2. [ บรรลุเป้าหมาย 3R สำเร็จ! (+%.0f pts) ]", pnlPts);
            card3SigDesc1 = "🎉 ชนเป้าหลัก 3R ครบสูตรสำเร็จ!";
            card3SigDesc2 = "   ↳ พิจารณาปิดทำกำไรเข้าพอร์ต หรือล็อกรันเทรนด์";
            card3SigCol   = C'255,80,90';
         }
         else if(isHitTP2)
         {
            card3BgCol = C'35,12,18'; card3BorderCol = C'240,60,85'; card3TitleCol = C'255,100,120';
            card3Title    = StringFormat("🎯 2. [ บรรลุเป้า TP 2R (+%.0f pts) ➔ ล็อกกำไรเหนือ 1R ]", pnlPts);
            card3SigDesc1 = "🚀 กำไรทะลุเป้า 2R แล้ว!";
            card3SigDesc2 = "   ↳ เลื่อน SL ล็อกกำไรเหนือฐาน TP1 เพื่อรันสู่เป้า TP3";
            card3SigCol   = C'255,100,120';
         }
         else if(isHitTP1)
         {
            card3BgCol = C'32,14,18'; card3BorderCol = C'220,70,85'; card3TitleCol = C'255,120,135';
            card3Title    = StringFormat("🛡️ 2. [ บรรลุเป้า TP 1R (+%.0f pts) ➔ บังหน้าทุนทันที! ]", pnlPts);
            card3SigDesc1 = "💎 กำไรแตะเป้า 1:1R เรียบร้อยแล้ว!";
            card3SigDesc2 = "   ↳ กดปุ่ม [ 🛡️ บังทุน ] ล็อกหน้าทุน ตัดความเสี่ยงเป็น 0";
            card3SigCol   = C'255,120,135';
         }
         else if(isRetesting)
         {
            card3BgCol = C'36,20,15'; card3BorderCol = C'255,140,50'; card3TitleCol = C'255,160,80';
            card3Title    = "🎯 2. [ 🔴 จังหวะดีดรีเทสต์! • จุดขึ้นรถ SELL ราคาดีที่สุด ]";
            card3SigDesc1 = StringFormat("🔥 ราคาเด้งแตะแนวไส้สั้นสุด %s พอดี!", DoubleToString(wickRef, _Digits));
            card3SigDesc2 = "   ↳ ได้เปรียบระยะ SL สั้นมาก สามารถลั่นไก SELL ได้เลย!";
            card3SigCol   = C'255,160,80';
         }
         else if(g_DTD.swBoxActive && g_DTD.swBreakState == -2)
         {
            card3BgCol = C'36,26,12'; card3BorderCol = C'240,175,40'; card3TitleCol = clrGold;
            card3Title    = "⚠️ 2. [ ระวังหลุดล่างหลอก! • ห้ามไล่ SELL ที่ก้นกรอบ SW ]";
            card3SigDesc1 = StringFormat("⚠️ กราฟแหย่ไส้กวาด SW LOW (%s) แล้วดึงกลับเข้ากรอบ!", DoubleToString(g_DTD.swBoxLow, _Digits));
            card3SigDesc2 = StringFormat("   ↳ ห้ามไล่ SELL เด็ดขาด! รอเด้งใกล้แนว %s ค่อยดัก SELL", DoubleToString(wickRef, _Digits));
            card3SigCol   = clrGold;
         }
         else if(isRunawayNow || (wickRef - curAsk) > (g_DTD.avgBarRange * 0.85))
         {
            card3BgCol = C'32,20,16'; card3BorderCol = C'220,175,45'; card3TitleCol = clrGold;
            card3Title    = "⏳ 2. [ ยืนยัน CF ขาลงแล้ว • รอเด้งใกล้แนว RETEST+CF ]";
            card3SigDesc1 = StringFormat("✋ ยืนยัน 2.CF [%s] แล้ว แต่ราคาอยู่ห่างแนวเข้า (ห้ามไล่ก้นเหว!)", g_DTD.tfName);
            card3SigDesc2 = StringFormat("   ↳ รอเด้งขึ้นใกล้แนว RETEST+CF (%s) ค่อยกด SELL คุ้ม SL กว่า!", DoubleToString(wickRef, _Digits));
            card3SigCol   = clrGold;
         }
         else
         {
            card3BgCol = C'38,12,18'; card3BorderCol = C'255,50,90'; card3TitleCol = C'255,80,110';
            card3Title    = "🔴 2. [ จบแท่งกลืนกิน SELL • พร้อมลั่นไก 1:3R! ]";
            card3SigDesc1 = StringFormat("🚀 จบแท่งกลืนกิน %s ใกล้แนวเข้า ➔ กด SELL ได้ทันที!", g_DTD.tfName);
            card3SigDesc2 = StringFormat("   ↳ ตั้ง SL เหนือชุดคอนเฟิร์ม (%s) เพื่อลุ้นเป้า 1:3R!", DoubleToString(g_Forecast.sellSLPrice, _Digits));
            card3SigCol   = C'255,80,90';
         }
      }
   }
   else if(InpUseDTD_CF_M1 && g_DTD.shortestWickPrice > 0.0)
   {
      card3Title    = StringFormat("⏳ 2. [ รอ CF %s กลืนกิน • แผน 1R-3R ]", g_DTD.tfName);
      card3SigDesc1 = (g_DTD.setupSide == -1) ? StringFormat("👀 แตะโซนต้านแล้ว ➔ รอแท่ง %s ปิดกลืนกินใต้ไส้ %s", g_DTD.tfName, DoubleToString(g_DTD.shortestWickPrice, _Digits))
                                              : StringFormat("👀 แตะโซนรับแล้ว ➔ รอแท่ง %s ปิดกลืนกินเหนือไส้ %s", g_DTD.tfName, DoubleToString(g_DTD.shortestWickPrice, _Digits));
      card3SigDesc2 = (g_DTD.setupSide == -1) ? "   ↳ รอให้จบแท่งคอนเฟิร์ม CF ก่อน จึงกดเข้าไม้ SELL 🔴"
                                              : "   ↳ รอให้จบแท่งคอนเฟิร์ม CF ก่อน จึงกดเข้าไม้ BUY 🟢";
      card3SigCol   = clrGold;
   }

   // Combined Signal Grade + Checklist in 2 full lines (↳)
   string combinedGradeStr1 = "";
   string combinedGradeStr2 = "";
   color  combinedGradeCol  = clrSilver;
   if(InpUseDTD_CF_M1)
   {
      double zoneTol = (g_Asset.assetType == ASSET_CRYPTO) ? (curBid * 0.00035) : (g_Asset.assetType == ASSET_GOLD ? (60.0 * _Point) : (20.0 * _Point));
      bool isBuySetup     = (g_DTD.setupSide == 1);
      bool inTargetZone   = isBuySetup ? (minDZDist <= zoneTol) : (minSZDist <= zoneTol);
      bool isLQSwept      = (g_IsFakeoutTrap || g_LQ.hasSweepAlert);
      bool isEngulfCF     = g_DTD.isEngulfConfirmed;

      if(inTargetZone && isLQSwept && isEngulfCF)
      {
         combinedGradeStr1 = StringFormat("⭐ เกรด A+ (ครบสูตร): [✅โซน DZ/SZ + ✅Sweep SL + ✅%s กลืนกิน]", g_DTD.tfName);
         combinedGradeStr2 = "   ↳ สัญญาณคมชัดระดับสูงสุด เข้าเทรดตามแผน 1:3R ได้ทันที";
         combinedGradeCol  = C'0,255,136';
      }
      else if(inTargetZone && isEngulfCF)
      {
         combinedGradeStr1 = StringFormat("⭐ เกรด A (โซนหลัก): [✅แตะโซนสำคัญ + ✅%s กลืนกินสำเร็จ]", g_DTD.tfName);
         combinedGradeStr2 = "   ↳ โซนใหญ่หนุนหลังแข็งแกร่ง เทรดตามแผน 1:3R ได้เลย";
         combinedGradeCol  = C'50,230,150';
      }
      else if(isLQSwept && isEngulfCF)
      {
         combinedGradeStr1 = StringFormat("⭐ เกรด A (สไนเปอร์): [✅Sweep SL เจ้ามือ + ✅%s กลืนกินสำเร็จ]", g_DTD.tfName);
         combinedGradeStr2 = "   ↳ กวาดกิน SL รายย่อยแล้วดึงกลับ เทรดตามแผน 1:3R ได้เลย";
         combinedGradeCol  = clrGold;
      }
      else if(isEngulfCF)
      {
         combinedGradeStr1 = StringFormat("⭐ เกรด B (กลางทาง): [✅%s กลืนกินสำเร็จ]", g_DTD.tfName);
         combinedGradeStr2 = StringFormat("   ↳ รอย่อ/เด้งแตะเส้นไส้สั้น (%s) จะได้เปรียบระยะ SL คุ้มกว่า", DoubleToString(g_DTD.shortestWickPrice, _Digits));
         combinedGradeCol  = clrOrange;
      }
      else if(inTargetZone)
      {
         combinedGradeStr1 = "⏳ รอคอนเฟิร์ม: [✅ราคาแตะโซนสำคัญ DZ/SZ เรียบร้อยแล้ว]";
         combinedGradeStr2 = StringFormat("   ↳ รอแท่ง %s ปิดเนื้อกลืนกินเส้นไส้สั้น (%s) จึงออกไม้", g_DTD.tfName, DoubleToString(g_DTD.shortestWickPrice, _Digits));
         combinedGradeCol  = clrGold;
      }
      else
      {
         combinedGradeStr1 = "⏳ รอเข้าโซน: [ราคาลอยอยู่กลางทาง ยังไม่แตะโซนสำคัญ]";
         combinedGradeStr2 = "   ↳ อดทนรอย่อเข้าโซนรับ Demand หรือเด้งแตะโซนต้าน Supply";
         combinedGradeCol  = clrSilver;
      }
   }

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
   string posRiskInfo = StringFormat("📊 พอร์ต: ถือ %d ไม้ ($%.2f) | เสี่ยงตั้งต้น: $%.1f ต่อชุด (1:3R)", totalPos, totalProfit, InpDTD_RiskMoney);

   // Smart Auto-Column Placement
   int chartMainH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   int cardH3 = 22;
   if(g_Card3_Expanded) cardH3 = 280;

   int c3X = baseX;
   int c3Y = curY;
   if(chartMainH > 260 && (curY + cardH3 > chartMainH - 4))
   {
      c3X = baseX + w + 8;
      c3Y = baseY + 42;
   }

   CreateRect(GUI_PREFIX + "C3_BG", c3X, c3Y, w, cardH3, card3BgCol, card3BorderCol);
   CreateLabel(GUI_PREFIX + "C3_TITLE", c3X + 12, c3Y + 4, card3Title, card3TitleCol, 8, true);
   CreateButton(GUI_PREFIX + "BTN_MIN_C3", c3X + w - 24, c3Y + 3, 18, 16, (g_Card3_Expanded ? "—" : "+"), C'35,50,70', clrSilver, 8);

   if(g_Card3_Expanded)
   {
      int lineY = c3Y + 20;

      // Row 1 & 2: Actionable Signal Description (2 Full Lines)
      CreateLabel(GUI_PREFIX + "C3_L_SIG",   c3X + 12, lineY, card3SigDesc1, card3SigCol, 8, true);
      lineY += 14;
      CreateLabel(GUI_PREFIX + "C3_L_SIG_B", c3X + 12, lineY, card3SigDesc2, card3SigCol, 8, false);
      lineY += 15;

      // Row 3 & 4: Combined Signal Grade + Checklist (2 Full Lines)
      CreateLabel(GUI_PREFIX + "C3_L_GRADE",   c3X + 12, lineY, combinedGradeStr1, combinedGradeCol, 8, true);
      lineY += 14;
      CreateLabel(GUI_PREFIX + "C3_L_GRADE_B", c3X + 12, lineY, combinedGradeStr2, combinedGradeCol, 8, false);
      ObjectDelete(0, GUI_PREFIX + "C3_L_CHK");
      ObjectDelete(0, GUI_PREFIX + "C3_L_DTD");
      lineY += 15;

      // Rows 5-10: Dual-Side Price Forecast (BUY & SELL Roadmaps + Magnet Lines)
      if(InpUseDualForecast)
      {
         CreateLabel(GUI_PREFIX + "C3_L_FC_B1", c3X + 12, lineY, g_Forecast.buyPlanLine1, C'70,255,155', 8, true);
         lineY += 14;
         CreateLabel(GUI_PREFIX + "C3_L_FC_B2", c3X + 12, lineY, g_Forecast.buyPlanLine2, C'180,250,210', 8, false);
         lineY += 14;
         CreateLabel(GUI_PREFIX + "C3_L_FC_B3", c3X + 12, lineY, g_Forecast.buyPlanLine3, C'130,235,190', 8, false);
         lineY += 15;
         CreateLabel(GUI_PREFIX + "C3_L_FC_S1", c3X + 12, lineY, g_Forecast.sellPlanLine1, C'255,115,125', 8, true);
         lineY += 14;
         CreateLabel(GUI_PREFIX + "C3_L_FC_S2", c3X + 12, lineY, g_Forecast.sellPlanLine2, C'255,195,205', 8, false);
         lineY += 14;
         CreateLabel(GUI_PREFIX + "C3_L_FC_S3", c3X + 12, lineY, g_Forecast.sellPlanLine3, C'255,165,180', 8, false);
         lineY += 15;
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "C3_L_FC_B1");
         ObjectDelete(0, GUI_PREFIX + "C3_L_FC_B2");
         ObjectDelete(0, GUI_PREFIX + "C3_L_FC_B3");
         ObjectDelete(0, GUI_PREFIX + "C3_L_FC_S1");
         ObjectDelete(0, GUI_PREFIX + "C3_L_FC_S2");
         ObjectDelete(0, GUI_PREFIX + "C3_L_FC_S3");
      }

      // Row 7: Portfolio & Risk
      CreateLabel(GUI_PREFIX + "C3_L5", c3X + 12, lineY, posRiskInfo, clrWhite, 8, false);
      lineY += 16;

      // Execution Buttons
      int btnY1 = lineY + 3;
      int btnY_DTD = btnY1 + 28;
      int btnY2 = btnY_DTD + 26;

      CreateButton(GUI_PREFIX + "LOT_MINUS",   c3X + 12,  btnY1, 28, 25, "-", C'45,55,75', clrWhite, 10);
      CreateButton(GUI_PREFIX + "LOT_VAL",     c3X + 43,  btnY1, 66, 25, DoubleToString(g_CurrentLot, 2), C'30,40,55', clrGold, 9);
      CreateButton(GUI_PREFIX + "LOT_PLUS",    c3X + 112, btnY1, 28, 25, "+", C'45,55,75', clrWhite, 10);

      CreateButton(GUI_PREFIX + "BTN_BE",      c3X + 146, btnY1, 74, 25, "🛡️ บังทุน", C'35,70,120', clrWhite, 8);
      CreateButton(GUI_PREFIX + "BTN_PARTIAL", c3X + 224, btnY1, 74, 25, "💰 ปิด 80%", C'145,100,20', clrWhite, 8);
      CreateButton(GUI_PREFIX + "BTN_CLOSE",   c3X + 302, btnY1, 84, 25, "❌ ปิดหมด", C'140,40,50', clrWhite, 8);

      if(InpUseDTD_CF_M1)
      {
         CreateButton(GUI_PREFIX + "BTN_DTD_LOT_BUY",  c3X + 12,  btnY_DTD, 184, 23, StringFormat("🎯 ใช้ Lot แผน BUY: %.2f (3R)", g_Forecast.buyLot), C'20,65,45', C'100,255,170', 8);
         CreateButton(GUI_PREFIX + "BTN_DTD_LOT_SELL", c3X + 202, btnY_DTD, 184, 23, StringFormat("🎯 ใช้ Lot แผน SELL: %.2f (3R)", g_Forecast.sellLot), C'75,25,35', C'255,150,160', 8);
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "BTN_DTD_LOT_BUY");
         ObjectDelete(0, GUI_PREFIX + "BTN_DTD_LOT_SELL");
         btnY2 = btnY_DTD;
      }

      CreateButton(GUI_PREFIX + "BTN_BUY",  c3X + 12,  btnY2, 184, 34, "🟢 กด BUY", C'30,120,60', clrWhite, 10);
      CreateButton(GUI_PREFIX + "BTN_SELL", c3X + 202, btnY2, 184, 34, "🔴 กด SELL", C'150,40,40', clrWhite, 10);

      cardH3 = (btnY2 + 34 - c3Y) + 8;
      if(ObjectGetInteger(0, GUI_PREFIX + "C3_BG", OBJPROP_YSIZE) != cardH3)
         ObjectSetInteger(0, GUI_PREFIX + "C3_BG", OBJPROP_YSIZE, cardH3);
   }
   else
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "C3_L");
      ObjectsDeleteAll(0, GUI_PREFIX + "LOT_");
      ObjectsDeleteAll(0, GUI_PREFIX + "BTN_BE");
      ObjectsDeleteAll(0, GUI_PREFIX + "BTN_PARTIAL");
      ObjectsDeleteAll(0, GUI_PREFIX + "BTN_CLOSE");
      ObjectsDeleteAll(0, GUI_PREFIX + "BTN_BUY");
      ObjectsDeleteAll(0, GUI_PREFIX + "BTN_SELL");
      ObjectDelete(0, GUI_PREFIX + "BTN_DTD_LOT_BUY");
      ObjectDelete(0, GUI_PREFIX + "BTN_DTD_LOT_SELL");
   }
}