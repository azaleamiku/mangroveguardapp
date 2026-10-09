import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/scan.dart';
import 'scan_repository.dart';

/// [ScanRepository] backed by SharedPreferences.
///
/// Behavior-preserving port of the storage previously embedded in
/// `MainNavPage`: full-list JSON `StringList` under the same storage key,
/// newest-first ordering, and the 10 000-record retention cap. Exists so the
/// UI seam can ship and be tested before the SQLite swap — the swap only
/// needs to implement [ScanRepository] plus a one-time migration from
/// [storageKey].
class PrefsScanRepository implements ScanRepository {
  static const String storageKey = 'recent_tree_scans_v1';
  static const int maxScans = 10000;

  final Future<SharedPreferences> Function() _prefsFactory;
  final StreamController<List<Scan>> _controller =
      StreamController<List<Scan>>.broadcast();
  List<Scan> _cache = const [];
  bool _loaded = false;

  PrefsScanRepository(
      {Future<SharedPreferences> Function()? prefsFactory})
      : _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  Future<List<Scan>> _ensureLoaded() async {
    if (_loaded) return _cache;
    try {
      final prefs = await _prefsFactory();
      final rawList = prefs.getStringList(storageKey) ?? const <String>[];
      final loaded = <Scan>[];
      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            loaded.add(Scan.fromJson(decoded));
          } else if (decoded is Map) {
            loaded.add(
                Scan.fromJson(decoded.cast<String, dynamic>()));
          }
        } catch (_) {
          // Skip corrupt entries; keep the rest of the queue intact.
        }
      }
      loaded.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      _cache = loaded.length <= maxScans
          ? loaded
          : loaded.sublist(0, maxScans);
    } catch (_) {
      _cache = const [];
    }
    _loaded = true;
    return _cache;
  }

  Future<void> _persist() async {
    try {
      final prefs = await _prefsFactory();
      final encoded =
          _cache.map((scan) => jsonEncode(scan.toJson())).toList(growable: false);
      await prefs.setStringList(storageKey, encoded);
    } catch (_) {}
    if (!_controller.isClosed) _controller.add(List<Scan>.unmodifiable(_cache));
  }

  static List<Scan> _sorted(List<Scan> scans) {
    final sorted = List<Scan>.from(scans);
    sorted.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return sorted;
  }

  @override
  Stream<List<Scan>> watch() async* {
    yield await _ensureLoaded();
    yield* _controller.stream;
  }

  @override
  Future<List<Scan>> getAll() async =>
      List<Scan>.unmodifiable(await _ensureLoaded());

  @override
  Future<List<Scan>> getPending() async {
    final scans = await _ensureLoaded();
    return scans
        .where((s) =>
            s.syncState == SyncState.pending ||
            s.syncState == SyncState.failed)
        .toList(growable: false);
  }

  @override
  Future<void> add(Scan scan) async {
    final scans = await _ensureLoaded();
    final updated = _sorted([
      scan,
      ...scans.where((s) => s.id != scan.id),
    ]);
    _cache = updated.length <= maxScans
        ? updated
        : updated.sublist(0, maxScans);
    await _persist();
  }

  @override
  Future<void> removeById(String id) async {
    await _ensureLoaded();
    _cache = _cache.where((s) => s.id != id).toList(growable: false);
    await _persist();
  }

  @override
  Future<void> markSyncing(String id) async {
    await _update(id, (s) => s.copyWith(syncState: SyncState.syncing));
  }

  @override
  Future<void> markSynced(String id) async {
    await _update(
        id,
        (s) => s.copyWith(
            syncState: SyncState.synced,
            lastError: () => null,
            retryCount: s.retryCount + 1));
  }

  @override
  Future<void> markFailed(String id, String error) async {
    await _update(
        id,
        (s) => s.copyWith(
            syncState: SyncState.failed,
            lastError: () => error,
            retryCount: s.retryCount + 1));
  }

  Future<void> _update(String id, Scan Function(Scan) transform) async {
    final scans = await _ensureLoaded();
    final index = scans.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final updated = List<Scan>.from(scans);
    updated[index] = transform(updated[index]);
    _cache = _sorted(updated);
    await _persist();
  }

  @override
  Future<int> clearSynced() async {
    final scans = await _ensureLoaded();
    final retained = scans.where((s) => !s.isSynced).toList(growable: false);
    final removed = scans.length - retained.length;
    if (removed == 0) return 0;
    _cache = retained;
    await _persist();
    return removed;
  }

  @override
  Future<void> replaceAll(List<Scan> scans) async {
    await _ensureLoaded();
    final sorted = _sorted(scans);
    _cache = sorted.length <= maxScans ? sorted : sorted.sublist(0, maxScans);
    await _persist();
  }

  @visibleForTesting
  void seedForTest(List<Scan> scans) {
    _cache = _sorted(scans);
    _loaded = true;
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
