import '../models/mangrove_tree.dart';

class RecentTreeScan {
  final String treeId;
  final DateTime scannedAt;
  final MangroveTree tree;
  final double? predictionConfidence;
  final StabilityAssessment? predictedAssessment;
  final String? capturedImagePath;
  final bool isSynced;

  const RecentTreeScan({
    required this.treeId,
    required this.scannedAt,
    required this.tree,
    this.predictionConfidence,
    this.predictedAssessment,
    this.capturedImagePath,
    this.isSynced = false,
  });

  StabilityAssessment get assessment =>
      predictedAssessment ?? StabilityAssessment.low;

  Map<String, dynamic> toJson() {
    return {
      'treeId': treeId,
      'scannedAt': scannedAt.toIso8601String(),
      if (predictionConfidence != null)
        'predictionConfidence': predictionConfidence,
      if (predictedAssessment != null)
        'predictedAssessment': predictedAssessment!.name,
      if (capturedImagePath != null) 'capturedImagePath': capturedImagePath,
      'isSynced': isSynced,
      'tree': {
        if (tree.treeBounds != null)
          'treeBounds': {
            'left': tree.treeBounds!.left,
            'top': tree.treeBounds!.top,
            'right': tree.treeBounds!.right,
            'bottom': tree.treeBounds!.bottom,
          },
      },
    };
  }

  factory RecentTreeScan.fromJson(Map<String, dynamic> json) {
    final treeMap = (json['tree'] as Map?)?.cast<String, dynamic>() ?? const {};

    final treeBoundsRaw = (treeMap['treeBounds'] as Map?)
        ?.cast<String, dynamic>();
    TreeBounds? treeBounds;
    if (treeBoundsRaw != null) {
      final left = (treeBoundsRaw['left'] as num?)?.toDouble();
      final top = (treeBoundsRaw['top'] as num?)?.toDouble();
      final right = (treeBoundsRaw['right'] as num?)?.toDouble();
      final bottom = (treeBoundsRaw['bottom'] as num?)?.toDouble();
      if (left != null && top != null && right != null && bottom != null) {
        treeBounds = TreeBounds(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        );
      }
    }

    final scannedAtRaw = json['scannedAt'] as String?;
    final predictedAssessmentRaw = json['predictedAssessment'] as String?;
    StabilityAssessment? predictedAssessment;
    if (predictedAssessmentRaw != null) {
      for (final assessment in StabilityAssessment.values) {
        if (assessment.name.toLowerCase() ==
            predictedAssessmentRaw.toLowerCase()) {
          predictedAssessment = assessment;
          break;
        }
      }
    }
    return RecentTreeScan(
      treeId: (json['treeId'] as String?)?.trim().isNotEmpty == true
          ? json['treeId'] as String
          : 'Tree',
      scannedAt: scannedAtRaw == null
          ? DateTime.now()
          : (DateTime.tryParse(scannedAtRaw) ?? DateTime.now()),
      predictionConfidence: (json['predictionConfidence'] as num?)?.toDouble(),
      predictedAssessment: predictedAssessment,
      capturedImagePath:
          ((json['capturedImagePath'] as String?)?.trim().isNotEmpty ?? false)
              ? (json['capturedImagePath'] as String).trim()
              : null,
      isSynced: (json['isSynced'] as bool?) ?? false,
      tree: MangroveTree(
        treeBounds: treeBounds,
      ),
    );
  }
}
