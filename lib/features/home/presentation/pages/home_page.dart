import 'package:flutter/material.dart';

// Import the color constants
const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color bangladeshGreen = Color(0xFF03624C);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MangroveGuard Dashboard"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: antiFlashWhite,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatCard("Total Trees Assessed", "124", Icons.park),
            const SizedBox(height: 20),
            _buildStatCard("Average Stability Score", "8.2/10", Icons.assessment),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [darkGreen.withOpacity(0.8), bangladeshGreen.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: caribbeanGreen.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: caribbeanGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: caribbeanGreen.withOpacity(0.2),
              boxShadow: [
                BoxShadow(
                  color: caribbeanGreen.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: caribbeanGreen, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: antiFlashWhite.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: caribbeanGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
