import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/navigation/presentation/main_nav_page.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D5A27)),
        useMaterial3: true,
      ),
      // If showHome is true, go straight to the app; else, show onboarding
      home: showHome ? const MainNavPage() : const OnboardingPage(),
    );
  }
}