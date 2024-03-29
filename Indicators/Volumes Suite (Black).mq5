//+-------------------------------------------------------------------------------------------+
//|                                                                                           |
//|                                      Volumes Suite.mq5                                    |
//|                                                                                           |
//+-------------------------------------------------------------------------------------------+
#property copyright "Copyright © 2015 traderathome and qFish and Enivid (2020, MT5)"
#property link "https://www.earnforex.com/forum/threads/convert-candle-suite-and-volume-suite-indicators-to-mt5.40593/"

/*---------------------------------------------------------------------------------------------
User Notes:

This indicator is coded to run on MT4 Builds 600+.  It draws a PVA (Price-Volume Analysis)
volumes histogram or a standard volumes histogram in the first chart subwindow.  An alert
option signals when a "Climax" situation exists.  Specific details follow.

The PVA Volumes Histogram -
   PVA volume is used together with PVA bars and PVA candlesticks for easy recognition of
   when special price and volume situations occur.  The special situations, or requirements
   for the the colors used are as follows.

   Situation "Climax"
   Bars with volume >= 200% of the average volume of the 10 previous chart TFs, or bars
   where the product of candle spread x candle volume is >= the highest for the 10 previous
   chart time TFs.
   Default Colors:  Bull bars are green and bear bars are red.

   Situation "Volume Rising Above Average"
   Bars with volume >= 150% of the average volume of the 10 previous chart TFs.
   Default Colors:  Bull bars are blue and bear are blue-violet.

   PVA Color Options -
   There are three PVA color options provided by "__PVA_Option_Simple_Standard_Default_123".
     1. Simple:  Use this option for a simple PVA two color display based on Climax only
        situations (an option allows you to include "Rising" volume).  You can change any
        color.  To start, a shade of green/red are input for the PVA bull/bear bars.
     2. Standard:  Use this option for the 4-color PVA display where you can change any
        color. To start, the traditional PVA colors are input.
     3. Default:  There are no inputs.  The hard coded traditional PVA colors display.
   These color options help traders suffering from color blindness by enabling them to
   choose the colors that work best for them.  Of course, there are many other reasons
   that some traders might wish to choose colors differing from the traditional colors.
   And, it is easy to return anytime to the default traditional PVA color display.

The Alert -
   This indicator includes a sound-text alert that triggers once per TF at the first
   qualification of the TF bar as a "Climax" situation.  Set "Alert_On" to "true"
   to activate the alert.  Enter your "Broker_Name_In_Alert" to avoid confusion if
   simultaneously using multiple platforms.  If also using the PVA Candles indicator,
   be sure the two alert inputs in that indicator are set to "false".

The Standard Volumes Display -
   A normal volume histogram is displayed in the single color selected.  However, you
   can highlight Climax situations with wider bars and utilize the Alert.

Revisons to previous release 05-30-2015:
* Add "on/off" option for showing volume count in subwindow ShortName.
* Add "wide/narrow" bar option for normal bars of STD and PVA volume displays.
* Removed "Highlight Climax" option in STD volumes display.
* Revised color of PVA rising bear for enhanced visibility.
* Modified External Inputs for additonal clarity.

                                                                    - Traderathome, 06-28-2015
-----------------------------------------------------------------------------------------------
Acknowledgements:
BetterVolume.mq4 - for initial "climax" candle code definition (BetterVolume_v1.4).

----------------------------------------------------------------------------------------------
Suggested Colors            White Chart        Black Chart        Remarks

indicator_color1            White              C'010,010,010'     Chart Background
indicator_color2            C'119,146,179'     C'102,099,163'     Normal Volume
indicator_color3            C'067,100,214'     C'017,136,255'     Bull Rising
indicator_color4            C'184,038,232'     C'184,051,255'     Bear Rising
indicator_color5            C'014,165,101'     C'031,192,071'     Bull Climax
indicator_color6            C'000,166,100'     C'224,001,006'     Bear Climax
indicator_color7            C'046,055,169'     C'102,099,163'     Standard Volume

Note: Suggested colors coincide with the colors of the Candles Suite indicator.
---------------------------------------------------------------------------------------------*/

