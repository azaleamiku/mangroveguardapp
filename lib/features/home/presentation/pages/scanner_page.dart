import 'package:flutter/material.dart';

// Color constants
const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color bangladeshGreen = Color(0xFF03624C);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool isLoading = true;
  bool isMeasuringDBH = false;
  double? measuredDBH;
  List<String> measurementHistory = [];

  @override
  void initState() {
    super.initState();
    // Simulate AR initialization
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: richBlack,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: caribbeanGreen),
              SizedBox(height: 20),
              Text(
                "Initializing AR...",
                style: TextStyle(color: antiFlashWhite, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: richBlack,
      body: Stack(
        children: [
          // AR Camera Placeholder
          Container(
            color: Colors.black,
            child: const Center(
              child: Text(
                "AR Camera Feed\n(ARCore Integration Ready)",
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Overlay UI
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: darkGreen.withOpacity(0.8),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: caribbeanGreen.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    isMeasuringDBH
                        ? "Measuring DBH... Align tree trunk in center"
                        : "Point camera at mangrove tree to analyze health",
                    style: const TextStyle(color: antiFlashWhite, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  if (measuredDBH != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: caribbeanGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: caribbeanGreen),
                      ),
                      child: Text(
                        "DBH: ${measuredDBH!.toStringAsFixed(1)} cm",
                        style: const TextStyle(
                          color: caribbeanGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Measurement Guide Overlay
          if (isMeasuringDBH)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: darkGreen.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: caribbeanGreen, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.center_focus_strong,
                          color: caribbeanGreen,
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "DBH Measurement Guide",
                          style: TextStyle(
                            color: antiFlashWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "1. Position camera 1.3m from ground\n2. Center tree trunk in crosshair\n3. Ensure trunk is vertical\n4. Tap measure when ready",
                          style: TextStyle(color: antiFlashWhite, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: _performDBHMeasurement,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: caribbeanGreen,
                                foregroundColor: richBlack,
                              ),
                              child: const Text("Measure"),
                            ),
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: () => setState(() => isMeasuringDBH = false),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: antiFlashWhite),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
                color: darkGreen.withOpacity(0.9),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: caribbeanGreen.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: caribbeanGreen.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _scannerAction(Icons.straighten, "Measure DBH", _measureDBH),
                  _scannerAction(Icons.psychology, "Analyze Health", _analyzeHealth),
                  _scannerAction(Icons.save, "Log Data", _logData),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _measureDBH() {
    setState(() {
      isMeasuringDBH = true;
    });
  }

  void _performDBHMeasurement() {
    // Simulate DBH measurement (in real implementation, this would use ARCore and ML)
    // Generate a realistic DBH value between 5-50 cm for mangrove trees
    final randomDBH = 5.0 + (45.0 * (DateTime.now().millisecondsSinceEpoch % 100) / 100.0);

    setState(() {
      measuredDBH = randomDBH;
      isMeasuringDBH = false;
      measurementHistory.add("DBH: ${randomDBH.toStringAsFixed(1)} cm - ${DateTime.now().toString().substring(0, 19)}");
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("DBH measured: ${randomDBH.toStringAsFixed(1)} cm"),
        backgroundColor: caribbeanGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _analyzeHealth() {
    // Placeholder for health analysis
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Health analysis feature coming soon")),
    );
  }

  void _logData() {
    // Placeholder for data logging
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Data logging feature coming soon")),
    );
  }

  Widget _scannerAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: caribbeanGreen.withOpacity(0.2),
              border: Border.all(color: caribbeanGreen.withOpacity(0.5)),
            ),
            child: Icon(icon, color: caribbeanGreen, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: antiFlashWhite, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
