import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../domain/scan.dart';
import '../models/mangrove_tree.dart';
import '../models/recent_tree_scan.dart';
import '../models/sync_error.dart';
import 'sync_dependencies.dart';

/// Per-scan outcome for batch flushes.
///
/// Unlike the legacy `flushPendingScans` (all-or-nothing `int`), this
/// records which ids succeeded so partial failures are retryable instead of
/// silently dropped.
class SyncResult {
  final List<String> syncedIds;
  final Map<String, String> failures;

  const SyncResult({this.syncedIds = const [], this.failures = const {}});

  int get syncedCount => syncedIds.length;
  bool get allSucceeded => failures.isEmpty;
}

/// Production [EndpointProvider] reading the paired server URL from prefs.
class PrefsEndpointProvider implements EndpointProvider {
  final Future<SharedPreferences> Function() prefsFactory;

  PrefsEndpointProvider({Future<SharedPreferences> Function()? prefsFactory})
      : prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  @override
  Future<String?> getEndpoint() async {
    final prefs = await prefsFactory();
    final savedUrl = prefs.getString(AppConstants.pairedServerUrlKey);
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(savedUrl.trim());
      if (uri != null &&
          uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https')) {
        return savedUrl.trim();
      }
    }
    return null;
  }
}

/// Production [DeviceIdentityProvider] backed by prefs + device_info_plus.
class PrefsDeviceIdentityProvider implements DeviceIdentityProvider {
  final Future<SharedPreferences> Function() prefsFactory;
  final DeviceInfoPlugin Function() deviceInfoFactory;

  PrefsDeviceIdentityProvider(
      {Future<SharedPreferences> Function()? prefsFactory,
      DeviceInfoPlugin Function()? deviceInfoFactory})
      : prefsFactory = prefsFactory ?? SharedPreferences.getInstance,
        deviceInfoFactory = deviceInfoFactory ?? DeviceInfoPlugin.new;

  @override
  Future<String> getOrCreateDeviceId() async {
    final prefs = await prefsFactory();
    final existing = prefs.getString(AppConstants.deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final deviceId =
        'device-${DateTime.now().millisecondsSinceEpoch}-${(DateTime.now().microsecond % 10000).toString().padLeft(4, '0')}';
    await prefs.setString(AppConstants.deviceIdKey, deviceId);
    return deviceId;
  }

  @override
  Future<String> getOrCreateSessionId() async {
    final prefs = await prefsFactory();
    final existing = prefs.getString(AppConstants.sessionIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final sessionId =
        'session-${DateTime.now().millisecondsSinceEpoch}-${(DateTime.now().microsecond % 10000).toString().padLeft(4, '0')}';
    await prefs.setString(AppConstants.sessionIdKey, sessionId);
    return sessionId;
  }

  @override
  Future<String> getDeviceName() async {
    final deviceInfo = deviceInfoFactory();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return info.device ?? info.model ?? 'Android Device';
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return info.name ?? 'iOS Device';
    } else if (Platform.isLinux) {
      final info = await deviceInfo.linuxInfo;
      return info.prettyName ?? info.name ?? 'Linux Device';
    } else if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      return info.computerName ?? 'Windows Device';
    } else if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      return info.computerName ?? 'macOS Device';
    }
    return 'Unknown Device';
  }
}

/// Production [ImageEncoder]: downscale to 1200px JPEG, 8MB cap.
class FileImageEncoder implements ImageEncoder {
  @override
  Future<String?> encodeImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    try {
      final original = await File(imagePath).readAsBytes();
      final decoded = image.decodeImage(original);
      final uploadBytes = decoded == null
          ? original
          : image.encodeJpg(
              image.copyResize(decoded, width: 1200),
              quality: 82,
            );
      if (uploadBytes.length > 8 * 1024 * 1024) {
        debugPrint('Monitoring image was too large to sync.');
        return null;
      }
      return base64Encode(uploadBytes);
    } catch (_) {
      debugPrint('Monitoring image could not be prepared for sync.');
      return null;
    }
  }
}

