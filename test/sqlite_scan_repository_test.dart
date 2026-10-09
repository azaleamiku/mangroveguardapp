import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangroveguardapp/data/sqlite_scan_repository.dart';
import 'package:mangroveguardapp/domain/scan.dart';
import 'package:mangroveguardapp/models/mangrove_tree.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Scan _scan(String id, DateTime scannedAt,
    {SyncState syncState = SyncState.pending}) {
  return Scan(
    id: id,
    serverScanId: id,
    treeId: 'MG-01-123456',
    scannedAt: scannedAt,
    assessment: StabilityAssessment.low,
    syncState: syncState,
  );
}

/// Opens a fresh handle to a SHARED temp file on every call, so state
/// survives `dispose()` (close) — the reopen test needs the meta flag to
/// persist across two opens. [path] is returned so tests can clean up.
String _newDbPath() {
  final dir = p.join(Directory.systemTemp.path,
      'mangrove_test_${DateTime.now().microsecondsSinceEpoch}.db');
  return dir;
}

Future<Database> Function() _factoryFor(String path) {
  return () {
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) async {
          await d.execute(SqliteScanRepository.createTableSql);
          await d.execute(SqliteScanRepository.createMetaSql);
          await d.execute(SqliteScanRepository.indexSyncStateSql);
          await d.execute(SqliteScanRepository.indexScannedAtSql);
        },
      ),
    );
  };
}

