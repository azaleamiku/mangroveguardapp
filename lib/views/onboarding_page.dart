import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mangroveguardapp/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangroveguardapp/views/main_nav_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heroAnimation;
  late final Animation<double> _featuresAnimation;
  late final Animation<double> _ctaAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _heroAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _featuresAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.75, curve: Curves.easeOutCubic),
    );
    _ctaAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleGetStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHome', true);
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FeatureWalkthroughPage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Theme(
      data: theme.copyWith(textTheme: textTheme),
      child: Scaffold(
        body: Stack(
          children: [
            const _OnboardingBackdrop(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final isWide = maxWidth >= 840;
                  final horizontalPadding = isWide ? 56.0 : 24.0;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      24,
                      horizontalPadding,
                      32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FadeSlide(
                          animation: _heroAnimation,
                          yOffset: 22,
                          child: _HeaderRow(isWide: isWide),
                        ),
                        const SizedBox(height: 28),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _FadeSlide(
                                  animation: _heroAnimation,
                                  yOffset: 36,
                                  child: _HeroCopy(textTheme: textTheme),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 5,
                                child: _FadeSlide(
                                  animation: _heroAnimation,
                                  yOffset: 36,
                                  child: const _HeroVisual(),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FadeSlide(
                                animation: _heroAnimation,
                                yOffset: 36,
                                child: const _HeroVisual(),
                              ),
                              const SizedBox(height: 24),
                              _FadeSlide(
                                animation: _heroAnimation,
                                yOffset: 36,
                                child: _HeroCopy(textTheme: textTheme),
                              ),
                            ],
                          ),
                        const SizedBox(height: 32),
                        _FadeSlide(
                          animation: _featuresAnimation,
                          yOffset: 28,
                          child: _FeatureGrid(isWide: isWide),
                        ),
                        const SizedBox(height: 28),
                        _FadeSlide(
                          animation: _ctaAnimation,
                          yOffset: 24,
                          child: _CallToAction(onGetStarted: _handleGetStarted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF031B1B), Color(0xFF052B26), Color(0xFF0A3C2F)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _MangroveAuraPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool isWide;
  const _HeaderRow({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.darkGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.caribbeanGreen.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: AppColors.caribbeanGreen.withOpacity(0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('images/MangroveGuardLogo.png'),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MangroveGuard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.antiFlashWhite,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              'Field capture meets web intelligence',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.antiFlashWhite.withOpacity(0.7),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (isWide)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.caribbeanGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.caribbeanGreen.withOpacity(0.4),
              ),
            ),
            child: Text(
              'LIVE BUILD',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.caribbeanGreen,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final TextTheme textTheme;
  const _HeroCopy({required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Capture in the field. Analyze everywhere.',
          style: textTheme.displaySmall?.copyWith(
            color: AppColors.antiFlashWhite,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Scan mangroves on-site with your device, then review detailed stability trends, historical comparisons, and team insights from the web dashboard.',
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.antiFlashWhite.withOpacity(0.78),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _TagPill(label: 'Field Scans'),
            _TagPill(label: 'Web Analytics'),
            _TagPill(label: 'Sync History'),
          ],
        ),
      ],
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.darkGreen.withOpacity(0.95),
              const Color(0xFF0E3D35),
              const Color(0xFF0F4734),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
          border: Border.all(color: AppColors.caribbeanGreen.withOpacity(0.2)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'images/MangroveGuardLogo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SignalPill(
                        label: 'Live Analysis',
                        color: AppColors.caribbeanGreen,
                      ),
                      Icon(
                        Icons.track_changes,
                        color: AppColors.caribbeanGreen.withOpacity(0.85),
                        size: 28,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Cross-device sync active',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.antiFlashWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Field scans, web analytics, and stability trends — all connected.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.antiFlashWhite.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ProgressBar(value: 0.78),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  final bool isWide;
  const _FeatureGrid({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _FeatureCard(
        title: 'Field Scanning',
        description:
            'Use your device camera to capture and assess mangrove root stability on-site. Works offline and syncs when you reconnect.',
        icon: Icons.videocam,
      ),
      const _FeatureCard(
        title: 'Web Analytics',
        description:
            'Review stability trends, compare scan history, and explore detailed environmental metrics on the MangroveGuard web dashboard.',
        icon: Icons.web,
      ),
      const _FeatureCard(
        title: 'Synced History',
        description:
            'All scans are synced across your mobile app and web dashboard. Pick up where you left off on any device.',
        icon: Icons.sync,
      ),
      const _FeatureCard(
        title: 'Multi-Device Access',
        description:
            'Pair your device once, then manage scans from any connected device. Camera permission is only needed for field scans.',
        icon: Icons.security,
      ),
    ];

    if (isWide) {
      final rowChildren = <Widget>[];
      for (int i = 0; i < cards.length; i++) {
        rowChildren.add(Expanded(child: cards[i]));
        if (i != cards.length - 1) {
          rowChildren.add(const SizedBox(width: 16));
        }
      }
      return Row(children: rowChildren);
    }

    return Column(
      children: cards
          .map(
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: card,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0B2E2A).withOpacity(0.9),
        border: Border.all(color: AppColors.caribbeanGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.caribbeanGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.caribbeanGreen),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.antiFlashWhite,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.antiFlashWhite.withOpacity(0.72),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallToAction extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _CallToAction({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0C2A25).withOpacity(0.9),
        border: Border.all(color: AppColors.caribbeanGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready to explore MangroveGuard? ',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.antiFlashWhite,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start with a field scan or open the web dashboard to review your coastal data.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.antiFlashWhite.withOpacity(0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.caribbeanGreen,
                foregroundColor: AppColors.richBlack,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              onPressed: onGetStarted,
              child: const Text('Get Started'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.caribbeanGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.caribbeanGreen.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.caribbeanGreen,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SignalPill extends StatelessWidget {
  final String label;
  final Color color;
  const _SignalPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.2),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 8,
        value: value,
        backgroundColor: AppColors.antiFlashWhite.withOpacity(0.08),
        valueColor: const AlwaysStoppedAnimation<Color>(
          AppColors.caribbeanGreen,
        ),
      ),
    );
  }
}

class _FadeSlide extends StatelessWidget {
  final Animation<double> animation;
  final double yOffset;
  final Widget child;

  const _FadeSlide({
    required this.animation,
    required this.yOffset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * yOffset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _MangroveAuraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.caribbeanGreen.withOpacity(0.08);

    final accentPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.caribbeanGreen.withOpacity(0.06);

    final center = Offset(size.width * 0.82, size.height * 0.2);
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(center, size.width * 0.18 + (i * 34), glowPaint);
    }

    final bottomLeft = Offset(size.width * 0.1, size.height * 0.82);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(bottomLeft, size.width * 0.15 + (i * 28), glowPaint);
    }

    final random = math.Random(7);
    for (int i = 0; i < 22; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = 3 + random.nextDouble() * 6;
      canvas.drawCircle(Offset(dx, dy), radius, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FeatureWalkthroughPage extends StatefulWidget {
  const FeatureWalkthroughPage({super.key});

  @override
  State<FeatureWalkthroughPage> createState() => _FeatureWalkthroughPageState();
}

class _FeatureWalkthroughPageState extends State<FeatureWalkthroughPage> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  final List<_WalkthroughStep> _steps = const [
    _WalkthroughStep(
      title: 'Scan in the Field',
      description:
          'Use your device camera to capture mangrove root structure. Analysis runs locally on-device and syncs to your web dashboard.',
      icon: Icons.videocam,
    ),
    _WalkthroughStep(
      title: 'Review on Web',
      description:
          'Open the MangroveGuard web dashboard to explore stability trends, historical comparisons, and detailed scan analytics.',
      icon: Icons.web,
    ),
    _WalkthroughStep(
      title: 'Sync Across Devices',
      description:
          'Your scans stay in sync between the mobile app and web dashboard. Resume analysis or manage data from anywhere.',
      icon: Icons.sync,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHome', true);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainNavPage()));
  }

  void _handleNext() {
    if (_pageIndex >= _steps.length - 1) {
      _completeWalkthrough();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final primaryActionLabel = _pageIndex == _steps.length - 1
        ? 'Start Scanning'
        : 'Next';

    return Theme(
      data: theme.copyWith(textTheme: textTheme),
      child: Scaffold(
        body: Stack(
          children: [
            const _OnboardingBackdrop(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Explore MangroveGuard',
                          style: textTheme.titleLarge?.copyWith(
                            color: AppColors.antiFlashWhite,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _pageIndex = index);
                      },
                      itemCount: _steps.length,
                      itemBuilder: (context, index) {
                        return _WalkthroughCard(
                          step: _steps[index],
                          index: index,
                          total: _steps.length,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Row(
                      children: [
                        _WalkthroughIndicators(
                          count: _steps.length,
                          index: _pageIndex,
                        ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.caribbeanGreen,
                            foregroundColor: AppColors.richBlack,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            textStyle: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: _handleNext,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  axis: Axis.horizontal,
                                  axisAlignment: -1,
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              primaryActionLabel,
                              key: ValueKey(primaryActionLabel),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkthroughStep {
  final String title;
  final String description;
  final IconData icon;

  const _WalkthroughStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _WalkthroughCard extends StatelessWidget {
  final _WalkthroughStep step;
  final int index;
  final int total;
  const _WalkthroughCard({
    required this.step,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0C332E).withOpacity(0.95),
              const Color(0xFF0C3D33).withOpacity(0.9),
              const Color(0xFF0E4735).withOpacity(0.9),
            ],
          ),
          border: Border.all(color: AppColors.caribbeanGreen.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.caribbeanGreen.withOpacity(0.15),
                ),
                child: Icon(
                  step.icon,
                  color: AppColors.caribbeanGreen,
                  size: 34,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                step.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.antiFlashWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                step.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.antiFlashWhite.withOpacity(0.75),
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.darkGreen.withOpacity(0.7),
                  border: Border.all(
                    color: AppColors.caribbeanGreen.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  'Step ${index + 1} of $total',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.caribbeanGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkthroughIndicators extends StatelessWidget {
  final int count;
  final int index;
  const _WalkthroughIndicators({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final dots = <Widget>[];
    for (int i = 0; i < count; i++) {
      final isActive = i == index;
      dots.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: isActive ? 28 : 10,
          height: 10,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: isActive
                ? AppColors.caribbeanGreen
                : AppColors.antiFlashWhite.withOpacity(0.2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.caribbeanGreen.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
        ),
      );
    }
    return Row(children: dots);
  }
}
