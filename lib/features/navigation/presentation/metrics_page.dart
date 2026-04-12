import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../home/models/mangrove_tree.dart';
import 'recent_scan_page.dart';

class MetricsPage extends StatefulWidget {
  final ValueListenable<List<RecentTreeScan>> scansListenable;

  const MetricsPage({super.key, required this.scansListenable});

  static const Color caribbeanGreen = Color(0xFF00DF81);
  static const Color antiFlashWhite = Color(0xFFF1F7F6);
  static const Color bangladeshGreen = Color(0xFF03624C);
  static const Color darkGreen = Color(0xFF032221);
  static const Color richBlack = Color(0xFF021B1A);

  @override
  State<MetricsPage> createState() => _MetricsPageState();
}

class _MetricsPageState extends State<MetricsPage> {
  static const double _aboutPullTrigger = 70;
  static const double _aboutPullDisarm = 52;
  static const double _aboutPullMaxExtent = 72;
  static const double _aboutMinIntentDrag = 96;
  static const double _aboutIndicatorBottom = 114;
  static const double _metricsListBottomPadding = 172;
  static const int _weeklyTrendWeeks = 8;

  double _aboutPullExtent = 0;
  double _aboutDragDistance = 0;
  bool _aboutTriggerArmed = false;
  bool _aboutReleaseQueued = false;
  bool _aboutSheetOpen = false;
  bool _aboutSheetPending = false;
  bool _showAboutHint = false;
  bool _aboutHintSeen = false;
  Timer? _aboutHintTimer;

