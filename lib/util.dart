import 'package:GlucoseStandby/settings.dart';
import 'package:dexcom/dexcom.dart';
import 'package:flutter/material.dart';

Color? readingToColor(DexcomReading reading, Settings settings) {
  final v = reading.value; // value
  final b = settings.bounderies; // bounderies

  if (v > b.superHigh) {
    return Colors.red;
  } else if (v > b.high) {
    return Colors.orange;
  } else if (v < b.superLow) {
    return Colors.red;
  } else if (v < b.low) {
    return Colors.orange;
  } else {
    return Colors.green;
  }
}

Color? timerToColor(int seconds) {
  if (seconds < 240) {
    return Colors.green;
  } else if (seconds < 360) {
    return Colors.yellow;
  } else {
    return Colors.red;
  }
}

String? trendToString(DexcomTrend trend) {
  switch (trend) {
    case DexcomTrend.flat: return "Steady";
    case DexcomTrend.fortyFiveDown: return "Slowly Falling";
    case DexcomTrend.fortyFiveUp: return "Slowly Rising";
    case DexcomTrend.singleDown: return "Falling";
    case DexcomTrend.singleUp: return "Rising";
    case DexcomTrend.doubleDown: return "Quickly Falling";
    case DexcomTrend.doubleUp: return "Quickly Rising";
    case DexcomTrend.none: return null;
    case DexcomTrend.nonComputable: return null;
  }
}

Color trendToColor(DexcomTrend trend) {
  switch (trend) {
    case DexcomTrend.flat: return Colors.green;
    case DexcomTrend.fortyFiveUp: return Colors.yellow;
    case DexcomTrend.fortyFiveDown: return Colors.yellow;
    case DexcomTrend.singleUp: return Colors.orange;
    case DexcomTrend.singleDown: return Colors.orange;
    case DexcomTrend.doubleUp: return Colors.red;
    case DexcomTrend.doubleDown: return Colors.red;
    default: throw UnimplementedError("Invalid trend: $trend");
  }
}

int trendToRotation(DexcomTrend trend) {
  switch (trend) {
    case DexcomTrend.flat: return 90;
    case DexcomTrend.fortyFiveUp: return 45;
    case DexcomTrend.fortyFiveDown: return 135;
    case DexcomTrend.singleUp: return 0;
    case DexcomTrend.singleDown: return 180;
    case DexcomTrend.doubleUp: return 0;
    case DexcomTrend.doubleDown: return 180;
    default: throw UnimplementedError("Invalid trend: $trend");
  }
}

String formatDuration(int seconds, {bool forceIncludeHours = false}) {
  if (seconds < 0) {
    seconds = 0;
  }

  Duration duration = Duration(seconds: seconds);
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String hours = duration.inHours > 0 ? duration.inHours.toString() : '';
  String minutes;

  if (seconds < 600) {
    minutes = duration.inMinutes.remainder(60).toString();
  } else {
    minutes = twoDigits(duration.inMinutes.remainder(60));
  }

  String secs = twoDigits(duration.inSeconds.remainder(60));

  if (hours.isNotEmpty || forceIncludeHours) {
    return "$hours:$minutes:$secs";
  } else {
    return "$minutes:$secs";
  }
}