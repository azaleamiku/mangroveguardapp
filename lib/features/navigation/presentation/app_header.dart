import 'package:flutter/material.dart';

const Color appHeaderBackground = Color(0xFF032221);
const Color appHeaderForeground = Color(0xFFF1F7F6);

PreferredSizeWidget buildAppHeader(String title) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
    centerTitle: true,
    elevation: 0,
    backgroundColor: appHeaderBackground,
    foregroundColor: appHeaderForeground,
  );
}