//+-------------------------------------------------------------------------------------------+
//| Indicator Global Inputs                                                                   |
//+-------------------------------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots 3
#property indicator_minimum 0

enum ENUM_PVA_OPTIONS {
   Simple,
   Standard,
   Default
};

// Global External Inputs
input group "Part 1 - Main Settings:";
input bool Indicator_On = true;
input bool Alert_On = true;
input string Broker_Name_In_Alert = "";

input group "Part 2 - Volume Window Settings:";
input color Chart_Background_Color = C'010,010,010';
input bool Volume_Count_in_ShortName = true;
input bool Volume_PVA_vs_STD = true;
input bool __Normal_Bars_Thin_vs_Wide = true;
input ENUM_PVA_OPTIONS __PVA_Option = Default;

input group "Part 3 - STD Volume Settings:";
input color STD_Volumes_Thin_Bar = C'102,099,163';
input color STD_Volumes_Wide_Bar = C'102,099,163';

input group "Part 4 - PVA Simple Settings:";
input color Simple_Normal_Thin_Bar = C'102,099,163';
input color Simple_Normal_Wide_Bar = C'056,061,137';
input color Simple_Bull_Climax = C'031,192,071';
input color Simple_Bear_Climax = C'224,001,006';
input bool Include_Rising_Volume = false;

input group "Part 5 - PVA Standard Settings:";
input color Standard_Normal_Thin_Bar = C'102,099,163';
input color Standard_Normal_Wide_Bar = C'056,061,137';
input color Standard_Bull_Rising = C'017,136,255';
input color Standard_Bear_Rising = C'184,051,255';
input color Standard_Bull_Climax = C'031,192,071';
input color Standard_Bear_Climax = C'224,001,006';

// Global Buffers and Variables
color Normal_Bar, Bull_Rising, Bear_Rising, Bull_Climax, Bear_Climax;
double Phantom[], Normal[], PVA[], PVA_Colors[];

// Default PVA Colors
color PVA_Normal_Thin_Bar = C'102,099,163';
color PVA_Normal_Wide_Bar = C'056,061,137';
color PVA_Bull_Rising = C'017,136,255';
color PVA_Bear_Rising = C'184,051,255';
color PVA_Bull_Climax = C'031,192,071';
color PVA_Bear_Climax = C'224,001,006';

// Alert
bool Alert_Allowed;

