import 'package:flutter_test/flutter_test.dart';
import 'package:mangroveguardapp/data/prefs_scan_repository.dart';
import 'package:mangroveguardapp/domain/scan.dart';
import 'package:mangroveguardapp/models/mangrove_tree.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  late PrefsScanRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = PrefsScanRepository();
  });

  tearDown(() async {
    await repository.dispose();
  });

  group('PrefsScanRepository', () {
    test('add + getAll keeps newest first', () async {
      final older = _scan('a', DateTime.utc(2026, 1, 1));
      final newer = _scan('b', DateTime.utc(2026, 1, 2));

      await repository.add(older);
      await repository.add(newer);

      final all = await repository.getAll();
      expect(all.map((s) => s.id), ['b', 'a']);
    });

    test('add is idempotent for the same id', () async {
      final scan = _scan('dup', DateTime.utc(2026, 1, 1));

      await repository.add(scan);
      await repository.add(scan.copyWith(syncState: SyncState.synced));

      final all = await repository.getAll();
      expect(all.length, 1);
      expect(all.first.syncState, SyncState.synced);
    });

    test('watch emits on mutation', () async {
      final events = <List<Scan>>[];
      final sub = repository.watch().listen(events.add);

      await repository.add(_scan('a', DateTime.utc(2026, 1, 1)));
      await Future<void>.delayed(Duration.zero);

      expect(events, isNotEmpty);
      expect(events.last.map((s) => s.id), contains('a'));
      await sub.cancel();
    });

    test('retention cap trims oldest beyond 10000', () async {
      for (var i = 0; i < PrefsScanRepository.maxScans + 2; i++) {
        await repository.add(
            _scan('s$i', DateTime.utc(2026, 1, 1, 0, 0, 0, i)));
      }

      final all = await repository.getAll();
      expect(all.length, PrefsScanRepository.maxScans);
      expect(all.first.id, 's${PrefsScanRepository.maxScans + 1}');
    });

    test('markSynced/markedFailed transitions drive getPending', () async {
      await repository.add(_scan('a', DateTime.utc(2026, 1, 1)));
      await repository.add(_scan('b', DateTime.utc(2026, 1, 2)));

      await repository.markSyncing('a');
      await repository.markSynced('a');
      await repository.markFailed('b', 'timeout');

      final pending = await repository.getPending();
      expect(pending.map((s) => s.id), ['b']);
      expect(pending.first.syncState, SyncState.failed);
      expect(pending.first.lastError, 'timeout');
    });

    test('removeById and clearSynced', () async {
      await repository.add(_scan('a', DateTime.utc(2026, 1, 1)));
      await repository.add(_scan('b', DateTime.utc(2026, 1, 2)));
      await repository.markSynced('a');

      await repository.removeById('b');
      final remaining = await repository.getAll();
      expect(remaining.map((s) => s.id), ['a']);

      final removed = await repository.clearSynced();
      expect(removed, 1);
      expect(await repository.getAll(), isEmpty);
    });

    test('tolerates corrupt JSON entries on load', () async {
      SharedPreferences.setMockInitialValues({
        PrefsScanRepository.storageKey: ['not-json', '{'],
      });
      final fresh = PrefsScanRepository();
      final all = await fresh.getAll();
      expect(all, isEmpty);
      await fresh.dispose();
    });
  });

  group('Scan serialization', () {
    test('round-trips all fields', () {
      final scan = Scan(
        id: 'scan-abc-123',
        serverScanId: 'scan-abc-123',
        treeId: 'MG-01-123456',
        scannedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        assessment: StabilityAssessment.high,
        predictionConfidence: 0.92,
        capturedImagePath: '/tmp/capture.jpg',
        syncState: SyncState.failed,
        lastError: 'timeout',
        retryCount: 2,
      );

      final restored = Scan.fromJson(scan.toJson());

      expect(restored.id, scan.id);
      expect(restored.serverScanId, scan.serverScanId);
      expect(restored.treeId, scan.treeId);
      expect(restored.scannedAt, scan.scannedAt);
      expect(restored.assessment, scan.assessment);
      expect(restored.predictionConfidence, scan.predictionConfidence);
      expect(restored.capturedImagePath, scan.capturedImagePath);
      expect(restored.syncState, scan.syncState);
      expect(restored.lastError, scan.lastError);
      expect(restored.retryCount, scan.retryCount);
      expect(restored, scan); // identity equality by id
    });

    test('tolerates corrupt/legacy payloads', () {
      // Missing id + legacy isSynced flag derives identity and sync state.
      final legacy = Scan.fromJson({
        'treeId': 'MG-01-123456',
        'scannedAt': '2026-01-02T03:04:05.000Z',
        'isSynced': true,
      });
      expect(legacy.id.isNotEmpty, isTrue);
      expect(legacy.serverScanId, legacy.id);
      expect(legacy.syncState, SyncState.synced);
      expect(legacy.assessment, StabilityAssessment.low);

      // Unknown enum strings fall back safely instead of throwing.
      final unknown = Scan.fromJson({
        'id': 'x',
        'treeId': 'MG-01-1',
        'scannedAt': 'not-a-date',
        'assessment': 'bogus',
        'syncState': 'bogus',
      });
      expect(unknown.assessment, StabilityAssessment.low);
      expect(unknown.syncState, SyncState.pending);
    });
  });
}
