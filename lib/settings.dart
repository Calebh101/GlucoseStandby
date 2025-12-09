import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  final bool showTimer;
  final Bounderies bounderies;
  final Autodim? autodim;
  final bool stayAwake;
  final double? sleepTimer;

  const Settings({required this.autodim, required this.bounderies, required this.showTimer, required this.sleepTimer, required this.stayAwake});

  static Settings fromPrefs(SharedPreferences prefs) {
    return Settings(
      showTimer: prefs.getBool("showTimer") ?? true,
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
      sleepTimer: prefs.getDouble("sleepTimer"),
      stayAwake: prefs.getBool("stayAwake") ?? false,
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