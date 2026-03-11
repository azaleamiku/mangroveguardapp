import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../home/models/mangrove_tree.dart';
import 'app_header.dart';
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
      final isReversingIntoList =
          !isPushingPastBottom && isDraggingDown;
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
      appBar: buildAppHeader('Dashboard'),
      body: ValueListenableBuilder<List<RecentTreeScan>>(
        valueListenable: widget.scansListenable,
        builder: (context, scans, _) {
          final totalTrees = scans.length;

          var highCount = 0;
          var moderateCount = 0;
          var lowCount = 0;

          for (final scan in scans) {
            switch (scan.assessment) {
              case StabilityAssessment.high:
                highCount += 1;
              case StabilityAssessment.moderate:
                moderateCount += 1;
              case StabilityAssessment.low:
                lowCount += 1;
            }
          }

          final highRatio = totalTrees == 0 ? 0.0 : highCount / totalTrees;
          final moderateRatio = totalTrees == 0
              ? 0.0
              : moderateCount / totalTrees;
          final lowRatio = totalTrees == 0 ? 0.0 : lowCount / totalTrees;

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
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      _metricsListBottomPadding,
                    ),
                    children: [
                      _HeroSummaryCard(totalTrees: totalTrees),
                      const SizedBox(height: 14),
                      _StabilityDistributionCard(
                        totalTrees: totalTrees,
                        highCount: highCount,
                        moderateCount: moderateCount,
                        lowCount: lowCount,
                        highRatio: highRatio,
                        moderateRatio: moderateRatio,
                        lowRatio: lowRatio,
                      ),
                      if (totalTrees == 0) ...[
                        const SizedBox(height: 14),
                        _EmptyStateHintCard(),
                      ],
                      const SizedBox(height: 12),
                      const _AboutGestureHintCard(),
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
    final title = isArmed
        ? 'Release for App Info'
        : 'Pull up for App Info';

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
                        color: MetricsPage.antiFlashWhite.withValues(alpha: 0.9),
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MetricsPage.antiFlashWhite.withValues(alpha: 0.3),
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
                        color: MetricsPage.bangladeshGreen.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MetricsPage.caribbeanGreen.withValues(alpha: 0.7),
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
                Text(
                  'Guided camera scans run TensorFlow Lite on-device, compute stability from root spread vs trunk width, save results locally, and support PDF export per scan.',
                  style: TextStyle(
                    color: MetricsPage.antiFlashWhite.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: MetricsPage.darkGreen.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: MetricsPage.bangladeshGreen.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Text(
                    'Stability scale: High > 3.0x, Moderate 1.5-3.0x, Low < 1.5x.',
                    style: TextStyle(
                      color: MetricsPage.antiFlashWhite.withValues(alpha: 0.84),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
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
  final int totalTrees;

  const _HeroSummaryCard({required this.totalTrees});

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
            'Mangrove Stability Dashboard',
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.92),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 5),
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
                  label: 'Total trees scanned',
                  value: '$totalTrees',
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

class _StabilityDistributionCard extends StatelessWidget {
  final int totalTrees;
  final int highCount;
  final int moderateCount;
  final int lowCount;
  final double highRatio;
  final double moderateRatio;
  final double lowRatio;

  const _StabilityDistributionCard({
    required this.totalTrees,
    required this.highCount,
    required this.moderateCount,
    required this.lowCount,
    required this.highRatio,
    required this.moderateRatio,
    required this.lowRatio,
  });

  @override
  Widget build(BuildContext context) {
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
            'Stability Classification',
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            totalTrees == 0 ? 'No scans yet' : '$totalTrees scans classified',
            style: TextStyle(
              color: MetricsPage.antiFlashWhite.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _StabilityBarRow(
            label: 'High',
            count: highCount,
            percent: highRatio * 100,
            ratio: highRatio,
            color: MetricsPage.caribbeanGreen,
          ),
          const SizedBox(height: 10),
          _StabilityBarRow(
            label: 'Moderate',
            count: moderateCount,
            percent: moderateRatio * 100,
            ratio: moderateRatio,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 10),
          _StabilityBarRow(
            label: 'Low',
            count: lowCount,
            percent: lowRatio * 100,
            ratio: lowRatio,
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }
}

class _StabilityBarRow extends StatelessWidget {
  final String label;
  final int count;
  final double percent;
  final double ratio;
  final Color color;

  const _StabilityBarRow({
    required this.label,
    required this.count,
    required this.percent,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clampedRatio = ratio.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '$count',
              style: const TextStyle(
                color: MetricsPage.antiFlashWhite,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                color: MetricsPage.antiFlashWhite.withValues(alpha: 0.66),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: Colors.black.withValues(alpha: 0.28),
            child: FractionallySizedBox(
              widthFactor: clampedRatio == 0 ? 0.02 : clampedRatio,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutGestureHintCard extends StatelessWidget {
  const _AboutGestureHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MetricsPage.bangladeshGreen.withValues(alpha: 0.84),
            MetricsPage.darkGreen.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MetricsPage.caribbeanGreen.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.swipe_up_alt_rounded,
              size: 18,
              color: MetricsPage.caribbeanGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'At the bottom, pull up and release for App Info.',
              style: TextStyle(
                color: MetricsPage.antiFlashWhite.withValues(alpha: 0.93),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
