import 'package:flutter/material.dart';

import 'app_header.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const Color caribbeanGreen = Color(0xFF00DF81);
  static const Color antiFlashWhite = Color(0xFFF1F7F6);
  static const Color bangladeshGreen = Color(0xFF03624C);
  static const Color darkGreen = Color(0xFF032221);
  static const Color richBlack = Color(0xFF021B1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: richBlack,
      appBar: buildAppHeader('About'),
      body: const SizedBox.shrink(),
    );
  }
}
