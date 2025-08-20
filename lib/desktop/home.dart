import 'dart:math';

import 'package:GlucoseStandby/desktop/account.dart';
import 'package:GlucoseStandby/desktop/main.dart';
import 'package:dexcom/dexcom.dart';
import 'package:flutter/material.dart';
import 'package:localpkg/logger.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late Dexcom dexcom;
  late DexcomStreamProvider provider;

  List<DexcomReading> readings = []; // 0: newest
  String? error;

  void refresh() {
    setState(() {});
  }

  @override
  void initState() {
    print("Initializing...");
    dexcom = Dexcom(username: DesktopApplication.prefs.getString("username"), password: DesktopApplication.prefs.getString("password"));
    provider = DexcomStreamProvider(dexcom);    
    super.initState();

    provider.listen(
      cancelOnError: true,
      onData: (data) {
        if (data.isNotEmpty) {
          readings = data.sublist(0, min(6, data.length) + 1);
          refresh();
        }
      },
      onError: (e) {
        warn("Dexcom error: $e");
        error = e.toString();
        refresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage(showBack: true)),
            );
          }, icon: Icon(Icons.account_box_outlined)),
          IconButton(onPressed: () {
            DesktopApplication.hide();
          }, icon: Icon(Icons.remove)),
        ],
      ),
      backgroundColor: Colors.black,
      body: error != null || readings.isEmpty ? Center(child: Text(error ?? "Loading...", style: TextStyle(fontSize: 26))) : Column(
        children: [
          Text(readings.toString()),
        ],
      ),
    );
  }
}