//+-------------------------------------------------------------------------------------------+
//| Custom indicator initialization function                                                  |
//+-------------------------------------------------------------------------------------------+
void OnInit() {
   string ShortName;
   // Determine the current chart scale (chart scale number should be 0-5)
   long Chart_Scale = ChartScaleGet();
   int Bar_Width = CalculateBarWidth(Chart_Scale);

   // Phantom Volume
   SetIndexBuffer(0, Phantom, INDICATOR_DATA);
   ArraySetAsSeries(Phantom, true);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, Bar_Width);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, Chart_Background_Color);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);

   // STD
   if (!Volume_PVA_vs_STD) {
      // Normal Volume Bars
      SetIndexBuffer(1, Normal, INDICATOR_DATA);
      ArraySetAsSeries(Normal, true);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
      if (__Normal_Bars_Thin_vs_Wide) {
         PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
         PlotIndexSetInteger(1, PLOT_LINE_COLOR, STD_Volumes_Thin_Bar);
      } else {
         PlotIndexSetInteger(1, PLOT_LINE_WIDTH, Bar_Width);
         PlotIndexSetInteger(1, PLOT_LINE_COLOR, STD_Volumes_Wide_Bar);
      }
      PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
      ShortName = "Broker Tick Volume:    ";
   }
   // PVA
   else {
      // Colors Selection for PVA
      if (__PVA_Option == Simple) {
         if (__Normal_Bars_Thin_vs_Wide) {
            Normal_Bar = Simple_Normal_Thin_Bar;
         } else {
            Normal_Bar = Simple_Normal_Wide_Bar;
         }
         Bull_Rising = Simple_Bull_Climax;
         Bear_Rising = Simple_Bear_Climax;
         Bull_Climax = Simple_Bull_Climax;
         Bear_Climax = Simple_Bear_Climax;
         if (!Include_Rising_Volume) {
            ShortName = "Broker Tick PVA, Climax only:    ";
         } else {
            ShortName = "Broker Tick PVA:    ";
         }
      } else {
         if (__PVA_Option == Standard) {
            if (__Normal_Bars_Thin_vs_Wide) {
               Normal_Bar = Standard_Normal_Thin_Bar;
            } else {
               Normal_Bar = Standard_Normal_Wide_Bar;
            }
            Bull_Rising = Standard_Bull_Rising;
            Bear_Rising = Standard_Bear_Rising;
            Bull_Climax = Standard_Bull_Climax;
            Bear_Climax = Standard_Bear_Climax;
            ShortName = "Broker Tick PVA:    ";
         } else {
            if (__PVA_Option == Default) {
               if (__Normal_Bars_Thin_vs_Wide) {
                  Normal_Bar = PVA_Normal_Thin_Bar;
               } else {
                  Normal_Bar = PVA_Normal_Wide_Bar;
               }
               Bull_Rising = PVA_Bull_Rising;
               Bear_Rising = PVA_Bear_Rising;
               Bull_Climax = PVA_Bull_Climax;
               Bear_Climax = PVA_Bear_Climax;
               ShortName = "Broker Tick PVA:    ";
            }
         }
      }
      // PVA: Simple Normal Volume Bars
      SetIndexBuffer(1, Normal, INDICATOR_DATA);
      ArraySetAsSeries(Normal, true);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, Normal_Bar);
      if (__Normal_Bars_Thin_vs_Wide) {
         PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
      } else {
         PlotIndexSetInteger(1, PLOT_LINE_WIDTH, Bar_Width);
      }
      PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);

      // PVA: Simple Rising Volume Bars
      SetIndexBuffer(2, PVA, INDICATOR_DATA);
      SetIndexBuffer(3, PVA_Colors, INDICATOR_COLOR_INDEX);
      ArraySetAsSeries(PVA, true);
      ArraySetAsSeries(PVA_Colors, true);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
      PlotIndexSetInteger(2, PLOT_LINE_WIDTH, Bar_Width);
      PlotIndexSetInteger(2, PLOT_COLOR_INDEXES, 4);
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, 0, Bull_Climax);
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, 1, Bear_Climax);
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, 2, Bull_Rising);
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, 3, Bear_Rising);
      PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);

      // Alert
      if (Alert_On) {
         Alert_Allowed = true;
         ShortName = ShortName + "Alert On";
      }
   }

   // Indicator ShortName, Index Digits & Labels
   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   PlotIndexSetString(0, PLOT_LABEL, NULL);
   if (Volume_Count_in_ShortName) {
      if (Alert_On) {
         ShortName = ShortName + ",  Count ";
      } else {
         ShortName = ShortName + "Count ";
      }
      PlotIndexSetString(1, PLOT_LABEL, "0");
   } else {
      PlotIndexSetString(1, PLOT_LABEL, NULL);
   }
   PlotIndexSetString(2, PLOT_LABEL, NULL);

   IndicatorSetString(INDICATOR_SHORTNAME, ShortName);
}

