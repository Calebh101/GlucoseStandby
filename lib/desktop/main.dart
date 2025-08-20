import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:localpkg/logger.dart';

// I'm implementing the desktop version a long time after I built the original mobile version,
// so bear with me if the code is different haha

Future<void> run() async {
  WidgetsFlutterBinding.ensureInitialized();
  const Size windowSize = Size(400, 400);

  Future<void> show() async {
    await windowManager.ensureInitialized();
    await windowManager.setTitle("Glucose Standby");
    await windowManager.setSize(windowSize);

    await windowManager.setPreventClose(true);
    await windowManager.setMinimizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setResizable(false);
    await windowManager.setClosable(false);

    await windowManager.show();
    await windowManager.focus();
  }

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
        await windowManager.hide();
      },
    ),
    MenuItem.separator(),
    MenuItem(
      key: 'exit_app',
      label: 'Exit App',
      onClick: (item) {
        windowManager.destroy();
        exit(0);
      },
    ),
  ];

  Menu menu = Menu(
    items: items,
  );

  await windowManager.ensureInitialized();
  await trayManager.setIcon(Environment.isWindows ? 'assets/app/icon/splash.ico' : 'assets/app/icon/splash.png');
  await trayManager.setContextMenu(menu);
  
  await windowManager.waitUntilReadyToShow();
  await show();

  print("Running desktop app...");
  runApp(const DesktopApp());
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
    return const Placeholder();
  }
}