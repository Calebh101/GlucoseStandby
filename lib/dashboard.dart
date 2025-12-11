import 'dart:async';
import 'dart:math';

import 'package:GlucoseStandby/settings.dart';
import 'package:GlucoseStandby/util.dart';
import 'package:dexcom/dexcom.dart';
import 'package:flutter/material.dart';
import 'package:GlucoseStandby/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart' hide EnvironmentType;
import 'package:intl/intl.dart';
import 'package:localpkg_flutter/localpkg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:universal_html/html.dart' as html;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

const bool dexcomDebug = false;

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
  bool? wakelockEnabled = false;
  bool isFullscreen = false;
  int sleepTimer = 0;

  // 0: Not loading
  // 1: Fetching account ID
  // 2: Fetching session ID
  // 3: Fetching glucose
  int loading = 0;

  Timer? timer;
  Timer? sleepTimerTimer;

  Future<void> reloadSettings() async {
    Logger.print("Reloading settings...");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    settings = Settings.fromPrefs(prefs);

    String? username = prefs.getString("username");
    String? password = prefs.getString("password");

    if ((username != dexcom?.username || password != dexcom?.password) && username != null && password != null) {
      dexcom = Dexcom(username: username, password: password, debug: dexcomDebug, onStatusUpdate: (status, finished) {
        Logger.print("Status update: $status (finished: $finished)");

        switch (status) {
          case DexcomUpdateStatus.fetchingAccountId:
            if (!finished) loading = 1;
            setState(() {});
            break;
          case DexcomUpdateStatus.fetchingSessionId:
            if (!finished) loading = 2;
            setState(() {});
            break;
          case DexcomUpdateStatus.fetchingGlucose:
            if (!finished) loading = 3;
            setState(() {});
            break;
          default:
            break;
        }
      });

      listen(dexcom!);
    }

    Logger.print("Finished reloading settings");
    setState(() {});
  }

  Future<void> initWakelock() async {
    try {
      Logger.print("Initializing wakelock...");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      wakelockEnabled = await WakelockPlus.enabled;
      await setWakelock(prefs.getBool("wakelock") ?? wakelockEnabled!);
      setState(() {});
    } catch (e) {
      wakelockEnabled = null;
      SnackBarManager.show(context, "Unable to use wakelock.");
      setState(() {});
    }
  }

  Future<void> setWakelock(bool value) async {
    try {
      wakelockEnabled = value;
      await WakelockPlus.toggle(enable: value);
      setState(() {});
    } catch (e) {
      wakelockEnabled = null;
      SnackBarManager.show(context, "Unable to use wakelock.");
      setState(() {});
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("wakelock", value);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      reloadSettings();
      initWakelock();
    });

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
    setWakelock(false);
  }

  void listen(Dexcom dexcom) {
    Logger.print("Starting listener...");
    provider?.close();
    provider = DexcomStreamProvider(dexcom, debug: dexcomDebug);

    provider!.listen(onData: (data) async {
      readings = (data.elementAtOrNull(0), data.elementAtOrNull(1));
      await reloadSettings();
      await DesktopApplication.update(readings?.$1);
      loading = 0;
      setState(() {});
    }, onRefresh: () {
      Logger.print("Refreshing...");
      loading = 3;
      setState(() {});
    }, onTimerChange: (time) {
      setState(() {});
    });

    provider!.refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    sleepTimerTimer?.cancel();

    provider?.close();
    super.dispose();
  }

  Future<void> setFullscreen(bool input) async {
    if (Environment.isWeb) {
      if (input) {
        html.document.documentElement?.requestFullscreen();
      } else {
        html.document.exitFullscreen();
      }
    } else {
      if (Environment.isMobile) {
        if (input) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
        }
      } else if (Environment.isDesktop) {
        await DesktopApplication.setFullScreen(input);
      }
    }

    isFullscreen = input;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = 24;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                if (wakelockEnabled == false)
                                Text("Note: The sleep timer won't do anything because wakelock is already disabled."),
                                if (wakelockEnabled == null)
                                Text("Note: Wakelock is currently not functional, so the sleep timer will have no effect."),
                                Slider(value: value.clamp(60, 24 * 60 * 60).toDouble(), min: 60, max: 24 * 60 * 60, divisions: 1439, onChanged: (x) {
                                  value = x.toInt();
                                  setState(() {});
                                }),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(onPressed: () {
                                      value = 0;
                                      setState(() {});
                                    }, child: Text("Turn Off")),
                                  ],
                                ),
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
              ),
            ),
          ),
          Builder(
            builder: (context) {
              double maxLoading = 3;
              double sizeMultiplier = mapRange(context.screenSize.width.clamp(100, 2000), inMin: 100, inMax: 2000, outMin: 0.5, outMax: 4);

              return Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (readings?.$1 != null)
                    ReadingWidget(reading: readings!.$1!, settings: settings, size: 64 * sizeMultiplier),
                    SizedBox(width: 8 * sizeMultiplier),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (readings?.$2 != null)
                        ReadingWidget(reading: readings!.$2!, settings: settings, size: 32 * sizeMultiplier),
                        if ((settings?.showTimer ?? true) && readings != null && provider?.time != null)
                        Text("-${formatDuration(provider!.time)}", style: TextStyle(color: timerToColor(provider!.time), fontSize: 24 * sizeMultiplier)),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (loading > 0 && loading < maxLoading)
                        Container(
                          width: iconSize,
                          height: 4,
                          child: LinearProgressIndicator(
                            value: loading / maxLoading,
                          ),
                        ),
                        Tooltip(
                          message: loading > 0 ? "Refreshing" : "Refresh",
                          child: IconButton(onPressed: () async {
                            loading = 3;
                            setState(() {});
                            await reloadSettings();
                            provider?.refresh();
                            setState(() {});
                          }, icon: loading > 0 ? Container(
                            width: iconSize,
                            height: iconSize,
                            child: CircularProgressIndicator(),
                          ) : Icon(Icons.refresh, size: iconSize)),
                        ),
                        if (wakelockEnabled != null)
                        Tooltip(
                          message: "Wakelock ${wakelockEnabled! ? "Enabled" : "Disabled"}",
                          child: IconButton(onPressed: () async {
                            await setWakelock(!wakelockEnabled!);
                            wakelockEnabled = await WakelockPlus.enabled;
                          }, icon: Icon(wakelockEnabled! ? Icons.lock_outline : Icons.lock_open)),
                        ),
                        Tooltip(
                          message: "Toggle Fullscreen",
                          child: IconButton(onPressed: () async {
                            await setFullscreen(!isFullscreen);
                            if (Environment.isDesktop) isFullscreen = await windowManager.isFullScreen();
                          }, icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
          ),
        ],
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