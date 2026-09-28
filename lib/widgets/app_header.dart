import 'package:flutter/material.dart';
import 'package:mangroveguardapp/theme/colors.dart';

PreferredSizeWidget buildAppHeader(String title) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
    ),
    centerTitle: true,
    elevation: 0,
    backgroundColor: AppColors.darkGreen,
    foregroundColor: AppColors.antiFlashWhite,
  );
}
