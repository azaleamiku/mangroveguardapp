import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../navigation/presentation/main_nav_page.dart';

// Import the color constants
const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color bangladeshGreen = Color(0xFF03624C);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

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
      backgroundColor: richBlack,
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
          ? Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [darkGreen, bangladeshGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: caribbeanGreen.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: antiFlashWhite,
                  minimumSize: const Size.fromHeight(80),
                ),
                child: const Text('I ACCEPT & GET STARTED', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('showHome', true);
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const MainNavPage()),
                    );
                  }
                },
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 80,
              color: darkGreen.withOpacity(0.9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => controller.jumpToPage(2),
                    child: Text('SKIP', style: TextStyle(color: antiFlashWhite.withOpacity(0.7))),
                  ),
                  Center(
                    child: SmoothPageIndicator(
                      controller: controller,
                      count: 3,
                      effect: WormEffect(
                        activeDotColor: caribbeanGreen,
                        dotColor: antiFlashWhite.withOpacity(0.3),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
                    child: Text('NEXT', style: TextStyle(color: caribbeanGreen)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOnboardingScreen({required String title, required String desc, required IconData icon}) {
    return Container(
      color: richBlack,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [caribbeanGreen.withOpacity(0.2), bangladeshGreen.withOpacity(0.2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: caribbeanGreen.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(icon, size: 80, color: caribbeanGreen),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: antiFlashWhite,
              shadows: [
                Shadow(
                  color: caribbeanGreen.withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: antiFlashWhite.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
