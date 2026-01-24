import 'package:flutter/material.dart';
import '../../home/presentation/pages/home_page.dart';
import '../../home/presentation/pages/scanner_page.dart';

class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key});

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  int _selectedIndex = 0;

  // Pages to switch between
  final List<Widget> _pages = [
    const HomePage(),
    const ScannerPage(), // Your AR & YOLO camera view
    const Center(child: Text('History Page')),
    const Center(child: Text('Settings')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack prevents the AR camera from "restarting" every time you switch tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2D5A27),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true, // Recommended for clear navigation
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.center_focus_strong), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}