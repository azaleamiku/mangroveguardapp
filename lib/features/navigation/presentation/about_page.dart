import 'package:flutter/material.dart';

import 'app_header.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const Color caribbeanGreen = Color(0xFF00DF81);
  static const Color antiFlashWhite = Color(0xFFF1F7F6);
  static const Color bangladeshGreen = Color(0xFF03624C);
  static const Color darkGreen = Color(0xFF032221);
  static const Color richBlack = Color(0xFF021B1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: richBlack,
      appBar: buildAppHeader('About'),
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [AboutContentSection()],
      ),
    );
  }
}

class AboutContentSection extends StatelessWidget {
  const AboutContentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _AboutCard(
          title: 'MangroveGuard',
          icon: Icons.shield_outlined,
          description:
              'MangroveGuard is an AI-assisted field app for Rhizophora '
              'mangrove assessment. It captures scans, runs on-device '
              'inference, and summarizes structural stability from root '
              'geometry.',
        ),
        SizedBox(height: 14),
        _AboutCard(
          title: 'How scanning works',
          icon: Icons.camera_alt_outlined,
          description:
              '1) Capture a tree image in Scanner.\n'
              '2) The model detects trunk/root features locally on device.\n'
              '3) The app extracts root geometry and computes a stability score.\n'
              '4) Results are saved to Recent Scans and reflected in Dashboard.',
        ),
        SizedBox(height: 14),
        _ClassificationCard(),
        SizedBox(height: 14),
        _AboutCard(
          title: 'Tabs and outputs',
          icon: Icons.dashboard_customize_outlined,
          description:
              'Dashboard: live distribution of High/Moderate/Low/Very Unstable scans.\n'
              'Scanner: camera capture and inference flow.\n'
              'Recent Scans: scan history with one-tap PDF report export.',
        ),
        SizedBox(height: 14),
        _AboutCard(
          title: 'Why this matters',
          icon: Icons.eco_outlined,
          description:
              'Healthy root systems support shoreline protection, biodiversity, '
              'and climate resilience for vulnerable coastal communities.',
        ),
        SizedBox(height: 14),
        _AboutCard(
          title: 'Data and privacy',
          icon: Icons.lock_outline_rounded,
          description:
              'Scans and generated reports are stored locally on your device '
              'for field use. The app keeps operational data needed for '
              'analysis and does not require cloud inference to run.',
        ),
        SizedBox(height: 14),
        _AboutCard(
          title: 'Dashboard pull gesture',
          icon: Icons.swipe_up_alt_rounded,
          description:
              'You can reveal this section by overscrolling at the bottom of '
              'the Dashboard tab.',
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _AboutCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AboutPage.bangladeshGreen.withValues(alpha: 0.88),
            AboutPage.darkGreen,
          ],
        ),
        border: Border.all(
          color: AboutPage.caribbeanGreen.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.24),
              border: Border.all(
                color: AboutPage.caribbeanGreen.withValues(alpha: 0.42),
              ),
            ),
            child: Icon(icon, color: AboutPage.caribbeanGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AboutPage.antiFlashWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: AboutPage.antiFlashWhite.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AboutPage.darkGreen,
        border: Border.all(
          color: AboutPage.caribbeanGreen.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(
                Icons.query_stats_rounded,
                color: AboutPage.caribbeanGreen,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Stability classification',
                style: TextStyle(
                  color: AboutPage.antiFlashWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _ClassificationRow(
            label: 'High',
            ratioText: 'Stability score 0.75–1.00',
            color: AboutPage.caribbeanGreen,
          ),
          SizedBox(height: 8),
          _ClassificationRow(
            label: 'Moderate',
            ratioText: 'Stability score 0.50–0.74',
            color: Color(0xFFF59E0B),
          ),
          SizedBox(height: 8),
          _ClassificationRow(
            label: 'Low',
            ratioText: 'Stability score 0.25–0.49',
            color: Color(0xFFEF4444),
          ),
          SizedBox(height: 8),
          _ClassificationRow(
            label: 'Very Unstable',
            ratioText: 'Stability score 0.00–0.24',
            color: Color(0xFFB91C1C),
          ),
        ],
      ),
    );
  }
}

class _ClassificationRow extends StatelessWidget {
  final String label;
  final String ratioText;
  final Color color;

  const _ClassificationRow({
    required this.label,
    required this.ratioText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    color: AboutPage.antiFlashWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ratioText,
                  style: TextStyle(
                    color: AboutPage.antiFlashWhite.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
