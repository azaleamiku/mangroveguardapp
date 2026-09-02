import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'views/onboarding_page.dart';
import 'views/main_nav_page.dart';

const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color bangladeshGreen = Color(0xFF03624C);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          primary: caribbeanGreen,
          onPrimary: richBlack,
          secondary: bangladeshGreen,
          onSecondary: antiFlashWhite,
          surface: darkGreen,
          onSurface: antiFlashWhite,
          error: Colors.redAccent,
          onError: antiFlashWhite,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: richBlack,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkGreen,
          foregroundColor: antiFlashWhite,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: darkGreen,
          selectedItemColor: caribbeanGreen,
          unselectedItemColor: antiFlashWhite,
        ),
      ),

      home: showHome ? const MainNavPage() : const OnboardingPage(),
    );
  }
}
