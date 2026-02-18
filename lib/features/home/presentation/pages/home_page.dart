import 'package:flutter/material.dart';
import '../../../navigation/presentation/app_header.dart';
import 'dashboard/mangrove_dashboard.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021B1A),
      appBar: buildAppHeader('MangroveGuard'),
      body: SafeArea(
        bottom: false,
        child: MangroveDashboard(),
      ),
    );
  }
}
