import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

import '../models/mangrove_tree.dart';

class MonitoringSyncService {
  static const String _endpoint = String.fromEnvironment(
    'MANGROVE_GUARD_API_URL',

    defaultValue: 'http://192.168.1.56:8080/api/scans',
  );

  static Future<void> syncCompletedScan({
    required String treeId,
    required DateTime scannedAt,
    required StabilityAssessment assessment,
    String? imagePath,
    double? predictionConfidence,
  }) async {
    final endpoint = Uri.tryParse(_endpoint);
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      debugPrint(
        'Monitoring sync is disabled: no valid API URL is configured.',
      );
      return;
    }

    final client = HttpClient();
    try {
      debugPrint('Sending monitoring scan to $endpoint');
      final imageBase64 = await _encodeImage(imagePath);
      final request = await client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 5));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'treeId': treeId,
          'scannedAt': scannedAt.toUtc().toIso8601String(),
          'assessment': assessment.name,
          if (imageBase64 != null) 'imageBase64': imageBase64,
          if (predictionConfidence != null)
            'predictionConfidence': predictionConfidence,
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      final responseBody = await utf8.decoder.bind(response).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Monitoring scan synced to $endpoint');
      } else {
        debugPrint(
          'Monitoring sync failed: server returned ${response.statusCode}: '
          '$responseBody',
        );
      }
    } on SocketException {
      debugPrint('Monitoring sync failed: dashboard server is unreachable.');
    } on HttpException {
      debugPrint('Monitoring sync failed: invalid server response.');
    } on TimeoutException {
      debugPrint('Monitoring sync failed: request timed out.');
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
