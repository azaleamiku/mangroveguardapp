import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mangrove_tree.dart';
import '../views/recent_scan_page.dart';

class MonitoringSyncService {
  static const String _endpoint = String.fromEnvironment(
    'MANGROVE_GUARD_API_URL',
    defaultValue: 'http://192.168.1.44:8080',
  );
  static const String _deviceIdKey = 'mangrove_device_id';
  static const String _sessionIdKey = 'mangrove_session_id';

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

  static Future<void> _registerDevice(String deviceId) async {
    final endpoint = Uri.tryParse(_endpoint);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      return;
    }

    final client = HttpClient();
    try {
      final baseUrl = Uri(
        scheme: endpoint.scheme,
        host: endpoint.host,
        port: endpoint.port,
        path: '/',
      );
      final request = await client
          .postUrl(Uri.parse('${baseUrl.toString()}api/devices'))
          .timeout(const Duration(seconds: 5));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'device_id': deviceId,
          'device_name': 'Field Device',
        }),
      );
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Device registered: $deviceId');
        return;
      }
      final responseBody = await utf8.decoder.bind(response).join();
      throw HttpException(
        'Device registration failed: ${response.statusCode}: $responseBody',
      );
    } catch (e) {
      debugPrint('Device registration failed: $e');
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _ensureSession(String deviceId) async {
    final sessionId = await _getOrCreateSessionId();
    final endpoint = Uri.tryParse(_endpoint);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      return sessionId;
    }

    final client = HttpClient();
    try {
      final baseUrl = Uri(
        scheme: endpoint.scheme,
        host: endpoint.host,
        port: endpoint.port,
        path: '/',
      );
      final request = await client
          .postUrl(Uri.parse('${baseUrl.toString()}api/sessions'))
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
      throw HttpException(
        'Session creation failed: ${response.statusCode}: $responseBody',
      );
    } catch (e) {
      debugPrint('Session creation failed: $e');
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> syncCompletedScan(RecentTreeScan scan) async {
    final endpoint = Uri.tryParse(_endpoint);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      debugPrint(
        'Monitoring sync is disabled: no valid API URL is configured.',
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
        path: '/api/scans',
      );
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
        debugPrint(
          'Monitoring sync failed: server returned ${response.statusCode}: '
          '$responseBody',
        );
        return false;
      }
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
    final endpoint = Uri.tryParse(_endpoint);
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
      final request = await client.getUrl(base).timeout(const Duration(seconds: 3));
      final response = await request.close().timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 500;
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
    final endpoint = Uri.tryParse(_endpoint);
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
      final batchUrl = Uri(
        scheme: endpoint.scheme,
        host: endpoint.host,
        port: endpoint.port,
        path: '/api/scans/batch',
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
        debugPrint(
          'Batch sync failed: server returned ${response.statusCode}: '
          '$responseBody',
        );
      }
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
