import 'dart:async';
import 'dart:math';

import 'package:GlucoseStandby/settings.dart';
import 'package:GlucoseStandby/util.dart';
import 'package:dexcom/dexcom.dart';
import 'package:flutter/material.dart';
import 'package:GlucoseStandby/main.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styled_logger/styled_logger.dart';

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
  int sleepTimer = 0;

  late Timer timer;
  late Timer sleepTimerTimer;

  Future<void> reloadSettings() async {
    Logger.print("Reloading settings...");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    settings = Settings.fromPrefs(prefs);

    String? username = prefs.getString("username");
    String? password = prefs.getString("password");

    if ((username != dexcom?.username || password != dexcom?.password) && username != null && password != null) {
      dexcom = Dexcom(username: username, password: password);
      listen(dexcom!);
    }

    Logger.print("Finished reloading settings");
    setState(() {});
  }

  @override
  void initState() {
    reloadSettings();
    super.initState();

    if (widget.type == EnvironmentType.desktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        timer = Timer.periodic(Duration(seconds: 30), (timer) {
          DesktopApplication.update(readings?.$1);
        });
      });
    }

    sleepTimerTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (sleepTimer > 0) {
        sleepTimer--;
        if (sleepTimer == 0) onSleep();
      }

      setState(() {});
    });
  }

  void onSleep() {
    Logger.print("Sleeping...");
  }

  void listen(Dexcom dexcom) {
    Logger.print("Starting listener...");
    provider?.close();
    provider = DexcomStreamProvider(dexcom);

    provider!.listen(onData: (data) async {
      readings = (data.elementAtOrNull(0), data.elementAtOrNull(1));
      await reloadSettings();
      await DesktopApplication.update(readings?.$1);
      loading = false;
      setState(() {});
    }, onRefresh: () {
      loading = true;
      setState(() {});
    }, onTimerChange: (time) {
      setState(() {});
    },);
  }

  @override
  void dispose() {
    timer.cancel();
    sleepTimerTimer.cancel();

    provider?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = 24;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        actions: [
          IconButton(onPressed: () async {
            int value = sleepTimer;

            bool? result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
              builder: (context, setState) {
                Timer timer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
                  if (!context.mounted) return timer.cancel();
                  setState(() {});
                });

                return AlertDialog(
                  title: Text("Sleep Timer"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sleepTimer > 0)
                      Text("-${formatDuration(sleepTimer)} Remaining (${DateFormat("MMMM d 'at' h:mm a").format(DateTime.now().add(Duration(seconds: sleepTimer)))})"),
                      if (sleepTimer <= 0)
                      Text("Currently off"),
                      if (value > 0)
                      Text("Setting to +${formatDuration(value)} (${DateFormat("MMMM d 'at' h:mm a").format(DateTime.now().add(Duration(seconds: value)))})"),
                      if (value <= 0)
                      Text("Setting to off"),
                      Slider(value: value.clamp(60, 24 * 60 * 60).toDouble(), min: 60, max: 24 * 60 * 60, divisions: 1439, onChanged: (x) {
                        value = x.toInt();
                        setState(() {});
                      }),
                      TextButton(onPressed: () {
                        value = 0;
                        setState(() {});
                      }, child: Text("Turn Off")),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () {
                      timer.cancel();
                      Navigator.of(context).pop(false);
                    }, child: Text("Cancel")),
                    TextButton(onPressed: () {
                      timer.cancel();
                      Navigator.of(context).pop(true);
                    }, child: Text("OK")),
                  ],
                );
              }
            ));

            if (result == true) {
              sleepTimer = value;
              setState(() {});
            }
          }, icon: Icon(Icons.bed)),
          IconButton(onPressed: () async {
            await reloadSettings();
            loading = true;
            provider?.refresh();
            setState(() {});
          }, icon: loading ? Container(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(),
          ) : Icon(Icons.refresh, size: iconSize)),
          if (settings != null)
          IconButton(onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsWidget(settings: settings!),
              ),
            );

            await reloadSettings();
          }, icon: Icon(Icons.settings, size: iconSize)),
        ],
      ),
      body: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (readings?.$1 != null)
            ReadingWidget(reading: readings!.$1!, settings: settings, size: 64),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (readings?.$2 != null)
                ReadingWidget(reading: readings!.$2!, settings: settings, size: 32),
                if ((settings?.showTimer ?? true) && provider?.time != null)
                Text("-${formatDuration(provider!.time)}", style: TextStyle(color: timerToColor(provider!.time), fontSize: 24)),
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
      width: size * 2.5,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("${reading.value}", style: TextStyle(fontSize: size, color: settings != null ? readingToColor(reading, settings!) : null)),
          if (reading.trend != DexcomTrend.none && reading.trend != DexcomTrend.nonComputable)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: trendToRotation(reading.trend) * pi / 180,
                child: Icon(Icons.arrow_upward, color: trendToColor(reading.trend), size: size),
              ),
              if (reading.trend == DexcomTrend.doubleUp || reading.trend == DexcomTrend.doubleDown)
              Transform.rotate(
                angle: trendToRotation(reading.trend) * pi / 180,
                child: Icon(Icons.arrow_upward, color: trendToColor(reading.trend), size: size),
              ),
            ],
          ),
        ],
      ),
    );
  }
}