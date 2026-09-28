import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'views/onboarding_page.dart';
import 'views/main_nav_page.dart';

import 'package:mangroveguardapp/theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    if (details.silent) return;
    debugPrint('Unhandled Flutter error: ${details.exception}');
  };
  final prefs = await SharedPreferences.getInstance();
  final showHome = prefs.getBool('showHome') ?? false;

  runApp(MangroveGuardApp(showHome: showHome));
}

class MangroveGuardApp extends StatelessWidget {
  final bool showHome;
  const MangroveGuardApp({super.key, required this.showHome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.caribbeanGreen,
          onPrimary: AppColors.richBlack,
          secondary: AppColors.bangladeshGreen,
          onSecondary: AppColors.antiFlashWhite,
          surface: AppColors.darkGreen,
          onSurface: AppColors.antiFlashWhite,
          error: Colors.redAccent,
          onError: AppColors.antiFlashWhite,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.richBlack,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkGreen,
          foregroundColor: AppColors.antiFlashWhite,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkGreen,
          selectedItemColor: AppColors.caribbeanGreen,
          unselectedItemColor: AppColors.antiFlashWhite,
        ),
      ),

      home: showHome ? const MainNavPage() : const OnboardingPage(),
    );
  }
}
