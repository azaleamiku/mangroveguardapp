import 'package:flutter/material.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Typical background for camera views
      body: Stack(
        children: [
          const Center(
            child: Text(
              "ARCore Camera Feed Placeholder",
              style: TextStyle(color: Colors.white),
            ),
          ),
          
          // Floating Action Bar for Field Tools
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _scannerAction(Icons.straighten, "Measure DBH"),
                  _scannerAction(Icons.psychology, "Root Count"),
                  _scannerAction(Icons.save, "Log Data"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scannerAction(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }
}