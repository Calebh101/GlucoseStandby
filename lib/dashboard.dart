import 'dart:math';

import 'package:GlucoseStandby/settings.dart';
import 'package:GlucoseStandby/util.dart';
import 'package:dexcom/dexcom.dart';
import 'package:flutter/material.dart';
import 'package:GlucoseStandby/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dashboard extends StatefulWidget {
  final EnvironmentType type;
  const Dashboard({super.key, required this.type});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Dexcom? dexcom;
  DexcomStreamProvider? provider;
  (DexcomReading?, DexcomReading?)? readings; // Latest, next latest
  Settings? settings;
  bool loading = true;

  Future<void> reloadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    settings = Settings.fromPrefs(prefs);

    String? username = prefs.getString("username");
    String? password = prefs.getString("password");

    if (username != dexcom?.username || password != dexcom?.password) {
      dexcom = Dexcom(username: username, password: password);
      listen(dexcom!);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  void listen(Dexcom dexcom) {
    provider?.close();
    provider = DexcomStreamProvider(dexcom);

    provider!.listen(onData: (data) async {
      readings = (data.elementAtOrNull(0), data.elementAtOrNull(1));
      await reloadSettings();
      loading = false;
      setState(() {});
    }, onRefresh: () {
      loading = true;
      setState(() {});
    });
  }

  @override
  void dispose() {
    provider?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = 24;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: loading ? Container(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(),
          ) : Icon(Icons.refresh, size: iconSize)),
          IconButton(onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsWidget(),
              ),
            );

            await reloadSettings();
          }, icon: Icon(Icons.settings, size: iconSize)),
        ],
      ),
      body: Center(
        child: Row(
          children: [
            if (readings?.$1 != null)
            ReadingWidget(reading: readings!.$1!, settings: settings, size: 48),
            Column(
              children: [
                if (readings?.$2 != null)
                ReadingWidget(reading: readings!.$2!, settings: settings, size: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReadingWidget extends StatelessWidget {
  final DexcomReading reading;
  final Settings? settings;
  final double size;
  const ReadingWidget({super.key, required this.reading, required this.settings, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 3,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("${reading.value}", style: TextStyle(fontSize: size, color: settings != null ? readingToColor(reading, settings!) : null)),
          if (reading.trend != DexcomTrend.none && reading.trend != DexcomTrend.nonComputable)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: trendToRotation(reading.trend) * pi / 180,
                child: Icon(Icons.arrow_upward, color: trendToColor(reading.trend)),
              ),
              if (reading.trend == DexcomTrend.doubleUp || reading.trend == DexcomTrend.doubleDown)
              Transform.rotate(
                angle: trendToRotation(reading.trend) * pi / 180,
                child: Icon(Icons.arrow_upward, color: trendToColor(reading.trend)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}