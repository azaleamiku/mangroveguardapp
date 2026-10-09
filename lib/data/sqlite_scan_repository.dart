import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/scan.dart';
import '../models/mangrove_tree.dart';
import 'scan_repository.dart';

/// [ScanRepository] backed by SQLite (Track 2 step 2).
///
/// Replaces the prefs `StringList` rewrite-on-every-mutation pattern with
/// targeted row writes, a `WHERE sync_state != synced` index for the sync
/// queue, and atomic transactions — the ~10 000-row prefs blob gets slower
/// linearly, this doesn't.
///
/// Migration from [PrefsScanRepository] is handled by
/// [SqliteScanRepository.openMigratingFromPrefs], which is idempotent: it
/// copies rows once (flagged in `meta(key='prefs_migrated')`), leaves the
/// prefs key intact as a rollback safety net, and only removes capture files
/// for rows trimmed beyond [maxScans] retention.
class SqliteScanRepository implements ScanRepository {
  static const int maxScans = 10000;
  static const String prefsFlagKey = 'prefs_migrated';

  /// Exposed so tests can create the schema with an alternate factory.
  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS scans (
      id TEXT PRIMARY KEY,
      server_scan_id TEXT NOT NULL,
      tree_id TEXT NOT NULL,
      scanned_at TEXT NOT NULL,
      assessment TEXT NOT NULL,
      prediction_confidence REAL,
      captured_image_path TEXT,
      sync_state TEXT NOT NULL,
      last_error TEXT,
      retry_count INTEGER NOT NULL DEFAULT 0,
      tree_bounds TEXT
    )
  ''';
  static const String createMetaSql = '''
    CREATE TABLE IF NOT EXISTS meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';
  static const String indexSyncStateSql =
      'CREATE INDEX IF NOT EXISTS idx_scans_sync_state ON scans(sync_state)';
  static const String indexScannedAtSql =
      'CREATE INDEX IF NOT EXISTS idx_scans_scanned_at ON scans(scanned_at DESC)';

  final Future<Database> Function() _dbFactory;
  final StreamController<List<Scan>> _controller =
      StreamController<List<Scan>>.broadcast();
  Database? _db;

  SqliteScanRepository({Future<Database> Function()? dbFactory})
      : _dbFactory = dbFactory ?? _defaultOpen;

