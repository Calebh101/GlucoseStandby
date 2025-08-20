import 'package:GlucoseStandby/mobile/home.dart';
import 'package:GlucoseStandby/mobile/var.dart';
import 'package:flutter/material.dart';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Glucose Standby',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: defaultFont,
      ),
      home: Home(),
    );
  }
}