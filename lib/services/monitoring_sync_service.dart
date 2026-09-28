import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../constants/app_constants.dart';
import '../models/mangrove_tree.dart';
import '../models/recent_tree_scan.dart';

class MonitoringSyncService {
  static const String _deviceIdKey = AppConstants.deviceIdKey;
  static const String _sessionIdKey = AppConstants.sessionIdKey;

  static Future<String?> _getEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(AppConstants.pairedServerUrlKey);
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(savedUrl.trim());
      if (uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return savedUrl.trim();
      }
    }
    return null;
  }

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) return existing.trim();
    final deviceId = 'device-${DateTime.now().millisecondsSinceEpoch}-${(DateTime.now().microsecond % 10000).toString().padLeft(4, '0')}';
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  static Future<String> _getOrCreateSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_sessionIdKey);
    if (existing != null && existing.trim().isNotEmpty) return existing.trim();
    final sessionId = 'session-${DateTime.now().millisecondsSinceEpoch}-${(DateTime.now().microsecond % 10000).toString().padLeft(4, '0')}';
    await prefs.setString(_sessionIdKey, sessionId);
    return sessionId;
  }

  static Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
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

  static Future<T> _withRetry<T>(Future<T> Function() action,
      {int maxAttempts = 3, Duration? baseDelay}) async {
    final delay = baseDelay ?? const Duration(seconds: 1);
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } on SocketException catch (_) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay * attempt);
      } on TimeoutException catch (_) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay * attempt);
      } on HttpException catch (_) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay * attempt);
      }
    }
  }

  static Future<void> _registerDevice(String deviceId) async {
    final savedUrl = await _getEndpoint();
    if (savedUrl == null) return;
    final endpoint = Uri.tryParse(savedUrl);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      return;
    }

    final client = HttpClient();
    try {
      await _withRetry(() async {
        final baseUrl = Uri(
          scheme: endpoint.scheme,
          host: endpoint.host,
          port: endpoint.port,
          path: '/',
        );
        final request = await client
            .postUrl(Uri.parse('${baseUrl.toString()}${AppConstants.apiDevices}'))
            .timeout(const Duration(seconds: 5));
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({
            'device_id': deviceId,
            'device_name': await _getDeviceName(),
          }),
        );
        final response = await request.close().timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('Device registered: $deviceId');
          return;
        }
        final responseBody = await utf8.decoder.bind(response).join();
        final errorMessage = _parseServerError(responseBody) ?? 'Device registration failed: ${response.statusCode}';
        throw HttpException(errorMessage);
      });
    } catch (e) {
      debugPrint('Device registration failed: $e');
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _ensureSession(String deviceId) async {
    final sessionId = await _getOrCreateSessionId();
    final savedUrl = await _getEndpoint();
    if (savedUrl == null) return sessionId;
    final endpoint = Uri.tryParse(savedUrl);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      return sessionId;
    }

    final client = HttpClient();
    try {
      return await _withRetry(() async {
        final baseUrl = Uri(
          scheme: endpoint.scheme,
          host: endpoint.host,
          port: endpoint.port,
          path: '/',
        );
        final request = await client
            .postUrl(Uri.parse('${baseUrl.toString()}${AppConstants.apiSessions}'))
            .timeout(const Duration(seconds: 5));
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({
            'session_id': sessionId,
            'device_id': deviceId,
          }),
        );
        final response = await request.close().timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('Session ensured: $sessionId');
          return sessionId;
        }
        final responseBody = await utf8.decoder.bind(response).join();
        final errorMessage = _parseServerError(responseBody) ?? 'Session creation failed: ${response.statusCode}';
        throw HttpException(errorMessage);
      });
    } catch (e) {
      debugPrint('Session creation failed: $e');
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> endSession(String sessionId) async {
    final savedUrl = await _getEndpoint();
    if (savedUrl == null) return;
    final endpoint = Uri.tryParse(savedUrl);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      return;
    }

    final client = HttpClient();
    try {
      await _withRetry(() async {
        final baseUrl = Uri(
          scheme: endpoint.scheme,
          host: endpoint.host,
          port: endpoint.port,
          path: '/',
        );
        final request = await client
            .postUrl(Uri.parse('${baseUrl.toString()}${AppConstants.apiSessionsEnd}/$sessionId/end'))
            .timeout(const Duration(seconds: 5));
        request.headers.contentType = ContentType.json;
        final response = await request.close().timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('Session ended: $sessionId');
          return;
        }
        final responseBody = await utf8.decoder.bind(response).join();
        final errorMessage = _parseServerError(responseBody) ?? 'Session end failed: ${response.statusCode}';
        throw HttpException(errorMessage);
      });
    } catch (e) {
      debugPrint('Session end failed: $e');
    } finally {
      client.close(force: true);
    }
  }

  static String? _parseServerError(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'] as String?;
        final code = decoded['code'] as String?;
        if (error != null && error.isNotEmpty) {
          return code != null && code.isNotEmpty ? '$error (code: $code)' : error;
        }
      }
    } on FormatException catch (_) {}
    on ArgumentError catch (_) {}
    return null;
  }

  static Future<bool> syncCompletedScan(RecentTreeScan scan) async {
    final savedUrl = await _getEndpoint();
    if (savedUrl == null) {
      debugPrint(
        'Monitoring sync is disabled: no paired server URL.',
      );
      return false;
    }
    final endpoint = Uri.tryParse(savedUrl);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      debugPrint(
        'Monitoring sync is disabled: invalid API URL.',
      );
      return false;
    }

    final client = HttpClient();
    try {
      final deviceId = await _getOrCreateDeviceId();
      await _registerDevice(deviceId);
      final sessionId = await _ensureSession(deviceId);
      final imageBase64 = await _encodeImage(scan.capturedImagePath);
      final scansUrl = Uri(
        scheme: endpoint.scheme,
        host: endpoint.host,
        port: endpoint.port,
        path: '/${AppConstants.apiScans}',
      );
      final success = await _withRetry(() async {
        final request = await client
            .postUrl(scansUrl)
            .timeout(const Duration(seconds: 5));
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({
            'scan_id': 'scan-${scan.treeId}-${scan.scannedAt.millisecondsSinceEpoch}',
            'session_id': sessionId,
            'tree_id': scan.treeId,
            'scanned_at': scan.scannedAt.toUtc().toIso8601String(),
            'predicted_assessment': scan.predictedAssessment?.name ?? StabilityAssessment.low.name,
            if (imageBase64 != null) 'imageBase64': imageBase64,
          }),
        );
        final response = await request.close().timeout(
          const Duration(seconds: 5),
        );
        final responseBody = await utf8.decoder.bind(response).join();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('Monitoring scan synced to $endpoint');
          return true;
        } else {
          final errorMessage = _parseServerError(responseBody) ?? 'Server rejected the request';
          debugPrint('Monitoring sync failed: $errorMessage');
          return false;
        }
      }, baseDelay: const Duration(seconds: 1));
      return success;
    } on SocketException {
      debugPrint('Monitoring sync failed: dashboard server is unreachable.');
      return false;
    } on HttpException {
      debugPrint('Monitoring sync failed: invalid server response.');
      return false;
    } on TimeoutException {
      debugPrint('Monitoring sync failed: request timed out.');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> pingServer() async {
    final savedUrl = await _getEndpoint();
    if (savedUrl == null) return false;
    final endpoint = Uri.tryParse(savedUrl);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      return false;
    }

    final client = HttpClient();
    try {
      final base = Uri(
        scheme: endpoint.scheme,
        host: endpoint.host,
        port: endpoint.port,
        path: '/',
      );
      return await _withRetry(() async {
        final request = await client.getUrl(base).timeout(const Duration(seconds: 3));
        final response = await request.close().timeout(const Duration(seconds: 3));
        return response.statusCode >= 200 && response.statusCode < 500;
      }, baseDelay: const Duration(seconds: 1));
    } on SocketException {
      return false;
    } on HttpException {
      return false;
    } on TimeoutException {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> flushPendingScans(
    List<RecentTreeScan> recentScans,
    Function(int index) onScanSynced,
  ) async {
    final savedUrl = await _getEndpoint();
    if (savedUrl == null) return;
    final endpoint = Uri.tryParse(savedUrl);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      return;
    }

    final deviceId = await _getOrCreateDeviceId();
    await _registerDevice(deviceId);
    final sessionId = await _ensureSession(deviceId);

    final pendingScans = recentScans.where((s) => !s.isSynced).toList();
    if (pendingScans.isEmpty) return;

    final client = HttpClient();
    try {
      await _withRetry(() async {
        final batchUrl = Uri(
          scheme: endpoint.scheme,
          host: endpoint.host,
          port: endpoint.port,
          path: '/${AppConstants.apiScansBatch}',
        );
        final request = await client
            .postUrl(batchUrl)
            .timeout(const Duration(seconds: 10));
        request.headers.contentType = ContentType.json;

        final batchPayload = <dynamic>[];
        for (final scan in pendingScans) {
          final imageBase64 = await _encodeImage(scan.capturedImagePath);
          batchPayload.add({
            'scan_id': 'scan-${scan.treeId}-${scan.scannedAt.millisecondsSinceEpoch}',
            'session_id': sessionId,
            'tree_id': scan.treeId,
            'scanned_at': scan.scannedAt.toUtc().toIso8601String(),
            'predicted_assessment': scan.predictedAssessment?.name ?? StabilityAssessment.low.name,
            if (imageBase64 != null) 'imageBase64': imageBase64,
          });
        }

        request.write(
          jsonEncode({
            'device_id': deviceId,
            'session_id': sessionId,
            'scans': batchPayload,
          }),
        );

        final response = await request.close().timeout(const Duration(seconds: 10));
        final responseBody = await utf8.decoder.bind(response).join();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('Batch synced ${pendingScans.length} scans');
          for (int i = 0; i < pendingScans.length; i++) {
            final originalIndex = recentScans.indexOf(pendingScans[i]);
            if (originalIndex >= 0) onScanSynced(originalIndex);
          }
        } else {
          final errorMessage = _parseServerError(responseBody) ?? 'Batch sync failed';
          debugPrint(errorMessage);
        }
      }, baseDelay: const Duration(seconds: 1));
    } on SocketException {
      debugPrint('Batch sync failed: dashboard server is unreachable.');
    } on HttpException {
      debugPrint('Batch sync failed: invalid server response.');
    } on TimeoutException {
      debugPrint('Batch sync failed: request timed out.');
    } finally {
      client.close(force: true);
    }
  }

  static Future<String?> _encodeImage(String? imagePath) async {
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