  void _showAboutHintNotice() {
    if (_aboutHintSeen) {
      return;
    }
    _aboutHintSeen = true;
    _aboutHintTimer?.cancel();
    if (mounted) {
      setState(() {
        _showAboutHint = true;
      });
    }
    _aboutHintTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showAboutHint = false;
      });
    });
  }

  bool _handleScrollNotification(
    ScrollNotification notification,
    BuildContext context,
  ) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _aboutDragDistance = 0;
      _aboutReleaseQueued = false;
      return false;
    }

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      if (!_aboutHintSeen &&
          metrics.maxScrollExtent > 0 &&
          metrics.pixels >= metrics.maxScrollExtent - 24 &&
          !_aboutSheetOpen) {
        _showAboutHintNotice();
      }

      final dragDelta = switch (notification) {
        ScrollUpdateNotification update => update.dragDetails?.primaryDelta,
        OverscrollNotification overscroll =>
          overscroll.dragDetails?.primaryDelta,
        _ => null,
      };
      final isDraggingUp = dragDelta != null && dragDelta < 0;
      final isDraggingDown = dragDelta != null && dragDelta > 0;
      if (dragDelta != null) {
        if (dragDelta < 0) {
          _aboutDragDistance = (_aboutDragDistance + -dragDelta)
              .clamp(0.0, _aboutPullMaxExtent * 2)
              .toDouble();
        } else if (dragDelta > 0 && _aboutDragDistance > 0) {
          _aboutDragDistance = (_aboutDragDistance - dragDelta)
              .clamp(0.0, _aboutPullMaxExtent * 2)
              .toDouble();
        }
      }

      final isPushingPastBottom = metrics.pixels > metrics.maxScrollExtent;
      final isReversingIntoList = !isPushingPastBottom && isDraggingDown;
      if (isReversingIntoList &&
          (_aboutPullExtent > 0 || _aboutTriggerArmed || _aboutReleaseQueued)) {
        setState(() {
          _aboutPullExtent = 0;
          _aboutTriggerArmed = false;
          _aboutReleaseQueued = false;
        });
        _aboutDragDistance = 0;
        return false;
      }

      if (isPushingPastBottom) {
        final rawPullExtent = (metrics.pixels - metrics.maxScrollExtent)
            .clamp(0.0, _aboutPullMaxExtent)
            .toDouble();
        final pullExtent = rawPullExtent > _aboutDragDistance
            ? _aboutDragDistance
            : rawPullExtent;
        final hasIntentionalDrag = _aboutDragDistance >= _aboutMinIntentDrag;
        final armed =
            (_aboutTriggerArmed && pullExtent >= _aboutPullDisarm) ||
            (isDraggingUp &&
                hasIntentionalDrag &&
                pullExtent >= _aboutPullTrigger);
        var releaseQueued = _aboutReleaseQueued || armed;
        // Backing off below trigger cancels the queued open.
        if (isDraggingDown && pullExtent < _aboutPullTrigger) {
          releaseQueued = false;
        }

        // Open immediately on finger release if still intentionally queued.
        if (dragDelta == null && releaseQueued && !_aboutSheetOpen) {
          setState(() {
            _aboutPullExtent = 0;
            _aboutTriggerArmed = false;
            _aboutReleaseQueued = false;
          });
          _aboutDragDistance = 0;
          _showAboutSheet(context);
          return false;
        }

        if (pullExtent != _aboutPullExtent ||
            armed != _aboutTriggerArmed ||
            releaseQueued != _aboutReleaseQueued) {
          setState(() {
            _aboutPullExtent = pullExtent;
            _aboutTriggerArmed = armed;
            _aboutReleaseQueued = releaseQueued;
          });
        }
      } else if (_aboutPullExtent > 0 ||
          _aboutTriggerArmed ||
          _aboutReleaseQueued) {
        setState(() {
          _aboutPullExtent = 0;
          _aboutTriggerArmed = false;
          _aboutReleaseQueued = false;
        });
      }
    } else if (notification is ScrollEndNotification) {
      final shouldShowAbout =
          (_aboutTriggerArmed || _aboutReleaseQueued) && !_aboutSheetOpen;
      if (_aboutPullExtent > 0 || _aboutTriggerArmed || _aboutReleaseQueued) {
        setState(() {
          _aboutPullExtent = 0;
          _aboutTriggerArmed = false;
          _aboutReleaseQueued = false;
        });
      }
      _aboutDragDistance = 0;
      if (shouldShowAbout) {
        _showAboutSheet(context);
      }
    }

    return false;
  }

  List<_WeeklyScanBucket> _buildWeeklyScanBuckets(List<RecentTreeScan> scans) {
    final today = DateTime.now();
    final currentWeekStart = _startOfWeek(today);
    final buckets = List<_WeeklyScanBucket>.generate(_weeklyTrendWeeks, (i) {
      final offsetWeeks = _weeklyTrendWeeks - 1 - i;
      final weekStart = currentWeekStart.subtract(
        Duration(days: 7 * offsetWeeks),
      );
      return _WeeklyScanBucket(weekStart: weekStart, count: 0);
    });

    for (final scan in scans) {
      final scanWeekStart = _startOfWeek(scan.scannedAt);
      final diffDays = currentWeekStart.difference(scanWeekStart).inDays;
      if (diffDays < 0) continue;
      final diffWeeks = diffDays ~/ 7;
      if (diffWeeks >= _weeklyTrendWeeks) continue;
      final index = _weeklyTrendWeeks - 1 - diffWeeks;
      final current = buckets[index];
      buckets[index] = _WeeklyScanBucket(
        weekStart: current.weekStart,
        count: current.count + 1,
      );
    }

    return buckets;
  }

  DateTime _startOfWeek(DateTime value) {
    final local = DateTime(value.year, value.month, value.day);
    final weekday = local.weekday;
    return local.subtract(Duration(days: weekday - DateTime.monday));
  }

  Future<void> _showAboutSheet(BuildContext context) async {
    if (_aboutSheetOpen || _aboutSheetPending) {
      return;
    }
    _aboutSheetPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _aboutSheetPending = false;
        return;
      }
      _aboutSheetPending = false;
      if (_aboutSheetOpen) {
        return;
      }

      _aboutHintTimer?.cancel();
      if (_showAboutHint) {
        setState(() {
          _showAboutHint = false;
        });
      }

      _aboutSheetOpen = true;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => const _AboutAppSheet(),
      );
      if (mounted) {
        setState(() {
          _aboutSheetOpen = false;
        });
      } else {
        _aboutSheetOpen = false;
      }
    });
  }

  @override
  void dispose() {
    _aboutHintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetricsPage.richBlack,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ValueListenableBuilder<List<RecentTreeScan>>(
          valueListenable: widget.scansListenable,
          builder: (context, scans, _) {
            final recentScanCount = scans.length;
            final topInset = MediaQuery.paddingOf(context).top;
            const extraTopPadding = 30.0;
            final contentTopPadding = topInset + extraTopPadding;

            var stabilitySum = 0.0;
            var highCount = 0;
            var moderateCount = 0;
            var lowCount = 0;

            for (final scan in scans) {
              stabilitySum += scan.stabilityScore;
              switch (scan.assessment) {
                case StabilityAssessment.high:
                  highCount++;
                  break;
                case StabilityAssessment.moderate:
                  moderateCount++;
                  break;
                case StabilityAssessment.low:
                  lowCount++;
                  break;
              }
            }

            final averageStability = recentScanCount == 0
                ? 0.0
                : (stabilitySum / recentScanCount).clamp(0.0, 1.0);
            final weeklyBuckets = _buildWeeklyScanBuckets(scans);

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) =>
                  _handleScrollNotification(notification, context),
              child: Stack(
                children: [
                  StretchingOverscrollIndicator(
                    axisDirection: AxisDirection.down,
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        contentTopPadding + 8,
                        16,
                        _metricsListBottomPadding,
                      ),
                      children: [
                        _HeroSummaryCard(recentScanCount: recentScanCount),
                        const SizedBox(height: 14),
                        _AverageStabilityGaugeCard(
                          recentScanCount: recentScanCount,
                          averageStability: averageStability,
                          lowCount: lowCount,
                          moderateCount: moderateCount,
                          highCount: highCount,
                        ),
                        const SizedBox(height: 14),
                        _StabilityBreakdownCard(
                          highCount: highCount,
                          moderateCount: moderateCount,
                          lowCount: lowCount,
                        ),
                        const SizedBox(height: 14),
                        _WeeklyScanVolumeTrendCard(buckets: weeklyBuckets),
                        if (recentScanCount == 0) ...[
                          const SizedBox(height: 14),
                          _EmptyStateHintCard(),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _aboutIndicatorBottom,
                    child: _AboutOverscrollNotice(
                      showHint: _showAboutHint,
                      pullExtent: _aboutPullExtent,
                      isArmed: _aboutTriggerArmed,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AboutOverscrollNotice extends StatelessWidget {
  final bool showHint;
  final double pullExtent;
  final bool isArmed;

  const _AboutOverscrollNotice({
    required this.showHint,
    required this.pullExtent,
    required this.isArmed,
  });

  @override
  Widget build(BuildContext context) {
    final isPulling = pullExtent > 0;
    final isVisible = isPulling || isArmed;
    final title = isArmed ? 'Release for App Info' : 'Pull up for App Info';

    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0, 0.45),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isVisible ? 1 : 0,
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: (MediaQuery.sizeOf(context).width - 32)
                    .clamp(220.0, 360.0)
                    .toDouble(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: MetricsPage.darkGreen.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isArmed
                      ? MetricsPage.caribbeanGreen.withValues(alpha: 0.9)
                      : MetricsPage.bangladeshGreen.withValues(alpha: 0.9),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isArmed
                        ? Icons.touch_app_rounded
                        : Icons.swipe_up_alt_rounded,
                    color: MetricsPage.caribbeanGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MetricsPage.antiFlashWhite.withValues(
                          alpha: 0.9,
                        ),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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
  }
}

class _AboutAppSheet extends StatelessWidget {
  const _AboutAppSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: MetricsPage.richBlack,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: MetricsPage.bangladeshGreen.withValues(alpha: 0.95),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = math.min(
                520.0,
                MediaQuery.sizeOf(context).height * 0.72,
              );
              return SizedBox(
                height: maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: MetricsPage.antiFlashWhite.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: MetricsPage.bangladeshGreen.withValues(
                              alpha: 0.9,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: MetricsPage.caribbeanGreen.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.forest_rounded,
                            color: MetricsPage.caribbeanGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About Mangrove Guard',
                                style: TextStyle(
                                  color: MetricsPage.antiFlashWhite.withValues(
                                    alpha: 0.94,
                                  ),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Text(
                                'AI-assisted mangrove scanning in the field.',
                                style: TextStyle(
                                  color: MetricsPage.antiFlashWhite.withValues(
                                    alpha: 0.66,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: MetricsPage.darkGreen.withValues(
                                  alpha: 0.9,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: MetricsPage.bangladeshGreen.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
	                                  Text(
	                                    'Mangroves',
	                                    style: TextStyle(
	                                      color: MetricsPage.antiFlashWhite
	                                          .withValues(alpha: 0.9),
	                                      fontSize: 12,
	                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
	                                  const SizedBox(height: 6),
	                                  Text(
	                                    'Mangroves anchor shorelines with dense roots, filter sediments, shelter juvenile marine life, and thrive in salty tidal water.',
	                                    style: TextStyle(
	                                      color: MetricsPage.antiFlashWhite
	                                          .withValues(alpha: 0.8),
	                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: MetricsPage.darkGreen.withValues(
                                  alpha: 0.9,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: MetricsPage.bangladeshGreen.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'The App',
                                    style: TextStyle(
                                      color: MetricsPage.antiFlashWhite
                                          .withValues(alpha: 0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Our platform utilizes YOLOv8-Nano and TensorFlow Lite (LiteRT) to deliver high-speed, on-device instance segmentation for real-time tree analysis. By extracting root geometry and computing a weighted stability score, the system evaluates structural stability directly through the camera feed. All data is processed and stored locally to ensure privacy and offline functionality, culminating in an automated, professional PDF report for every scan.',
                                    style: TextStyle(
                                      color: MetricsPage.antiFlashWhite
                                          .withValues(alpha: 0.82),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: const [
                                      Expanded(
                                        child: _AboutPillMetric(
                                          icon: Icons.memory_rounded,
                                          label: 'Inference',
                                          value: 'On-device',
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: _AboutPillMetric(
                                          icon: Icons.history_rounded,
                                          label: 'History',
                                          value: 'Local',
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: _AboutPillMetric(
                                          icon: Icons.picture_as_pdf_rounded,
                                          label: 'Reports',
                                          value: 'PDF',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: MetricsPage.darkGreen.withValues(
                                  alpha: 0.9,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: MetricsPage.bangladeshGreen.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Stability Score (S)',
                                    style: TextStyle(
                                      color: MetricsPage.antiFlashWhite
                                          .withValues(alpha: 0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'S is a weighted score from 0 to 1 computed from root count, density, spread, coverage, symmetry, and thickness proxy. Higher scores indicate stronger structural stability.',
                                    style: TextStyle(
                                      color: MetricsPage.antiFlashWhite
                                          .withValues(alpha: 0.82),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.28,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: MetricsPage.bangladeshGreen
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: const Text(
                                      'S = 0.20RC + 0.15RD + 0.20RS + 0.15RCR + 0.20SS + 0.10RT',
                                      style: TextStyle(
                                        color: MetricsPage.antiFlashWhite,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: const [
                                      Expanded(
                                        child: _AboutPillMetric(
                                          icon: Icons.trending_down_rounded,
                                          label: 'Low',
                                          value: '0.00–0.49',
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: _AboutPillMetric(
                                          icon: Icons.trending_flat_rounded,
                                          label: 'Moderate',
                                          value: '0.50–0.74',
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: _AboutPillMetric(
                                          icon: Icons.trending_up_rounded,
                                          label: 'High',
                                          value: '0.75–1.00',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Built and maintained by the Mangrove Guard team.',
                              style: TextStyle(
                                color: MetricsPage.antiFlashWhite.withValues(
                                  alpha: 0.82,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: MetricsPage.caribbeanGreen,
                          foregroundColor: MetricsPage.richBlack,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AboutPillMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutPillMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: MetricsPage.darkGreen.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MetricsPage.bangladeshGreen.withValues(alpha: 0.95),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: MetricsPage.caribbeanGreen),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: MetricsPage.antiFlashWhite,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final int recentScanCount;

  const _HeroSummaryCard({required this.recentScanCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MetricsPage.bangladeshGreen.withValues(alpha: 0.86),
            MetricsPage.darkGreen,
          ],
        ),
        border: Border.all(
          color: MetricsPage.caribbeanGreen.withValues(alpha: 0.44),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live metrics from your recent scans',
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroValueBlock(
                  label: 'Recent Scans Count',
                  value: '$recentScanCount',
                  icon: Icons.forest_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AverageStabilityGaugeCard extends StatelessWidget {
  final int recentScanCount;
  final double averageStability;
  final int lowCount;
  final int moderateCount;
  final int highCount;

  const _AverageStabilityGaugeCard({
    required this.recentScanCount,
    required this.averageStability,
    required this.lowCount,
    required this.moderateCount,
    required this.highCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = recentScanCount > 0;

    final majorityCount = hasData 
        ? [lowCount, moderateCount, highCount].reduce(math.max) 
        : 0;
    final majorityRatio = hasData ? majorityCount / recentScanCount : 0.0;

    final averageLabel = hasData
        ? '${(majorityRatio * 100).toStringAsFixed(0)}%'
        : '--';

    StabilityAssessment? majorityAssessment;
    if (hasData) {
      if (lowCount >= moderateCount && lowCount >= highCount) {
        majorityAssessment = StabilityAssessment.low;
      } else if (moderateCount >= highCount) {
        majorityAssessment = StabilityAssessment.moderate;
      } else {
        majorityAssessment = StabilityAssessment.high;
      }
    }

    final statusLabel = hasData ? '${majorityAssessment!.label} Majority' : 'No data yet';
    final statusColor = hasData ? _statusColorForAssessment(majorityAssessment!) : MetricsPage.antiFlashWhite.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetricsPage.darkGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MetricsPage.bangladeshGreen.withValues(alpha: 0.95),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average Stability of the Mangroves',
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hasData
                ? 'Based on $recentScanCount recent scans'
                : 'Scan a mangrove to begin',
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          _AverageStabilityGauge(
            value: majorityRatio,
            valueLabel: averageLabel,
            caption: '',
            statusLabel: statusLabel,
            statusColor: statusColor,
            lowCount: lowCount,
            moderateCount: moderateCount,
            highCount: highCount,
          ),
        ],
      ),
    );
  }

  Color _statusColorForAssessment(StabilityAssessment assessment) {
    return switch (assessment) {
      StabilityAssessment.high => MetricsPage.caribbeanGreen,
      StabilityAssessment.moderate => const Color(0xFFF59E0B),
      StabilityAssessment.low => const Color(0xFFEF4444),
    };
  }
}

class _StabilityBreakdownCard extends StatelessWidget {
  final int highCount;
  final int moderateCount;
  final int lowCount;

  const _StabilityBreakdownCard({
    required this.highCount,
    required this.moderateCount,
    required this.lowCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = highCount + moderateCount + lowCount;
    final subtitle = total == 0 ? 'No scans yet' : 'From $total recent scans';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetricsPage.darkGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MetricsPage.bangladeshGreen.withValues(alpha: 0.95),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stability Breakdown',
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BreakdownMetric(
                  label: 'Low',
                  value: '$lowCount',
                  color: const Color(0xFFEF4444),
                  icon: Icons.trending_down_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BreakdownMetric(
                  label: 'Moderate',
                  value: '$moderateCount',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.trending_flat_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BreakdownMetric(
                  label: 'High',
                  value: '$highCount',
                  color: MetricsPage.caribbeanGreen,
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _BreakdownMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: MetricsPage.antiFlashWhite,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AverageStabilityGauge extends StatelessWidget {
  static const double maxValue = 1.0;

  final double value;
  final String valueLabel;
  final String caption;
  final String statusLabel;
  final Color statusColor;
  final int lowCount;
  final int moderateCount;
  final int highCount;

  const _AverageStabilityGauge({
    required this.value,
    required this.valueLabel,
    required this.caption,
    required this.statusLabel,
    required this.statusColor,
    required this.lowCount,
    required this.moderateCount,
    required this.highCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 165,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _AverageStabilityGaugePainter(
                    value: value,
                    maxValue: maxValue,
                    progressColor: statusColor,
                    lowCount: lowCount,
                    moderateCount: moderateCount,
                    highCount: highCount,
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      valueLabel,
                      style: const TextStyle(
                        color: MetricsPage.antiFlashWhite,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        style: TextStyle(
                          color: MetricsPage.antiFlashWhite.withValues(
                            alpha: 0.68,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          statusLabel,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        const Column(
          children: [
            _GaugeLegendItem(
              label: 'High Stability',
              color: MetricsPage.caribbeanGreen,
              alignment: Alignment.centerLeft,
            ),
            SizedBox(height: 6),
            _GaugeLegendItem(
              label: 'Moderate Stability',
              color: Color(0xFFF59E0B),
              alignment: Alignment.centerLeft,
            ),
            SizedBox(height: 6),
            _GaugeLegendItem(
              label: 'Low Stability',
              color: Color(0xFFEF4444),
              alignment: Alignment.centerLeft,
            ),
          ],
        ),
      ],
    );
  }
}

class _AverageStabilityGaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color progressColor;
  final int lowCount;
  final int moderateCount;
  final int highCount;

  const _AverageStabilityGaugePainter({
    required this.value,
    required this.maxValue,
    required this.progressColor,
    required this.lowCount,
    required this.moderateCount,
    required this.highCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    const trackThickness = 18.0;
    const scaleThickness = 8.0;
    const progressThickness = 18.0;

    final center = Offset(size.width / 2, size.height - trackThickness - 6);
    final radius = math.min(size.width / 2, center.dy) - trackThickness;
    if (radius <= 0) return;

    final labelStyle = TextStyle(
      color: MetricsPage.antiFlashWhite.withValues(alpha: 0.7),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.55),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

    const startAngle = math.pi;
    const sweepAngle = math.pi;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackThickness
      ..strokeCap = StrokeCap.round
      ..color = MetricsPage.antiFlashWhite.withValues(alpha: 0.22);

    final total = lowCount + moderateCount + highCount;
    final List<double> stabilityStops;
    final List<String> stabilityLabels;

    if (total == 0) {
      stabilityStops = [0.0, 0.25, 0.5, 1.0];
      stabilityLabels = ['0.00', '0.50', '0.75', '1.00'];
    } else {
      stabilityStops = [
        0.0,
        highCount / total,
        (highCount + moderateCount) / total,
        1.0,
      ];
      stabilityLabels = [
        '0',
        '$highCount',
        '${highCount + moderateCount}',
        '$total',
      ];
    }

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, trackPaint);

    final scaleRadius = radius + (trackThickness / 2) + 8;
    final scaleRect = Rect.fromCircle(center: center, radius: scaleRadius);
    final scalePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = scaleThickness
      ..strokeCap = StrokeCap.round;
    var currentAngle = startAngle;
    const scaleGap = 0.095;
    final scaleSegments = <(double, Color)>[
      (stabilityStops[1] - stabilityStops[0], MetricsPage.caribbeanGreen),
      (stabilityStops[2] - stabilityStops[1], const Color(0xFFF59E0B)),
      (stabilityStops[3] - stabilityStops[2], const Color(0xFFEF4444)),
    ];
    final sweepSign = sweepAngle.sign == 0 ? 1.0 : sweepAngle.sign;
    for (var index = 0; index < scaleSegments.length; index++) {
      final segment = scaleSegments[index];
      final portion = segment.$1;
      if (portion <= 0) continue;

      final fullSweep = sweepAngle * portion;
      final startTrim = index == 0 ? 0.0 : scaleGap / 2;
      final endTrim = index == scaleSegments.length - 1 ? 0.0 : scaleGap / 2;
      final drawableSweep = fullSweep - ((startTrim + endTrim) * sweepSign);
      if (drawableSweep.abs() <= 0.001) {
        currentAngle += fullSweep;
        continue;
      }

      scalePaint.color = segment.$2;
      canvas.drawArc(
        scaleRect,
        currentAngle + (startTrim * sweepSign),
        drawableSweep,
        false,
        scalePaint,
      );

      if (portion > 0.02) {
        final middleAngle = currentAngle + (fullSweep / 2);
        final countLabel = switch (index) {
          0 => '$highCount',
          1 => '$moderateCount',
          2 => '$lowCount',
          _ => '',
        };

        final segmentColor = segment.$2;
        final countPainter = TextPainter(
          text: TextSpan(
            text: countLabel,
            style: labelStyle.copyWith(
              color: segmentColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              shadows: [],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final countRadius = scaleRadius + 15;
        final countOffset = Offset(
          center.dx + countRadius * math.cos(middleAngle) - countPainter.width / 2,
          center.dy + countRadius * math.sin(middleAngle) - countPainter.height / 2,
        );
        countPainter.paint(canvas, countOffset);
      }

      currentAngle += fullSweep;
    }

    final clampedValue = value.clamp(0.0, maxValue);
    final progressRatio = (clampedValue / maxValue).clamp(0.0, 1.0);
    final progressSweep = sweepAngle * progressRatio;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = progressThickness
      ..strokeCap = StrokeCap.round
      ..color = progressColor;
    canvas.drawArc(arcRect, startAngle, progressSweep, false, progressPaint);

    final progressEndAngle = startAngle + progressSweep;
    final progressEnd = Offset(
      center.dx + radius * math.cos(progressEndAngle),
      center.dy + radius * math.sin(progressEndAngle),
    );
    final markerFill = Paint()..color = progressColor;
    final markerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = MetricsPage.antiFlashWhite.withValues(alpha: 0.9);
    canvas
      ..drawCircle(progressEnd, 7, markerFill)
      ..drawCircle(progressEnd, 7, markerBorder);

  }

  @override
  bool shouldRepaint(covariant _AverageStabilityGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.lowCount != lowCount ||
        oldDelegate.moderateCount != moderateCount ||
        oldDelegate.highCount != highCount;
  }
}

class _GaugeLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final Alignment alignment;

  const _GaugeLegendItem({
    required this.label,
    required this.color,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MetricsPage.antiFlashWhite.withValues(alpha: 0.7),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroValueBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroValueBlock({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MetricsPage.antiFlashWhite.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: MetricsPage.caribbeanGreen, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: MetricsPage.antiFlashWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetricsPage.antiFlashWhite.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _WeeklyScanVolumeTrendCard extends StatelessWidget {
  final List<_WeeklyScanBucket> buckets;

  const _WeeklyScanVolumeTrendCard({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxCount = buckets.fold<int>(0, (value, bucket) {
      return math.max(value, bucket.count);
    });
    final hasData = maxCount > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetricsPage.darkGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MetricsPage.bangladeshGreen.withValues(alpha: 0.95),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Scan Volume Trend',
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hasData ? 'Last ${buckets.length} weeks' : 'No scans yet',
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _WeeklyScanSparkline(
            buckets: buckets,
            maxCount: maxCount,
            hasData: hasData,
          ),
        ],
      ),
    );
  }
}

class _WeeklyScanSparkline extends StatefulWidget {
  final List<_WeeklyScanBucket> buckets;
  final int maxCount;
  final bool hasData;

  const _WeeklyScanSparkline({
    required this.buckets,
    required this.maxCount,
    required this.hasData,
  });

  @override
  State<_WeeklyScanSparkline> createState() => _WeeklyScanSparklineState();
}

class _WeeklyScanSparklineState extends State<_WeeklyScanSparkline> {
  int? _selectedIndex;

  String _formatWeekLabel(DateTime weekStart) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[weekStart.month - 1]} ${weekStart.day}';
  }

  String _formatWeekRange(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final startLabel = _formatWeekLabel(weekStart);
    final endLabel = weekStart.month == weekEnd.month
        ? '${weekEnd.day}'
        : _formatWeekLabel(weekEnd);
    return '$startLabel - $endLabel';
  }

  void _selectIndex(double dx, double width) {
    if (widget.buckets.isEmpty) return;
    final clampedX = dx.clamp(0.0, width);
    final stepX = widget.buckets.length == 1
        ? width
        : width / (widget.buckets.length - 1);
    final rawIndex = stepX == 0 ? 0 : (clampedX / stepX).round();
    final index = rawIndex.clamp(0, widget.buckets.length - 1);
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = widget.hasData
        ? MetricsPage.caribbeanGreen.withValues(alpha: 0.9)
        : MetricsPage.antiFlashWhite.withValues(alpha: 0.3);
    final labelColor = MetricsPage.antiFlashWhite.withValues(alpha: 0.7);
    final firstLabel = widget.buckets.isEmpty
        ? ''
        : _formatWeekLabel(widget.buckets.first.weekStart);
    final lastLabel = widget.buckets.isEmpty
        ? ''
        : _formatWeekLabel(widget.buckets.last.weekStart);

    return Column(
      children: [
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              height: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.maxCount}',
                    style: TextStyle(
                      color: labelColor.withValues(alpha: 0.75),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${(widget.maxCount / 2).round()}',
                    style: TextStyle(
                      color: labelColor.withValues(alpha: 0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '0',
                    style: TextStyle(
                      color: labelColor.withValues(alpha: 0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const chartHeight = 72.0;
                  final width = constraints.maxWidth;
                  final selectedIndex = _selectedIndex;
                  final selectedBucket =
                      (selectedIndex != null &&
                          selectedIndex >= 0 &&
                          selectedIndex < widget.buckets.length)
                      ? widget.buckets[selectedIndex]
                      : null;
                  final maxValue = widget.maxCount == 0 ? 1 : widget.maxCount;
                  final stepX = widget.buckets.length == 1
                      ? 0.0
                      : width / (widget.buckets.length - 1);

                  double? selectedX;
                  double? selectedY;
                  if (selectedBucket != null) {
                    final ratio = selectedBucket.count / maxValue;
                    selectedX = stepX * selectedIndex!;
                    selectedY = chartHeight - (chartHeight * ratio);
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        _selectIndex(details.localPosition.dx, width),
                    onHorizontalDragUpdate: (details) =>
                        _selectIndex(details.localPosition.dx, width),
                    child: SizedBox(
                      height: chartHeight,
                      width: double.infinity,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CustomPaint(
                            size: Size(width, chartHeight),
                            painter: _WeeklyScanSparklinePainter(
                              buckets: widget.buckets,
                              maxCount: widget.maxCount,
                              lineColor: lineColor,
                              selectedIndex: selectedIndex,
                            ),
                          ),
                          if (selectedBucket != null &&
                              selectedX != null &&
                              selectedY != null)
                            _SparklineTooltip(
                              x: selectedX,
                              y: selectedY,
                              chartWidth: width,
                              chartHeight: chartHeight,
                              label:
                                  '${selectedBucket.count} scans • ${_formatWeekRange(selectedBucket.weekStart)}',
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              firstLabel,
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              widget.buckets.isEmpty
                  ? ''
                  : _formatWeekLabel(
                      widget.buckets[widget.buckets.length ~/ 2].weekStart,
                    ),
              style: TextStyle(
                color: labelColor.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              lastLabel,
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SparklineTooltip extends StatelessWidget {
  final double x;
  final double y;
  final double chartWidth;
  final double chartHeight;
  final String label;

  const _SparklineTooltip({
    required this.x,
    required this.y,
    required this.chartWidth,
    required this.chartHeight,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    const tooltipWidth = 160.0;
    const tooltipHeight = 32.0;
    const verticalGap = 10.0;

    final placeAbove = y - tooltipHeight - verticalGap >= 0;
    final top = placeAbove
        ? y - tooltipHeight - verticalGap
        : (y + verticalGap).clamp(0.0, chartHeight - tooltipHeight);
    final left = (x - (tooltipWidth / 2)).clamp(0.0, chartWidth - tooltipWidth);

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: tooltipWidth,
        height: tooltipHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MetricsPage.richBlack.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MetricsPage.caribbeanGreen.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: MetricsPage.antiFlashWhite.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WeeklyScanSparklinePainter extends CustomPainter {
  final List<_WeeklyScanBucket> buckets;
  final int maxCount;
  final Color lineColor;
  final int? selectedIndex;

  _WeeklyScanSparklinePainter({
    required this.buckets,
    required this.maxCount,
    required this.lineColor,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;

    final maxValue = maxCount == 0 ? 1 : maxCount;
    final stepX = buckets.length == 1 ? 0.0 : size.width / (buckets.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < buckets.length; i++) {
      final ratio = buckets[i].count / maxValue;
      final x = stepX * i;
      final y = size.height - (size.height * ratio);
      points.add(Offset(x, y));
    }

    final gridPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final dashPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dashHeight = 4.0;
    const dashGap = 4.0;
    for (var i = 0; i < points.length; i++) {
      final x = points[i].dx;
      var y = 0.0;
      while (y < size.height) {
        final yEnd = (y + dashHeight).clamp(0.0, size.height);
        canvas.drawLine(Offset(x, y), Offset(x, yEnd), dashPaint);
        y += dashHeight + dashGap;
      }
    }

    final smoothPath = Path();
    if (points.length == 1) {
      smoothPath.moveTo(points.first.dx, points.first.dy);
    } else {
      smoothPath.moveTo(points.first.dx, points.first.dy);
      for (var i = 0; i < points.length - 1; i++) {
        final p0 = i == 0 ? points[i] : points[i - 1];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

        final cp1 = Offset(
          p1.dx + (p2.dx - p0.dx) / 6,
          p1.dy + (p2.dy - p0.dy) / 6,
        );
        final cp2 = Offset(
          p2.dx - (p3.dx - p1.dx) / 6,
          p2.dy - (p3.dy - p1.dy) / 6,
        );

        smoothPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      }
    }

    final areaPath = Path.from(smoothPath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final gradient = LinearGradient(
      colors: [
        lineColor.withValues(alpha: 0.0),
        lineColor.withValues(alpha: 0.25),
      ],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );

    final areaPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);

    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawPath(smoothPath, glowPaint);

    final lineGradient = LinearGradient(
      colors: [
        lineColor.withValues(alpha: 0.4),
        lineColor,
        lineColor.withValues(alpha: 0.7),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final linePaint = Paint()
      ..shader = lineGradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(smoothPath, linePaint);

    final pointPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final pointInnerPaint = Paint()
      ..color = MetricsPage.antiFlashWhite.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    for (final point in points) {
      canvas.drawCircle(point, 3.6, pointPaint);
      canvas.drawCircle(point, 1.6, pointInnerPaint);
    }

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < points.length) {
      final highlightPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      final glowPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final highlightPoint = points[selected];
      canvas.drawCircle(highlightPoint, 8, glowPaint);
      canvas.drawCircle(highlightPoint, 6, highlightPaint);
      canvas.drawCircle(highlightPoint, 3.6, pointPaint);
      canvas.drawCircle(highlightPoint, 1.6, pointInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyScanSparklinePainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.maxCount != maxCount ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _WeeklyScanBucket {
  final DateTime weekStart;
  final int count;

  const _WeeklyScanBucket({required this.weekStart, required this.count});
}

class _EmptyStateHintCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetricsPage.darkGreen.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MetricsPage.bangladeshGreen.withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: MetricsPage.caribbeanGreen.withValues(alpha: 0.9),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Capture your first tree scan to populate dashboard metrics.',
              style: TextStyle(
                color: MetricsPage.antiFlashWhite.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