/// Production [ScanHttpClient] over `dart:io` HttpClient.
class IoScanHttpClient implements ScanHttpClient {
  final HttpClient Function() clientFactory;

  IoScanHttpClient({HttpClient Function()? clientFactory})
      : clientFactory = clientFactory ?? HttpClient.new;

  @override
  Future<ScanHttpResponse> postJson(Uri url,
      {required Map<String, String> headers, required String body}) async {
    final client = clientFactory();
    try {
      final request =
          await client.postUrl(url).timeout(const Duration(seconds: 10));
      headers.forEach(request.headers.set);
      request.headers.contentType = ContentType.json;
      request.write(body);
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final responseBody = await utf8.decoder.bind(response).join();
      return ScanHttpResponse(response.statusCode, responseBody);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<ScanHttpResponse> getJson(Uri url,
      {required Map<String, String> headers}) async {
    final client = clientFactory();
    try {
      final request = await client.getUrl(url).timeout(const Duration(seconds: 5));
      headers.forEach(request.headers.set);
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      final responseBody = await utf8.decoder.bind(response).join();
      return ScanHttpResponse(response.statusCode, responseBody);
    } finally {
      client.close(force: true);
    }
  }
}


/// Injectable sync client.
///
/// Same wire protocol as the legacy static `MonitoringSyncService`, but all
/// collaborators are constructor-injected so retry/offline/partial-failure
/// paths are unit-testable with fakes.
class SyncClient {
  final EndpointProvider endpointProvider;
  final DeviceIdentityProvider identityProvider;
  final ImageEncoder imageEncoder;
  final ScanHttpClient httpClient;
  final Future<void> Function(Duration delay)? delayOverride;

  /// See [ScanBridge.scanFromRecent].
  static Scan scanFromRecent(RecentTreeScan recent, {String? id}) =>
      ScanBridge.scanFromRecent(recent, id: id);

  /// See [ScanBridge.recentFromScan].
  static RecentTreeScan recentFromScan(Scan scan) =>
      ScanBridge.recentFromScan(scan);

  SyncClient({
    required this.endpointProvider,
    required this.identityProvider,
    required this.imageEncoder,
    required this.httpClient,
    this.delayOverride,
  });

  factory SyncClient.production() => SyncClient(
        endpointProvider: PrefsEndpointProvider(),
        identityProvider: PrefsDeviceIdentityProvider(),
        imageEncoder: FileImageEncoder(),
        httpClient: IoScanHttpClient(),
      );

  Future<T> withRetry<T>(Future<T> Function() action,
      {int maxAttempts = 3, Duration? baseDelay}) async {
    final delay = baseDelay ?? const Duration(seconds: 1);
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } on SyncError catch (error) {
        attempt++;
        if (!error.retryable || attempt >= maxAttempts) rethrow;
        await _delay(delay * attempt);
      } on SocketException catch (_) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await _delay(delay * attempt);
      } on TimeoutException catch (_) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await _delay(delay * attempt);
      }
    }
  }

  Future<void> _delay(Duration d) async {
    if (delayOverride != null) {
      await delayOverride!(d);
    } else {
      await Future.delayed(d);
    }
  }

  SyncError responseToSyncError(int statusCode, String body) {
    if (statusCode == 401 || statusCode == 403) {
      return SyncAuthError('Server rejected the request ($statusCode). $body');
    }
    if (statusCode == 400 || statusCode == 422) {
      return SyncValidationError('Server rejected the scan ($statusCode). $body');
    }
    if (statusCode >= 500) {
      return SyncServerError(statusCode, body);
    }
    return SyncUnknownError('Unexpected status $statusCode. $body');
  }

  /// Liveness probe used by the UI to gate sync actions. Returns `true`
  /// when the paired server answers 2xx on its root path.
  Future<bool> pingServer() async {
    final endpointRaw = await endpointProvider.getEndpoint();
    if (endpointRaw == null) return false;
    final endpoint = Uri.parse(endpointRaw);
    if (!endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      return false;
    }
    final base = Uri(
      scheme: endpoint.scheme,
      host: endpoint.host,
      port: endpoint.port,
      path: '/',
    );
    try {
      return await withRetry(() async {
        final response = await httpClient.getJson(base, headers: const {});
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
        if (response.statusCode >= 500) {
          throw SyncServerError(response.statusCode, 'Server unavailable');
        }
        return false;
      }, baseDelay: const Duration(seconds: 1));
    } on SyncError catch (e) {
      debugPrint('Ping failed: ${e.message}');
      return false;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}

/// Upload operations for [SyncClient], kept as an extension so the core
/// retry/error-mapping above stays reviewable on its own.
extension SyncClientUploads on SyncClient {
  /// Upload one scan. Returns the synced scan id on success.
  Future<String> syncSingleScan(Scan scan) async {
    final endpointRaw = await endpointProvider.getEndpoint();
    if (endpointRaw == null) throw const SyncNotPairedError();
    final endpoint = Uri.parse(endpointRaw);

    final deviceId = await identityProvider.getOrCreateDeviceId();
    await registerDevice(deviceId);
    final sessionId = await ensureSession(deviceId);

    return withRetry(() async {
      final singleUrl = Uri(
        scheme: endpoint.scheme,
        host: endpoint.host,
        port: endpoint.port,
        path: '/${AppConstants.apiScans}',
      );
      final imageBase64 = await imageEncoder.encodeImage(scan.capturedImagePath);
      final payload = {
        'scan_id': scan.serverScanId,
        'session_id': sessionId,
        'tree_id': scan.treeId,
        'scanned_at': scan.scannedAt.toUtc().toIso8601String(),
        'predicted_assessment': scan.assessment.name,
        if (imageBase64 != null) 'imageBase64': imageBase64,
      };
      final response = await httpClient.postJson(singleUrl,
          headers: const {}, body: jsonEncode(payload));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return scan.id;
      }
      throw responseToSyncError(response.statusCode, response.body);
    }, baseDelay: const Duration(seconds: 1));
  }

  /// Upload pending scans in one batch. Records per-id outcomes so partial
  /// failures remain retryable; never throws for server responses.
  Future<SyncResult> flushPendingScans(List<Scan> pendingScans) async {
    if (pendingScans.isEmpty) return const SyncResult();
    final endpointRaw = await endpointProvider.getEndpoint();
    if (endpointRaw == null) throw const SyncNotPairedError();
    final endpoint = Uri.parse(endpointRaw);

    final deviceId = await identityProvider.getOrCreateDeviceId();
    await registerDevice(deviceId);
    final sessionId = await ensureSession(deviceId);

    final batchPayload = <dynamic>[];
    for (final scan in pendingScans) {
      final imageBase64 =
          await imageEncoder.encodeImage(scan.capturedImagePath);
      batchPayload.add({
        'scan_id': scan.serverScanId,
        'session_id': sessionId,
        'tree_id': scan.treeId,
        'scanned_at': scan.scannedAt.toUtc().toIso8601String(),
        'predicted_assessment': scan.assessment.name,
        if (imageBase64 != null) 'imageBase64': imageBase64,
      });
    }

    try {
      final result = await withRetry(() async {
        final batchUrl = Uri(
          scheme: endpoint.scheme,
          host: endpoint.host,
          port: endpoint.port,
          path: '/${AppConstants.apiScansBatch}',
        );
        final response = await httpClient.postJson(batchUrl,
            headers: const {},
            body: jsonEncode({
              'device_id': deviceId,
              'session_id': sessionId,
              'scans': batchPayload,
            }));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return SyncResult(
              syncedIds: pendingScans.map((s) => s.id).toList());
        }
        throw responseToSyncError(response.statusCode, response.body);
      }, baseDelay: const Duration(seconds: 1));
      return result;
    } on SyncError catch (e) {
      debugPrint('Batch sync failed: ${e.message}');
      return SyncResult(failures: {
        for (final s in pendingScans) s.id: e.message,
      });
    } on SocketException {
      debugPrint('Batch sync failed: dashboard server is unreachable.');
      return SyncResult(failures: {
        for (final s in pendingScans) s.id: 'unreachable',
      });
    } on TimeoutException {
      debugPrint('Batch sync failed: request timed out.');
      return SyncResult(failures: {
        for (final s in pendingScans) s.id: 'timeout',
      });
    }
  }
}

