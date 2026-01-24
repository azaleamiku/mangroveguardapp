import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:flutter/material.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool _isARInitialized = false;

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
          // AR View
          ARView(
            onARViewCreated: (
              ARSessionManager arSessionManager,
              ARObjectManager arObjectManager,
              ARAnchorManager arAnchorManager,
              ARLocationManager arLocationManager,
            ) {
              setState(() {
                _isARInitialized = true;
              });
            },
          ),
          
          // Loading indicator while AR initializes
          if (!_isARInitialized)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          
          // Status text
          const Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Point camera at mangrove to scan',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
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
          backgroundColor: Colors.white.withValues(alpha: 0.3),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
