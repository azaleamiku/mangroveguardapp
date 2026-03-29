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
        return 'High Stability (0.75–1.00) — Dense, well-distributed prop roots provide strong structural support.';
      case StabilityAssessment.moderate:
        return 'Moderate Stability (0.50–0.74) — Root support is adequate but may be vulnerable under stronger stressors.';
      case StabilityAssessment.low:
        return 'Low Stability (0.00–0.49) — Root structure is limited or uneven; stability may be compromised.';
    }
  }
}

class StabilityMetrics {
  static const int _kMaxRoots = 96;
  static const double _kRootThicknessNormMax = 0.05;

  final int rootCount;
  final double rootDensity;
  final double rootSpread;
  final double rootCoverageRatio;
  final double symmetryScore;
  final double rootThicknessProxy;
  final double stabilityScore;
  final StabilityAssessment assessment;

  const StabilityMetrics({
    required this.rootCount,
    required this.rootDensity,
    required this.rootSpread,
    required this.rootCoverageRatio,
    required this.symmetryScore,
    required this.rootThicknessProxy,
    required this.stabilityScore,
    required this.assessment,
  });

  factory StabilityMetrics.fromTree(MangroveTree tree) {
    final roots = tree.roots;
    final rootCount = roots.length;

    final trunkCentroid = _trunkCentroid(tree);
    final rootRects = <Rect>[];
    final rootCentroids = <Offset>[];

    for (final root in roots) {
      final rect = _rootRectNormalized(root);
      if (rect == null) continue;
      rootRects.add(rect);
      rootCentroids.add(
        Offset((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2),
      );
    }

    final roi = _roiBounds(tree.treeBounds, rootRects);
    final roiWidth = (roi.right - roi.left).abs();
    final roiHeight = (roi.bottom - roi.top).abs();
    final roiArea = math.max(roiWidth * roiHeight, 1e-9);
    final roiDiagonal = math.sqrt(
      (roiWidth * roiWidth) + (roiHeight * roiHeight),
    );

    var rootAreaSum = 0.0;
    for (final rect in rootRects) {
      final w = (rect.right - rect.left).clamp(0.0, 1.0);
      final h = (rect.bottom - rect.top).clamp(0.0, 1.0);
      rootAreaSum += w * h;
    }

    final rootCoverageRatio = (rootAreaSum / roiArea).clamp(0.0, 1.0);
    final rootThicknessProxy = rootCount == 0 ? 0.0 : (rootAreaSum / rootCount);
    final rootDensity = rootCount / roiArea;

    // Root spread (RS) is defined as the horizontal span of root endpoints.
    final rootSpread = tree.rootSpread;
    final thetas = <double>[];
    if (rootCentroids.isNotEmpty) {
      for (final centroid in rootCentroids) {
        final dx = centroid.dx - trunkCentroid.dx;
        final dy = centroid.dy - trunkCentroid.dy;
        thetas.add(math.atan2(dy, dx));
      }
    }

    final symmetryScore = _symmetryScoreFromAngles(thetas);

    final rcNorm = (rootCount / _kMaxRoots).clamp(0.0, 1.0);
    final rdNorm = (rootDensity / _kMaxRoots).clamp(0.0, 1.0);
    final rsNorm = roiDiagonal <= 0
        ? 0.0
        : (rootSpread / roiDiagonal).clamp(0.0, 1.0);
    final rcrNorm = rootCoverageRatio.clamp(0.0, 1.0);
    final ssNorm = symmetryScore.clamp(0.0, 1.0);
    final rtNorm = (rootThicknessProxy / _kRootThicknessNormMax).clamp(
      0.0,
      1.0,
    );

    final stabilityScore =
        (0.20 * rcNorm) +
        (0.15 * rdNorm) +
        (0.20 * rsNorm) +
        (0.15 * rcrNorm) +
        (0.20 * ssNorm) +
        (0.10 * rtNorm);
    final clampedScore = stabilityScore.clamp(0.0, 1.0);
    final assessment = switch (clampedScore) {
      >= 0.75 => StabilityAssessment.high,
      >= 0.50 => StabilityAssessment.moderate,
      _ => StabilityAssessment.low,
    };

    return StabilityMetrics(
      rootCount: rootCount,
      rootDensity: rootDensity,
      rootSpread: rootSpread,
      rootCoverageRatio: rootCoverageRatio,
      symmetryScore: symmetryScore,
      rootThicknessProxy: rootThicknessProxy,
      stabilityScore: clampedScore,
      assessment: assessment,
    );
  }

  static Offset _trunkCentroid(MangroveTree tree) {
    final trunkMeasurement = tree.trunkMeasurement;
    if (trunkMeasurement != null) {
      return Offset(
        (trunkMeasurement.startX + trunkMeasurement.endX) / 2,
        trunkMeasurement.y,
      );
    }
    final bounds = tree.treeBounds;
    if (bounds != null) {
      return Offset(
        (bounds.left + bounds.right) / 2,
        (bounds.top + bounds.bottom) / 2,
      );
    }
    return const Offset(0.5, 0.6);
  }

  static Rect _roiBounds(TreeBounds? trunkBounds, List<Rect> rootRects) {
    var minX = 1.0;
    var minY = 1.0;
    var maxX = 0.0;
    var maxY = 0.0;
    var hasAny = false;

    void includeRect(Rect rect) {
      hasAny = true;
      minX = math.min(minX, rect.left);
      minY = math.min(minY, rect.top);
      maxX = math.max(maxX, rect.right);
      maxY = math.max(maxY, rect.bottom);
    }

    if (trunkBounds != null) {
      includeRect(
        Rect.fromLTRB(
          trunkBounds.left.clamp(0.0, 1.0),
          trunkBounds.top.clamp(0.0, 1.0),
          trunkBounds.right.clamp(0.0, 1.0),
          trunkBounds.bottom.clamp(0.0, 1.0),
        ),
      );
    }
    for (final rect in rootRects) {
      includeRect(rect);
    }

    if (!hasAny) return const Rect.fromLTRB(0, 0, 1, 1);
    return Rect.fromLTRB(
      minX.clamp(0.0, 1.0),
      minY.clamp(0.0, 1.0),
      maxX.clamp(0.0, 1.0),
      maxY.clamp(0.0, 1.0),
    );
  }

  static Rect? _rootRectNormalized(Root root) {
    final left = root.normalizedLeft;
    final top = root.normalizedTop;
    final right = root.normalizedRight;
    final bottom = root.normalizedBottom;
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    final l = left.clamp(0.0, 1.0);
    final t = top.clamp(0.0, 1.0);
    final r = right.clamp(0.0, 1.0);
    final b = bottom.clamp(0.0, 1.0);
    if (r <= l || b <= t) return null;
    return Rect.fromLTRB(l, t, r, b);
  }

  static double _symmetryScoreFromAngles(List<double> angles) {
    if (angles.isEmpty) return 0.0;

    var cosSum = 0.0;
    var sinSum = 0.0;
    for (final theta in angles) {
      cosSum += math.cos(theta);
      sinSum += math.sin(theta);
    }
    final n = angles.length.toDouble();
    final meanCos = cosSum / n;
    final meanSin = sinSum / n;
    final r = math
        .sqrt((meanCos * meanCos) + (meanSin * meanSin))
        .clamp(0.0, 1.0);

    final circularStd = r <= 0
        ? math.pi
        : math.sqrt(-2.0 * math.log(r)).clamp(0.0, math.pi);
    return (1.0 - (circularStd / math.pi)).clamp(0.0, 1.0);
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

  StabilityMetrics get stabilityMetrics => StabilityMetrics.fromTree(this);

  double get stabilityScore => stabilityMetrics.stabilityScore;

  double get symmetryScore => stabilityMetrics.symmetryScore;

  StabilityAssessment get assessment {
    return stabilityMetrics.assessment;
  }
}
