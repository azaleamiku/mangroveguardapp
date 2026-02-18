import 'package:flutter/material.dart';

// Color constants
const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
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
                "Initializing Scanner...",
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
          // Camera Placeholder
          Container(
            color: Colors.black,
            child: const Center(
              child: Text(
                "Camera Feed\n(Point at mangrove tree)",
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
              child: const Text(
                "Point camera at mangrove tree to analyze health",
                style: TextStyle(color: antiFlashWhite, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Floating Action Bar for Field Tools
          Positioned(
            bottom: 110,
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

  void _analyzeHealth() {
    _showTopNotification("Health analysis feature coming soon");
  }

  void _logData() {
    _showTopNotification("Data logging feature coming soon");
  }

  void _showTopNotification(String message) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'notification',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        });

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: darkGreen.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: caribbeanGreen.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_active, color: caribbeanGreen, size: 20),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: antiFlashWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.2),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
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
