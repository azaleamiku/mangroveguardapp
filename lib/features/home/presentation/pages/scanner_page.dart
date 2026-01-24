import 'package:flutter/material.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Placeholder for the AR/AI Camera Feed
          Container(color: Colors.black),
          
          const Center(
            child: Text(
              'Initializing ARCore & YOLOv10...',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          
          // Bottom Scanning Controls
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScannerButton(Icons.straighten, "Measure DBH"),
                _buildScannerButton(Icons.psychology, "Count Roots"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerButton(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white.withOpacity(0.3),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}