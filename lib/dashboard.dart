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
  bool loading = true;

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

    provider!.listen(onData: (data) async {
      readings = (data.elementAtOrNull(0), data.elementAtOrNull(1));
      await reloadSettings();
      loading = false;
      setState(() {});
    }, onRefresh: () {
      loading = true;
      setState(() {});
    });
  }

  @override
  void dispose() {
    provider?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = 24;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: loading ? Container(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(),
          ) : Icon(Icons.refresh, size: iconSize)),
          IconButton(onPressed: () {}, icon: Icon(Icons.settings, size: iconSize)),
        ],
      ),
      body: Center(
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [],
            ),
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}