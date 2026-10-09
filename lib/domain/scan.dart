import '../models/mangrove_tree.dart';

/// Sync lifecycle for a locally stored scan.
enum SyncState { pending, syncing, synced, failed }

/// Domain entity for a field scan.
///
/// Unlike [RecentTreeScan] (the UI view-model), [Scan] carries a stable
/// identity ([id] / [serverScanId]) that survives re-sorts, restarts, and
/// retries — so sync, deletion, and the backend `INSERT OR IGNORE`
/// idempotency key all refer to the same record.
class Scan {
  /// Stable local identity, persisted at creation (UUID v4-style).
  final String id;

  /// Backend idempotency key sent as `scan_id`. Stable across retries so a
  /// re-POST of the same scan is a no-op server-side instead of a duplicate.
  final String serverScanId;

  final String treeId;
  final DateTime scannedAt;
  final StabilityAssessment assessment;
  final double? predictionConfidence;
  final String? capturedImagePath;
  final SyncState syncState;
  final String? lastError;
  final int retryCount;

  /// Mangrove bounding box (normalized 0–1) for the highlight overlay.
  /// Persisted so the recents overlay survives the repository round-trip —
  /// dropping it would blank the detection overlay.
  final TreeBounds? treeBounds;

  const Scan({
    required this.id,
    required this.serverScanId,
    required this.treeId,
    required this.scannedAt,
    required this.assessment,
    this.predictionConfidence,
    this.capturedImagePath,
    this.syncState = SyncState.pending,
    this.lastError,
    this.retryCount = 0,
    this.treeBounds,
  });

  bool get isSynced => syncState == SyncState.synced;

  Scan copyWith({
    String? id,
    String? serverScanId,
    String? treeId,
    DateTime? scannedAt,
    StabilityAssessment? assessment,
    double? Function()? predictionConfidence,
    String? Function()? capturedImagePath,
    SyncState? syncState,
    String? Function()? lastError,
    int? retryCount,
    TreeBounds? treeBounds,
  }) {
    return Scan(
      id: id ?? this.id,
      serverScanId: serverScanId ?? this.serverScanId,
      treeId: treeId ?? this.treeId,
      scannedAt: scannedAt ?? this.scannedAt,
      assessment: assessment ?? this.assessment,
      predictionConfidence: predictionConfidence != null
          ? predictionConfidence()
          : this.predictionConfidence,
      capturedImagePath: capturedImagePath != null
          ? capturedImagePath()
          : this.capturedImagePath,
      syncState: syncState ?? this.syncState,
      lastError: lastError != null ? lastError() : this.lastError,
      retryCount: retryCount ?? this.retryCount,
      treeBounds: treeBounds ?? this.treeBounds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serverScanId': serverScanId,
      'treeId': treeId,
      'scannedAt': scannedAt.toIso8601String(),
      'assessment': assessment.name,
      if (predictionConfidence != null)
        'predictionConfidence': predictionConfidence,
      if (capturedImagePath != null) 'capturedImagePath': capturedImagePath,
      'syncState': syncState.name,
      if (lastError != null) 'lastError': lastError,
      'retryCount': retryCount,
      if (treeBounds != null)
        'treeBounds': {
          'left': treeBounds!.left,
          'top': treeBounds!.top,
          'right': treeBounds!.right,
          'bottom': treeBounds!.bottom,
        },
    };
  }

  factory Scan.fromJson(Map<String, dynamic> json) {
    StabilityAssessment assessment = StabilityAssessment.low;
    final rawAssessment = json['assessment'] as String?;
    if (rawAssessment != null) {
      for (final value in StabilityAssessment.values) {
        if (value.name.toLowerCase() == rawAssessment.toLowerCase()) {
          assessment = value;
          break;
        }
      }
    }
    SyncState syncState = SyncState.pending;
    final rawSync = json['syncState'] as String?;
    if (rawSync != null) {
      for (final value in SyncState.values) {
        if (value.name == rawSync) {
          syncState = value;
          break;
        }
      }
    }
    // Back-compat: rows written before stable ids derive serverScanId from
    // the legacy scan-{treeId}-{ms} scheme; isSynced maps to SyncState.synced.
    final legacySynced = (json['isSynced'] as bool?) ?? false;
    if (rawSync == null && legacySynced) syncState = SyncState.synced;
    final scannedAtRaw = json['scannedAt'] as String?;
    final id = (json['id'] as String?)?.trim();
    final treeId = (json['treeId'] as String?)?.trim();
    final scannedAt =
        scannedAtRaw == null ? DateTime.now() : (DateTime.tryParse(scannedAtRaw) ?? DateTime.now());
    final resolvedId = (id != null && id.isNotEmpty)
        ? id
        : 'scan-${treeId ?? 'unknown'}-${scannedAt.millisecondsSinceEpoch}';
    final serverScanId = (json['serverScanId'] as String?)?.trim();
    // Bounds may be flat here or nested under the legacy `tree.treeBounds`.
    final boundsMap = (json['treeBounds'] as Map?)?.cast<String, dynamic>() ??
        ((json['tree'] as Map?)?.cast<String, dynamic>()?['treeBounds']
            as Map?)
            ?.cast<String, dynamic>();
    TreeBounds? treeBounds;
    if (boundsMap != null) {
      final left = (boundsMap['left'] as num?)?.toDouble();
      final top = (boundsMap['top'] as num?)?.toDouble();
      final right = (boundsMap['right'] as num?)?.toDouble();
      final bottom = (boundsMap['bottom'] as num?)?.toDouble();
      if (left != null && top != null && right != null && bottom != null) {
        treeBounds =
            TreeBounds(left: left, top: top, right: right, bottom: bottom);
      }
    }
    return Scan(
      id: resolvedId,
      serverScanId: (serverScanId != null && serverScanId.isNotEmpty)
          ? serverScanId
          : resolvedId,
      treeId: (treeId != null && treeId.isNotEmpty) ? treeId : 'Tree',
      scannedAt: scannedAt,
      assessment: assessment,
      predictionConfidence: (json['predictionConfidence'] as num?)?.toDouble(),
      capturedImagePath:
          ((json['capturedImagePath'] as String?)?.trim().isNotEmpty ?? false)
          ? (json['capturedImagePath'] as String).trim()
          : null,
      syncState: syncState,
      lastError: json['lastError'] as String?,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      treeBounds: treeBounds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Scan && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
