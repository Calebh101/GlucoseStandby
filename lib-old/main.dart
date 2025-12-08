import 'dart:core';

import 'package:localpkg/logger.dart';
import 'desktop/main.dart';
import 'mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';

void main(List<String> arguments) async {
  if (arguments.contains("--mobile") || Environment.isMobile || Environment.isWeb) {
    print("Running mobile app...");
    runApp(const MobileApp());
  } else if (Environment.isDesktop) {
    DesktopApplication.run(arguments.contains("--service"));
  }
}
