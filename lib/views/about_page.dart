import 'package:flutter/material.dart';
import 'package:mangroveguardapp/theme/colors.dart';
import 'package:mangroveguardapp/widgets/app_header.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.richBlack,
      appBar: buildAppHeader('About'),
      body: const SizedBox.shrink(),
    );
  }
}