Future<void> _cleanup(String path) async {
  try {
    await databaseFactoryFfi.deleteDatabase(path);
  } catch (_) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteScanRepository repository;
  late String repoPath;

  setUp(() async {
    repoPath = _newDbPath();
    repository = SqliteScanRepository(dbFactory: _factoryFor(repoPath));
    await repository.getAll(); // Force schema creation.
  });

  tearDown(() async {
    await repository.dispose();
    await _cleanup(repoPath);
  });

  group('SqliteScanRepository', () {
    test('add + getAll keeps newest first', () async {
      await repository.add(_scan('a', DateTime.utc(2026, 1, 1)));
      await repository.add(_scan('b', DateTime.utc(2026, 1, 2)));

      final all = await repository.getAll();
      expect(all.map((s) => s.id), ['b', 'a']);
    });

    test('round-trips all fields through SQLite', () async {
      final scan = Scan(
        id: 'full-1',
        serverScanId: 'server-1',
        treeId: 'MG-01-123456',
        scannedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        assessment: StabilityAssessment.high,
        predictionConfidence: 0.91,
        capturedImagePath: '/tmp/cap.jpg',
        syncState: SyncState.failed,
        lastError: 'boom',
        retryCount: 3,
      );

      await repository.add(scan);
      final restored = (await repository.getAll()).single;

      expect(restored.id, 'full-1');
      expect(restored.serverScanId, 'server-1');
      expect(restored.assessment, StabilityAssessment.high);
      expect(restored.predictionConfidence, 0.91);
      expect(restored.capturedImagePath, '/tmp/cap.jpg');
      expect(restored.syncState, SyncState.failed);
      expect(restored.lastError, 'boom');
      expect(restored.retryCount, 3);
      expect(restored.scannedAt, scan.scannedAt);
    });

    test('add is idempotent via INSERT OR REPLACE', () async {
      await repository.add(_scan('dup', DateTime.utc(2026, 1, 1)));
      await repository.add(
          _scan('dup', DateTime.utc(2026, 1, 1), syncState: SyncState.synced));

      final all = await repository.getAll();
      expect(all.length, 1);
      expect(all.first.syncState, SyncState.synced);
    });

    test('sync state transitions and retry counter', () async {
      await repository.add(_scan('a', DateTime.utc(2026, 1, 1)));

      await repository.markSyncing('a');
      expect((await repository.getAll()).single.syncState, SyncState.syncing);
      expect((await repository.getAll()).single.retryCount, 0);

      await repository.markSynced('a');
      var row = (await repository.getAll()).single;
      expect(row.syncState, SyncState.synced);
      expect(row.retryCount, 1);

      await repository.markFailed('a', 'timeout');
      row = (await repository.getAll()).single;
      expect(row.syncState, SyncState.failed);
      expect(row.lastError, 'timeout');
      expect(row.retryCount, 2);
    });

    test('markSynced clears lastError', () async {
      await repository.add(_scan('a', DateTime.utc(2026, 1, 1)));
      await repository.markFailed('a', 'nope');
      await repository.markSynced('a');

      final row = (await repository.getAll()).single;
      expect(row.syncState, SyncState.synced);
      expect(row.lastError, isNull);
    });

    test('getPending excludes only synced rows', () async {
      await repository.add(_scan('a', DateTime.utc(2026, 1, 1)));
      await repository.add(_scan('b', DateTime.utc(2026, 1, 2)));
      await repository.add(_scan('c', DateTime.utc(2026, 1, 3)));
      await repository.markSynced('a');
      await repository.markFailed('c', 'err');

      final pending = await repository.getPending();
      expect(pending.map((s) => s.id), ['c', 'b']);
    });

    test('removeById and clearSynced', () async {
      await repository.add(_scan('a', DateTime.utc(2026, 1, 1)));
      await repository.add(_scan('b', DateTime.utc(2026, 1, 2)));
      await repository.markSynced('a');

      await repository.removeById('b');
      expect((await repository.getAll()).map((s) => s.id), ['a']);

      expect(await repository.clearSynced(), 1);
      expect(await repository.getAll(), isEmpty);
    });

    test('replaceAll is atomic and re-sorts unsorted input', () async {
      await repository.add(_scan('x', DateTime.utc(2026, 1, 9)));
      await repository.replaceAll([
        _scan('low', DateTime.utc(2026, 1, 1)),
        _scan('high', DateTime.utc(2026, 1, 5)),
      ]);

      final all = await repository.getAll();
      expect(all.map((s) => s.id), ['high', 'low']);
    });

    test('watch emits on mutation', () async {
      final events = <List<Scan>>[];
      final sub = repository.watch().listen(events.add);

      await repository.add(_scan('w', DateTime.utc(2026, 1, 1)));
      await Future<void>.delayed(Duration.zero);

      expect(events, isNotEmpty);
      expect(events.last.map((s) => s.id), contains('w'));
      await sub.cancel();
    });

    test('migration from legacy prefs runs once and is idempotent',
        () async {
      final legacy = [
        _scan('legacy-1', DateTime.utc(2026, 1, 1),
            syncState: SyncState.synced),
        _scan('legacy-2', DateTime.utc(2026, 1, 2)),
      ];
      var readerCalls = 0;
      Future<List<Scan>> reader() async {
        readerCalls++;
        return legacy;
      }

      // Share ONE path so both opens hit the same physical DB (each fresh
      // path would otherwise mint an empty DB and re-run migration).
      final path = _newDbPath();
      final sharedFactory = _factoryFor(path);
      final migrated = await SqliteScanRepository.openMigratingFromPrefs(
        dbFactory: sharedFactory,
        legacyRows: reader,
      );
      expect(readerCalls, 1);
      expect(
          (await migrated.getAll()).map((s) => s.id), ['legacy-2', 'legacy-1']);

      // Re-open against the same DB: meta flag present, reader NOT consulted.
      await migrated.dispose();
      final reopened = await SqliteScanRepository.openMigratingFromPrefs(
        dbFactory: sharedFactory,
        legacyRows: reader,
      );
      expect(readerCalls, 1);
      expect((await reopened.getAll()).length, 2);
      await reopened.dispose();
      await _cleanup(path);
    });

    test('migration trims rows beyond retention cap', () async {
      final legacy = [
        for (var i = 0; i < SqliteScanRepository.maxScans + 3; i++)
          _scan('s$i', DateTime.utc(2026, 1, 1, 0, 0, 0, i)),
      ];

      final path = _newDbPath();
      final repo = await SqliteScanRepository.openMigratingFromPrefs(
        dbFactory: _factoryFor(path),
        legacyRows: () async => legacy,
      );

      final all = await repo.getAll();
      expect(all.length, SqliteScanRepository.maxScans);
      // Newest kept.
      expect(all.first.id, 's${SqliteScanRepository.maxScans + 2}');
      await repo.dispose();
      await _cleanup(path);
    });
  });
}
