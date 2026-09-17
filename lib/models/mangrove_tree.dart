
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
        return 'Well-distributed support structure.';
      case StabilityAssessment.moderate:
        return 'Support is adequate but may be vulnerable.';
      case StabilityAssessment.low:
        return 'Structure is limited or uneven; stability compromised.';
    }
  }
}

class MangroveTree {
  final TreeBounds? treeBounds;

  const MangroveTree({
    this.treeBounds,
  });
}