int OnCalculate(const int rates_total,
   const int prev_calculated,
      const datetime & Time[],
         const double & Open[],
            const double & High[],
               const double & Low[],
                  const double & Close[],
                     const long & Volume[],
                        const long & volume[],
                           const int & spread[]) {
   // If Indicator is "Off" deinitialize only once, not every tick
   if (!Indicator_On) return (0);

   ArraySetAsSeries(Time, true);
   ArraySetAsSeries(Open, true);
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   ArraySetAsSeries(Close, true);
   ArraySetAsSeries(Volume, true);

   // Confirm range of chart bars for calculations
   // check for possible errors
   int counted_bars = prev_calculated > 0 ? prev_calculated - 1 : 0;
   if (counted_bars < 0) return (-1);
   // last counted bar will be recounted
   if (counted_bars > 0) counted_bars--;
   int limit = rates_total - counted_bars;
   if (limit > rates_total - 11) limit = rates_total - 11; // Because of the inner cycles further below.

   // Begin the loop of calculations for the range of chart bars.
   for (int i = limit - 1; i >= 0; i--) {
      // Define Phantom volume larger than Normal, which displayed without color
      // assures Normal volume will occupy only the lower 75% of the volume window
      Phantom[i] = Volume[i] / 0.75;

      // Define Normal volume
      Normal[i] = (double) Volume[i];

      if (Volume_PVA_vs_STD) {
         // Clear buffers
         PVA[i] = 0;
         double av = 0;
         int va = 0;

         // Rising Volume
         for (int j = i + 1; j <= i + 10; j++) {
            av = av + Volume[j];
         }
         av = av / 10;

         // Climax Volume
         double Range = High[i] - Low[i];
         double Value2 = Volume[i] * Range;
         double HiValue2 = 0;
         for (int j = i + 1; j <= i + 10; j++) {
            double tempv2 = Volume[j] * (High[j] - Low[j]);
            if (tempv2 >= HiValue2) {
               HiValue2 = tempv2;
            }
         }
         if ((Value2 >= HiValue2) || (Volume[i] >= av * 2)) {
            va = 1;
         }

         // Rising Volume
         if (((va == 0) && (Volume_PVA_vs_STD)) && ((__PVA_Option != Simple) || ((__PVA_Option == Simple) && (Include_Rising_Volume)))) {
            if (Volume[i] >= av * 1.5) {
               va = 2;
            }
         }

         // Apply Correct Color to bars
         if (va == 1) {
            PVA[i] = (double) Volume[i];
            // Bull Candle
            if (Close[i] > Open[i]) {
               PVA_Colors[i] = 0;
            }
            // Bear Candle
            else if (Close[i] <= Open[i]) {
               PVA_Colors[i] = 1;
            }
            // Sound & Text Alert
            if ((i == 0) && (Alert_Allowed) && (Alert_On)) {
               Alert_Allowed = false;
               Alert(Broker_Name_In_Alert, ":  ", Symbol(), "-", Period(), "   PVA alert!");
            }
         } else if (va == 2) {
            PVA[i] = (double) Volume[i];
            if (Close[i] > Open[i]) {
               PVA_Colors[i] = 2;
            }
            if (Close[i] <= Open[i]) {
               PVA_Colors[i] = 3;
            }
         }
      }
   } // End "for i" loop

   return (rates_total);
}

//+-------------------------------------------------------------------------------------------+
//| Subroutine:  Set up to get the chart scale number                                         |
//+-------------------------------------------------------------------------------------------+
void OnChartEvent(const int id,
   const long & lparam,
      const double & dparam,
         const string & sparam) {
   if (id != CHARTEVENT_CHART_CHANGE) return;
   long Chart_Scale = ChartScaleGet();
   int Bar_Width = CalculateBarWidth(Chart_Scale);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, Bar_Width);
   if (!__Normal_Bars_Thin_vs_Wide) PlotIndexSetInteger(1, PLOT_LINE_WIDTH, Bar_Width);
   if (Volume_PVA_vs_STD) PlotIndexSetInteger(2, PLOT_LINE_WIDTH, Bar_Width);
   ChartRedraw();
}

//+-------------------------------------------------------------------------------------------+
//| Subroutine:  Get the chart scale number                                                   |
//+-------------------------------------------------------------------------------------------+
long ChartScaleGet() {
   long result = -1;
   ChartGetInteger(0, CHART_SCALE, 0, result);
   return (result);
}

//+-------------------------------------------------------------------------------------------+
//| Subroutine:  Get the bar width depending on chart scale                                   |
//+-------------------------------------------------------------------------------------------+
int CalculateBarWidth(long chart_scale) {
   switch ((int) chart_scale) {
   case 0:
      return (1);
   case 1:
      return (2);
   case 2:
      return (3);
   case 3:
      return (4);
   case 4:
      return (5);
   default:
      return (13);
   }
}
//+-------------------------------------------------------------------------------------------+
//|Custom indicator end                                                                       |
//+-------------------------------------------------------------------------------------------+
