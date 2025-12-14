import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:GlucoseStandby/recursive_caster.g.dart';
import 'package:GlucoseStandby/settings.dart';
import 'package:GlucoseStandby/util.dart';
import 'package:dexcom/dexcom.dart';
import 'package:flutter/foundation.dart';
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
const int maxSleepTimer = 12; // hours
const int maxFakeSleep = 12; // hours

final Color sliderActiveColor = Colors.redAccent;
final Color sliderInactiveColor = Colors.redAccent.shade100.withValues(alpha: 0.5);

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
  int inactive = 0;
  bool isOld = true;
  double dim = 0;

  Timer? timer;
  Timer? periodicTimer;

  // 0: Not loading
  // 1: Fetching account ID
  // 2: Fetching session ID
  // 3: Fetching glucose
  int loading = 0;

  Future<void> reloadSettings([bool firstTime = false]) async {
    Logger.print("Reloading settings...");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    settings = Settings.fromPrefs(prefs);

    String? username = prefs.getString("username");
    String? password = prefs.getString("password");

    if (firstTime || (username != dexcom?.username || password != dexcom?.password) && username != null && password != null) {
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

  void resetOrientation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      setState(() {});
    });
  }

  @override
  void initState() {
    resetOrientation();
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await reloadSettings(true);
      initWakelock();

      if (settings!.defaultToWakelockOn) {
        setWakelock(true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? pref = prefs.getString("lastReading");
      if (pref == null) return;

      try {
        Map<String, dynamic> output = RecursiveCaster.cast(jsonDecode(pref));
        DexcomReading reading = DexcomReading.fromJson(output);
        readings = (reading, readings?.$2);
        setState(() {});
      } catch (e) {
        Logger.warn("Unrecoverable error with last reading preference: $e\n\nOutput: $pref");
        await prefs.remove("lastReading");
      }
    });

    if (widget.type == EnvironmentType.desktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        timer = Timer.periodic(Duration(seconds: 30), (timer) {
          DesktopApplication.update(readings?.$1);
        });
      });
    }

    periodicTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (sleepTimer > 0) {
        sleepTimer--;
        if (sleepTimer == 0) onSleep();
      }

      inactive++;
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
      if (widget.type == EnvironmentType.desktop) await DesktopApplication.update(readings?.$1);
      loading = 0;
      isOld = false;
      setState(() {});

      if (readings?.$1 == null) return;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Logger.print("Saving last reading...");
      await prefs.setString("lastReading", jsonEncode(readings!.$1!.toJson()));
    }, onRefresh: () {
      Logger.print("Refreshing...");
      loading = 3;
      setState(() {});
    }, onTimerChange: (time) {
      setState(() {});
    }, onError: (e) {
      Logger.warn("Dexcom stream error: $e");

      if (loading == 1) {
        loading = 0;
        setState(() {});
        SnackBarManager.show(context, "Unable to log in to your Dexcom account.");
      }
    });

    provider!.refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    periodicTimer?.cancel();

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

  void rotate() {
    bool portrait = MediaQuery.of(context).orientation == Orientation.portrait;
    Logger.print("Rotating screen... (currently portrait: $portrait)");

    if (portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      resetOrientation();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      resetOrientation();
    }

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
                    if (kDebugMode && provider != null)
                    Tooltip(
                      message: "Pause/unpause the listener (debug option)",
                      child: IconButton(onPressed: () {
                        if (provider!.paused) {
                          provider!.unpause();
                        } else {
                          provider!.pause();
                        }

                        setState(() {});
                      }, icon: Icon(provider!.paused ? Icons.play_arrow : Icons.pause)),
                    ),
                    Tooltip(
                      message: "Dim",
                      child: IconButton(onPressed: () async {
                        final child = StatefulBuilder(
                          builder: (context, setState) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: context.screenSize.width * 0.9),
                              Slider(value: (1 - dim) * 100, min: 0, max: 100, onChanged: (value) {
                                dim = 1 - (value / 100);
                                setState(() {});
                              }, activeColor: sliderActiveColor, inactiveColor: sliderInactiveColor),
                              SizedBox(
                                height: 80,
                                child: dim > 0.9 ? Center(child: Text("Warning! Setting your brightness to this could make the screen unseeable!")) : null,
                              ),
                            ],
                          ),
                        );

                        SimpleDialogue.show(context: context, title: "Brightness", content: child);
                      }, icon: Icon(Icons.sunny)),
                    ),
                    Tooltip(
                      message: "Sleep timer",
                      child: IconButton(onPressed: () async {
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
                                  SizedBox(width: context.screenSize.width * 0.9),
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
                                  Slider(value: value.clamp(60, maxSleepTimer * 60 * 60).toDouble(), min: 60, max: maxSleepTimer * 60 * 60, divisions: 1439, onChanged: (x) {
                                    value = x.toInt();
                                    setState(() {});
                                  }, activeColor: sliderActiveColor, inactiveColor: sliderInactiveColor),
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
                    ),
                    if (settings != null)
                    Tooltip(
                      message: "Settings",
                      child: IconButton(onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsWidget(settings: settings!),
                          ),
                        );

                        await reloadSettings();
                      }, icon: Icon(Icons.settings, size: iconSize)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (settings != null)
          Builder(
            builder: (context) {
              double maxLoading = 3;
              double sizeMultiplier = mapRange(context.screenSize.width.clamp(100, 2000), inMin: 100, inMax: 2000, outMin: 0.5, outMax: 4);

              return SafeArea(
                child: Align(
                  alignment: switch (settings!.alignment) {
                    DashboardAlignment.center => Alignment.center,
                    DashboardAlignment.left => Alignment.centerLeft,
                    DashboardAlignment.right => Alignment.centerRight,
                  },
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
                          if (!isOld)
                          Text("-${formatDuration(provider!.time)}", style: TextStyle(color: timerToColor(provider!.time), fontSize: 24 * sizeMultiplier))
                          else
                          Text("Old", style: TextStyle(color: Colors.red, fontSize: 24 * sizeMultiplier)),
                        ],
                      ),
                      SizedBox(width: 8 * sizeMultiplier),
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
                          if (widget.type == EnvironmentType.mobile)
                          Tooltip(
                            message: "Rotate the screen",
                            child: IconButton(onPressed: () => rotate(), icon: Icon(Icons.rotate_90_degrees_cw)),
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
                      SizedBox(width: 8 * sizeMultiplier),
                    ],
                  ),
                ),
              );
            }
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: (settings?.fakeSleep != null && inactive > settings!.fakeSleep!) ? 1 : dim,
                duration: Duration(milliseconds: 300),
                child: Container(
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                Logger.print("Screen tapped");
                inactive = 0;
                setState(() {});
              },
            ),
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