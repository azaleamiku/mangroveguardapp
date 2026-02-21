
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../home/presentation/pages/home_page.dart';
import '../../home/presentation/pages/scanner_page.dart';
import 'recent_scan_page.dart';
import 'info_page.dart';
import 'metrics_page.dart';

class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key});

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  static const Color caribbeanGreen = Color(0xFF00DF81);
  static const Color antiFlashWhite = Color(0xFFF1F7F6);
  static const Color bangladeshGreen = Color(0xFF03624C);
  static const Color darkGreen = Color(0xFF032221);

  int _selectedIndex = 0;

  // Pages to switch between
  final List<Widget> _pages = [
    const HomePage(),
    const MetricsPage(),
    const ScannerPage(), // Your AR & YOLO camera view
    const RecentScanPage(),
    const InfoPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // IndexedStack prevents the AR camera from "restarting" every time you switch tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      // Glassmorphic Floating Dock Navigation Bar
      bottomNavigationBar: SizedBox(
        height: 112,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    height: 85,
                    decoration: BoxDecoration(
                      color: darkGreen.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(
                        color: bangladeshGreen.withValues(alpha: 0.85),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavItem(
                          icon: Icons.dashboard_rounded,
                          isSelected: _selectedIndex == 0,
                          selectedColor: caribbeanGreen,
                          unselectedColor: antiFlashWhite.withValues(alpha: 0.58),
                          onTap: () => setState(() => _selectedIndex = 0),
                        ),
                        _NavItem(
                          icon: Icons.analytics_rounded,
                          isSelected: _selectedIndex == 1,
                          selectedColor: caribbeanGreen,
                          unselectedColor: antiFlashWhite.withValues(alpha: 0.58),
                          onTap: () => setState(() => _selectedIndex = 1),
                        ),
                        const SizedBox(width: 70),
                        _NavItem(
                          icon: Icons.auto_stories_rounded,
                          isSelected: _selectedIndex == 3,
                          selectedColor: caribbeanGreen,
                          unselectedColor: antiFlashWhite.withValues(alpha: 0.58),
                          onTap: () => setState(() => _selectedIndex = 3),
                        ),
                        _NavItem(
                          icon: Icons.info_rounded,
                          isSelected: _selectedIndex == 4,
                          selectedColor: caribbeanGreen,
                          unselectedColor: antiFlashWhite.withValues(alpha: 0.58),
                          onTap: () => setState(() => _selectedIndex = 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: _ScannerFab(
                isSelected: _selectedIndex == 2,
                selectedColor: caribbeanGreen,
                baseColor: bangladeshGreen,
                iconColor: antiFlashWhite,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerFab extends StatelessWidget {
  final bool isSelected;
  final Color selectedColor;
  final Color baseColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ScannerFab({
    required this.isSelected,
    required this.selectedColor,
    required this.baseColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: isSelected ? 78 : 74,
        height: isSelected ? 78 : 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [selectedColor, selectedColor.withValues(alpha: 0.7)]
                : [baseColor.withValues(alpha: 0.95), baseColor],
          ),
          border: Border.all(
            color: iconColor.withValues(alpha: isSelected ? 0.4 : 0.22),
            width: isSelected ? 2.2 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: selectedColor.withValues(alpha: isSelected ? 0.35 : 0.2),
              blurRadius: isSelected ? 24 : 14,
              spreadRadius: isSelected ? 2 : 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.14),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.center_focus_strong_rounded,
              color: iconColor,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Navigation Item Widget
class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 26,
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
