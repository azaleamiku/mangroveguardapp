import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../navigation/presentation/main_nav_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  bool isLastPage = false;

  @override
  Widget build(BuildContext buildContext) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.only(bottom: 80),
        child: PageView(
          controller: controller,
          onPageChanged: (index) => setState(() => isLastPage = index == 2),
          children: [
            // Page 1: Terms & Privacy
            _buildOnboardingScreen(
              title: "Data Privacy & Terms",
              desc: "By using MangroveGuard, you consent to our data collection for ecological research. We do not share your personal location with third parties.",
              icon: Icons.security,
            ),
            // Page 2: About Mangroves
            _buildOnboardingScreen(
              title: "Why Mangroves?",
              desc: "Mangroves are vital coastal guardians. They protect against storm surges and sequester 4x more carbon than tropical rainforests.",
              icon: Icons.eco,
            ),
            // Page 3: About the App
            _buildOnboardingScreen(
              title: "MangroveGuard AI",
              desc: "Our YOLOv10-Nano model and ARCore integration allow you to measure tree health with expert-level precision on your mobile device.",
              icon: Icons.auto_awesome,
            ),
          ],
        ),
      ),
      bottomSheet: isLastPage
          ? TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF2D5A27),
                minimumSize: const Size.fromHeight(80),
              ),
              child: const Text('I ACCEPT & GET STARTED', style: TextStyle(fontSize: 18)),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('showHome', true);
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const MainNavPage()),
                  );
                }
              },
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => controller.jumpToPage(2), child: const Text('SKIP')),
                  Center(
                    child: SmoothPageIndicator(
                      controller: controller,
                      count: 3,
                      effect: const WormEffect(activeDotColor: Color(0xFF2D5A27)),
                    ),
                  ),
                  TextButton(onPressed: () => controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut), child: const Text('NEXT')),
                ],
              ),
            ),
    );
  }

  Widget _buildOnboardingScreen({required String title, required String desc, required IconData icon}) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: const Color(0xFF2D5A27)),
          const SizedBox(height: 40),
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}