/// Device/session lifecycle helpers for [SyncClient].
extension SyncClientSessions on SyncClient {
  Future<void> registerDevice(String deviceId) async {
    final endpointRaw = await endpointProvider.getEndpoint();
    if (endpointRaw == null) return;
    final endpoint = Uri.parse(endpointRaw);
    try {
      await withRetry(() async {
        final deviceUrl = Uri(
          scheme: endpoint.scheme,
          host: endpoint.host,
          port: endpoint.port,
          path: '/${AppConstants.apiDevices}',
        );
        final deviceName = await identityProvider.getDeviceName();
        final response = await httpClient.postJson(deviceUrl,
            headers: const {},
            body: jsonEncode({
              'device_id': deviceId,
              'device_name': deviceName,
            }));
        if (response.statusCode >= 200 && response.statusCode < 300) return;
        throw responseToSyncError(response.statusCode, response.body);
      }, baseDelay: const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Device registration skipped: $e');
    }
  }

  Future<String> ensureSession(String deviceId) async {
    final sessionId = await identityProvider.getOrCreateSessionId();
    final endpointRaw = await endpointProvider.getEndpoint();
    if (endpointRaw == null) return sessionId;
    final endpoint = Uri.parse(endpointRaw);
    try {
      await withRetry(() async {
        final sessionUrl = Uri(
          scheme: endpoint.scheme,
          host: endpoint.host,
          port: endpoint.port,
          path: '/${AppConstants.apiSessions}',
        );
        final response = await httpClient.postJson(sessionUrl,
            headers: const {},
            body: jsonEncode({
              'session_id': sessionId,
              'device_id': deviceId,
            }));
        if (response.statusCode >= 200 && response.statusCode < 300) return;
        throw responseToSyncError(response.statusCode, response.body);
      }, baseDelay: const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Session ensure skipped: $e');
    }
    return sessionId;
  }

  Future<void> endSession(String sessionId) async {
    final endpointRaw = await endpointProvider.getEndpoint();
    if (endpointRaw == null) return;
    final endpoint = Uri.parse(endpointRaw);
    try {
      final endUrl = Uri(
        scheme: endpoint.scheme,
        host: endpoint.host,
        port: endpoint.port,
        path: '/${AppConstants.apiSessionsEnd}/$sessionId/end',
      );
      await httpClient.postJson(endUrl, headers: const {}, body: jsonEncode({}));
    } catch (_) {}
  }
}

/// Bridge between UI view-models and domain entities.
///
/// Plain class (not an extension) so `SyncClient.scanFromRecent(...)` works
/// — Dart forbids static members on extensions.
class ScanBridge {
  const ScanBridge._();

  /// Convert a UI [RecentTreeScan] into a domain [Scan] with a stable id.
  static Scan scanFromRecent(RecentTreeScan recent, {String? id}) {
    final scannedAt = recent.scannedAt;
    final stableId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : recent.effectiveScanId;
    return Scan(
      id: stableId,
      serverScanId: stableId,
      treeId: recent.treeId,
      scannedAt: scannedAt,
      assessment: recent.predictedAssessment ?? StabilityAssessment.low,
      predictionConfidence: recent.predictionConfidence,
      capturedImagePath: recent.capturedImagePath,
      syncState: recent.isSynced ? SyncState.synced : SyncState.pending,
      treeBounds: recent.tree.treeBounds,
    );
  }

  static RecentTreeScan recentFromScan(Scan scan) {
    return RecentTreeScan(
      scanId: scan.id,
      treeId: scan.treeId,
      scannedAt: scan.scannedAt,
      tree: MangroveTree(treeBounds: scan.treeBounds),
      predictionConfidence: scan.predictionConfidence,
      predictedAssessment: scan.assessment,
      capturedImagePath: scan.capturedImagePath,
      isSynced: scan.isSynced,
    );
  }
}