  static Future<Database> _defaultOpen() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'mangroveguard_scans.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(createTableSql);
        await db.execute(createMetaSql);
        await db.execute(indexSyncStateSql);
        await db.execute(indexScannedAtSql);
      },
    );
  }

  /// Open with a one-time copy from the legacy prefs store.
  ///
  /// [legacyRows] returns scans already decoded from the legacy prefs
  /// `StringList`; when null (e.g. already migrated), this is a no-op. On
  /// first open, rows beyond [maxScans] are trimmed (newest kept); callers
  /// should diff the input against what persisted to GC orphaned captures.
  static Future<SqliteScanRepository> openMigratingFromPrefs({
    Future<Database> Function()? dbFactory,
    Future<List<Scan>> Function()? legacyRows,
  }) async {
    final repo = SqliteScanRepository(dbFactory: dbFactory);
    final db = await repo._database();
    final flagRow = await db
        .query('meta', where: 'key = ?', whereArgs: [prefsFlagKey]);
    if (flagRow.isEmpty && legacyRows != null) {
      final rows = await legacyRows();
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final scan in rows) {
          batch.insert('scans', _scanToRow(scan),
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await batch.commit(noResult: true);
        await txn.insert('meta', {
          'key': prefsFlagKey,
          'value': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.rawDelete(
          'DELETE FROM scans WHERE id IN ('
          'SELECT id FROM scans ORDER BY scanned_at DESC LIMIT -1 OFFSET ?)',
          [maxScans],
        );
      });
    }
    return repo;
  }

  Future<Database> _database() async => _db ??= await _dbFactory();

  Future<void> _emit() async {
    if (_controller.isClosed) return;
    try {
      _controller.add(await getAll());
    } catch (_) {}
  }

  static Map<String, Object?> _scanToRow(Scan scan) => {
        'id': scan.id,
        'server_scan_id': scan.serverScanId,
        'tree_id': scan.treeId,
        'scanned_at': scan.scannedAt.toIso8601String(),
        'assessment': scan.assessment.name,
        'prediction_confidence': scan.predictionConfidence,
        'captured_image_path': scan.capturedImagePath,
        'sync_state': scan.syncState.name,
        'last_error': scan.lastError,
        'retry_count': scan.retryCount,
        'tree_bounds': scan.treeBounds == null
            ? null
            : jsonEncode({
                'left': scan.treeBounds!.left,
                'top': scan.treeBounds!.top,
                'right': scan.treeBounds!.right,
                'bottom': scan.treeBounds!.bottom,
              }),
      };

  static Scan _rowToScan(Map<String, Object?> row) {
    TreeBounds? bounds;
    final boundsRaw = row['tree_bounds'] as String?;
    if (boundsRaw != null && boundsRaw.isNotEmpty) {
      try {
        final map = jsonDecode(boundsRaw) as Map<String, dynamic>;
        bounds = TreeBounds(
          left: (map['left'] as num).toDouble(),
          top: (map['top'] as num).toDouble(),
          right: (map['right'] as num).toDouble(),
          bottom: (map['bottom'] as num).toDouble(),
        );
      } catch (_) {}
    }
    return Scan(
      id: row['id'] as String,
      serverScanId: row['server_scan_id'] as String,
      treeId: row['tree_id'] as String,
      scannedAt: DateTime.tryParse(row['scanned_at'] as String? ?? '') ??
          DateTime.now(),
      assessment: _parseAssessment(row['assessment'] as String?),
      predictionConfidence:
          (row['prediction_confidence'] as num?)?.toDouble(),
      capturedImagePath: row['captured_image_path'] as String?,
      syncState: _parseSyncState(row['sync_state'] as String?),
      lastError: row['last_error'] as String?,
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
      treeBounds: bounds,
    );
  }

  static StabilityAssessment _parseAssessment(String? raw) {
    if (raw == null) return StabilityAssessment.low;
    for (final value in StabilityAssessment.values) {
      if (value.name == raw) return value;
    }
    return StabilityAssessment.low;
  }

  static SyncState _parseSyncState(String? raw) {
    if (raw == null) return SyncState.pending;
    for (final value in SyncState.values) {
      if (value.name == raw) return value;
    }
    return SyncState.pending;
  }


  @override
  Stream<List<Scan>> watch() async* {
    yield await getAll();
    yield* _controller.stream;
  }

  @override
  Future<List<Scan>> getAll() async {
    final db = await _database();
    final rows = await db
        .query('scans', orderBy: 'scanned_at DESC', limit: maxScans);
    return rows.map(_rowToScan).toList(growable: false);
  }

  @override
  Future<List<Scan>> getPending() async {
    final db = await _database();
    final rows = await db.query(
      'scans',
      where: 'sync_state != ?',
      whereArgs: [SyncState.synced.name],
      orderBy: 'scanned_at DESC',
    );
    return rows.map(_rowToScan).toList(growable: false);
  }

  @override
  Future<void> add(Scan scan) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.insert('scans', _scanToRow(scan),
          conflictAlgorithm: ConflictAlgorithm.replace);
      // Retention trim (newest kept), mirroring prefs cap semantics.
      await txn.rawDelete(
        'DELETE FROM scans WHERE id IN ('
        'SELECT id FROM scans ORDER BY scanned_at DESC LIMIT -1 OFFSET ?)',
        [maxScans],
      );
    });
    await _emit();
  }

  @override
  Future<void> removeById(String id) async {
    final db = await _database();
    await db.delete('scans', where: 'id = ?', whereArgs: [id]);
    await _emit();
  }

  @override
  Future<void> markSyncing(String id) =>
      _updateState(id, SyncState.syncing, bumpRetry: false);

  @override
  Future<void> markSynced(String id) =>
      _updateState(id, SyncState.synced, clearError: true);

  @override
  Future<void> markFailed(String id, String error) =>
      _updateState(id, SyncState.failed, error: error);

  Future<void> _updateState(
    String id,
    SyncState state, {
    bool bumpRetry = true,
    bool clearError = false,
    String? error,
  }) async {
    final db = await _database();
    // `retry_count + 1` is column arithmetic, so this must be raw SQL (sqflite
    // `update` values only accept literals).
    if (bumpRetry) {
      await db.rawUpdate(
        'UPDATE scans SET sync_state = ?, last_error = ?, '
        'retry_count = retry_count + 1 WHERE id = ?',
        [
          state.name,
          clearError ? null : error,
          id,
        ],
      );
    } else {
      await db.update(
        'scans',
        {
          'sync_state': state.name,
          if (clearError) 'last_error': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await _emit();
  }

  @override
  Future<int> clearSynced() async {
    final db = await _database();
    final removed = await db.delete('scans',
        where: 'sync_state = ?', whereArgs: [SyncState.synced.name]);
    if (removed > 0) await _emit();
    return removed;
  }

  @override
  Future<void> replaceAll(List<Scan> scans) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.delete('scans');
      final batch = txn.batch();
      for (final scan in scans) {
        batch.insert('scans', _scanToRow(scan),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    await _emit();
  }

  Future<void> dispose() async {
    await _controller.close();
    final db = _db;
    _db = null;
    await db?.close();
  }
}
