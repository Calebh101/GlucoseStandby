import 'package:GlucoseStandby/settings.dart';
import 'package:dexcom/dexcom.dart';
import 'package:flutter/material.dart';
import 'package:GlucoseStandby/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> reloadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    settings = Settings.fromPrefs(prefs);

    final String? username = prefs.getString("username");
    final String? password = prefs.getString("password");

    if (username != dexcom?.username || password != dexcom?.password) {
      dexcom = Dexcom(username: username, password: password);
      listen(dexcom!);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  void listen(Dexcom dexcom) {
    provider?.close();
    provider = DexcomStreamProvider(dexcom);

    provider!.listen(onData: (data) {
      readings = (data.elementAtOrNull(0), data.elementAtOrNull(1));
      reloadSettings();
    });
  }

  @override
  void dispose() {
    provider?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}