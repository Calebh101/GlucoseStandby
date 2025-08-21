import 'dart:io';

import 'package:GlucoseStandby/desktop/home.dart';
import 'package:dexcom/dexcom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:localpkg/logger.dart';

// I'm implementing the desktop version a long time after I built the original mobile version,
// so bear with me if the code is different haha

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

class DesktopApplication {
  static late SharedPreferences prefs;
  static const Size windowSize = Size(400, 500);

  static Menu getMenu([DexcomReading? reading]) {
    List<MenuItem> items = [
      if (reading != null)
      ...[
        MenuItem(
          key: 'live_reading',
          label: (() {
            int timeSince = DateTime.now().difference(reading.systemTime).inMinutes;

            return "${["${reading.value}", trendToString(reading.trend)].whereType<String>().join(" and ")} (-$timeSince Minute${timeSince == 1 ? "" : "s"})";
          })(),
          onClick: (item) async {
            await show();
          },
        ),
        MenuItem.separator(),
      ],
      MenuItem(
        key: 'show_window',
        label: 'Show Window',
        onClick: (item) async {
          await show();
        },
      ),
      MenuItem(
        key: 'show_window',
        label: 'Hide Window',
        onClick: (item) async {
          await hide();
        },
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'exit_app',
        label: 'Close',
        onClick: (item) async {
          await close();
        },
      ),
      MenuItem(
        key: 'restart_app',
        label: 'Restart',
        onClick: (item) async {
          await close(true);
        },
      ),
    ];

    Menu menu = Menu(
      items: items,
    );

    print("Updating menu of ${menu.items?.length} items...");
    return menu;
  }

  static Future<void> run() async {
    prefs = await SharedPreferences.getInstance();
    WidgetsFlutterBinding.ensureInitialized();

    await windowManager.ensureInitialized();
    await trayManager.setIcon(Environment.isWindows ? 'assets/app/icon/splash.ico' : 'assets/app/icon/splash.png');
    await trayManager.setContextMenu(getMenu());

    print("Running desktop app...");
    await show();
    runApp(const DesktopApp());
  }

  static Future<void> show() async {
    WindowOptions options = WindowOptions(
      title: "Glucose Standby",
      size: windowSize,
    );

    await windowManager.setPreventClose(true);
    await windowManager.setMinimizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setClosable(false);

    await windowManager.waitUntilReadyToShow(options);
    print("Showing window... (size: ${await windowManager.getSize()})");
  
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> hide() async {
    await windowManager.hide();
  }

  static Future<void> close([bool restart = false]) async {
    print("Closing app... (restart: $restart)");
    await windowManager.destroy();

    if (restart) {
      print("Restarting...");
      await Restart.restartApp();
      print("Restarted!");
    } else {
      print("Closing...");
      exit(0);
      print("Closed!");
    }
  }

  static Future<void> update([DexcomReading? reading]) async {
    if (reading != null) if (DateTime.now().difference(reading.systemTime) > Duration(minutes: 10)) reading = null;
    await trayManager.setContextMenu(getMenu(reading));
  }
}

class DesktopApp extends StatefulWidget {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> with TrayListener {
  @override
  void initState() {
    trayManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(
        useMaterial3: true,
      ),
      home: Home(),
    );
  }
}