//+------------------------------------------------------------------+
//|                                            DeungDang_Trade.mq5   |
//|                    Good Trade Gold & Kamnan Ball Trading Suite   |
//|               Visual Training Co-Pilot & Manual Precision Radar  |
//|             (ตัวชี้เป้าและฝึกดูสิ่งที่กำนันบอลสอน - ไม่ใช่บอทออโต้)            |
//+------------------------------------------------------------------+
#property copyright   "Good Trade Gold & Kamnan Ball Trading Suite"
#property link        "https://github.com/eaeybaent51-creator/Good"
#property version     "2.00"
#property description "DeungDang_Trade V2.00 - Zero-Popup Clean Cockpit & Unhindered Manual Execution Suite"
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
input bool     InpUseVSL_LockFloor       = true;          // 🛡️ เซฟตี้ล็อกกำไร +10 จุดเมื่อราคาหมดแรงที่ปลายคลื่น (VSL Floor Lock)
input int      InpVSL_TriggerProfitPts   = 200;           // กำไรขั้นต่ำก่อนเปิดระบบหมดแรงล็อกทุน (จุด: 200 pts)
input int      InpVSL_FloorPts           = 10;            // ระยะล็อกกำไรหน้าทุนเมื่อราคาหมดแรง (จุด: +10 pts)

input group "=== [ 12. ระบบคอนเฟิร์ม CF M1 & บริหารหน้าตัก 3R (อาจารย์เดช DTD) ] ==="
input bool     InpUseDTD_CF_M1           = true;          // 🎯 เปิดเรดาร์คอนเฟิร์ม CF M1 เสมอ (เกาะปลายไส้ที่สั้นที่สุด + แท่งกลืนกิน)
input bool     InpDrawDTD_M1_Visuals     = true;          // 📐 วาดเส้นประปลายไส้สั้นสุด & กล่องวัดระยะ 1R:3R บนชาร์ต
input double   InpDTD_RiskMoney          = 20.0;          // 💵 เงินความเสี่ยงต่อไม้ ($ หรือ USC) คำนวณ Lot = ความเสี่ยง ÷ ระยะ SL
input double   InpDTD_TargetRR           = 3.0;           // 🏆 เป้าความคุ้มค่า RR ตามสูตรอาจารย์เดช (แนะนำ 3.0 เท่า = 3R)
input int      InpDTD_SL_BufferPts       = 35;            // 🛡️ ระยะเผื่อสเปรดใต้/เหนือชุดคอนเฟิร์ม M1 (จุด)
input bool     InpRequireM15_Alignment   = true;          // 🎯 กฎเหล็ก อ.เดช: M1 และ M15 ต้องไปในทิศทางเดียวกัน 100% (ห้ามสวนเทรนด์ M15)

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

struct SDTD_ConfirmState
{
   int      setupSide;          // +1 = แผน BUY, -1 = แผน SELL, 0 = รอเข้าโซน
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

   // Initial Scan
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 0, InpMaxBarsScan, rates);
   if(copied > 30)
   {
      UpdateMultiTF_EMA14();
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
      UpdateMarketBiasAndSession(rates, copied);
      ScanCME_OptionsMatrix();
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
}

