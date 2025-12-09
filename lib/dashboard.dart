import 'package:dexcom/dexcom.dart';
import 'package:flutter/material.dart';
import 'package:GlucoseStandby/main.dart';

class Dashboard extends StatefulWidget {
  final EnvironmentType type;
  const Dashboard({super.key, required this.type});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late Dexcom dexcom;
  late DexcomStreamProvider provider;
  (DexcomReading?, DexcomReading?)? readings; // Latest, next latest

  Future<void> reloadSettings() async {}

  @override
  void initState() {
    dexcom = Dexcom();
    provider = DexcomStreamProvider(dexcom);

    provider.listen(onData: (data) {
      readings = (data.elementAtOrNull(0), data.elementAtOrNull(1));
      reloadSettings();
    });

    super.initState();
  }

  @override
  void dispose() {
    provider.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}