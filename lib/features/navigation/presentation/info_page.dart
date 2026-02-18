import 'package:flutter/material.dart';
import 'app_header.dart';

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
      appBar: buildAppHeader("About MangroveGuard"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: "About Mangroves",
              content: "Mangroves are critical coastal ecosystems that reduce erosion, absorb storm surge impact, and support marine biodiversity. Protecting mangroves directly improves shoreline resilience and community safety.",
              icon: Icons.eco,
            ),
            const SizedBox(height: 30),
            _buildSection(
              title: "MangroveGuard App",
              content: "MangroveGuard is an optimized computer vision tool for mangrove stability assessment. It automates field assessment using AI and is designed to run well even on mid-range mobile hardware.",
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 30),
            _buildSection(
              title: "Core Capabilities",
              content: "1. Real-time root quantification using YOLOv8-Nano (Quantized).\n2. Stability indexing to produce a structural resilience score.\n3. Offline-first operation with on-device inference via LiteRT.\n4. Educational modules for conservation context and responsible data use.",
              icon: Icons.center_focus_strong,
            ),
            const SizedBox(height: 30),
            _buildSection(
              title: "Tech Stack",
              content: "Framework: Flutter (Dart)\nAI Model: YOLOv8-Nano (Quantized)\nInference Engine: LiteRT (formerly TFLite)\nArchitecture: Clean Architecture (Data, Domain, Presentation)",
              icon: Icons.security,
            ),
            const SizedBox(height: 30),
            _buildSection(
              title: "Privacy & Terms",
              content: "MangroveGuard is designed for ecological research. Location data is used only to tag assessments and is not shared with third parties. Image processing is performed locally on-device and no images are uploaded to external servers.",
              icon: Icons.group,
            ),
            const SizedBox(height: 30),
            _buildSection(
              title: "Researchers",
              content: "Ivan Kly B. Lamason - Lead Systems Architect & Project Coordinator\nDan Coby G. Tabao - Lead Systems Developer & Data Engineer\nElzen Rein Marco Maceda - UI/UX Designer & ML Specialist\nVincent N. Pensader - Solutions Engineer & Technical Writer",
              icon: Icons.groups,
            ),
            const SizedBox(height: 30),
            _buildSection(
              title: "Co-Author / Adviser",
              content: "Devine Grace Funcion, MSIT - Bachelor of Science in Information Technology",
              icon: Icons.school,
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
