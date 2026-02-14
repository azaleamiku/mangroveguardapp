import 'package:flutter/material.dart';
import 'dashboard/mangrove_dashboard.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021B1A),
      appBar: AppBar(
        title: const Text(
          'MangroveGuard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF032221),
        elevation: 0,
      ),
      body: SafeArea(
        child: MangroveDashboard(),
      ),
    );
  }
}