//+------------------------------------------------------------------+
//| EXPERT TICK HANDLER                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   m_symbol.Refresh();

   // Auto-Reset เมื่อมีการสลับ Timeframe ป้องกันเส้นและคลื่นของ TF เดิมค้างคาจอ
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

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 0, InpMaxBarsScan, rates);
   if(copied < 30) return;

   // 1. Get EMA 14 values (Current TF, H1, H4)
   if(g_EMA_Handle != INVALID_HANDLE)
   {
      double emaBuf[1];
      if(CopyBuffer(g_EMA_Handle, 0, 0, 1, emaBuf) > 0)
         g_EMA14_Val = emaBuf[0];
   }
   UpdateMultiTF_EMA14();

   // 2. Perform Full Market Structure Analysis
   ScanSwings(rates, copied);
   ClassifySwingsAndBreaks(rates, copied);
   UpdateSpeedlines(rates, copied);
   AnalyzeWaveStructure(rates, copied);
   CalculateWave_D_Targets();
   DetectFakeoutTrap(rates, copied);
   ScanDemandSupplyZones(rates, copied);
   ScanHiddenBladeWicks();
   CheckICTUnicorn(rates, copied);
   CheckSidewayRegime(rates, copied);
   CalculateLRLChannel(rates, copied);
   CheckCandlePATrigger(rates);
   CalculateDynamicTargets();
   UpdateMarketBiasAndSession(rates, copied);
   CheckVoiceAlerts();
   ScanCME_OptionsMatrix();
   CalculateGannWaveEnergy(rates, copied);
   ScanDTD_CF_M1();

   // 3. Synchronize Shared SL & VSL Floor Lock for Manual Positions
   SynchronizeSharedSL();
   CheckVelocityStopLockFloor();

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
      ChartSetInteger(0, CHART_HEIGHT_IN_PIXELS, 1, 160);
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
   if(winH < 65)   winH   = 160;

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
      // Step 1: Cycle Completed / Sweep / Wait Structure
      if(g_WaveCycleCompleted)
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
   // 3. DETERMINE THE ACTIVE DOMINANT WAVE CYCLE
   // -------------------------------------------------------------
   int chosen = 0;
   if(sellValid && buyValid)
   {
      if(sellC_Time >= buyC_Time) chosen = -1;
      else                        chosen = 1;
   }
   else if(sellValid) chosen = -1;
   else if(buyValid)  chosen = 1;

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

   int lastHighIdx = -1, lastLowIdx = -1;
   for(int i = 0; i < g_SwingCount && i < 6; i++)
   {
      if(g_Swings[i].isHigh && lastHighIdx == -1) lastHighIdx = i;
      if(!g_Swings[i].isHigh && lastLowIdx == -1) lastLowIdx = i;
   }

   // 1. ตรวจสอบ "กลับตัวลงหลอก" (Bear Trap Sweep -> BUY)
   if(lastLowIdx >= 0)
   {
      double swingLowPrice = g_Swings[lastLowIdx].price;
      datetime swingLowTime = g_Swings[lastLowIdx].time;

      for(int bar = 1; bar <= 4 && bar < total - 1; bar++)
      {
         // หากราคาปัจจุบันหลุดทะลุก้น Sweep ไปแล้ว ถือว่าไม่ใช่ Fakeout แต่เป็นการพังจริง (Invalidate)
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

   // 2. ตรวจสอบ "กลับตัวขึ้นหลอก" (Bull Trap Sweep -> SELL)
   if(lastHighIdx >= 0)
   {
      double swingHighPrice = g_Swings[lastHighIdx].price;
      datetime swingHighTime = g_Swings[lastHighIdx].time;

      for(int bar = 1; bar <= 4 && bar < total - 1; bar++)
      {
         // หากราคาปัจจุบันทะลุยอด Sweep ไปแล้ว ถือว่าไม่ใช่ Fakeout แต่เป็นการเบรกจริง (Invalidate)
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

            if(!merged && g_ZoneCount < 40)
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

            if(!merged && g_ZoneCount < 40)
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
//| Calibrated: 13/10/2569 (41.45 DTE, Ref Futures $4,170.1)         |
//+------------------------------------------------------------------+
const SCME_Level g_CME_Levels[] = {
   {3650.0,    0, 1712, false,  true}, // Half-Century Put 3650 (1.7k OI)
   {3655.0,    0,  264, false, false},
   {3660.0,    2,   61, false, false},
   {3670.0,    1,  130, false, false},
   {3675.0,    0,  173, false, false},
   {3680.0,    1,   51, false, false},
   {3685.0,    1,  407, false, false},
   {3700.0,  146, 3535,  true, false}, // Major Put Base 3700 (3.5k OI)
   {3710.0,    2,  154, false, false},
   {3715.0,    0,  156, false, false},
   {3725.0,    0,  197, false, false},
   {3730.0,    0,  403, false, false},
   {3735.0,    0,  171, false, false},
   {3740.0,    0,   94, false, false},
   {3750.0,    8, 1923, false,  true}, // Half-Century Put 3750 (1.9k OI)
   {3760.0,    2,  146, false, false},
   {3775.0,    2,   91, false, false},
   {3785.0,    4,   88, false, false},
   {3790.0,    2,  194, false, false},
   {3800.0,   27, 1737,  true, false}, // Major Put Base 3800 (1.7k OI)
   {3805.0,    1,   61, false, false},
   {3810.0,    0,  124, false, false},
   {3825.0,    1,  136, false, false},
   {3840.0,    1,  239, false, false},
   {3850.0,    1,  975, false,  true}, // Half-Century Put 3850
   {3875.0,    1,  157, false, false},
   {3895.0,    2,  285, false, false},
   {3900.0,   41, 4350,  true, false}, // Major Put Wall 3900 (4.35k OI)
   {3915.0,    4,  232, false, false},
   {3925.0,    0,  399, false, false},
   {3930.0,    1,  105, false, false},
   {3935.0,   12,  227, false, false},
   {3940.0,    1,  305, false, false},
   {3950.0,    7, 3034, false,  true}, // Half-Century Put 3950 (3.0k OI)
   {3960.0,    1,  471, false, false},
   {3975.0,    0,  953, false, false},
   {3980.0,    0,  266, false, false},
   {3990.0,    4,  470, false, false},
   {4000.0,  246, 4622,  true, false}, // Mega Put Base 4000 (4.6k OI)
   {4005.0,    6,  208, false, false},
   {4015.0,    1,   82, false, false},
   {4025.0,    2, 1059, false, false},
   {4030.0,   13,  118, false, false},
   {4040.0,   40,  104, false, false},
   {4050.0,  974, 2316, false,  true}, // Half-Century Put 4050 (2.3k OI)
   {4060.0,  106,  147, false, false},
   {4075.0,   22,  381, false, false},
   {4080.0,  140,  581, false, false},
   {4090.0,   44,  255, false, false},
   {4100.0, 1570, 2401,  true, false}, // Major Put/Call Wall 4100 (2.4k Put / 1.57k Call)
   {4110.0,  210,   79, false, false},
   {4120.0,   42,  682, false, false},
   {4125.0,  173,  242, false, false},
   {4130.0,  717,  725, false, false}, // Dual Speed Bump 4130
   {4140.0,   69,  118, false, false},
   {4150.0,  588, 1352, false,  true}, // Half-Century Put 4150 (1.35k OI)
   {4160.0,  173,  338, false, false},
   {4170.0,  160,  340, false, false},
   {4175.0, 1061,  441, false, false}, // Pivot Call/Put 4175 (1.06k Call OI)
   {4180.0,   31,  247, false, false},
   {4190.0,  399,  511, false, false},
   {4200.0, 2489, 2525,  true, false}, // Macro Put Base / Heavy Pivot 4200 (2.5k Put / 2.5k Call)
   {4205.0,  418,   65, false, false},
   {4210.0,   48,  108, false, false},
   {4215.0,   92,  227, false, false},
   {4220.0,  243,   61, false, false},
   {4225.0,  590,  263, false, false},
   {4230.0,  100,  443, false, false},
   {4235.0,   25,  129, false, false},
   {4240.0,   64,   73, false, false},
   {4245.0,  205,   44, false, false},
   {4250.0, 1325, 2466, false,  true}, // Intermediate Put 4250 (2.47k Put / 1.33k Call)
   {4255.0,  128,   38, false, false},
   {4260.0,  196,   79, false, false},
   {4265.0,   34,  112, false, false},
   {4275.0,   72,  151, false, false},
   {4280.0,   90,  176, false, false},
   {4290.0,   99,  242, false, false},
   {4295.0,  116,   93, false, false},
   {4300.0, 2441, 3293,  true, false}, // Tactical Put Wall 4300 (3.3k Put / 2.4k Call)
   {4310.0,   63,  237, false, false},
   {4320.0,  196,  264, false, false},
   {4325.0,  226,  866, false, false},
   {4330.0,  127,   46, false, false},
   {4340.0,   73,  115, false, false},
   {4345.0,  222,   25, false, false},
   {4350.0, 1439,  719, false,  true}, // Intermediate Call 4350 (1.44k Call OI)
   {4360.0,   67,  100, false, false},
   {4365.0,   37,  243, false, false},
   {4375.0,  509,  196, false, false},
   {4380.0,  206,  156, false, false},
   {4390.0,   97,  226, false, false},
   {4395.0,  105,   30, false, false},
   {4400.0, 2871, 1184,  true, false}, // Tactical Call Wall 4400 (2.87k Call OI)
   {4405.0,  141,   74, false, false},
   {4410.0,  136,   91, false, false},
   {4415.0,  197,   11, false, false},
   {4420.0,  203,   45, false, false},
   {4425.0,  682,  255, false, false},
   {4430.0,  125,  171, false, false},
   {4435.0,   74,  164, false, false},
   {4445.0,   50,  197, false, false},
   {4450.0, 1550,  589, false,  true}, // Half-Century Call 4450 (1.55k OI)
   {4455.0,  389,   47, false, false},
   {4460.0,  220,   73, false, false},
   {4465.0,  142,   84, false, false},
   {4470.0,  363,  177, false, false},
   {4475.0,  499,  223, false, false},
   {4480.0,  156,   52, false, false},
   {4500.0,10133, 1730,  true, false}, // MEGA Call Wall 4500 (10.1k OI)
   {4510.0, 5044,   20,  true, false}, // Super Strike 4510 (5.0k OI)
   {4515.0,  121,  270, false, false},
   {4525.0,  926,  384, false, false},
   {4530.0,   74,  334, false, false},
   {4535.0,  111,  109, false, false},
   {4545.0,  120,   61, false, false},
   {4550.0, 2243,  322, false,  true}, // Half-Century Call 4550 (2.24k OI)
   {4560.0,  606,   11, false, false},
   {4575.0,  308,  221, false, false},
   {4580.0,  293,  179, false, false},
   {4585.0,  315,  351, false, false},
   {4590.0,  116,   13, false, false},
   {4600.0, 7348,  972,  true, false}, // Major Call Wall 4600 (7.35k OI)
   {4610.0,   75,   22, false, false},
   {4620.0,   96,   62, false, false},
   {4625.0,  500,   59, false, false},
   {4630.0,  163,    4, false, false},
   {4640.0,  212,  120, false, false},
   {4650.0, 1508,  235, false,  true}, // Half-Century Call 4650 (1.5k OI)
   {4660.0,  281,  122, false, false},
   {4675.0,  358,   16, false, false},
   {4680.0,  202,   64, false, false},
   {4690.0,  272,  146, false, false},
   {4695.0,  326,   33, false, false},
   {4700.0, 6296,  682,  true, false}, // Major Call Wall 4700 (6.3k OI)
   {4705.0,  152,   17, false, false},
   {4715.0,  117,   12, false, false},
   {4720.0,  139,   15, false, false},
   {4725.0, 9532,  142,  true, false}, // Super Cluster 4725 (9.5k OI)
   {4730.0,  147,    8, false, false},
   {4750.0, 3813,   74, false,  true}, // Half-Century Call 4750 (3.8k OI)
   {4760.0,  163,   25, false, false},
   {4775.0,  345,    6, false, false},
   {4790.0,  237,   73, false, false},
   {4795.0,  147,    1, false, false},
   {4800.0, 8996,  362,  true, false}, // Super Cluster 4800 (9.0k OI)
   {4820.0,  210,   24, false, false},
   {4825.0,  265,  114, false, false},
   {4835.0,  169,  126, false, false},
   {4840.0,  164,    0, false, false},
   {4850.0, 3325,   15, false,  true}, // Half-Century Call 4850 (3.3k OI)
   {4855.0,  138,    3, false, false},
   {4875.0,  228,   16, false, false},
   {4880.0,  314,   11, false, false},
   {4895.0,  252,    2, false, false},
   {4900.0, 5557,  107,  true, false}, // Major Call Wall 4900 (5.56k OI)
   {4910.0, 2042,    0, false, false},
   {4920.0,  143,    4, false, false},
   {4925.0,  426,  240, false, false},
   {4950.0,  676,   25, false,  true}, // Half-Century Call 4950
   {4960.0,  162,    0, false, false},
   {4965.0,  153,    1, false, false},
   {4970.0,  198,    1, false, false},
   {4990.0,  431,    2, false, false},
   {5000.0,12393,  555,  true, false}, // MONSTER Call Wall 5000 (12.4k OI)
   {5020.0,  101,   10, false, false},
   {5025.0,  457,  217, false, false},
   {5030.0,  119,    3, false, false},
   {5050.0,  746,  201, false,  true}, // Half-Century Call 5050
   {5075.0,  135,  100, false, false},
   {5100.0, 3662,   32,  true, false}, // Major Call Wall 5100 (3.66k OI)
   {5115.0,  114,    0, false, false},
   {5120.0,  130,    0, false, false},
   {5135.0,  136,    0, false, false},
   {5150.0,  926,    1, false,  true}, // Half-Century Call 5150
   {5175.0,  231,    0, false, false},
   {5200.0, 2807,  194,  true, false}, // Major Call Wall 5200
   {5210.0,  148,    0, false, false},
   {5215.0,  120,    0, false, false},
   {5220.0,  111,    0, false, false},
   {5225.0, 9411,    0,  true, false}, // Super Cluster 5225 (9.4k OI)
   {5250.0, 1872,  161, false,  true}, // Half-Century Call 5250
   {5300.0, 2375,    3,  true, false}, // Major Call Wall 5300
   {5350.0,  901,    0, false,  true}, // Half-Century Call 5350
   {5360.0,  119,   60, false, false},
   {5390.0,  214,    0, false, false},
   {5400.0, 4202,   61,  true, false}, // Major Call Wall 5400
   {5425.0,  269,    0, false, false},
   {5450.0,  442,    0, false,  true}, // Half-Century Call 5450
   {5475.0,  588,    0, false, false},
   {5480.0,   98,   25, false, false},
   {5495.0,  100,    0, false, false},
   {5500.0,17102,    0,  true, false}, // COLOSSAL Call Wall 5500 (17.1k OI)
   {5525.0,  129,    1, false, false},
   {5550.0,  447,    0, false,  true}, // Half-Century Call 5550
   {5570.0,  257,    0, false, false},
   {5600.0, 3068,    0,  true, false}, // Major Call Wall 5600
   {5650.0,  352,    0, false,  true}, // Half-Century Call 5650
   {5670.0,  161,    0, false, false},
   {5700.0,  865,    0,  true, false}, // Major Call Wall 5700
   {5800.0, 2178,    0,  true, false}, // Extended Call Wall 5800
   {5900.0, 1090,    0,  true, false}, // Extended Call Wall 5900
   {6000.0,14976,    0,  true, false}  // MONSTER Call Wall 6000 (15.0k OI)
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
         ObjectCreate(0, lblName, OBJ_TEXT, 0, tLbl, val);
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
         if(ObjectGetDouble(0, lblName, OBJPROP_PRICE) != val) ObjectSetDouble(0, lblName, OBJPROP_PRICE, val);
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
   double extThreshPts = (baseDecade * 0.60) / _Point;
   bool isStretched    = (MathAbs(g_GannEnergy.displacementPts) >= extThreshPts);
   bool isLowVelocity  = (MathAbs(g_GannEnergy.velocityPtsSec) <= 1.8);
   bool isDecelerating = (g_GannEnergy.accelPtsSec2 * g_GannEnergy.displacementPts <= 0.0);

   if(isStretched && isLowVelocity && isDecelerating)
   {
      g_GannEnergy.isStationPoint = true;
      if(g_GannEnergy.displacementPts > 0)
      {
         g_GannEnergy.stationDirection = 1; // หมดแรงที่ยอดดอย (เตือนเตรียมทุบ Sell)
         g_GannEnergy.energyStatus = "⚡ จุดหมดแรงยอดดอย (v ≈ 0) • ระวังร่วง / ชิงปิดทำกำไร 🔴";
         g_GannEnergy.statusColor  = C'255,80,90';
      }
      else
      {
         g_GannEnergy.stationDirection = -1; // หมดแรงที่ก้นเหว (เตือนเตรียมช้อน Buy)
         g_GannEnergy.energyStatus = "⚡ จุดหมดแรงก้นเหว (v ≈ 0) • ระวังดีด / ชิงปิดทำกำไร 🟢";
         g_GannEnergy.statusColor  = C'50,255,150';
      }
   }
   else
   {
      g_GannEnergy.isStationPoint   = false;
      g_GannEnergy.stationDirection = 0;

      double absV = MathAbs(g_GannEnergy.velocityPtsSec);
      if(absV >= 8.0)
      {
         g_GannEnergy.energyStatus = "🚀 พุ่งตัวแรงเต็มสปีด • คลื่นกำลังขยายตัว";
         g_GannEnergy.statusColor  = clrAqua;
      }
      else if(absV >= 2.5)
      {
         g_GannEnergy.energyStatus = "🟢 คลื่นวิ่งปกติ • มีแรงส่งต่อเนื่อง";
         g_GannEnergy.statusColor  = clrPaleGreen;
      }
      else
      {
         g_GannEnergy.energyStatus = "🟡 สปีดเริ่มชะลอตัว • สะสมพลังใกล้จุดสมดุล";
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
   if(!InpUseVSL_LockFloor) return;
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
//| 14E. DTD CONFIRMATION (CF M1) & MONEY MANAGEMENT 1:3R            |
//+------------------------------------------------------------------+
void ScanDTD_CF_M1()
{
   if(!InpUseDTD_CF_M1)
   {
      g_DTD.statusText = "🎯 CF M1: ปิดการใช้งาน";
      g_DTD.mmPlanText = "—";
      g_DTD.statusColor = clrSilver;
      return;
   }

   MqlRates ratesM1[];
   ArraySetAsSeries(ratesM1, true);
   int copiedM1 = CopyRates(_Symbol, PERIOD_M1, 0, 100, ratesM1);
   if(copiedM1 < 25)
   {
      g_DTD.statusText = "🎯 CF M1: กำลังโหลดแท่งเทียน M1...";
      g_DTD.statusColor = clrSilver;
      return;
   }

   // 1. ตรวจจับโครงสร้างสวิงไฮ/โลว์บน M1 ("ขึ้น" / "ลง") ใน 25 แท่งล่าสุด
   int highestM1Bar = 1;
   int lowestM1Bar = 1;
   double highestM1High = ratesM1[1].high;
   double lowestM1Low = ratesM1[1].low;

   for(int i = 1; i < 25 && i < copiedM1; i++)
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

   g_DTD.m1SwingHighPrice = highestM1High;
   g_DTD.m1SwingHighTime  = ratesM1[highestM1Bar].time;
   g_DTD.m1SwingLowPrice  = lowestM1Low;
   g_DTD.m1SwingLowTime   = ratesM1[lowestM1Bar].time;

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
   // 1B. ตรวจสอบสถานะการล็อกและตรึงกรอบแผนเทรด (SETUP FREEZE & LATCH CHECK)
   // =========================================================================
   if(g_DTD.isLatched)
   {
      bool unlatch = false;
      if(g_DTD.latchedSide == 1)
      {
         if(curBid >= g_DTD.latchedTP3Price) unlatch = true;
         else if(curBid <= g_DTD.latchedSLPrice) unlatch = true;
         else if((ratesM1[0].time - g_DTD.latchedTime) > 45 * 60 && lowestM1Low < g_DTD.latchedSLPrice) unlatch = true;
      }
      else if(g_DTD.latchedSide == -1)
      {
         if(curAsk <= g_DTD.latchedTP3Price) unlatch = true;
         else if(curAsk >= g_DTD.latchedSLPrice) unlatch = true;
         else if((ratesM1[0].time - g_DTD.latchedTime) > 45 * 60 && highestM1High > g_DTD.latchedSLPrice) unlatch = true;
      }

      if(unlatch)
      {
         Print(">>> [DeungDang_Trade] 🔓 ปลดล็อกแผนเทรดเดิม ➔ รีเซ็ตเพื่อรอจับโครงสร้างใหม่");
         g_DTD.isLatched   = false;
         g_DTD.latchedSide = 0;
      }
      else
      {
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
         g_DTD.recommendedLot    = g_DTD.latchedLot;
         g_DTD.isEngulfConfirmed = true;

         if(g_DTD.latchedSide == 1)
         {
            g_DTD.buyEngulfConfirmed   = true;
            g_DTD.buyConfirmEntryPrice = g_DTD.latchedEntryPrice;
            g_DTD.buyConfirmSLPrice    = g_DTD.latchedSLPrice;
            g_DTD.buyConfirmTP1RPrice  = g_DTD.latchedTP1Price;
            g_DTD.buyConfirmTP2RPrice  = g_DTD.latchedTP2Price;
            g_DTD.buyConfirmTP3RPrice  = g_DTD.latchedTP3Price;
            g_DTD.buySlDistPoints      = g_DTD.latchedSLDist;
            g_DTD.buyRecommendedLot    = g_DTD.latchedLot;

            double distRetest = (curBid - g_DTD.shortestWickPrice) / _Point;
            if(MathAbs(distRetest) <= 40.0)
            {
               g_DTD.statusText  = StringFormat("🎯 CF M1: 🟢 [จังหวะย่อรีเทส!] ราคาแตะเส้นไส้สั้นสุด %s • จุดขึ้นรถ BUY ราคาดีที่สุด!", DoubleToString(g_DTD.shortestWickPrice, _Digits));
               g_DTD.statusColor = C'0,255,200';
            }
            else if(curBid > g_DTD.latchedEntryPrice)
            {
               double pnlPts = (curBid - g_DTD.latchedEntryPrice) / _Point;
               g_DTD.statusText  = StringFormat("🎯 CF M1: 🟢 แผน BUY วิ่งทำกำไร (+%.0f pts) ➔ มุ่งสู่เป้าหมาย 1:3R", pnlPts);
               g_DTD.statusColor = C'0,255,136';
            }
            else
            {
               g_DTD.statusText  = "🎯 CF M1: 🟢 จบกลืนกิน BUY สำเร็จ! (กรอบ 1:3R ล็อกนิ่งสนิท รอขึ้นรถ)";
               g_DTD.statusColor = C'0,255,136';
            }
         }
         else
         {
            g_DTD.sellEngulfConfirmed   = true;
            g_DTD.sellConfirmEntryPrice = g_DTD.latchedEntryPrice;
            g_DTD.sellConfirmSLPrice    = g_DTD.latchedSLPrice;
            g_DTD.sellConfirmTP1RPrice  = g_DTD.latchedTP1Price;
            g_DTD.sellConfirmTP2RPrice  = g_DTD.latchedTP2Price;
            g_DTD.sellConfirmTP3RPrice  = g_DTD.latchedTP3Price;
            g_DTD.sellSlDistPoints      = g_DTD.latchedSLDist;
            g_DTD.sellRecommendedLot    = g_DTD.latchedLot;

            double distRetest = (g_DTD.shortestWickPrice - curAsk) / _Point;
            if(MathAbs(distRetest) <= 40.0)
            {
               g_DTD.statusText  = StringFormat("🎯 CF M1: 🔴 [จังหวะดีดรีเทส!] ราคาแตะเส้นไส้สั้นสุด %s • จุดขึ้นรถ SELL ราคาดีที่สุด!", DoubleToString(g_DTD.shortestWickPrice, _Digits));
               g_DTD.statusColor = C'255,180,80';
            }
            else if(curAsk < g_DTD.latchedEntryPrice)
            {
               double pnlPts = (g_DTD.latchedEntryPrice - curAsk) / _Point;
               g_DTD.statusText  = StringFormat("🎯 CF M1: 🔴 แผน SELL วิ่งทำกำไร (+%.0f pts) ➔ มุ่งสู่เป้าหมาย 1:3R", pnlPts);
               g_DTD.statusColor = C'255,80,90';
            }
            else
            {
               g_DTD.statusText  = "🎯 CF M1: 🔴 จบกลืนกิน SELL สำเร็จ! (กรอบ 1:3R ล็อกนิ่งสนิท รอขึ้นรถ)";
               g_DTD.statusColor = C'255,80,90';
            }
         }

         g_DTD.mmPlanText = StringFormat("💵 แผน MM (1R/2R/3R): SL %.0f | TP1 %.0f | TP2 %.0f | TP3 %.0f pts | Lot แนะนำ: %.2f (เสี่ยง %s%.1f)", g_DTD.slDistPoints, g_DTD.tp1RDistPoints, g_DTD.tp2RDistPoints, g_DTD.tp3RDistPoints, g_DTD.recommendedLot, moneyUnit, InpDTD_RiskMoney);
         return;
      }
   }

   // =========================================================================
   // 2. คำนวณแผน BUY อิสระ (Bullish DTD Candidate)
   // =========================================================================
   bool buyHasShift = (ratesM1[0].close >= highestM1High || ratesM1[1].close >= highestM1High || highestM1Bar >= 3);
   int buyStartBar = 1;
   int buyEndBar = MathMin(highestM1Bar, 15);
   if(buyEndBar <= buyStartBar) buyEndBar = MathMin(10, copiedM1 - 1);

   double buyShortestWickLen = 999999.0;
   double buyTargetWickPrice = 0.0;
   datetime buyTargetWickTime = 0;
   double lowestPullbackPrice = ratesM1[1].low;

   for(int b = buyStartBar; b <= buyEndBar; b++)
   {
      double bodyTop = MathMax(ratesM1[b].open, ratesM1[b].close);
      double upperWick = ratesM1[b].high - bodyTop;
      if(ratesM1[b].low < lowestPullbackPrice) lowestPullbackPrice = ratesM1[b].low;

      if(upperWick < buyShortestWickLen && upperWick >= 0.0)
      {
         buyShortestWickLen = upperWick;
         buyTargetWickPrice = ratesM1[b].high;
         buyTargetWickTime = ratesM1[b].time;
      }
   }
   if(buyTargetWickPrice <= 0.0)
   {
      buyTargetWickPrice = ratesM1[1].high;
      buyTargetWickTime = ratesM1[1].time;
   }

   bool buyConfirmed = (ratesM1[1].close > buyTargetWickPrice || ratesM1[2].close > buyTargetWickPrice);
   bool buyIsTestingNow = (!buyConfirmed && ratesM1[0].close > buyTargetWickPrice);

   double buyEntryPrice = curAsk;
   double buySLPrice = lowestPullbackPrice - buffer;
   if((buyEntryPrice - buySLPrice) < 80.0 * _Point)
      buySLPrice = buyEntryPrice - (80.0 * _Point);

   double buySLDist = (buyEntryPrice - buySLPrice) / _Point;
   if(buySLDist <= 0.0) buySLDist = 100.0;

   double buyTP1RPrice = buyEntryPrice + (buySLDist * _Point * 1.0);
   double buyTP2RPrice = buyEntryPrice + (buySLDist * _Point * 2.0);
   double buyTP3RPrice = buyEntryPrice + (buySLDist * _Point * InpDTD_TargetRR);

   double buyLossPerLot = buySLDist * ptValPerLot;
   double buyCalcLot = InpDefaultLot;
   if(buyLossPerLot > 0.0 && InpDTD_RiskMoney > 0.0)
      buyCalcLot = InpDTD_RiskMoney / buyLossPerLot;
   buyCalcLot = MathFloor(buyCalcLot / stepLot) * stepLot;
   if(buyCalcLot < minLot) buyCalcLot = minLot;
   if(buyCalcLot > maxLot) buyCalcLot = maxLot;
   double buyRecommendedLot = NormalizeDouble(buyCalcLot, 2);

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

   // =========================================================================
   // 3. คำนวณแผน SELL อิสระ (Bearish DTD Candidate)
   // =========================================================================
   bool sellHasShift = (ratesM1[0].close <= lowestM1Low || ratesM1[1].close <= lowestM1Low || lowestM1Bar >= 3);
   int sellStartBar = 1;
   int sellEndBar = MathMin(lowestM1Bar, 15);
   if(sellEndBar <= sellStartBar) sellEndBar = MathMin(10, copiedM1 - 1);

   double sellShortestWickLen = 999999.0;
   double sellTargetWickPrice = 0.0;
   datetime sellTargetWickTime = 0;
   double highestPullbackPrice = ratesM1[1].high;

   for(int b = sellStartBar; b <= sellEndBar; b++)
   {
      double bodyBottom = MathMin(ratesM1[b].open, ratesM1[b].close);
      double lowerWick = bodyBottom - ratesM1[b].low;
      if(ratesM1[b].high > highestPullbackPrice) highestPullbackPrice = ratesM1[b].high;

      if(lowerWick < sellShortestWickLen && lowerWick >= 0.0)
      {
         sellShortestWickLen = lowerWick;
         sellTargetWickPrice = ratesM1[b].low;
         sellTargetWickTime = ratesM1[b].time;
      }
   }
   if(sellTargetWickPrice <= 0.0)
   {
      sellTargetWickPrice = ratesM1[1].low;
      sellTargetWickTime = ratesM1[1].time;
   }

   bool sellConfirmed = (ratesM1[1].close < sellTargetWickPrice || ratesM1[2].close < sellTargetWickPrice);
   bool sellIsTestingNow = (!sellConfirmed && ratesM1[0].close < sellTargetWickPrice);

   double sellEntryPrice = curBid;
   double sellSLPrice = highestPullbackPrice + buffer;
   if((sellSLPrice - sellEntryPrice) < 80.0 * _Point)
      sellSLPrice = sellEntryPrice + (80.0 * _Point);

   double sellSLDist = (sellSLPrice - sellEntryPrice) / _Point;
   if(sellSLDist <= 0.0) sellSLDist = 100.0;

   double sellTP1RPrice = sellEntryPrice - (sellSLDist * _Point * 1.0);
   double sellTP2RPrice = sellEntryPrice - (sellSLDist * _Point * 2.0);
   double sellTP3RPrice = sellEntryPrice - (sellSLDist * _Point * InpDTD_TargetRR);

   double sellLossPerLot = sellSLDist * ptValPerLot;
   double sellCalcLot = InpDefaultLot;
   if(sellLossPerLot > 0.0 && InpDTD_RiskMoney > 0.0)
      sellCalcLot = InpDTD_RiskMoney / sellLossPerLot;
   sellCalcLot = MathFloor(sellCalcLot / stepLot) * stepLot;
   if(sellCalcLot < minLot) sellCalcLot = minLot;
   if(sellCalcLot > maxLot) sellCalcLot = maxLot;
   double sellRecommendedLot = NormalizeDouble(sellCalcLot, 2);

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
   // 4. SMART CONTEXT ARBITRATOR (POI Demand/Supply & Liquidity Sweep Confluence)
   // =========================================================================
   double zoneTol = (g_Asset.assetType == ASSET_CRYPTO) ? (curBid * 0.003) : (g_Asset.assetType == ASSET_GOLD ? (100.0 * _Point) : (25.0 * _Point));

   double distDZ = 9999999.0;
   double distSZ = 9999999.0;
   for(int z = 0; z < g_ZoneCount; z++)
   {
      if(!g_Zones[z].isActive) continue;
      if(g_Zones[z].isDemand)
      {
         double d = (curBid >= g_Zones[z].low && curBid <= g_Zones[z].high) ? 0.0 : MathAbs(curBid - g_Zones[z].high);
         if(d < distDZ) distDZ = d;
      }
      else
      {
         double d = (curAsk >= g_Zones[z].low && curAsk <= g_Zones[z].high) ? 0.0 : MathAbs(g_Zones[z].low - curAsk);
         if(d < distSZ) distSZ = d;
      }
   }

   bool inDZ = (distDZ <= zoneTol);
   bool inSZ = (distSZ <= zoneTol);
   bool sweepSSL = (g_IsFakeoutTrap && g_FakeoutSide == 1);
   bool sweepBSL = (g_IsFakeoutTrap && g_FakeoutSide == -1);

   int m15Dir = GetM15_TrendDirection();
   bool m15AllowsBuy  = (!InpRequireM15_Alignment || m15Dir == 1);
   bool m15AllowsSell = (!InpRequireM15_Alignment || m15Dir == -1);

   int activeSide = 0;
   if(inDZ || sweepSSL)
   {
      activeSide = 1;
   }
   else if(inSZ || sweepBSL)
   {
      activeSide = -1;
   }
   else
   {
      if(buyConfirmed && !sellConfirmed)
         activeSide = 1;
      else if(sellConfirmed && !buyConfirmed)
         activeSide = -1;
      else if(buyConfirmed && sellConfirmed)
         activeSide = (buyTargetWickTime >= sellTargetWickTime) ? 1 : -1;
      else
      {
         if(distDZ < distSZ) activeSide = 1;
         else if(distSZ < distDZ) activeSide = -1;
         else if(g_WaveSide != 0) activeSide = g_WaveSide;
         else if(g_SamuraiMTF.consensusDir != 0) activeSide = g_SamuraiMTF.consensusDir;
         else activeSide = 1;
      }
   }

   g_DTD.setupSide = activeSide;

   // =========================================================================
   // 5. ซิงค์ค่าของฝั่งที่แอคทีฟเข้าสู่โครงสร้างหลัก g_DTD
   // =========================================================================
   if(activeSide == 1)
   {
      g_DTD.hasM1Shift        = buyHasShift;
      g_DTD.m1StructDir       = 1;
      g_DTD.m1ShiftBreakPrice = highestM1High;
      g_DTD.m1ShiftTime       = ratesM1[highestM1Bar].time;
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
      g_DTD.tp3RDistPoints    = buySLDist * InpDTD_TargetRR;
      g_DTD.recommendedLot    = buyRecommendedLot;

      if(buyConfirmed)
      {
         if(!g_DTD.isLatched && m15AllowsBuy)
         {
            g_DTD.isLatched           = true;
            g_DTD.latchedSide         = 1;
            g_DTD.latchedTime         = ratesM1[1].time;
            g_DTD.latchedEntryPrice   = buyEntryPrice;
            g_DTD.latchedSLPrice      = buySLPrice;
            g_DTD.latchedTP1Price     = buyTP1RPrice;
            g_DTD.latchedTP2Price     = buyTP2RPrice;
            g_DTD.latchedTP3Price     = buyTP3RPrice;
            g_DTD.latchedSLDist       = buySLDist;
            g_DTD.latchedLot          = buyRecommendedLot;
            g_DTD.latchedShortestWick = buyTargetWickPrice;
            Print(">>> [DeungDang_Trade] 🔒 ล็อกกรอบแผนเทรด BUY นิ่งสนิท! Entry: ", buyEntryPrice, " SL: ", buySLPrice, " TP3: ", buyTP3RPrice);
         }
         g_DTD.statusText  = StringFormat("🎯 CF M1: 🟢 จบกลืนกิน BUY สำเร็จ! (1R/2R/3R พร้อมลั่นไก)", DoubleToString(buyTargetWickPrice, _Digits));
         g_DTD.statusColor = C'0,255,136';
      }
      else if(buyIsTestingNow)
      {
         double distToCF = (buyTargetWickPrice - curAsk) / _Point;
         g_DTD.statusText  = StringFormat("⚡ CF M1: 🟢 แท่งสด M1 กำลังเบรกทดสอบ %s (ห่าง %s จุด • รอจบแท่งคอนเฟิร์ม)", DoubleToString(buyTargetWickPrice, _Digits), DoubleToString(distToCF, 0));
         g_DTD.statusColor = clrOrange;
      }
      else
      {
         double distToCF = (buyTargetWickPrice - curAsk) / _Point;
         g_DTD.statusText  = (buyHasShift ? StringFormat("🎯 CF M1: 🟢 ทะลุ 'ขึ้น' แล้ว ➔ รอ M1 รีเทสต์+กลืนกิน %s (ห่าง %s จุด)", DoubleToString(buyTargetWickPrice, _Digits), DoubleToString(distToCF, 0)) : StringFormat("🎯 CF M1: ⏳ รอแท่ง M1 เบรกทะลุเส้น 'ขึ้น' %s", DoubleToString(highestM1High, _Digits)));
         g_DTD.statusColor = clrGold;
      }

      g_DTD.mmPlanText = StringFormat("💵 แผน MM (1R/2R/3R): SL %.0f | TP1 %.0f | TP2 %.0f | TP3 %.0f pts | Lot แนะนำ: %.2f (เสี่ยง %s%.1f)", g_DTD.slDistPoints, g_DTD.tp1RDistPoints, g_DTD.tp2RDistPoints, g_DTD.tp3RDistPoints, g_DTD.recommendedLot, moneyUnit, InpDTD_RiskMoney);
   }
   else
   {
      g_DTD.hasM1Shift        = sellHasShift;
      g_DTD.m1StructDir       = -1;
      g_DTD.m1ShiftBreakPrice = lowestM1Low;
      g_DTD.m1ShiftTime       = ratesM1[lowestM1Bar].time;
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
      g_DTD.tp3RDistPoints    = sellSLDist * InpDTD_TargetRR;
      g_DTD.recommendedLot    = sellRecommendedLot;

      if(sellConfirmed)
      {
         if(!g_DTD.isLatched && m15AllowsSell)
         {
            g_DTD.isLatched           = true;
            g_DTD.latchedSide         = -1;
            g_DTD.latchedTime         = ratesM1[1].time;
            g_DTD.latchedEntryPrice   = sellEntryPrice;
            g_DTD.latchedSLPrice      = sellSLPrice;
            g_DTD.latchedTP1Price     = sellTP1RPrice;
            g_DTD.latchedTP2Price     = sellTP2RPrice;
            g_DTD.latchedTP3Price     = sellTP3RPrice;
            g_DTD.latchedSLDist       = sellSLDist;
            g_DTD.latchedLot          = sellRecommendedLot;
            g_DTD.latchedShortestWick = sellTargetWickPrice;
            Print(">>> [DeungDang_Trade] 🔒 ล็อกกรอบแผนเทรด SELL นิ่งสนิท! Entry: ", sellEntryPrice, " SL: ", sellSLPrice, " TP3: ", sellTP3RPrice);
         }
         g_DTD.statusText  = StringFormat("🎯 CF M1: 🔴 จบกลืนกิน SELL สำเร็จ! (1R/2R/3R พร้อมลั่นไก)", DoubleToString(sellTargetWickPrice, _Digits));
         g_DTD.statusColor = C'255,80,90';
      }
      else if(sellIsTestingNow)
      {
         double distToCF = (curBid - sellTargetWickPrice) / _Point;
         g_DTD.statusText  = StringFormat("⚡ CF M1: 🔴 แท่งสด M1 กำลังทุบทดสอบ %s (ห่าง %s จุด • รอจบแท่งคอนเฟิร์ม)", DoubleToString(sellTargetWickPrice, _Digits), DoubleToString(distToCF, 0));
         g_DTD.statusColor = clrOrange;
      }
      else
      {
         double distToCF = (curBid - sellTargetWickPrice) / _Point;
         g_DTD.statusText  = (sellHasShift ? StringFormat("🎯 CF M1: 🔴 หลุด 'ลง' แล้ว ➔ รอ M1 รีเทสต์+กลืนกิน %s (ห่าง %s จุด)", DoubleToString(sellTargetWickPrice, _Digits), DoubleToString(distToCF, 0)) : StringFormat("🎯 CF M1: ⏳ รอแท่ง M1 หลุดทะลุเส้น 'ลง' %s", DoubleToString(lowestM1Low, _Digits)));
         g_DTD.statusColor = clrGold;
      }

      g_DTD.mmPlanText = StringFormat("💵 แผน MM (1R/2R/3R): SL %.0f | TP1 %.0f | TP2 %.0f | TP3 %.0f pts | Lot แนะนำ: %.2f (เสี่ยง %s%.1f)", g_DTD.slDistPoints, g_DTD.tp1RDistPoints, g_DTD.tp2RDistPoints, g_DTD.tp3RDistPoints, g_DTD.recommendedLot, moneyUnit, InpDTD_RiskMoney);
   }
}

//+------------------------------------------------------------------+
//| 14F. DRAW DTD M1 VISUALS (AJARN DEJ M1 SETUP & 1R/2R/3R TIERS)   |
//+------------------------------------------------------------------+
void DrawDTD_M1_Visuals()
{
   if(!InpUseDTD_CF_M1 || !InpDrawDTD_M1_Visuals || g_DTD.shortestWickPrice <= 0.0)
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_UP");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_UP");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_DOWN");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_DOWN");
      ObjectDelete(0, GUI_PREFIX + "DTD_MARK_ENTRY");
      ObjectDelete(0, GUI_PREFIX + "DTD_WICK_LINE");
      ObjectDelete(0, GUI_PREFIX + "DTD_WICK_LBL");
      ObjectDelete(0, GUI_PREFIX + "DTD_BOX_SL");
      ObjectDelete(0, GUI_PREFIX + "DTD_BOX_TP");
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
   int forwardBars = 12;
   if(_Period == PERIOD_M1)       forwardBars = 15;
   else if(_Period <= PERIOD_M5)  forwardBars = 8;
   else if(_Period <= PERIOD_M15) forwardBars = 6;
   else if(_Period <= PERIOD_M30) forwardBars = 5;
   else                           forwardBars = 4;

   datetime tStart   = (g_DTD.isLatched && g_DTD.latchedTime > 0) ? g_DTD.latchedTime : ((g_DTD.shortestWickTime > 0) ? g_DTD.shortestWickTime : (TimeCurrent() - (tfSec * 4)));
   datetime tEnd     = TimeCurrent() + (tfSec * forwardBars);
   datetime tWickLbl = tEnd;

   // 1. เส้นแนวนอนและป้ายภาษาไทย "ขึ้น" (Swing High M1) สไตล์ชาร์ตอาจารย์เดช
   if(g_DTD.m1SwingHighPrice > 0.0)
   {
      string lineUp = GUI_PREFIX + "DTD_LINE_UP";
      datetime tUpStart = (g_DTD.m1SwingHighTime > 0) ? g_DTD.m1SwingHighTime : (TimeCurrent() - (tfSec * 15));
      if(ObjectFind(0, lineUp) < 0)
      {
         ObjectCreate(0, lineUp, OBJ_TREND, 0, tUpStart, g_DTD.m1SwingHighPrice, tEnd, g_DTD.m1SwingHighPrice);
         ObjectSetInteger(0, lineUp, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, lineUp, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, lineUp, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineUp, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineUp, OBJPROP_BACK, false);
      }
      else
      {
         ObjectSetInteger(0, lineUp, OBJPROP_TIME, 0, tUpStart);
         ObjectSetDouble(0, lineUp, OBJPROP_PRICE, 0, g_DTD.m1SwingHighPrice);
         ObjectSetInteger(0, lineUp, OBJPROP_TIME, 1, tEnd);
         ObjectSetDouble(0, lineUp, OBJPROP_PRICE, 1, g_DTD.m1SwingHighPrice);
         ObjectSetInteger(0, lineUp, OBJPROP_COLOR, clrWhite);
      }

      string lblUp = GUI_PREFIX + "DTD_LBL_UP";
      string txtUp = StringFormat("ขึ้น (%s)", DoubleToString(g_DTD.m1SwingHighPrice, _Digits));
      if(ObjectFind(0, lblUp) < 0)
      {
         ObjectCreate(0, lblUp, OBJ_TEXT, 0, tUpStart, g_DTD.m1SwingHighPrice);
         ObjectSetString(0, lblUp, OBJPROP_TEXT, txtUp);
         ObjectSetString(0, lblUp, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, lblUp, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblUp, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, lblUp, OBJPROP_ANCHOR, ANCHOR_LOWER);
         ObjectSetInteger(0, lblUp, OBJPROP_BACK, false);
      }
      else
      {
         ObjectSetInteger(0, lblUp, OBJPROP_TIME, 0, tUpStart);
         ObjectSetDouble(0, lblUp, OBJPROP_PRICE, 0, g_DTD.m1SwingHighPrice);
         ObjectSetString(0, lblUp, OBJPROP_TEXT, txtUp);
         ObjectSetInteger(0, lblUp, OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, lblUp, OBJPROP_FONT, "Segoe UI Black");
      }
   }

   // 2. เส้นแนวนอนและป้ายภาษาไทย "ลง" (Swing Low M1) สไตล์ชาร์ตอาจารย์เดช
   if(g_DTD.m1SwingLowPrice > 0.0)
   {
      string lineDn = GUI_PREFIX + "DTD_LINE_DOWN";
      datetime tDnStart = (g_DTD.m1SwingLowTime > 0) ? g_DTD.m1SwingLowTime : (TimeCurrent() - (tfSec * 15));
      if(ObjectFind(0, lineDn) < 0)
      {
         ObjectCreate(0, lineDn, OBJ_TREND, 0, tDnStart, g_DTD.m1SwingLowPrice, tEnd, g_DTD.m1SwingLowPrice);
         ObjectSetInteger(0, lineDn, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, lineDn, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, lineDn, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineDn, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineDn, OBJPROP_BACK, false);
      }
      else
      {
         ObjectSetInteger(0, lineDn, OBJPROP_TIME, 0, tDnStart);
         ObjectSetDouble(0, lineDn, OBJPROP_PRICE, 0, g_DTD.m1SwingLowPrice);
         ObjectSetInteger(0, lineDn, OBJPROP_TIME, 1, tEnd);
         ObjectSetDouble(0, lineDn, OBJPROP_PRICE, 1, g_DTD.m1SwingLowPrice);
         ObjectSetInteger(0, lineDn, OBJPROP_COLOR, clrWhite);
      }

      string lblDn = GUI_PREFIX + "DTD_LBL_DOWN";
      string txtDn = StringFormat("ลง (%s)", DoubleToString(g_DTD.m1SwingLowPrice, _Digits));
      if(ObjectFind(0, lblDn) < 0)
      {
         ObjectCreate(0, lblDn, OBJ_TEXT, 0, tDnStart, g_DTD.m1SwingLowPrice);
         ObjectSetString(0, lblDn, OBJPROP_TEXT, txtDn);
         ObjectSetString(0, lblDn, OBJPROP_FONT, "Segoe UI Black");
         ObjectSetInteger(0, lblDn, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblDn, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, lblDn, OBJPROP_ANCHOR, ANCHOR_UPPER);
         ObjectSetInteger(0, lblDn, OBJPROP_BACK, false);
      }
      else
      {
         ObjectSetInteger(0, lblDn, OBJPROP_TIME, 0, tDnStart);
         ObjectSetDouble(0, lblDn, OBJPROP_PRICE, 0, g_DTD.m1SwingLowPrice);
         ObjectSetString(0, lblDn, OBJPROP_TEXT, txtDn);
         ObjectSetInteger(0, lblDn, OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, lblDn, OBJPROP_FONT, "Segoe UI Black");
      }
   }

   // 3. เส้นประแนวนอนเกาะ "ปลายไส้ที่สั้นที่สุด" (Shortest Wick Level)
   string wickLine = GUI_PREFIX + "DTD_WICK_LINE";
   color  wickCol  = g_DTD.isEngulfConfirmed ? (g_DTD.setupSide == 1 ? C'0,255,136' : C'255,80,90') : clrGold;
   if(ObjectFind(0, wickLine) < 0)
   {
      ObjectCreate(0, wickLine, OBJ_TREND, 0, tStart, g_DTD.shortestWickPrice, tEnd, g_DTD.shortestWickPrice);
      ObjectSetInteger(0, wickLine, OBJPROP_COLOR, wickCol);
      ObjectSetInteger(0, wickLine, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, wickLine, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, wickLine, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, wickLine, OBJPROP_BACK, false);
   }
   else
   {
      ObjectSetInteger(0, wickLine, OBJPROP_TIME, 0, tStart);
      ObjectSetDouble(0, wickLine, OBJPROP_PRICE, 0, g_DTD.shortestWickPrice);
      ObjectSetInteger(0, wickLine, OBJPROP_TIME, 1, tEnd);
      ObjectSetDouble(0, wickLine, OBJPROP_PRICE, 1, g_DTD.shortestWickPrice);
      ObjectSetInteger(0, wickLine, OBJPROP_COLOR, wickCol);
      ObjectSetInteger(0, wickLine, OBJPROP_WIDTH, 2);
   }

   // 4. ป้ายข้อความบอกเกณฑ์ CF M1 (ชิดขอบแท่งเทียนปัจจุบัน ไม่หลุดลอยนอกจอ)
   string wickLbl = GUI_PREFIX + "DTD_WICK_LBL";
   string lblTxt  = StringFormat("🎯 เกณฑ์ CF M1 (ไส้สั้นสุด): %s %s", 
                                 DoubleToString(g_DTD.shortestWickPrice, _Digits),
                                 (g_DTD.isEngulfConfirmed ? "★ [CF กลืนกินสำเร็จ!]" : "[รอปิดแท่งกลืนกิน]"));
   if(ObjectFind(0, wickLbl) < 0)
   {
      ObjectCreate(0, wickLbl, OBJ_TEXT, 0, tWickLbl, g_DTD.shortestWickPrice);
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
      ObjectSetDouble(0, wickLbl, OBJPROP_PRICE, 0, g_DTD.shortestWickPrice);
      ObjectSetString(0, wickLbl, OBJPROP_TEXT, lblTxt);
      ObjectSetInteger(0, wickLbl, OBJPROP_COLOR, clrWhite);
      ObjectSetString(0, wickLbl, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, wickLbl, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }

   // 5. สัญลักษณ์จุดลั่นไก (Entry Tick Mark สไตล์อาจารย์เดช)
   if(g_DTD.isEngulfConfirmed && g_DTD.confirmEntryPrice > 0.0)
   {
      string markName = GUI_PREFIX + "DTD_MARK_ENTRY";
      if(ObjectFind(0, markName) < 0)
      {
         ObjectCreate(0, markName, OBJ_ARROW_CHECK, 0, TimeCurrent(), g_DTD.confirmEntryPrice);
         ObjectSetInteger(0, markName, OBJPROP_COLOR, (g_DTD.setupSide == 1 ? C'0,255,136' : C'255,80,90'));
         ObjectSetInteger(0, markName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, markName, OBJPROP_ANCHOR, (g_DTD.setupSide == 1 ? ANCHOR_TOP : ANCHOR_BOTTOM));
      }
      else
      {
         ObjectSetInteger(0, markName, OBJPROP_TIME, 0, TimeCurrent());
         ObjectSetDouble(0, markName, OBJPROP_PRICE, 0, g_DTD.confirmEntryPrice);
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

      // กล่อง SL (1R Risk Box)
      string boxSL = GUI_PREFIX + "DTD_BOX_SL";
      double slTop = MathMax(g_DTD.confirmEntryPrice, g_DTD.confirmSLPrice);
      double slBtm = MathMin(g_DTD.confirmEntryPrice, g_DTD.confirmSLPrice);
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
      string boxTP = GUI_PREFIX + "DTD_BOX_TP";
      double tpTop = MathMax(g_DTD.confirmEntryPrice, g_DTD.confirmTP3RPrice);
      double tpBtm = MathMin(g_DTD.confirmEntryPrice, g_DTD.confirmTP3RPrice);
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
      if(g_DTD.confirmTP1RPrice > 0.0)
      {
         string lineTP1 = GUI_PREFIX + "DTD_LINE_TP1R";
         if(ObjectFind(0, lineTP1) < 0)
         {
            ObjectCreate(0, lineTP1, OBJ_TREND, 0, bStart, g_DTD.confirmTP1RPrice, bEnd, g_DTD.confirmTP1RPrice);
            ObjectSetInteger(0, lineTP1, OBJPROP_COLOR, C'100,210,140');
            ObjectSetInteger(0, lineTP1, OBJPROP_STYLE, STYLE_DOT);
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

         string lblTP1 = GUI_PREFIX + "DTD_LBL_TP1R";
         double tp1Dist = MathAbs(g_DTD.confirmTP1RPrice - curBidPrice) / _Point;
         string tp1Txt  = StringFormat(" 🛡️ TP 1R (1:1): %s (+%s) ", DoubleToString(g_DTD.confirmTP1RPrice, _Digits), FormatMoneyOrPoints(tp1Dist));
         if(ObjectFind(0, lblTP1) < 0)
         {
            ObjectCreate(0, lblTP1, OBJ_TEXT, 0, bEnd, g_DTD.confirmTP1RPrice);
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
            ObjectSetDouble(0, lblTP1, OBJPROP_PRICE, 0, g_DTD.confirmTP1RPrice);
            ObjectSetString(0, lblTP1, OBJPROP_TEXT, tp1Txt);
            ObjectSetInteger(0, lblTP1, OBJPROP_COLOR, clrWhite);
            ObjectSetString(0, lblTP1, OBJPROP_FONT, "Segoe UI Black");
         }
      }

      // เส้น & ป้าย TP 2R (1:2)
      if(g_DTD.confirmTP2RPrice > 0.0)
      {
         string lineTP2 = GUI_PREFIX + "DTD_LINE_TP2R";
         if(ObjectFind(0, lineTP2) < 0)
         {
            ObjectCreate(0, lineTP2, OBJ_TREND, 0, bStart, g_DTD.confirmTP2RPrice, bEnd, g_DTD.confirmTP2RPrice);
            ObjectSetInteger(0, lineTP2, OBJPROP_COLOR, C'70,235,160');
            ObjectSetInteger(0, lineTP2, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, lineTP2, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lineTP2, OBJPROP_RAY_RIGHT, false);
         }
         else
         {
            ObjectSetInteger(0, lineTP2, OBJPROP_TIME, 0, bStart);
            ObjectSetDouble(0, lineTP2, OBJPROP_PRICE, 0, g_DTD.confirmTP2RPrice);
            ObjectSetInteger(0, lineTP2, OBJPROP_TIME, 1, bEnd);
            ObjectSetDouble(0, lineTP2, OBJPROP_PRICE, 1, g_DTD.confirmTP2RPrice);
         }

         string lblTP2 = GUI_PREFIX + "DTD_LBL_TP2R";
         double tp2Dist = MathAbs(g_DTD.confirmTP2RPrice - curBidPrice) / _Point;
         string tp2Txt  = StringFormat(" 🎯 TP 2R (1:2): %s (+%s) ", DoubleToString(g_DTD.confirmTP2RPrice, _Digits), FormatMoneyOrPoints(tp2Dist));
         if(ObjectFind(0, lblTP2) < 0)
         {
            ObjectCreate(0, lblTP2, OBJ_TEXT, 0, bEnd, g_DTD.confirmTP2RPrice);
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
            ObjectSetDouble(0, lblTP2, OBJPROP_PRICE, 0, g_DTD.confirmTP2RPrice);
            ObjectSetString(0, lblTP2, OBJPROP_TEXT, tp2Txt);
            ObjectSetInteger(0, lblTP2, OBJPROP_COLOR, clrWhite);
            ObjectSetString(0, lblTP2, OBJPROP_FONT, "Segoe UI Black");
         }
      }

      // เส้น & ป้าย TP 3R (1:3 เป้าหลักอาจารย์เดช)
      string lineTP3 = GUI_PREFIX + "DTD_LINE_TP3R";
      if(ObjectFind(0, lineTP3) < 0)
      {
         ObjectCreate(0, lineTP3, OBJ_TREND, 0, bStart, g_DTD.confirmTP3RPrice, bEnd, g_DTD.confirmTP3RPrice);
         ObjectSetInteger(0, lineTP3, OBJPROP_COLOR, C'50,255,130');
         ObjectSetInteger(0, lineTP3, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, lineTP3, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, lineTP3, OBJPROP_RAY_RIGHT, false);
      }
      else
      {
         ObjectSetInteger(0, lineTP3, OBJPROP_TIME, 0, bStart);
         ObjectSetDouble(0, lineTP3, OBJPROP_PRICE, 0, g_DTD.confirmTP3RPrice);
         ObjectSetInteger(0, lineTP3, OBJPROP_TIME, 1, bEnd);
         ObjectSetDouble(0, lineTP3, OBJPROP_PRICE, 1, g_DTD.confirmTP3RPrice);
      }

      string lblTP3 = GUI_PREFIX + "DTD_LBL_TP3R";
      double tpDist = MathAbs(g_DTD.confirmTP3RPrice - curBidPrice) / _Point;
      string tpTxt  = StringFormat(" 🏆 TP 3R (1:3): %s (+%s) [เป้าหลัก อ.เดช] ", DoubleToString(g_DTD.confirmTP3RPrice, _Digits), FormatMoneyOrPoints(tpDist));
      if(ObjectFind(0, lblTP3) < 0)
      {
         ObjectCreate(0, lblTP3, OBJ_TEXT, 0, bEnd, g_DTD.confirmTP3RPrice);
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
         ObjectSetDouble(0, lblTP3, OBJPROP_PRICE, 0, g_DTD.confirmTP3RPrice);
         ObjectSetString(0, lblTP3, OBJPROP_TEXT, tpTxt);
         ObjectSetInteger(0, lblTP3, OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, lblTP3, OBJPROP_FONT, "Segoe UI Black");
      }

      // เส้น & ป้าย SL (1R)
      string lineSL = GUI_PREFIX + "DTD_LINE_SL";
      if(ObjectFind(0, lineSL) < 0)
      {
         ObjectCreate(0, lineSL, OBJ_TREND, 0, bStart, g_DTD.confirmSLPrice, bEnd, g_DTD.confirmSLPrice);
         ObjectSetInteger(0, lineSL, OBJPROP_COLOR, C'255,80,90');
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
      }

      string lblSL = GUI_PREFIX + "DTD_LBL_SL";
      double slDist = MathAbs(g_DTD.confirmSLPrice - curBidPrice) / _Point;
      string slTxt  = StringFormat(" 🛑 SL 1R: %s (-%s) [ใต้ชุดคอนเฟิร์ม] ", DoubleToString(g_DTD.confirmSLPrice, _Digits), FormatMoneyOrPoints(slDist));
      if(ObjectFind(0, lblSL) < 0)
      {
         ObjectCreate(0, lblSL, OBJ_TEXT, 0, bEnd, g_DTD.confirmSLPrice);
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
         ObjectSetDouble(0, lblSL, OBJPROP_PRICE, 0, g_DTD.confirmSLPrice);
         ObjectSetString(0, lblSL, OBJPROP_TEXT, slTxt);
         ObjectSetInteger(0, lblSL, OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, lblSL, OBJPROP_FONT, "Segoe UI Black");
      }
   }
   else
   {
      ObjectDelete(0, GUI_PREFIX + "DTD_BOX_SL");
      ObjectDelete(0, GUI_PREFIX + "DTD_BOX_TP");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_TP1R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_TP1R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_TP2R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_TP2R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_TP3R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_TP3R");
      ObjectDelete(0, GUI_PREFIX + "DTD_LINE_SL");
      ObjectDelete(0, GUI_PREFIX + "DTD_LBL_SL");
   }
}
//+------------------------------------------------------------------+
//| 15. SYNCHRONIZE ZONE-ANCHORED SHARED SL                          |
//+------------------------------------------------------------------+
void SynchronizeSharedSL()
{
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
      if(InpUseDTD_CF_M1 && g_DTD.buyEngulfConfirmed && g_DTD.buyConfirmSLPrice > 0.0 && g_DTD.buyConfirmSLPrice < bid - minStopDist)
         sl = g_DTD.buyConfirmSLPrice;
      else if(InpUseDTD_CF_M1 && g_DTD.setupSide == 1 && g_DTD.confirmSLPrice > 0.0 && g_DTD.confirmSLPrice < bid - minStopDist)
         sl = g_DTD.confirmSLPrice;
      else if(g_WaveSide == 1 && g_TargetSL > 0.0 && g_TargetSL < bid - minStopDist)
         sl = g_TargetSL;
      else
         sl = bid - (g_Asset.slPoints * _Point);

      // 2. ตรวจสอบ TP สำหรับ BUY (ต้องอยู่เหนือราคา Ask เสมอ)
      if(InpUseDTD_CF_M1 && g_DTD.buyEngulfConfirmed && g_DTD.buyConfirmTP3RPrice > ask + minStopDist)
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
      if(InpUseDTD_CF_M1 && g_DTD.sellEngulfConfirmed && g_DTD.sellConfirmSLPrice > ask + minStopDist)
         sl = g_DTD.sellConfirmSLPrice;
      else if(InpUseDTD_CF_M1 && g_DTD.setupSide == -1 && g_DTD.confirmSLPrice > ask + minStopDist)
         sl = g_DTD.confirmSLPrice;
      else if(g_WaveSide == -1 && g_TargetSL > ask + minStopDist)
         sl = g_TargetSL;
      else
         sl = ask + (g_Asset.slPoints * _Point);

      // 2. ตรวจสอบ TP สำหรับ SELL (ต้องอยู่ใต้ราคา Bid เสมอ)
      if(InpUseDTD_CF_M1 && g_DTD.sellEngulfConfirmed && g_DTD.sellConfirmTP3RPrice > 0.0 && g_DTD.sellConfirmTP3RPrice < bid - minStopDist)
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

   for(int i = g_BOS_Count; i < 15; i++)
   {
      ObjectDelete(0, GUI_PREFIX + "SMC_BOS_L_" + IntegerToString(i));
      ObjectDelete(0, GUI_PREFIX + "SMC_BOS_T_" + IntegerToString(i));
   }

   for(int i = 0; i < g_BOS_Count && i < 10; i++)
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

      // Stagger line ends and label positions horizontally so labels never collide
      datetime tLineEnd = tBaseEnd + (datetime)(secPerBar * ((i % 3) * 2));
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

      // 2. Draw label at the right tip of the line
      string valStr  = (_Digits > 2) ? StringFormat("%.1f", val) : StringFormat("%.2f", val);
      string icon    = InpUseTF_Colors_EMA14 ? g_EMA14_Icons[i] : "🟣";
      string expText = StringFormat(" %s EMA 14 [%s]: %s ", icon, g_EMA14_Tags[i], valStr);

      if(ObjectFind(0, lblName) < 0)
      {
         ObjectCreate(0, lblName, OBJ_TEXT, 0, tLbl, val);
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
         if(ObjectGetDouble(0, lblName, OBJPROP_PRICE) != val) ObjectSetDouble(0, lblName, OBJPROP_PRICE, val);
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
      string dText    = StringFormat("  🎯 [EP4] ขา D (161.8%%) %.2f (+%.0f pts)", g_WaveD_1618, ptsToD);

      if(ObjectFind(0, lblD) < 0)
      {
         ObjectCreate(0, lblD, OBJ_TEXT, 0, tLbl, g_WaveD_1618);
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
         if(ObjectGetDouble(0, lblD, OBJPROP_PRICE) != g_WaveD_1618) ObjectSetDouble(0, lblD, OBJPROP_PRICE, g_WaveD_1618);
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

   // 10. Multi-TF EMA 14 Dotted Lines (H1 & H4)
   DrawMultiTF_EMA14_Lines();

   // 11. CME Options Walls & Open Interest Matrix (Red Resistance & Blue Support)
   DrawCME_OptionsWalls();

   // 12. Gann Equilibrium Grid & Zero Origin Line (ตารางตาข่ายสมดุลราคาและเวลา 45°)
   DrawGannEquilibriumGrid();

   // 13. DTD M1 Confirmation Visuals & 1R:3R TradingView Box
   DrawDTD_M1_Visuals();
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
//| SMART MULTI-LINE TEXT SPLITTER & WRAPPING ENGINE (AUTO-WRAP)     |
//+------------------------------------------------------------------+
int FindBestSplitPos(string text, int maxLen)
{
   int len = StringLen(text);
   if(len <= maxLen) return len;
   
   int bestPos = -1;
   // Only look for a split point near the end of the line (at least 70% of maxLen)
   int minRange = (int)(maxLen * 0.70);
   
   // 1. Delimiters where delimiter starts line 2 (➔, •, -)
   string nextLineDelims[] = {" ➔ ", "➔", " • ", " - "};
   for(int d = 0; d < ArraySize(nextLineDelims); d++)
   {
      int pos = StringFind(text, nextLineDelims[d]);
      while(pos >= 0)
      {
         if(pos >= minRange && pos <= maxLen)
         {
            if(pos > bestPos) bestPos = pos;
         }
         pos = StringFind(text, nextLineDelims[d], pos + 1);
      }
   }
   
   // 2. Delimiters like " | ", ", "
   string midDelims[] = {" | ", ", "};
   for(int m = 0; m < ArraySize(midDelims); m++)
   {
      int pos = StringFind(text, midDelims[m]);
      while(pos >= 0)
      {
         int splitPt = pos + StringLen(midDelims[m]);
         if(splitPt >= minRange && splitPt <= maxLen)
         {
            if(splitPt > bestPos) bestPos = splitPt;
         }
         pos = StringFind(text, midDelims[m], pos + 1);
      }
   }

   // 3. Parentheses/brackets " (", " ["
   string parenDelims[] = {" (", " ["};
   for(int p = 0; p < ArraySize(parenDelims); p++)
   {
      int pos = StringFind(text, parenDelims[p]);
      while(pos >= 0)
      {
         if(pos >= minRange && pos <= maxLen)
         {
            if(pos > bestPos) bestPos = pos;
         }
         pos = StringFind(text, parenDelims[p], pos + 1);
      }
   }
   
   // 4. Spaces near the end of line
   int posSpace = StringFind(text, " ");
   while(posSpace >= 0)
   {
      if(posSpace >= minRange && posSpace <= maxLen)
      {
         if(posSpace > bestPos) bestPos = posSpace;
      }
      posSpace = StringFind(text, " ", posSpace + 1);
   }
   
   if(bestPos > 0) return bestPos;

   // 5. Fallback: if no split point found between 70% and maxLen, look for ANY space up to maxLen (at least 50% of maxLen)
   int fallbackMin = (int)(maxLen * 0.50);
   posSpace = StringFind(text, " ");
   while(posSpace >= 0)
   {
      if(posSpace >= fallbackMin && posSpace <= maxLen)
      {
         if(posSpace > bestPos) bestPos = posSpace;
      }
      posSpace = StringFind(text, " ", posSpace + 1);
   }

   if(bestPos > 0) return bestPos;
   
   return maxLen;
}

void SplitTextToLines(string fullText, int maxLen, string &l1, string &l2, string &l3)
{
   l1 = ""; l2 = ""; l3 = "";
   StringTrimLeft(fullText);
   StringTrimRight(fullText);
   
   if(StringLen(fullText) <= maxLen)
   {
      l1 = fullText;
      return;
   }
   
   int split1 = FindBestSplitPos(fullText, maxLen);
   l1 = StringSubstr(fullText, 0, split1);
   string rem1 = StringSubstr(fullText, split1);
   StringTrimLeft(rem1);
   StringTrimRight(rem1);
   
   if(StringLen(rem1) <= maxLen)
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

   // IF DASHBOARD IS COLLAPSED (MASTER HIDE TOGGLE)
   if(!g_Dashboard_Visible)
   {
      // Clean up all full dashboard elements
      ObjectsDeleteAll(0, GUI_PREFIX + "DASH_");
      ObjectsDeleteAll(0, GUI_PREFIX + "L_");
      ObjectsDeleteAll(0, GUI_PREFIX + "C1_");
      ObjectsDeleteAll(0, GUI_PREFIX + "C2_");
      ObjectsDeleteAll(0, GUI_PREFIX + "C3_");
      ObjectsDeleteAll(0, GUI_PREFIX + "LOT_");
      ObjectsDeleteAll(0, GUI_PREFIX + "BTN_");

      // Render sleek compact floating pill button to reopen dashboard
      CreateButton(GUI_PREFIX + "BTN_SHOW_DASH", baseX, baseY, 210, 30, "📊 แสดงแดชบอร์ด [คลิก]", C'18,32,54', clrGold, 9);
      return;
   }

   // IF DASHBOARD IS VISIBLE: Remove the reopen button
   ObjectDelete(0, GUI_PREFIX + "BTN_SHOW_DASH");

   // Header & Subtitle
   CreateRect(GUI_PREFIX + "DASH_BG", baseX, baseY, w, 40, C'12,18,28', C'35,50,75');
   string titleStr = "DeungDang_Trade ● " + _Symbol + " [" + GetCleanTFName((ENUM_TIMEFRAMES)_Period) + "] - " + g_Asset.name;
   CreateLabel(GUI_PREFIX + "L_TITLE", baseX + 14, baseY + 8, titleStr, clrGold, 9, true);
   CreateLabel(GUI_PREFIX + "L_SUBTITLE", baseX + 14, baseY + 24, "กำนันบอล + พี่ชนัฐ + SAMURAI MTF 36 แท่ง + STANDARD FIBO", C'140,165,195', 7, false);

   // Master Dashboard Collapse Button
   CreateButton(GUI_PREFIX + "BTN_HIDE_DASH", baseX + w - 66, baseY + 8, 56, 24, "◀ พับเก็บ", C'140,40,50', clrWhite, 8);

   int curY = baseY + 46;

   // ==============================================================
   // CARD 1: สภาพตลาด & เทรนด์ (MARKET ANALYSIS & KAMNAN BALL)
   // ==============================================================
   string assetShort = (g_Asset.assetType == ASSET_CRYPTO) ? "Bitcoin (BTC)" : ((g_Asset.assetType == ASSET_GOLD) ? "Gold (XAUUSD)" : _Symbol);
   string sessShort  = g_SessionName;
   StringReplace(sessShort, " Overlap", "");
   StringReplace(sessShort, " (Prime)", "");
   string assetSessionStr = StringFormat("🌐 สินทรัพย์: %s | เซสชัน: %s", assetShort, sessShort);

   string sig1 = "📢 สัญญาณ: รอกราฟฟอร์มตัวในสปีดไลน์...";
   string sig2 = "👉 แอ็กชัน: กราฟกำลังวิ่งตามเทรนด์ปกติ";
   color sigClr = clrSilver;

   if(g_IsFakeoutTrap)
   {
      sig1 = (g_FakeoutSide == 1) ? "📢 สัญญาณ: ⚡ ตรวจพบ 'กลับตัวลงหลอก' (Bear Trap Sweep)!" : "📢 สัญญาณ: ⚡ ตรวจพบ 'กลับตัวขึ้นหลอก' (Bull Trap Sweep)!";
      sig2 = (g_FakeoutSide == 1) ? "👉 แอ็กชัน: เจ้ามือล้าง SL ใต้ฐานเสร็จแล้ว ➔ ช้อน BUY บินสู่ขา D! 🟢" : "👉 แอ็กชัน: เจ้ามือล้าง SL เหนือยอดเสร็จแล้ว ➔ ดักทุบ SELL ดิ่งสู่ขา D! 🔴";
      sigClr = (g_FakeoutSide == 1) ? C'50,255,150' : C'255,80,100';
   }
   else if(g_IsFailedHigh && g_WaveSide == -1)
   {
      sig1 = "📢 สัญญาณ: ปริ้นสปีดขาขึ้น + ขาดการเบรกไฮแล้ว!";
      sig2 = "👉 แอ็กชัน: แรงซื้อหมดเกลี้ยง ➔ เตรียมกด SELL 🔴";
      sigClr = C'255,100,120';
   }
   else if(g_IsFailedLow && g_WaveSide == 1)
   {
      sig1 = "📢 สัญญาณ: ปริ้นสปีดขาลง + ขาดการหลุดโลแล้ว!";
      sig2 = "👉 แอ็กชัน: แรงขายหมดเกลี้ยง ➔ เตรียมกด BUY 🟢";
      sigClr = C'80,250,160';
   }
   else if(g_WaveCycleCompleted)
   {
      sig1 = "📢 โครงสร้างใหญ่: จบวงรอบคลื่นสมบูรณ์ (Wave Cycle Completed)";
      sig2 = (InpUseDTD_CF_M1 && g_DTD.isEngulfConfirmed) ? "👉 แอ็กชัน: DTD CF M1 จบกลืนกินแล้ว ➔ พร้อมลั่นไกตามแผน 1:3R 🎯" : "👉 แอ็กชัน: ตลาดพักตัว ➔ รอกรอบสวิงชุดใหม่ หรือรอ CF M1 คอนเฟิร์ม 🟡";
      sigClr = clrGold;
   }
   else if(g_Regime == SW_UP_ACCUM)
   {
      sig1 = "📢 สัญญาณ: เกิด SW Up (กินดีมานด์ตัวเองซ้ำๆ)";
      sig2 = "👉 แอ็กชัน: ระวังดูดซับแรงซื้อหมด ➔ เตรียมกด SELL 🔴";
      sigClr = clrOrange;
   }
   else if(g_Regime == SW_DOWN_DIST)
   {
      sig1 = "📢 สัญญาณ: เกิด SW Down (กินซัพพลายตัวเองซ้ำๆ)";
      sig2 = "👉 แอ็กชัน: ระวังดูดซับแรงขายหมด ➔ เตรียมกด BUY 🟢";
      sigClr = C'255,160,80';
   }
   else if(g_Regime == SW_HORIZONTAL)
   {
      sig1 = "📢 สัญญาณ: ตลาดเป็น Sideway ออกข้าง (ตีปิงปอง)";
      sig2 = "👉 แอ็กชัน: วิ่งในกรอบแคบ ➔ นั่งทับมือ ห้ามเทรด! 🟡";
      sigClr = clrYellow;
   }
   else if(g_HasUnicorn && g_UnicornSide == 1)
   {
      sig1 = "📢 สัญญาณ: ตรวจพบ ICT Unicorn โซนเด้ง BUY! (Breaker + FVG)";
      sig2 = "👉 แอ็กชัน: ราคาทดสอบ FVG โซนกลับตัว ➔ มองหาจังหวะ BUY 🟢";
      sigClr = C'80,250,160';
   }
   else if(g_HasUnicorn && g_UnicornSide == -1)
   {
      sig1 = "📢 สัญญาณ: ตรวจพบ ICT Unicorn โซนย่อ SELL! (Breaker + FVG)";
      sig2 = "👉 แอ็กชัน: ราคาทดสอบ FVG โซนกลับตัว ➔ มองหาจังหวะ SELL 🔴";
      sigClr = C'255,100,120';
   }
   else if(g_HasUpSpeedline && !g_IsUpSL_Broken)
   {
      sig1 = "📢 สัญญาณ: เกาะสปีดไลน์ขาขึ้น (Bullish Speedline Active)";
      sig2 = "👉 แอ็กชัน: ประคองตัวขึ้นตามแนวรับสปีดไลน์ ➔ รอสัญญาณปริ้น 🟢";
      sigClr = C'80,250,160';
   }
   else if(g_HasDnSpeedline && !g_IsDnSL_Broken)
   {
      sig1 = "📢 สัญญาณ: เกาะสปีดไลน์ขาลง (Bearish Speedline Active)";
      sig2 = "👉 แอ็กชัน: กดตัวลงตามแนวต้านสปีดไลน์ ➔ รอสัญญาณปริ้น 🔴";
      sigClr = C'255,100,120';
   }

   int cardH1 = 24;
   if(g_Card1_Expanded)
   {
      int h1 = 22; // title offset
      h1 += 18;    // bias
      h1 += (StringLen(g_StepTitle) > 56 ? 32 : 16);
      h1 += (StringLen(g_StepDesc) > 56 ? 32 : 16);
      h1 += (StringLen(assetSessionStr) > 56 ? 32 : 16);
      h1 += 18;    // spread
      h1 += 18;    // samurai dots
      h1 += 18;    // macro
      h1 += (StringLen(sig1) > 56 ? 32 : 16);
      h1 += (StringLen(sig2) > 56 ? 32 : 16);
      h1 += 10;    // padding
      cardH1 = h1;
   }

   // 1. CREATE BACKGROUND RECTANGLE FIRST (Bottom layer)
   CreateRect(GUI_PREFIX + "C1_BG", baseX, curY, w, cardH1, C'15,22,34', C'30,48,72');

   // 2. CREATE TITLE & BUTTON ON TOP
   CreateLabel(GUI_PREFIX + "C1_TITLE", baseX + 12, curY + 5, "🌐 1. สภาพตลาด & เทรนด์ (MARKET ANALYSIS)", clrLightSkyBlue, 8, true);
   CreateButton(GUI_PREFIX + "BTN_MIN_C1", baseX + w - 24, curY + 3, 18, 18, (g_Card1_Expanded ? "—" : "+"), C'35,50,70', clrSilver, 8);

   if(g_Card1_Expanded)
   {
      int lineY = curY + 22;

      // Row 1: Directional Bias Gauge
      CreateLabel(GUI_PREFIX + "C1_L_BIAS_T", baseX + 14, lineY, "⚖️ น้ำหนักตลาด :", clrGold, 8, true);
      string buyBiasStr  = StringFormat("🟢 BUY %d%%", g_MarketBiasBuyPct);
      string sellBiasStr = StringFormat("🔴 SELL %d%%", g_MarketBiasSellPct);
      color  buyCol      = (g_MarketBiasBuyPct >= 50) ? C'50,225,130' : clrGray;
      color  sellCol     = (g_MarketBiasSellPct >= 50) ? C'255,100,120' : clrGray;
      CreateLabel(GUI_PREFIX + "C1_L_BIAS_BUY", baseX + 115, lineY, buyBiasStr, buyCol, 8, true);
      CreateLabel(GUI_PREFIX + "C1_L_BIAS_SEP", baseX + 215, lineY, "|", clrDarkGray, 8, false);
      CreateLabel(GUI_PREFIX + "C1_L_BIAS_SELL", baseX + 230, lineY, sellBiasStr, sellCol, 8, true);
      lineY += 18;

      // Row 2 & 3: 3-Step Execution (Auto-Wrap if long)
      RenderWrappedLabel(GUI_PREFIX + "C1_L_STEP1", baseX + 14, lineY, g_StepTitle, g_StepColor, 8, true, 56, 16);
      RenderWrappedLabel(GUI_PREFIX + "C1_L_STEP2", baseX + 14, lineY, g_StepDesc, C'255,220,130', 8, false, 56, 16);

      // Row 4: Asset & Session (Auto-Wrap if long)
      RenderWrappedLabel(GUI_PREFIX + "C1_L_ASSET", baseX + 14, lineY, assetSessionStr, clrAqua, 8, false, 56, 16);

      // Row 5: Spread
      long curSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      string spreadStr = StringFormat("⚡ Spread ปัจจุบัน: %d pts (%s)", curSpread, (curSpread <= 45 ? "ปกติ 🟢" : "สเปรดปกติ ✅"));
      CreateLabel(GUI_PREFIX + "C1_L_SPREAD", baseX + 14, lineY, spreadStr, clrPaleGreen, 8, false);
      lineY += 18;

      // Row 6: Samurai 6-TF Individual High-Contrast Badges
      ObjectDelete(0, GUI_PREFIX + "C1_L_SAMURAI"); // Cleanup legacy single label
      CreateLabel(GUI_PREFIX + "C1_L_SAM_T", baseX + 14, lineY, "⚔️ MTF (6-TF):", C'180,205,230', 8, false);
      const string s6_tfNames[6] = {"M1", "M5", "M15", "M30", "H1", "H4"};
      int s6_x = baseX + 98;
      for(int k = 0; k < 6; k++)
      {
         string tfSym = g_SamuraiMTF.isBullish[k] ? "▲" : (g_SamuraiMTF.isBearish[k] ? "▼" : "━");
         color  tfCol = g_SamuraiMTF.isBullish[k] ? C'50,225,130' : (g_SamuraiMTF.isBearish[k] ? C'255,80,90' : clrGold);
         string tfStr = StringFormat("%s:%s", s6_tfNames[k], tfSym);
         CreateLabel(GUI_PREFIX + "C1_L_SAM_" + s6_tfNames[k], s6_x, lineY, tfStr, tfCol, 8, true);
         s6_x += (k < 2 ? 38 : (k < 4 ? 44 : 38));
      }
      lineY += 18;

      // Row 7: Samurai Macro H1 & H4
      CreateLabel(GUI_PREFIX + "C1_L_MACRO_T", baseX + 14, lineY, "🔹 MTF:", C'180,205,230', 8, false);
      string h1Text = g_SamuraiMTF.isBullish[4] ? "H1: BULL ▲" : (g_SamuraiMTF.isBearish[4] ? "H1: BEAR ▼" : "H1: SIDE ━");
      color  h1Col  = g_SamuraiMTF.isBullish[4] ? C'50,225,130' : (g_SamuraiMTF.isBearish[4] ? C'255,80,90' : clrGold);
      CreateLabel(GUI_PREFIX + "C1_L_MACRO_H1", baseX + 60, lineY, h1Text, h1Col, 8, true);

      string h4Text = g_SamuraiMTF.isBullish[5] ? "H4: BULL ▲" : (g_SamuraiMTF.isBearish[5] ? "H4: BEAR ▼" : "H4: SIDE ━");
      color  h4Col  = g_SamuraiMTF.isBullish[5] ? C'50,225,130' : (g_SamuraiMTF.isBearish[5] ? C'255,80,90' : clrGold);
      CreateLabel(GUI_PREFIX + "C1_L_MACRO_H4", baseX + 130, lineY, h4Text, h4Col, 8, true);

      CreateLabel(GUI_PREFIX + "C1_L_MACRO_SEP", baseX + 200, lineY, "|", clrDarkGray, 8, false);

      string trendText = "";
      color  trendCol  = clrGold;
      if(g_SamuraiMTF.consensusDir == 1)
      {
         trendText = StringFormat("มติ: BUY (%d%%) ▲", (int)MathRound(g_SamuraiMTF.bullScore));
         trendCol  = C'50,235,130';
      }
      else if(g_SamuraiMTF.consensusDir == -1)
      {
         trendText = StringFormat("มติ: SELL (%d%%) ▼", (int)MathRound(100.0 - g_SamuraiMTF.bullScore));
         trendCol  = C'255,75,90';
      }
      else
      {
         trendText = "มติ: SIDEWAY ━";
         trendCol  = clrGold;
      }
      CreateLabel(GUI_PREFIX + "C1_L_MACRO_TREND", baseX + 212, lineY, trendText, trendCol, 8, true);
      lineY += 18;

      // Row 8 & 9: Kamnan Ball Signal & Action (Auto-Wrap if long)
      RenderWrappedLabel(GUI_PREFIX + "C1_L1", baseX + 14, lineY, sig1, sigClr, 8, true, 56, 16);
      RenderWrappedLabel(GUI_PREFIX + "C1_L2", baseX + 14, lineY, sig2, sigClr, 8, true, 56, 16);

      cardH1 = (lineY - curY) + 8;
      if(ObjectGetInteger(0, GUI_PREFIX + "C1_BG", OBJPROP_YSIZE) != cardH1)
         ObjectSetInteger(0, GUI_PREFIX + "C1_BG", OBJPROP_YSIZE, cardH1);
   }
   else
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "C1_L");
   }

   curY += cardH1 + 6;

   // ==============================================================
   // CARD 2: SAMURAI MTF CONFLUENCE & LINEAR REGRESSION CHANNEL
   // ==============================================================
   string chanStr = StringFormat("📐 Samurai Channel: มุม %.1f° | บน: %s | ล่าง: %s", g_LRL.angle, DoubleToString(g_LRL.curUpper, _Digits), DoubleToString(g_LRL.curLower, _Digits));

   string uStr;
   color  uColor;
   if(!g_HasUnicorn)
   {
      uStr   = "🦄 ICT Unicorn: ยังไม่พบ (รอแท่งเบรกทิ้ง Gap)";
      uColor = clrSilver;
   }
   else if(g_UnicornSide == 1)
   {
      uStr   = "🦄 ICT Unicorn: 🟢 BUY! (Breaker Block + Bullish FVG)";
      uColor = C'0,255,136';
   }
   else if(g_UnicornSide == -1)
   {
      uStr   = "🦄 ICT Unicorn: 🔴 SELL! (Breaker Block + Bearish FVG)";
      uColor = C'255,80,90';
   }
   else
   {
      uStr   = "🦄 ICT Unicorn: ★ ตรวจพบ! (Breaker Block + FVG ซ้อนทับ)";
      uColor = C'220,160,255';
   }

   string mtfStr = "🕯️ แถบล่าง 9-TF: 36 แท่งสด + เส้น Bid + นับถอยหลัง";

   // Calculate nearest DZ & SZ
   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(curBid <= 0) curBid = iClose(_Symbol, _Period, 0);
   if(curAsk <= 0) curAsk = curBid;

   string nearDZStr = "ไม่มี";
   string nearSZStr = "ไม่มี";
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
            // หากราคาอยู่ในโซน ให้เลือกโซนที่กระชับและเจาะจงที่สุด (Smallest Span)
            if(minDZDist > 0.0 || span < bestInDZ_Span)
            {
               minDZDist = 0.0;
               bestInDZ_Span = span;
               nearDZStr = StringFormat("%s - %s [%s] (★ ในโซน)", DoubleToString(g_Zones[z].low, _Digits), DoubleToString(g_Zones[z].high, _Digits), g_Zones[z].tfName);
            }
         }
         else if(curBid > g_Zones[z].high)
         {
            double d = curBid - g_Zones[z].high;
            if(minDZDist > 0.0 && d < minDZDist)
            {
               minDZDist = d;
               nearDZStr = StringFormat("%s [%s] (-%s)", DoubleToString(g_Zones[z].high, _Digits), g_Zones[z].tfName, FormatMoneyOrPoints(d / _Point));
            }
         }
      }
      else if(!g_Zones[z].isDemand)
      {
         if(curAsk >= g_Zones[z].low && curAsk <= g_Zones[z].high)
         {
            // หากราคาอยู่ในโซน ให้เลือกโซนที่กระชับและเจาะจงที่สุด (Smallest Span)
            if(minSZDist > 0.0 || span < bestInSZ_Span)
            {
               minSZDist = 0.0;
               bestInSZ_Span = span;
               nearSZStr = StringFormat("%s - %s [%s] (★ ในโซน)", DoubleToString(g_Zones[z].low, _Digits), DoubleToString(g_Zones[z].high, _Digits), g_Zones[z].tfName);
            }
         }
         else if(curAsk < g_Zones[z].low)
         {
            double d = g_Zones[z].low - curAsk;
            if(minSZDist > 0.0 && d < minSZDist)
            {
               minSZDist = d;
               nearSZStr = StringFormat("%s [%s] (+%s)", DoubleToString(g_Zones[z].low, _Digits), g_Zones[z].tfName, FormatMoneyOrPoints(d / _Point));
            }
         }
      }
   }
   string dzFull = StringFormat("🏛️ Demand รับ:  %s", nearDZStr);
   string szFull = StringFormat("🏛️ Supply ต้าน: %s", nearSZStr);

   // CME Options Matrix Radar Line
   bool showCME = (InpUseCME_OI && g_Asset.assetType == ASSET_GOLD && (g_CME_NearResStrike > 0 || g_CME_NearSupStrike > 0));

   string gannLatticeStr = "";
   string gannEnergyStr  = "";
   if(InpUseWaveEnergyRadar)
   {
      string signDisp = (g_GannEnergy.displacementPts >= 0) ? "+" : "";
      gannLatticeStr = StringFormat("🌐 จุดสมดุลคลื่น: เลขกลม %s | ยืด %s%s | สปีด %.1f จุด/วิ", 
                                    DoubleToString(g_GannEnergy.zeroPrice, _Digits), 
                                    signDisp, FormatMoneyOrPoints(MathAbs(g_GannEnergy.displacementPts)), 
                                    g_GannEnergy.velocityPtsSec);
      gannEnergyStr  = StringFormat("⚡ พลังงานคลื่น: %s", g_GannEnergy.energyStatus);
   }

   int cardH2 = 24;
   if(g_Card2_Expanded)
   {
      int h2 = 24; // title
      h2 += (StringLen(chanStr) > 56 ? 32 : 16);
      h2 += (StringLen(uStr) > 56 ? 32 : 16);
      h2 += (StringLen(mtfStr) > 56 ? 32 : 16);
      h2 += (StringLen(dzFull) > 56 ? 32 : 16);
      h2 += (StringLen(szFull) > 56 ? 32 : 16);
      if(showCME) h2 += 18;
      if(InpUseWaveEnergyRadar)
      {
         h2 += (StringLen(gannLatticeStr) > 56 ? 32 : 16);
         h2 += (StringLen(gannEnergyStr) > 56 ? 32 : 16);
      }
      h2 += 10; // padding
      cardH2 = h2;
   }

   // 1. CREATE BACKGROUND RECTANGLE FIRST (Bottom layer)
   CreateRect(GUI_PREFIX + "C2_BG", baseX, curY, w, cardH2, C'12,24,24', C'25,55,55');

   // 2. CREATE TITLE & BUTTON ON TOP
   CreateLabel(GUI_PREFIX + "C2_TITLE", baseX + 12, curY + 5, "⚔️ 2. SAMURAI CHANNEL, CME OI & พลังงานคลื่น (QUANT)", C'100,240,180', 8, true);
   CreateButton(GUI_PREFIX + "BTN_MIN_C2", baseX + w - 24, curY + 3, 18, 18, (g_Card2_Expanded ? "—" : "+"), C'35,50,70', clrSilver, 8);

   if(g_Card2_Expanded)
   {
      int lineY = curY + 24;
      RenderWrappedLabel(GUI_PREFIX + "C2_L1", baseX + 14, lineY, chanStr, clrWhite, 8, false, 56, 16);
      RenderWrappedLabel(GUI_PREFIX + "C2_L2", baseX + 14, lineY, uStr, uColor, 8, g_HasUnicorn, 56, 16);
      RenderWrappedLabel(GUI_PREFIX + "C2_L3", baseX + 14, lineY, mtfStr, clrGold, 8, false, 56, 16);
      RenderWrappedLabel(GUI_PREFIX + "C2_L4_DZ", baseX + 14, lineY, dzFull, C'50,225,130', 8, true, 56, 16);
      RenderWrappedLabel(GUI_PREFIX + "C2_L4_SZ", baseX + 14, lineY, szFull, C'255,100,120', 8, true, 56, 16);

      if(showCME)
      {
         CreateLabel(GUI_PREFIX + "C2_L_CME_T", baseX + 14, lineY, "🏛️ CME OI :", clrGold, 8, true);
         CreateLabel(GUI_PREFIX + "C2_L_CME_RES", baseX + 82, lineY, g_CME_NearResStr, InpColorCME_Resistance, 8, true);
         CreateLabel(GUI_PREFIX + "C2_L_CME_SEP", baseX + 218, lineY, "|", clrDarkGray, 8, false);
         CreateLabel(GUI_PREFIX + "C2_L_CME_SUP", baseX + 230, lineY, g_CME_NearSupStr, InpColorCME_Support, 8, true);
         lineY += 18;
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "C2_L_CME_T");
         ObjectDelete(0, GUI_PREFIX + "C2_L_CME_RES");
         ObjectDelete(0, GUI_PREFIX + "C2_L_CME_SEP");
         ObjectDelete(0, GUI_PREFIX + "C2_L_CME_SUP");
      }

      if(InpUseWaveEnergyRadar)
      {
         RenderWrappedLabel(GUI_PREFIX + "C2_L_GANN1", baseX + 14, lineY, gannLatticeStr, C'100,200,255', 8, false, 56, 16);
         RenderWrappedLabel(GUI_PREFIX + "C2_L_GANN2", baseX + 14, lineY, gannEnergyStr, g_GannEnergy.statusColor, 8, g_GannEnergy.isStationPoint, 56, 16);
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "C2_L_GANN1");
         ObjectDelete(0, GUI_PREFIX + "C2_L_GANN2");
      }

      ObjectDelete(0, GUI_PREFIX + "C2_L_DTD");

      cardH2 = (lineY - curY) + 8;
      if(ObjectGetInteger(0, GUI_PREFIX + "C2_BG", OBJPROP_YSIZE) != cardH2)
         ObjectSetInteger(0, GUI_PREFIX + "C2_BG", OBJPROP_YSIZE, cardH2);
   }
   else
   {
      ObjectsDeleteAll(0, GUI_PREFIX + "C2_L");
   }

   curY += cardH2 + 6;

   // ==============================================================
   // CARD 3: ซิกแนลบอกทิศทาง & แผงสั่งการด้วยมือ (SIGNAL & MANUAL COCKPIT)
   // ==============================================================
   color card3BgCol     = C'20,18,30';
   color card3BorderCol = C'50,40,75';
   color card3TitleCol  = C'255,180,220';
   string card3Title    = "🎯 3. ซิกแนล & แผงสั่งการด้วยมือ (SIGNAL COCKPIT)";
   string card3SigDesc  = "⏳ รอกราฟฟอร์มตัวเลือกข้าง...";
   color card3SigCol    = clrSilver;

   bool isSideway = (!g_IsFakeoutTrap) && ((g_Regime == SW_HORIZONTAL) || g_WaveCycleCompleted || (g_WaveSide == 0 && g_SamuraiMTF.consensusDir == 0));
   bool isSell    = (g_IsFakeoutTrap && g_FakeoutSide == -1) || ((!isSideway) && (g_WaveSide == -1 || (g_WaveSide == 0 && g_SamuraiMTF.consensusDir == -1)));
   bool isBuy     = (g_IsFakeoutTrap && g_FakeoutSide == 1)  || ((!isSideway) && (g_WaveSide == 1  || (g_WaveSide == 0 && g_SamuraiMTF.consensusDir == 1)));

   curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(curBid <= 0) curBid = iClose(_Symbol, _Period, 0);
   if(curAsk <= 0) curAsk = curBid;

   if(InpUseDTD_CF_M1 && g_DTD.isEngulfConfirmed)
   {
      double entryRef = (g_DTD.confirmEntryPrice > 0.0) ? g_DTD.confirmEntryPrice : g_DTD.latchedEntryPrice;
      double slRef    = (g_DTD.confirmSLPrice > 0.0) ? g_DTD.confirmSLPrice : g_DTD.latchedSLPrice;
      double tp1Ref   = (g_DTD.confirmTP1RPrice > 0.0) ? g_DTD.confirmTP1RPrice : g_DTD.latchedTP1Price;
      double tp2Ref   = (g_DTD.confirmTP2RPrice > 0.0) ? g_DTD.confirmTP2RPrice : g_DTD.latchedTP2Price;
      double tp3Ref   = (g_DTD.confirmTP3RPrice > 0.0) ? g_DTD.confirmTP3RPrice : g_DTD.latchedTP3Price;
      double wickRef  = (g_DTD.shortestWickPrice > 0.0) ? g_DTD.shortestWickPrice : g_DTD.latchedShortestWick;

      if(g_DTD.setupSide == 1) // BUY
      {
         double pnlPts     = (curBid - entryRef) / _Point;
         double retestDist = (curBid - wickRef) / _Point;
         bool isHitTP3     = (tp3Ref > 0.0 && curBid >= tp3Ref);
         bool isHitTP2     = (tp2Ref > 0.0 && curBid >= tp2Ref);
         bool isHitTP1     = (tp1Ref > 0.0 && curBid >= tp1Ref);
         bool isRetesting  = (MathAbs(retestDist) <= 40.0);
         bool isRunaway    = (pnlPts > 80.0 && !isHitTP1);

         if(isHitTP3)
         {
            card3BgCol     = C'10,35,25';
            card3BorderCol = C'0,255,180';
            card3TitleCol  = C'0,255,200';
            card3Title     = StringFormat("🏆 3. ซิกแนลเทรด: [ บรรลุเป้าหมาย 3R สำเร็จ! (+%.0f pts) ]", pnlPts);
            card3SigDesc   = "🎉 ซิกแนล อ.เดช: ชนเป้าหลัก 3R ครบสูตร! ➔ พิจารณาปิดทำกำไรเข้าพอร์ต หรือล็อกรันเทรนด์";
            card3SigCol    = C'0,255,136';
         }
         else if(isHitTP2)
         {
            card3BgCol     = C'10,32,22';
            card3BorderCol = C'0,230,160';
            card3TitleCol  = C'50,255,180';
            card3Title     = StringFormat("🎯 3. ซิกแนลเทรด: [ บรรลุเป้า TP 2R (+%.0f pts) ➔ ล็อกกำไรใต้ 1R ]", pnlPts);
            card3SigDesc   = "🚀 ซิกแนล อ.เดช: กำไร 2R แล้ว! ➔ เลื่อน SL ล็อกกำไรใต้ฐาน TP1 รันสู่ TP3";
            card3SigCol    = C'50,255,180';
         }
         else if(isHitTP1)
         {
            card3BgCol     = C'12,28,20';
            card3BorderCol = C'40,210,120';
            card3TitleCol  = C'100,245,160';
            card3Title     = StringFormat("🛡️ 3. ซิกแนลเทรด: [ บรรลุเป้า TP 1R (+%.0f pts) ➔ บังหน้าทุนทันที! ]", pnlPts);
            card3SigDesc   = "💎 ซิกแนล อ.เดช: แตะ 1:1R แล้ว! ➔ กด [ 🛡️ บังทุน ] ล็อกกำไรหน้าทุน ตัดความเสี่ยงเหลือ 0!";
            card3SigCol    = C'100,255,160';
         }
         else if(isRetesting)
         {
            card3BgCol     = C'10,35,28';
            card3BorderCol = C'0,255,200';
            card3TitleCol  = C'0,255,220';
            card3Title     = "🎯 3. ซิกแนลเทรด: [ 🟢 จังหวะย่อรีเทสต์! • จุดขึ้นรถ BUY ราคาดีที่สุด ]";
            card3SigDesc   = StringFormat("🔥 ซิกแนล อ.เดช: ราคาย่อแตะแนวไส้สั้นสุด %s ➔ ได้เปรียบระยะ SL สั้นมาก ลั่นไก BUY ได้!", DoubleToString(wickRef, _Digits));
            card3SigCol    = C'0,255,200';
         }
         else if(isRunaway)
         {
            card3BgCol     = C'32,24,12';
            card3BorderCol = C'220,160,40';
            card3TitleCol  = clrGold;
            card3Title     = StringFormat("⚠️ 3. ซิกแนลเทรด: [ แผน BUY วิ่งทำกำไร (+%.0f pts) • ห้ามไล่ราคา! ]", pnlPts);
            card3SigDesc   = "✋ คำสอน อ.เดช: ราคาวิ่งพุ่งเลยจุดเข้าแล้ว ➔ ห้ามไล่ยอดดอย! รอย่อรีเทสต์เส้นไส้สั้นสุด หรือถือรันกำไร";
            card3SigCol    = clrGold;
         }
         else // Fresh
         {
            card3BgCol     = C'10,32,22';
            card3BorderCol = C'0,255,180';
            card3TitleCol  = C'0,255,200';
            card3Title     = "🟢 3. ซิกแนลเทรด: [ จบแท่งกลืนกิน BUY • พร้อมลั่นไก 1:3R! ]";
            card3SigDesc   = "🚀 ซิกแนล อ.เดช: จบแท่งกลืนกิน M1 คอนเฟิร์ม ➔ เข้า BUY ที่ราคาปิดแท่ง SL ใต้ชุดคอนเฟิร์ม!";
            card3SigCol    = C'50,255,180';
         }
      }
      else // SELL
      {
         double pnlPts     = (entryRef - curAsk) / _Point;
         double retestDist = (wickRef - curAsk) / _Point;
         bool isHitTP3     = (tp3Ref > 0.0 && curAsk <= tp3Ref);
         bool isHitTP2     = (tp2Ref > 0.0 && curAsk <= tp2Ref);
         bool isHitTP1     = (tp1Ref > 0.0 && curAsk <= tp1Ref);
         bool isRetesting  = (MathAbs(retestDist) <= 40.0);
         bool isRunaway    = (pnlPts > 80.0 && !isHitTP1);

         if(isHitTP3)
         {
            card3BgCol     = C'38,12,18';
            card3BorderCol = C'255,50,90';
            card3TitleCol  = C'255,80,110';
            card3Title     = StringFormat("🏆 3. ซิกแนลเทรด: [ บรรลุเป้าหมาย 3R สำเร็จ! (+%.0f pts) ]", pnlPts);
            card3SigDesc   = "🎉 ซิกแนล อ.เดช: ชนเป้าหลัก 3R ครบสูตร! ➔ พิจารณาปิดทำกำไรเข้าพอร์ต หรือล็อกรันเทรนด์";
            card3SigCol    = C'255,80,90';
         }
         else if(isHitTP2)
         {
            card3BgCol     = C'35,12,18';
            card3BorderCol = C'240,60,85';
            card3TitleCol  = C'255,100,120';
            card3Title     = StringFormat("🎯 3. ซิกแนลเทรด: [ บรรลุเป้า TP 2R (+%.0f pts) ➔ ล็อกกำไรเหนือ 1R ]", pnlPts);
            card3SigDesc   = "🚀 ซิกแนล อ.เดช: กำไร 2R แล้ว! ➔ เลื่อน SL ล็อกกำไรเหนือฐาน TP1 รันสู่ TP3";
            card3SigCol    = C'255,100,120';
         }
         else if(isHitTP1)
         {
            card3BgCol     = C'32,14,18';
            card3BorderCol = C'220,70,85';
            card3TitleCol  = C'255,120,135';
            card3Title     = StringFormat("🛡️ 3. ซิกแนลเทรด: [ บรรลุเป้า TP 1R (+%.0f pts) ➔ บังหน้าทุนทันที! ]", pnlPts);
            card3SigDesc   = "💎 ซิกแนล อ.เดช: แตะ 1:1R แล้ว! ➔ กด [ 🛡️ บังทุน ] ล็อกกำไรหน้าทุน ตัดความเสี่ยงเหลือ 0!";
            card3SigCol    = C'255,120,135';
         }
         else if(isRetesting)
         {
            card3BgCol     = C'36,20,15';
            card3BorderCol = C'255,140,50';
            card3TitleCol  = C'255,160,80';
            card3Title     = "🎯 3. ซิกแนลเทรด: [ 🔴 จังหวะดีดรีเทสต์! • จุดขึ้นรถ SELL ราคาดีที่สุด ]";
            card3SigDesc   = StringFormat("🔥 ซิกแนล อ.เดช: ราคาดีดแตะแนวไส้สั้นสุด %s ➔ ได้เปรียบระยะ SL สั้นมาก ลั่นไก SELL ได้!", DoubleToString(wickRef, _Digits));
            card3SigCol    = C'255,160,80';
         }
         else if(isRunaway)
         {
            card3BgCol     = C'32,24,12';
            card3BorderCol = C'220,160,40';
            card3TitleCol  = clrGold;
            card3Title     = StringFormat("⚠️ 3. ซิกแนลเทรด: [ แผน SELL วิ่งทำกำไร (+%.0f pts) • ห้ามไล่ราคา! ]", pnlPts);
            card3SigDesc   = "✋ คำสอน อ.เดช: ราคาทุบดิ่งเลยจุดเข้าแล้ว ➔ ห้ามไล่ก้นเหว! รอดีดรีเทสต์เส้นไส้สั้นสุด หรือถือรันกำไร";
            card3SigCol    = clrGold;
         }
         else // Fresh
         {
            card3BgCol     = C'38,12,18';
            card3BorderCol = C'255,50,90';
            card3TitleCol  = C'255,80,110';
            card3Title     = "🔴 3. ซิกแนลเทรด: [ จบแท่งกลืนกิน SELL • พร้อมลั่นไก 1:3R! ]";
            card3SigDesc   = "🚀 ซิกแนล อ.เดช: จบแท่งกลืนกิน M1 คอนเฟิร์ม ➔ เข้า SELL ที่ราคาปิดแท่ง SL เหนือชุดคอนเฟิร์ม!";
            card3SigCol    = C'255,80,90';
         }
      }
   }
   else if(InpUseDTD_CF_M1 && g_DTD.shortestWickPrice > 0.0)
   {
      if(g_DTD.setupSide == -1)
      {
         card3BgCol     = C'34,14,18';
         card3BorderCol = C'230,55,75';
         card3TitleCol  = C'255,110,125';
         card3Title     = "⏳ 3. ซิกแนลเทรด: [ รอ CF M1 กลืนกิน SELL • แผน 1R-3R ]";
         card3SigDesc   = StringFormat("👀 ซิกแนล อ.เดช: แตะ Supply แล้ว ➔ รอ M1 ปิดกลืนกินไส้ %s เพื่อ SELL 🔴", DoubleToString(g_DTD.shortestWickPrice, _Digits));
         card3SigCol    = C'255,130,140';
      }
      else
      {
         card3BgCol     = C'12,28,18';
         card3BorderCol = C'45,195,85';
         card3TitleCol  = C'90,240,150';
         card3Title     = "⏳ 3. ซิกแนลเทรด: [ รอ CF M1 กลืนกิน BUY • แผน 1R-3R ]";
         card3SigDesc   = StringFormat("👀 ซิกแนล อ.เดช: แตะ Demand แล้ว ➔ รอ M1 ปิดกลืนกินไส้ %s เพื่อ BUY 🟢", DoubleToString(g_DTD.shortestWickPrice, _Digits));
         card3SigCol    = C'120,240,160';
      }
   }
   else if(g_GannEnergy.isStationPoint && !g_IsFakeoutTrap)
   {
      if(g_GannEnergy.stationDirection == 1)
      {
         card3BgCol     = C'38,15,22';
         card3BorderCol = C'255,60,90';
         card3TitleCol  = C'255,90,110';
         card3Title     = "⚡ 3. [หมดแรงยอดดอย v≈0] • ชิงปิดทำกำไร / เล็งทุบ SELL";
         card3SigDesc   = "⚠️ สัญญาณ: คลื่นยืดสุดทาง+หมดแรง (v≈0) ➔ ชิงปิดทำกำไร หรือเล็งทุบ SELL 🔴";
         card3SigCol    = C'255,90,110';
      }
      else if(g_GannEnergy.stationDirection == -1)
      {
         card3BgCol     = C'12,32,20';
         card3BorderCol = C'0,225,140';
         card3TitleCol  = C'50,255,180';
         card3Title     = "⚡ 3. [หมดแรงก้นเหว v≈0] • ชิงปิดทำกำไร / เล็งช้อน BUY";
         card3SigDesc   = "⚠️ สัญญาณ: คลื่นยืดสุดทาง+หมดแรง (v≈0) ➔ ชิงปิดทำกำไร หรือเล็งช้อน BUY 🟢";
         card3SigCol    = C'50,255,180';
      }
   }
   else if(g_IsFakeoutTrap)
   {
      if(g_FakeoutSide == 1)
      {
         card3BgCol     = C'10,32,22';
         card3BorderCol = C'0,255,180';
         card3TitleCol  = C'0,255,200';
         card3Title     = "⚡ 3. [EP4 กลับตัวลงหลอก!] • ช้อน BUY ก้นเหว";
         card3SigDesc   = "🚀 ซิกแนล: เจ้ามือ Sweep ล้าง SL ➔ ช้อน 🟢 BUY บินสู่ขา D!";
         card3SigCol    = C'50,255,180';
      }
      else
      {
         card3BgCol     = C'38,12,18';
         card3BorderCol = C'255,50,90';
         card3TitleCol  = C'255,80,110';
         card3Title     = "⚡ 3. [EP4 กลับตัวขึ้นหลอก!] • ดักทุบ SELL ยอดดอย";
         card3SigDesc   = "🔥 ซิกแนล: เจ้ามือ Sweep ล้าง SL ➔ ดักทุบ 🔴 SELL ดิ่งสู่ขา D!";
         card3SigCol    = C'255,80,100';
      }
   }
   else if(isSideway)
   {
      card3BgCol     = C'28,24,10';
      card3BorderCol = C'220,175,40';
      card3TitleCol  = clrGold;
      if(g_WaveCycleCompleted)
      {
         card3Title   = "🟡 3. ซิกแนลเทรด: [ จบรอบคลื่นแล้ว • รอนับรอบใหม่ ]";
         card3SigDesc = "✋ ซิกแนล: " + g_WaveCompletionDesc + " ➔ นั่งทับมือ 🟡";
      }
      else
      {
         card3Title   = "🟡 3. ซิกแนลเทรด: [ SIDEWAY • นั่งทับมือ ห้ามเทรด! ]";
         card3SigDesc = "✋ ซิกแนล: ตลาดออกข้างในกรอบ ➔ นั่งทับมือ ห้ามเทรด! 🟡";
      }
      card3SigCol    = clrGold;
   }
   else if(isSell)
   {
      card3BgCol     = C'34,14,18';
      card3BorderCol = C'230,55,75';
      card3TitleCol  = C'255,110,125';
      if(g_SniperStage == STAGE_TRIGGER_PA)
      {
         card3Title   = "🔴 3. ซิกแนลเทรด: [ ลั่นไก SELL! • กดปุ่มแดงด้านล่าง ]";
         card3SigDesc = "🔥 ซิกแนล: แท่งทิ้งไส้คอนเฟิร์ม ➔ กดปุ่ม 🔴 SELL ทันที!";
         card3SigCol  = C'255,80,90';
      }
      else if(g_SniperStage == STAGE_IN_ZONE)
      {
         card3Title   = "🔴 3. ซิกแนลเทรด: [ แตะ Supply • รอแท่งปิดทิ้งไส้ ]";
         card3SigDesc = "⏳ ซิกแนล: แตะ Supply แล้ว ➔ รอแท่งปิดเพื่อ SELL 🔴";
         card3SigCol  = C'255,140,140';
      }
      else
      {
         if(showCME && g_CME_NearSupStrike > 0 && (curBid - g_CME_NearSupStrike) <= 250 * _Point)
         {
            card3Title   = "⚠️ 3. ซิกแนลเทรด: [ ระวังติดฐานรับสถาบัน • ห้ามไล่ SELL ]";
            card3SigDesc = StringFormat("⚠️ ระวัง: ใกล้รับ %.0f (Put %s) ➔ รอหลุดก่อน SELL!", g_CME_NearSupStrike, FormatOI_Number(g_CME_NearSupOI));
            card3SigCol  = clrOrange;
         }
         else
         {
            card3Title   = "🔴 3. ซิกแนลเทรด: [ แผนฝั่ง SELL • รอเด้งเข้าโซน ]";
            card3SigDesc = "🎯 ซิกแนล: ตลาดขาลง ➔ รอเด้งเข้าโซนเล็งขายเพื่อ SELL 🔴";
            card3SigCol  = C'255,130,140';
         }
      }
   }
   else if(isBuy)
   {
      card3BgCol     = C'12,28,18';
      card3BorderCol = C'45,195,85';
      card3TitleCol  = C'90,240,150';
      if(g_SniperStage == STAGE_TRIGGER_PA)
      {
         card3Title   = "🟢 3. ซิกแนลเทรด: [ ลั่นไก BUY! • กดปุ่มเขียวด้านล่าง ]";
         card3SigDesc = "🔥 ซิกแนล: แท่งทิ้งไส้คอนเฟิร์ม ➔ กดปุ่ม 🟢 BUY ทันที!";
         card3SigCol  = C'70,255,140';
      }
      else if(g_SniperStage == STAGE_IN_ZONE)
      {
         card3Title   = "🟢 3. ซิกแนลเทรด: [ แตะ Demand • รอแท่งปิดทิ้งไส้ ]";
         card3SigDesc = "⏳ ซิกแนล: แตะ Demand แล้ว ➔ รอแท่งปิดเพื่อ BUY 🟢";
         card3SigCol  = C'140,245,180';
      }
      else
      {
         if(showCME && g_CME_NearResStrike > 0 && (g_CME_NearResStrike - curBid) <= 250 * _Point)
         {
            card3Title   = "⚠️ 3. ซิกแนลเทรด: [ ระวังติดต้านสถาบัน • ห้ามไล่ BUY ]";
            card3SigDesc = StringFormat("⚠️ ระวัง: ใกล้ต้าน %.0f (Call %s) ➔ รอเบรกก่อน BUY!", g_CME_NearResStrike, FormatOI_Number(g_CME_NearResOI));
            card3SigCol  = clrOrange;
         }
         else
         {
            card3Title   = "🟢 3. ซิกแนลเทรด: [ แผนฝั่ง BUY • รอย่อเข้าโซน ]";
            card3SigDesc = "🎯 ซิกแนล: ตลาดขาขึ้น ➔ รอย่อเข้าโซนเล็งซื้อเพื่อ BUY 🟢";
            card3SigCol  = C'120,240,160';
         }
      }
   }

   string entryStr = "";
   string slStr    = "";
   string tpStr    = "";

   if(InpUseDTD_CF_M1 && g_DTD.isEngulfConfirmed)
   {
      double cfEntry = (g_DTD.confirmEntryPrice > 0) ? g_DTD.confirmEntryPrice : curBid;
      entryStr = StringFormat("🎯 จุดเข้า CF M1: %s (แท่งกลืนกินคอนเฟิร์ม)", DoubleToString(cfEntry, _Digits));
      double dtdSL_Dist = MathAbs(g_DTD.confirmSLPrice - curBid) / _Point;
      slStr = StringFormat("🛑 SL 1R: %s (ห่างราคาปัจจุบัน -%s | กรอบเสี่ยง %.0f pts)", DoubleToString(g_DTD.confirmSLPrice, _Digits), FormatMoneyOrPoints(dtdSL_Dist), g_DTD.slDistPoints);
      tpStr = StringFormat("🏆 TP 1R: %s | 2R: %s | 3R: %s (เป้า 3R: +%.0f pts)", DoubleToString(g_DTD.confirmTP1RPrice, _Digits), DoubleToString(g_DTD.confirmTP2RPrice, _Digits), DoubleToString(g_DTD.confirmTP3RPrice, _Digits), g_DTD.tp3RDistPoints);
   }
   else if(InpUseDTD_CF_M1 && g_DTD.shortestWickPrice > 0.0)
   {
      entryStr = StringFormat("🎯 โซนเล็งเข้า CF M1: เกณฑ์ไส้สั้นสุด %s", DoubleToString(g_DTD.shortestWickPrice, _Digits));
      if(g_DTD.confirmSLPrice > 0)
      {
         double dtdSL_Dist = MathAbs(g_DTD.confirmSLPrice - curBid) / _Point;
         slStr = StringFormat("🛑 SL 1R: %s (ห่างราคาปัจจุบัน -%s | กรอบเสี่ยง %.0f pts)", DoubleToString(g_DTD.confirmSLPrice, _Digits), FormatMoneyOrPoints(dtdSL_Dist), g_DTD.slDistPoints);
      }
      else
      {
         slStr = "🛑 SL 1R: รอแท่ง M1 ปิดคอนเฟิร์มยอดไส้";
      }

      if(g_DTD.confirmTP3RPrice > 0)
         tpStr = StringFormat("🏆 TP 1R: %s | 2R: %s | 3R: %s (เป้า 3R: +%.0f pts)", DoubleToString(g_DTD.confirmTP1RPrice, _Digits), DoubleToString(g_DTD.confirmTP2RPrice, _Digits), DoubleToString(g_DTD.confirmTP3RPrice, _Digits), g_DTD.tp3RDistPoints);
      else
         tpStr = "🏆 เป้ากำไร: คำนวณอัตโนมัติ 1R:1R / 1R:2R / 1R:3R ตามระยะ SL";
   }
   else
   {
      entryStr = "🎯 โซนเล็งเข้า: " + DoubleToString(g_EntryMin, _Digits) + " - " + DoubleToString(g_EntryMax, _Digits);
      if(isSideway) entryStr = "🎯 โซนเล็งเข้า: ตลาดเป็น Sideway รอกราฟเบรกสปีดไลน์เลือกทาง";

      double slDist = MathAbs(g_TargetSL - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
      slStr = "🛑 จุดยอมแพ้ (SL): " + DoubleToString(g_TargetSL, _Digits) + " (ระยะ " + FormatMoneyOrPoints(slDist) + ")";
      if(isSideway) slStr = "🛑 จุดยอมแพ้ (SL): — (ยังไม่เปิดสถานะ)";

      tpStr = (g_HasWave_D && g_WaveD_1618 > 0) ? StringFormat("🏆 TP1: %s | ขา D (161.8%%): %s | R:R = 1 : %.1f", DoubleToString(g_TargetTP1, _Digits), DoubleToString(g_WaveD_1618, _Digits), g_RR_Ratio) : ("🏆 TP1: " + DoubleToString(g_TargetTP1, _Digits) + " | TP2: " + DoubleToString(g_TargetTP2, _Digits) + " | R:R = 1 : " + DoubleToString(g_RR_Ratio, 1));
      if(isSideway) tpStr = "🏆 เป้ากำไร (TP): — (ยังไม่เปิดสถานะ)";
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
   string posInfo = StringFormat("📊 ถือ: %d ไม้ | กำไรรวม: $%.2f%s", totalPos, totalProfit, (g_ZoneSharedSL > 0 ? " | Shared SL: " + DoubleToString(g_ZoneSharedSL, _Digits) : ""));

   // คำนวณเกรดคุณภาพสัญญาณ DTD ตามหลักการ อ.เดช (Location DZ/SZ + Liquidity Sweep + M1 CF)
   string dtdGradeStr  = "";
   color  dtdGradeCol  = clrSilver;
   string dtdChecklist = "";

   if(InpUseDTD_CF_M1)
   {
      double zoneTol    = (g_Asset.assetType == ASSET_CRYPTO) ? (curBid * 0.003) : (g_Asset.assetType == ASSET_GOLD ? (100.0 * _Point) : (25.0 * _Point));
      bool isBuySetup   = (g_DTD.setupSide == 1);
      bool inTargetZone = isBuySetup ? (minDZDist <= zoneTol) : (minSZDist <= zoneTol);
      bool isLQSwept    = isBuySetup ? (g_IsFakeoutTrap && g_FakeoutSide == 1) : (g_IsFakeoutTrap && g_FakeoutSide == -1);
      bool isEngulfCF   = g_DTD.isEngulfConfirmed;

      if(inTargetZone && isLQSwept && isEngulfCF)
      {
         dtdGradeStr  = "⭐ เกรดสัญญาณ: [ A+ ★★★★★ สถาบันครบสูตร! ]";
         dtdGradeCol  = C'0,255,136';
         dtdChecklist = isBuySetup ? "✅ แตะ Demand + ✅ Sweep SSL ล้าง SL + ✅ M1 กลืนกิน (3R!)" : "✅ แตะ Supply + ✅ Sweep BSL ล้าง SL + ✅ M1 กลืนกิน (3R!)";
      }
      else if(inTargetZone && isEngulfCF)
      {
         dtdGradeStr  = "⭐ เกรดสัญญาณ: [ A ★★★★ สวยงามเข้าโซนหลัก ]";
         dtdGradeCol  = C'50,230,150';
         dtdChecklist = isBuySetup ? "✅ แตะ Demand + [—] รอจังหวะ Sweep + ✅ M1 กลืนกิน (เทรดได้)" : "✅ แตะ Supply + [—] รอจังหวะ Sweep + ✅ M1 กลืนกิน (เทรดได้)";
      }
      else if(isLQSwept && isEngulfCF)
      {
         dtdGradeStr  = "⭐ เกรดสัญญาณ: [ A ★★★★ จังหวะดักกินเจ้ามือ ]";
         dtdGradeCol  = clrGold;
         dtdChecklist = isBuySetup ? "[—] นอก Demand + ✅ Sweep SSL ล้าง SL + ✅ M1 กลืนกิน (สไนเปอร์)" : "[—] นอก Supply + ✅ Sweep BSL ล้าง SL + ✅ M1 กลืนกิน (สไนเปอร์)";
      }
      else if(isEngulfCF)
      {
         dtdGradeStr  = "⭐ เกรดสัญญาณ: [ B ⚠️ กลืนกินนอกโซน ระวังเด้งสั้น ]";
         dtdGradeCol  = clrOrange;
         dtdChecklist = isBuySetup ? "⚠️ อยู่นอก Demand (เสี่ยงเด้งหลอก รอย่อเข้าโซนจะปลอดภัยกว่า)" : "⚠️ อยู่นอก Supply (เสี่ยงเด้งหลอก รอเด้งเข้าโซนจะปลอดภัยกว่า)";
      }
      else if(inTargetZone)
      {
         dtdGradeStr  = "⏳ เกรดสัญญาณ: [ รอ M1 ปิดกลืนกินคอนเฟิร์ม ]";
         dtdGradeCol  = clrGold;
         dtdChecklist = isBuySetup ? "✅ แตะ Demand แล้ว ➔ รอแท่ง M1 ปิดเนื้อเหนือไส้สั้นสุด" : "✅ แตะ Supply แล้ว ➔ รอแท่ง M1 ปิดเนื้อใต้ไส้สั้นสุด";
      }
      else
      {
         dtdGradeStr  = "⏳ เกรดสัญญาณ: [ รอกราฟเข้าโซนต้นน้ำ DZ/SZ ]";
         dtdGradeCol  = clrSilver;
         dtdChecklist = "👀 ตลาดยังลอยอยู่กลางทาง ➔ อดทนรอย่อเข้า Demand หรือเด้งแตะ Supply";
      }
   }

   int cardH3 = 24;
   if(g_Card3_Expanded)
   {
      int h3 = 24; // title
      h3 += (StringLen(card3SigDesc) > 56 ? 32 : 16);
      if(InpUseDTD_CF_M1)
      {
         h3 += (StringLen(dtdGradeStr) > 56 ? 32 : 16);
         h3 += (StringLen(dtdChecklist) > 56 ? 32 : 16);
      }
      h3 += (StringLen(entryStr) > 56 ? 32 : 16);
      h3 += (StringLen(slStr) > 56 ? 32 : 16);
      h3 += (StringLen(tpStr) > 56 ? 32 : 16);
      h3 += (StringLen(posInfo) > 56 ? 32 : 16);
      if(InpUseDTD_CF_M1)
      {
         h3 += (StringLen(g_DTD.mmPlanText) > 56 ? 32 : 16);
      }
      h3 += 6;  // spacing before buttons
      h3 += 28; // btn row 1 (lot / close)
      if(InpUseDTD_CF_M1)
      {
         h3 += 6;
         h3 += 26; // btn row DTD Lot
      }
      h3 += 8;  // spacing between btn rows
      h3 += 38; // btn row 2 (buy / sell)
      h3 += 12; // bottom padding
      cardH3 = h3;
   }

   // 1. CREATE BACKGROUND RECTANGLE FIRST (Bottom layer)
   CreateRect(GUI_PREFIX + "C3_BG", baseX, curY, w, cardH3, card3BgCol, card3BorderCol);

   // 2. CREATE TITLE & BUTTON ON TOP
   CreateLabel(GUI_PREFIX + "C3_TITLE", baseX + 12, curY + 5, card3Title, card3TitleCol, 8, true);
   CreateButton(GUI_PREFIX + "BTN_MIN_C3", baseX + w - 24, curY + 3, 18, 18, (g_Card3_Expanded ? "—" : "+"), C'35,50,70', clrSilver, 8);

   if(g_Card3_Expanded)
   {
      int lineY = curY + 24;
      RenderWrappedLabel(GUI_PREFIX + "C3_L_SIG", baseX + 14, lineY, card3SigDesc, card3SigCol, 8, true, 56, 16);
      RenderWrappedLabel(GUI_PREFIX + "C3_L1", baseX + 14, lineY, entryStr, clrWhite, 8, true, 56, 16);
      RenderWrappedLabel(GUI_PREFIX + "C3_L2", baseX + 14, lineY, slStr, C'255,110,110', 8, false, 56, 16);
      RenderWrappedLabel(GUI_PREFIX + "C3_L3", baseX + 14, lineY, tpStr, C'100,255,160', 8, false, 56, 16);
      RenderWrappedLabel(GUI_PREFIX + "C3_L5", baseX + 14, lineY, posInfo, clrWhite, 8, false, 56, 16);

      if(InpUseDTD_CF_M1)
      {
         RenderWrappedLabel(GUI_PREFIX + "C3_L_GRADE", baseX + 14, lineY, dtdGradeStr, dtdGradeCol, 8, true, 56, 16);
         RenderWrappedLabel(GUI_PREFIX + "C3_L_CHK", baseX + 14, lineY, dtdChecklist, clrWhite, 8, false, 56, 16);
         RenderWrappedLabel(GUI_PREFIX + "C3_L_DTD", baseX + 14, lineY, g_DTD.mmPlanText, clrGold, 8, true, 56, 16);
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "C3_L_GRADE");
         ObjectDelete(0, GUI_PREFIX + "C3_L_CHK");
         ObjectDelete(0, GUI_PREFIX + "C3_L_DTD");
      }

      int btnY1 = lineY + 6;
      int btnY_DTD = btnY1 + 34;
      int btnY2 = btnY_DTD;

      CreateButton(GUI_PREFIX + "LOT_MINUS",   baseX + 14,  btnY1, 30, 28, "-", C'45,55,75', clrWhite, 11);
      CreateButton(GUI_PREFIX + "LOT_VAL",     baseX + 47,  btnY1, 70, 28, DoubleToString(g_CurrentLot, 2), C'30,40,55', clrGold, 10);
      CreateButton(GUI_PREFIX + "LOT_PLUS",    baseX + 120, btnY1, 30, 28, "+", C'45,55,75', clrWhite, 11);

      CreateButton(GUI_PREFIX + "BTN_BE",      baseX + 158, btnY1, 72, 28, "🛡️ บังทุน", C'35,70,120', clrWhite, 8);
      CreateButton(GUI_PREFIX + "BTN_PARTIAL", baseX + 236, btnY1, 72, 28, "💰 ปิด 80%", C'145,100,20', clrWhite, 8);
      CreateButton(GUI_PREFIX + "BTN_CLOSE",   baseX + 314, btnY1, 72, 28, "❌ ปิดหมด", C'140,40,50', clrWhite, 8);

      if(InpUseDTD_CF_M1)
      {
         CreateButton(GUI_PREFIX + "BTN_DTD_LOT", baseX + 14, btnY_DTD, w - 28, 26, StringFormat("🎯 คลิกใช้ขนาด Lot อ.เดช: %.2f (แผน MM 1R:3R)", g_DTD.recommendedLot), C'25,55,90', clrGold, 8);
         btnY2 = btnY_DTD + 32;
      }
      else
      {
         ObjectDelete(0, GUI_PREFIX + "BTN_DTD_LOT");
         btnY2 = btnY1 + 34;
      }
      CreateButton(GUI_PREFIX + "BTN_BUY",  baseX + 14,  btnY2, 181, 38, "🟢 กด BUY", C'30,120,60', clrWhite, 11);
      CreateButton(GUI_PREFIX + "BTN_SELL", baseX + 205, btnY2, 181, 38, "🔴 กด SELL", C'150,40,40', clrWhite, 11);

      cardH3 = (btnY2 + 38 - curY) + 10;
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
      ObjectDelete(0, GUI_PREFIX + "BTN_DTD_LOT");
   }
}
//+------------------------------------------------------------------+
