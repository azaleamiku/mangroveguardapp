import 'package:flutter/material.dart';
import 'features/home/presentation/pages/home_page.dart';

void main() {
  runApp(const MangroveGuardApp());
}

class MangroveGuardApp extends StatelessWidget {
  const MangroveGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MangroveGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Using a "Mangrove Forest" color palette
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D5A27), // Forest Green
          primary: const Color(0xFF2D5A27),
          secondary: const Color(0xFF8BAB3E), // Leaf Green
        ),
        // Custom font (Axiforma or similar)
        fontFamily: 'Axiforma', 
      ),
      home: const HomePage(),
    );
  }
}