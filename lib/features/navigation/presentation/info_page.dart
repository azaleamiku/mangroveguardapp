import 'package:flutter/material.dart';

// Import the color constants
const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color bangladeshGreen = Color(0xFF03624C);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About MangroveGuard"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: antiFlashWhite,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: "About Mangroves",
              content: "Mangroves are vital coastal ecosystems that protect shorelines from erosion, storm surges, and flooding. They sequester carbon at rates 4 times higher than tropical rainforests, making them crucial for climate change mitigation. Mangroves provide habitats for diverse marine life and support coastal communities worldwide.",
              icon: Icons.eco,
            ),
            const SizedBox(height: 30),
            _buildSection(
              title: "MangroveGuard App",
              content: "MangroveGuard uses advanced AI technology to assess mangrove tree health. Our YOLOv10-Nano model, combined with ARCore integration, enables precise health measurements directly on your mobile device. This tool helps researchers, conservationists, and communities monitor mangrove ecosystems effectively.",
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 30),
            _buildSection(
              title: "How It Works",
              content: "1. Use the Scan tab to capture mangrove trees with your camera.\n2. Our AI analyzes tree structure, leaf density, and health indicators.\n3. Receive instant health scores and recommendations.\n4. Contribute to global mangrove conservation efforts.",
              icon: Icons.center_focus_strong,
            ),
            const SizedBox(height: 30),
            _buildSection(
              title: "Privacy & Data",
              content: "We prioritize your privacy. Location data is used solely for ecological research and is never shared with third parties. All processing happens on-device where possible, ensuring your data stays secure.",
              icon: Icons.security,
            ),
            const SizedBox(height: 30),
            _buildSection(
              title: "Get Involved",
              content: "Join the mangrove conservation movement! Share your findings, participate in community monitoring programs, and help protect these vital ecosystems for future generations.",
              icon: Icons.group,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content, required IconData icon}) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
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
                child: Icon(icon, color: caribbeanGreen, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: antiFlashWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              color: antiFlashWhite.withOpacity(0.9),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
