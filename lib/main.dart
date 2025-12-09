import 'dart:io';

import 'package:GlucoseStandby/dashboard.dart';
import 'package:GlucoseStandby/util.dart';
import 'package:dexcom/dexcom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styled_logger/styled_logger.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

const String version = "0.0.1A";
const bool beta = true;
const String defaultFont = "Arial";

void main(List<String> arguments) {
  if (Environment.isDesktop) {
    DesktopApplication.run(arguments.contains("--service"));
  } else {
    runApp(Dashboard(type: Environment.isWeb ? EnvironmentType.web : EnvironmentType.mobile));
  }
}

enum EnvironmentType {
  desktop,
  mobile,
  web,
}

class DesktopApplication {
  static late SharedPreferences prefs;
  static const Size windowSize = Size(400, 500);
  static bool _ranYet = false;

  static Menu getMenu([DexcomReading? reading]) {
    List<MenuItem> items = [
      if (reading != null)
      ...[
        MenuItem(
          key: 'live_reading',
          label: (() {
            int timeSince = DateTime.now().difference(reading.systemTime).inMinutes;
            bool useLongTime = false;

            return "${["${reading.value}", trendToString(reading.trend)].whereType<String>().join(" and ")} (-$timeSince${useLongTime ? " Minute${timeSince == 1 ? "" : "s"}" : "m"})";
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

    Logger.print("Updating menu of ${menu.items?.length} items...");
    return menu;
  }

  static Future<void> run(bool service) async {
    WidgetsFlutterBinding.ensureInitialized();
    prefs = await SharedPreferences.getInstance();

    await trayManager.setIcon(Environment.isWindows ? 'assets/app/icon/splash.ico' : 'assets/app/icon/splash.png');
    await trayManager.setContextMenu(getMenu());

    Logger.print("Running desktop app...");
    await show();
    if (service) await hide();
  }

  static Future<void> show() async {
    WindowOptions options = WindowOptions(
      title: "Glucose Standby",
      size: windowSize,
    );

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await windowManager.setMinimizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setClosable(false);
    await windowManager.waitUntilReadyToShow(options);

    Logger.print("Showing window... (size: ${await windowManager.getSize()})");

    await windowManager.show();
    await windowManager.focus();

    if (!_ranYet) {
      Logger.print("Running application...");
      runApp(Dashboard(type: EnvironmentType.desktop));
    }

    _ranYet = true;
    Logger.print("Finished calling show");
  }

  static Future<void> hide() async {
    await windowManager.hide();
  }

  static Future<void> close([bool restart = false]) async {
    Logger.print("Closing app... (restart: $restart)");
    await windowManager.destroy();

    if (restart) {
      Logger.print("Restarting...");
      await Restart.restartApp();
      Logger.print("Restarted!");
    } else {
      Logger.print("Closing...");
      exit(0);
      Logger.print("Closed!");
    }
  }

  static Future<void> update([DexcomReading? reading]) async {
    if (reading != null) if (DateTime.now().difference(reading.systemTime) > Duration(minutes: 10)) reading = null;
    await trayManager.setContextMenu(getMenu(reading));
  }
}