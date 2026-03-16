import 'dart:ui';
import 'dart:math' as math;

class Root {
  final Offset position;
  final double length;
  final double angle;
  final double? normalizedLeft;
  final double? normalizedTop;
  final double? normalizedRight;
  final double? normalizedBottom;

  const Root({
    required this.position,
    required this.length,
    required this.angle,
    this.normalizedLeft,
    this.normalizedTop,
    this.normalizedRight,
    this.normalizedBottom,
  });

  // Horizontal endpoint in pixels, using root angle in radians.
  double get endpointX => position.dx + (length * math.cos(angle));
}

class TrunkMeasurement {
  final double startX;
  final double endX;
  final double y;
  final bool isEstimated;

  const TrunkMeasurement({
    required this.startX,
    required this.endX,
    required this.y,
    this.isEstimated = false,
  });
}

class TreeBounds {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const TreeBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}

enum StabilityAssessment { high, moderate, low }

extension StabilityAssessmentExtension on StabilityAssessment {
  String get description {
    switch (this) {
      case StabilityAssessment.high:
        return 'High Stability - Root spread is more than three times the trunk width';
      case StabilityAssessment.moderate:
        return 'Moderate Stability - Foundation is sufficient for normal tides but might struggle in a major storm surge';
      case StabilityAssessment.low:
        return 'Low Stability - Roots are dropping almost straight down. The mangrove is "top-heavy" and relies more on the mud\'s grip than structural geometry';
    }
  }
}

class MangroveTree {
  final double trunkWidthAtBranchPoint;
  final List<Root> roots;
  final TrunkMeasurement? trunkMeasurement;
  final TreeBounds? treeBounds;

  const MangroveTree({
    required this.trunkWidthAtBranchPoint,
    required this.roots,
    this.trunkMeasurement,
    this.treeBounds,
  });

  double get trunkWidthPixels => trunkWidthAtBranchPoint;

  double get rootSpread {
    if (roots.isEmpty) return 0;

    double minX = roots.first.endpointX;
    double maxX = roots.first.endpointX;

    for (final root in roots) {
      final endX = root.endpointX;
      if (endX < minX) minX = endX;
      if (endX > maxX) maxX = endX;
    }

    return (maxX - minX).abs();
  }

  double get rootSpreadPixels => rootSpread;

  double get stabilityIndex {
    if (trunkWidthAtBranchPoint <= 0) return 0;
    return rootSpread / trunkWidthAtBranchPoint;
  }

  StabilityAssessment get assessment {
    final ratio = stabilityIndex;
    if (ratio > 3) return StabilityAssessment.high;
    if (ratio >= 1.5) return StabilityAssessment.moderate;
    return StabilityAssessment.low;
  }
}
