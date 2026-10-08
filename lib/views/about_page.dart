import 'package:flutter/material.dart';
import 'package:mangroveguardapp/theme/colors.dart';
import 'package:mangroveguardapp/widgets/app_header.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.richBlack,
      appBar: buildAppHeader('About'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.caribbeanGreen.withOpacity(0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Image.asset('images/MangroveGuardLogo.png'),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MangroveGuard',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.antiFlashWhite,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Version 1.0',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.antiFlashWhite.withOpacity(0.6),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            _AboutSection(
              title: 'About',
              body:
                  'MangroveGuard is a coastal mangrove monitoring platform that turns field scans into actionable stability assessments. The system pairs a mobile YOLOv8-based vision pipeline with a live web dashboard for conservation teams to review observations, monitor activity, and trigger intervention protocols.',
            ),
            const SizedBox(height: 20),
            _AboutSection(
              title: 'How it works',
              body:
                  'Capture mangrove root structure on-site with your device camera. Analysis runs locally using on-device inference, then syncs to the MangroveGuard web dashboard for team review, stability trends, and historical comparisons.',
            ),
            const SizedBox(height: 20),
            _AboutSection(
              title: 'Ecosystem',
              body:
                  'The platform spans two surfaces: the Flutter mobile client for field capture and the React web dashboard for analytics. Scans are persisted by an Express backend and streamed live over Server-Sent Events so both surfaces stay in sync.',
            ),
            const SizedBox(height: 20),
            _AboutSection(
              title: 'Technology',
              body:
                  'Flutter mobile app • YOLOv8 on-device inference • React + Vite web dashboard • Express REST API • Server-Sent Events • Dockerized deployment',
            ),
            const SizedBox(height: 28),
            Text(
              'MangroveGuard • Coastal Conservation Tech',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.antiFlashWhite.withOpacity(0.45),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;
  final String body;

  const _AboutSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            color: AppColors.caribbeanGreen,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.antiFlashWhite.withOpacity(0.78),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
