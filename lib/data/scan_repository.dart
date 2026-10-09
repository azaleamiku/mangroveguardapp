import '../domain/scan.dart';

/// Persistence contract for field scans.
///
/// UI layers program against this interface; the backing store (prefs today,
/// SQLite tomorrow) is an implementation detail. All identity is [Scan.id] —
/// never list indices — so re-sorts and concurrent syncs can't shift targets.
abstract class ScanRepository {
  /// Live list of scans, newest first.
  Stream<List<Scan>> watch();

  /// Current snapshot, newest first.
  Future<List<Scan>> getAll();

  /// Pending (unsynced, non-syncing) scans for the sync queue.
  Future<List<Scan>> getPending();

  Future<void> add(Scan scan);

  Future<void> removeById(String id);

  Future<void> markSyncing(String id);

  Future<void> markSynced(String id);

  Future<void> markFailed(String id, String error);

  /// Remove synced scans (retention); returns number removed.
  Future<int> clearSynced();

  Future<void> replaceAll(List<Scan> scans);
}
