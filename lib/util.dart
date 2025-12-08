import 'package:dexcom/dexcom.dart';

String? trendToString(DexcomTrend trend) {
  switch (trend) {
    case DexcomTrend.doubleDown: return "Quickly Falling";
    case DexcomTrend.doubleUp: return "Quickly Rising";
    case DexcomTrend.flat: return "Steady";
    case DexcomTrend.fortyFiveDown: return "Slowly Falling";
    case DexcomTrend.fortyFiveUp: return "Slowly Rising";
    case DexcomTrend.nonComputable: return null;
    case DexcomTrend.none: return null;
    case DexcomTrend.singleDown: return "Falling";
    case DexcomTrend.singleUp: return "Rising";
  }
}