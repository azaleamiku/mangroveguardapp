import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MangroveGuard Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatCard("Total Trees Assessed", "124", Icons.park),
            const SizedBox(height: 15),
            _buildStatCard("Average Stability Score", "8.2/10", Icons.assessment),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2D5A27), size: 40),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        trailing: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}