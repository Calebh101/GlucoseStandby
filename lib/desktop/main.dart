import 'dart:io';

import 'package:GlucoseStandby/desktop/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:localpkg/logger.dart';

// I'm implementing the desktop version a long time after I built the original mobile version,
// so bear with me if the code is different haha

class DesktopApplication {
  static late SharedPreferences prefs;
  static const Size windowSize = Size(400, 400);

  static Future<void> run() async {
    prefs = await SharedPreferences.getInstance();
    WidgetsFlutterBinding.ensureInitialized();

    List<MenuItem> items = [
      MenuItem(
        key: 'show_window',
        label: 'Show Window',
        onClick: (item) async {
          show();
        },
      ),
      MenuItem(
        key: 'show_window',
        label: 'Hide Window',
        onClick: (item) async {
          hide();
        },
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'exit_app',
        label: 'Exit App',
        onClick: (item) {
          close();
        },
      ),
    ];

    Menu menu = Menu(
      items: items,
    );

    await windowManager.ensureInitialized();
    await trayManager.setIcon(Environment.isWindows ? 'assets/app/icon/splash.ico' : 'assets/app/icon/splash.png');
    await trayManager.setContextMenu(menu);

    print("Running desktop app...");
    await show();
    runApp(const DesktopApp());
  }

  static Future<void> show() async {
    WindowOptions options = WindowOptions(
      title: "Glucose Standby",
      size: windowSize,
      center: true,
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

  static Future<void> close() async {
    await windowManager.destroy();
    exit(0);
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