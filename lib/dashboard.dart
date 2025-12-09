import 'package:flutter/material.dart';
import 'package:GlucoseStandby/main.dart';

class Dashboard extends StatefulWidget {
  final EnvironmentType type;
  const Dashboard({super.key, required this.type});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}