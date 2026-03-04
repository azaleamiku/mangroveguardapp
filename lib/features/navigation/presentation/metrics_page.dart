import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../home/models/mangrove_tree.dart';
import 'app_header.dart';
import 'recent_scan_page.dart';

class MetricsPage extends StatelessWidget {
  final ValueListenable<List<RecentTreeScan>> scansListenable;

  const MetricsPage({super.key, required this.scansListenable});

  static const Color caribbeanGreen = Color(0xFF00DF81);
  static const Color antiFlashWhite = Color(0xFFF1F7F6);
  static const Color bangladeshGreen = Color(0xFF03624C);
  static const Color darkGreen = Color(0xFF032221);
  static const Color richBlack = Color(0xFF021B1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: richBlack,
      appBar: buildAppHeader('Dashboard'),
      body: ValueListenableBuilder<List<RecentTreeScan>>(
        valueListenable: scansListenable,
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
            ],
          );
        },
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
