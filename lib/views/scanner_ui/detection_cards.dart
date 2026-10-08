import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../models/mangrove_tree.dart';

class BoundingBoxOverlay extends StatelessWidget {
  final Rect? boundingBox;
  final Rect? frameRect;
  final StabilityAssessment? assessment;

  const BoundingBoxOverlay({
    super.key,
    required this.boundingBox,
    required this.frameRect,
    required this.assessment,
  });

  @override
  Widget build(BuildContext context) {
    final bbox = boundingBox;
    final frame = frameRect;
    if (bbox == null || frame == null) return const SizedBox.shrink();

    final left = frame.left + bbox.left * frame.width;
    final top = frame.top + bbox.top * frame.height;
    final width = bbox.width * frame.width;
    final height = bbox.height * frame.height;

    Color boxColor;
    switch (assessment) {
      case StabilityAssessment.high:
        boxColor = AppColors.caribbeanGreen;
        break;
      case StabilityAssessment.moderate:
        boxColor = const Color(0xFFFFA34D);
        break;
      case StabilityAssessment.low:
        boxColor = Colors.redAccent;
        break;
      default:
        boxColor = AppColors.caribbeanGreen;
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (assessment != null)
            Positioned(
              top: -40,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: boxColor.withValues(alpha: 0.7), width: 1),
                ),
                child: Text(
                  assessment!.name.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.antiFlashWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: boxColor, width: 2.5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: boxColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LiveDetectionCard extends StatelessWidget {
  final StabilityAssessment? assessment;

  const LiveDetectionCard({super.key, required this.assessment});

  @override
  Widget build(BuildContext context) {
    if (assessment == null) return const SizedBox.shrink();

    Color boxColor;
    String description;
    switch (assessment!) {
      case StabilityAssessment.high:
        boxColor = AppColors.caribbeanGreen;
        description =
            "This mangrove shows High Stability. It acts as a primary defense line, capable of absorbing heavy wave energy and resisting gale-force winds. Its deep, interlocking root system makes it highly unlikely to uproot during a storm.";
        break;
      case StabilityAssessment.moderate:
        boxColor = const Color(0xFFFFA34D);
        description =
            "This mangrove shows Moderate Stability. While it offers decent protection, it may suffer branch breakage or partial root loosening during a strong storm. It can handle moderate winds, but it needs surrounding support to stay upright in a typhoon.";
        break;
      case StabilityAssessment.low:
        boxColor = Colors.redAccent;
        description =
            "This mangrove has Low Stability. It provides minimal protection against storm surges and is at high risk of being uprooted by strong winds. In its current state, it may not survive a major weather event and could even become floating debris.";
        break;
    }

    return Positioned(
      left: 16,
      right: 80,
      bottom: 116,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkGreen.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: boxColor.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: boxColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  assessment!.name.toUpperCase(),
                  style: TextStyle(
                    color: boxColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.antiFlashWhite,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}