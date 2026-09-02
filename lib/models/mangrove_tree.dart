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
  String get label {
    switch (this) {
      case StabilityAssessment.high:
        return 'High Stability';
      case StabilityAssessment.moderate:
        return 'Moderate Stability';
      case StabilityAssessment.low:
        return 'Low Stability';
    }
  }

  String get description {
    switch (this) {
      case StabilityAssessment.high:
        return 'High Stability (0.75–1.00) — Well-distributed support structure.';
      case StabilityAssessment.moderate:
        return 'Moderate Stability (0.50–0.74) — Support is adequate but may be vulnerable.';
      case StabilityAssessment.low:
        return 'Low Stability (0.00–0.49) — Structure is limited or uneven; stability compromised.';
    }
  }
}

class MangroveTree {
  final double trunkWidthAtBranchPoint;
  final TrunkMeasurement? trunkMeasurement;
  final TreeBounds? treeBounds;

  const MangroveTree({
    required this.trunkWidthAtBranchPoint,
    this.trunkMeasurement,
    this.treeBounds,
  });

  double get trunkWidthPixels => trunkWidthAtBranchPoint;
}
