import '../models/mangrove_tree.dart';

class RecentTreeScan {
  final String treeId;
  final DateTime scannedAt;
  final MangroveTree tree;
  final double? predictionConfidence;
  final StabilityAssessment? predictedAssessment;
  final String? capturedImagePath;
  final bool isSynced;

  /// Stable identity minted at creation and persisted in JSON.
  ///
  /// Previously the UI identified scans by list index and the sync layer
  /// derived `scan_id` per-attempt (`scan-{treeId}-{ms}`), so a rescan in
  /// the same millisecond or a re-sort could collide/shift targets. This id
  /// is now the single identity shared with the domain [Scan] layer and the
  /// backend `INSERT OR IGNORE` idempotency key.
  final String scanId;

  const RecentTreeScan({
    required this.treeId,
    required this.scannedAt,
    required this.tree,
    this.predictionConfidence,
    this.predictedAssessment,
    this.capturedImagePath,
    this.isSynced = false,
    this.scanId = '',
  });

  /// Effective stable id: explicit [scanId] when present, otherwise the
  /// legacy derived key. Used everywhere identity matters so rows created
  /// before ids were minted still resolve deterministically.
  String get effectiveScanId => scanId.trim().isNotEmpty
      ? scanId
      : 'scan-$treeId-${scannedAt.millisecondsSinceEpoch}';

  /// Mint a copy with a stable id when this instance predates ids.
  RecentTreeScan withStableId([String? id]) {
    if (scanId.trim().isNotEmpty) return this;
    final stable = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : 'scan-$treeId-${scannedAt.millisecondsSinceEpoch}';
    return RecentTreeScan(
      scanId: stable,
      treeId: treeId,
      scannedAt: scannedAt,
      tree: tree,
      predictionConfidence: predictionConfidence,
      predictedAssessment: predictedAssessment,
      capturedImagePath: capturedImagePath,
      isSynced: isSynced,
    );
  }

  StabilityAssessment get assessment =>
      predictedAssessment ?? StabilityAssessment.low;

  Map<String, dynamic> toJson() {
    return {
      'scanId': scanId,
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
    final scannedAtValue = scannedAtRaw == null
        ? DateTime.now()
        : (DateTime.tryParse(scannedAtRaw) ?? DateTime.now());
    final treeIdValue = (json['treeId'] as String?)?.trim().isNotEmpty == true
        ? json['treeId'] as String
        : 'Tree';
    final scanIdValue =
        (json['scanId'] as String?)?.trim().isNotEmpty == true
        ? (json['scanId'] as String)
        : 'scan-$treeIdValue-${scannedAtValue.millisecondsSinceEpoch}';
    return RecentTreeScan(
      scanId: scanIdValue,
      treeId: treeIdValue,
      scannedAt: scannedAtValue,
      predictionConfidence: (json['predictionConfidence'] as num?)?.toDouble(),
      predictedAssessment: predictedAssessment,
      capturedImagePath:
          ((json['capturedImagePath'] as String?)?.trim().isNotEmpty ?? false)
          ? (json['capturedImagePath'] as String).trim()
          : null,
      isSynced: (json['isSynced'] as bool?) ?? false,
      tree: MangroveTree(treeBounds: treeBounds),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentTreeScan &&
          runtimeType == other.runtimeType &&
          effectiveScanId == other.effectiveScanId;

  @override
  int get hashCode => effectiveScanId.hashCode;

  /// Copy with a new sync flag, preserving the stable [scanId].
  RecentTreeScan copyWithSynced(bool synced) {
    return RecentTreeScan(
      scanId: scanId,
      treeId: treeId,
      scannedAt: scannedAt,
      tree: tree,
      predictionConfidence: predictionConfidence,
      predictedAssessment: predictedAssessment,
      capturedImagePath: capturedImagePath,
      isSynced: synced,
    );
  }
}
