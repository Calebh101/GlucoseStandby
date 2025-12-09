import 'dart:async';
import 'dart:math';

import 'account.dart';
import 'main.dart';
import 'package:dexcom/dexcom.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:localpkg/logger.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late Dexcom dexcom;
  late DexcomStreamProvider provider;
  late Timer timer;

  List<DexcomReading> readings = []; // 0: newest
  String? error;
  int sinceLast = 0; // seconds

  void refresh() {
    setState(() {});
  }

  void reload() {
    print("Reloading...");

    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (context) => widget,
    ));
  }

  @override
  void initState() {
    print("Initializing...");
    dexcom = Dexcom(username: DesktopApplication.prefs.getString("username"), password: DesktopApplication.prefs.getString("password"));
    provider = DexcomStreamProvider(dexcom, maxCount: 12, buffer: 30, debug: false);
    super.initState();

    provider.listen(
      cancelOnError: false,
      onData: (data) {
        print("Received data of ${data.length} entries");
        if (data.isEmpty) return;
        readings = data.sublist(0, min(provider.maxCount, data.length));
        DesktopApplication.update(readings.firstOrNull);
        refresh();
      },
      onError: (e) {
        warn("Dexcom error: $e");
        error = e.toString();
        refresh();

        Timer(Duration(minutes: 2), () {
          print("Error timer triggered...");
          reload();
        });
      },
      onTimerChange: (time) {
        print("Tick: $time");
        sinceLast = time;
        refresh();
      },
    );

    timer = Timer.periodic(Duration(seconds: 30), (timer) {
      print("Periodic timer triggered...");
      DesktopApplication.update(readings.firstOrNull);

      (() async {
        List<DexcomReading>? result = await dexcom.getGlucoseReadings();
        print("Latest reading: ${(result ?? []).firstOrNull}");
      })();
    });
  }

  @override
  void dispose() {
    timer.cancel();
    provider.close();
    super.dispose();
  }

  Widget generateArrows(DexcomReading reading, {required double rotation, required double size}) {
    double shift = 20;
    if (reading.trend == DexcomTrend.nonComputable || reading.trend == DexcomTrend.none) return SizedBox.shrink();

    List<Widget> items = [
      Transform.rotate(
        angle: rotation * pi / 180,
        child: Icon(
          Icons.arrow_upward,
          size: size,
          color: DexcomEffects.colorForTrend(reading.trend),
        ),
      ),
      if (reading.trend == DexcomTrend.doubleDown || reading.trend == DexcomTrend.doubleUp)
      Transform.rotate(
        angle: rotation * pi / 180,
        child: Icon(
          Icons.arrow_upward,
          size: size,
          color: DexcomEffects.colorForTrend(reading.trend),
        ),
      ),
    ];

    return SizedBox(
      width: size + ((items.length - 1) * shift),
      height: size,
      child: Stack(
        children: List.generate(items.length, (i) {
          return Positioned(
            left: i * shift,
            child: items[i],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage(showBack: true)),
            );
          }, icon: Icon(Icons.account_box_outlined)),
          IconButton(onPressed: () {
            print("Refreshing...");
            reload();
          }, icon: Icon(Icons.refresh)),
          IconButton(onPressed: () {
            DesktopApplication.hide();
          }, icon: Icon(Icons.remove)),
        ],
      ),
      backgroundColor: Colors.black,
      body: error != null || readings.isEmpty ? Center(child: Text(error ?? "Loading...", style: TextStyle(fontSize: 26))) : Builder(
        builder: (context) {
          int? rotation = DexcomEffects.rotationForTrend(readings.first.trend);
          int? subrotation = readings.length >= 2 ? DexcomEffects.rotationForTrend(readings[1].trend) : null;
          double mainTextSize = 96;
          double subTextSize = 32;
          double iconSize = 88;
          double subIconSize = 42;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("${readings.first.value}", style: TextStyle(fontSize: mainTextSize, color: DexcomEffects.colorForValue(readings.first.value))),
                    if (rotation != null)
                    generateArrows(readings.first, rotation: rotation.toDouble(), size: iconSize),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (readings.length >= 2)
                        Row(
                          children: [
                            Text("${readings[1].value}", style: TextStyle(fontSize: subTextSize, color: DexcomEffects.colorForValue(readings[1].value))),
                            if (subrotation != null)
                            generateArrows(readings[1], rotation: subrotation.toDouble(), size: subIconSize),
                          ],
                        ),
                        Text("-${formatSeconds(sinceLast)}", style: TextStyle(fontSize: subTextSize, color: DexcomEffects.colorForTime(sinceLast))),
                      ],
                    ),
                  ],
                ),
                SizedBox(
                  height: 250,
                  width: 350,
                  child: Builder(
                    builder: (context) {
                      double suggestedMin = 70;
                      double suggestedMax = 180;

                      List<FlSpot> points = List.generate(readings.length, (int i) {
                        DexcomReading reading = readings[i];
                        return FlSpot(0 - DateTime.now().difference(reading.systemTime).inMinutes.toDouble(), reading.value.toDouble());
                      });

                      double dataMin = points.map((e) => e.y).reduce((a, b) => a < b ? a : b);
                      double dataMax = points.map((e) => e.y).reduce((a, b) => a > b ? a : b);

                      double minY = dataMin < suggestedMin ? dataMin : suggestedMin;
                      double maxY = dataMax > suggestedMax ? dataMax : suggestedMax;

                      return LineChart(
                        LineChartData(
                          minY: minY,
                          maxY: maxY,
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    "-${value.toInt()}",
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: points,
                              isCurved: true,
                              color: Colors.blue,
                              dotData: FlDotData(show: true),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}

String formatSeconds(int seconds) {
  int minutes = (seconds / 60).floor();
  int left = seconds % 60;
  return ["$minutes", left.toString().padLeft(2, "0")].join(":");
}

class DexcomEffects {
  static Color colorForTrend(DexcomTrend trend) {
    switch (trend) {
      case DexcomTrend.doubleDown: return Colors.red;
      case DexcomTrend.doubleUp: return Colors.red;
      case DexcomTrend.flat: return Colors.green;
      case DexcomTrend.fortyFiveDown: return Colors.orange;
      case DexcomTrend.fortyFiveUp: return Colors.orange;
      case DexcomTrend.nonComputable: return Colors.white;
      case DexcomTrend.none: return Colors.white;
      case DexcomTrend.singleDown: return Colors.deepOrange;
      case DexcomTrend.singleUp: return Colors.deepOrange;
    }
  }

  static int? rotationForTrend(DexcomTrend trend) {
    switch (trend) {
      case DexcomTrend.doubleDown: return 180;
      case DexcomTrend.doubleUp: return 0;
      case DexcomTrend.flat: return 90;
      case DexcomTrend.fortyFiveDown: return (180 - 45);
      case DexcomTrend.fortyFiveUp: return 45;
      case DexcomTrend.nonComputable: return null;
      case DexcomTrend.none: return null;
      case DexcomTrend.singleDown: return 180;
      case DexcomTrend.singleUp: return 0;
    }
  }

  static Color colorForValue(int value) {
    if (value >= 150) {
      if (value >= 180) {
        if (value >= 240) {
          return Colors.red;
        } else {
          return Colors.deepOrange;
        }
      } else {
        return Colors.orange;
      }
    } else if (value <= 100) {
      if (value <= 70) {
        if (value <= 55) {
          return Colors.red;
        } else {
          return Colors.deepOrange;
        }
      } else {
        return Colors.orange;
      }
    } else {
      return Colors.green;
    }
  }

  static Color colorForTime(int seconds) {
    if (seconds >= 600) return Colors.red;
    if (seconds >= 360) return Colors.deepOrange;
    if (seconds >= 240) return Colors.yellow;
    return Colors.green;
  }
}