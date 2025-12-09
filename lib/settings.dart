import 'package:flutter/material.dart';
import 'package:localpkg_flutter/localpkg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  final bool showTimer;
  final bool stayAwake;
  final Bounderies bounderies;
  final Autodim? autodim;
  final double? sleepTimer; // seconds

  const Settings({required this.autodim, required this.bounderies, required this.showTimer, required this.sleepTimer, required this.stayAwake});

  static Settings fromPrefs(SharedPreferences prefs) {
    return Settings(
      showTimer: prefs.getBool("showTimer") ?? true,
      stayAwake: prefs.getBool("stayAwake") ?? false,
      sleepTimer: prefs.getDouble("sleepTimer"),
      bounderies: Bounderies(
        high: prefs.getInt("high") ?? 180,
        low: prefs.getInt("low") ?? 70,
        superHigh: prefs.getInt("superHigh") ?? 240,
        superLow: prefs.getInt("superLow") ?? 55,
      ),
      autodim: (prefs.getBool("autodim") ?? false) ? Autodim(
        endValue: prefs.getDouble("autodimValue") ?? 0.75,
        delay: prefs.getDouble("autodimDelay") ?? 300,
      ) : null,
    );
  }
}

// mg/dL
class Bounderies {
  final int superLow;
  final int superHigh;
  final int low;
  final int high;

  const Bounderies({required this.high, required this.low, required this.superHigh, required this.superLow});
}

class Autodim {
  final double endValue; // 0 being darkest, 1 being brightest
  final double delay; // seconds

  const Autodim({required this.endValue, required this.delay});
}

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({super.key});

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        centerTitle: true,
        leading: IconButton(onPressed: () {
          context.navigator.pop();
        }, icon: Icon(Icons.arrow_back)),
      ),
      body: Column(
        children: [],
      ),
    );
  }
}