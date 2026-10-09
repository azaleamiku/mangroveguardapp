import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangroveguardapp/constants/app_constants.dart';
import 'package:mangroveguardapp/domain/scan.dart';
import 'package:mangroveguardapp/models/mangrove_tree.dart';
import 'package:mangroveguardapp/models/recent_tree_scan.dart';
import 'package:mangroveguardapp/models/sync_error.dart';
import 'package:mangroveguardapp/services/sync_client.dart';
import 'package:mangroveguardapp/services/sync_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Endpoint implements EndpointProvider {
  final String? value;
  _Endpoint(this.value);

  @override
  Future<String?> getEndpoint() async => value;
}

class _Identity implements DeviceIdentityProvider {
  @override
  Future<String> getDeviceName() async => 'White Box Device';

  @override
  Future<String> getOrCreateDeviceId() async => 'device-white-box';

  @override
  Future<String> getOrCreateSessionId() async => 'session-white-box';
}

class _Images implements ImageEncoder {
  final List<String?> encoded = [];

  @override
  Future<String?> encodeImage(String? imagePath) async {
    encoded.add(imagePath);
    return imagePath == null ? null : 'encoded-$imagePath';
  }
}

class _Http implements ScanHttpClient {
  final List<ScanHttpResponse> responses;
  final List<Uri> urls = [];
  final List<String> bodies = [];
  int calls = 0;

  _Http(this.responses);

  @override
  Future<ScanHttpResponse> postJson(
    Uri url, {
    required Map<String, String> headers,
    required String body,
  }) async {
    urls.add(url);
    bodies.add(body);
    final response = calls < responses.length
        ? responses[calls]
        : responses.last;
    calls++;
    return response;
  }

  @override
  Future<ScanHttpResponse> getJson(
    Uri url, {
    required Map<String, String> headers,
  }) async {
    urls.add(url);
    final response = calls < responses.length
        ? responses[calls]
        : responses.last;
    calls++;
    return response;
  }
}

SyncClient _client({
  String? endpoint = 'https://dashboard.test:8443/base',
  _Http? http,
  _Images? images,
  Future<void> Function(Duration delay)? delayOverride,
}) => SyncClient(
  endpointProvider: _Endpoint(endpoint),
  identityProvider: _Identity(),
  imageEncoder: images ?? _Images(),
  httpClient: http ?? _Http(const [ScanHttpResponse(200, '{}')]),
  delayOverride: delayOverride ?? (_) async {},
);

Scan _scan(String id, {String? imagePath}) => Scan(
  id: id,
  serverScanId: 'server-$id',
  treeId: 'MG-01-123456',
  scannedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
  assessment: StabilityAssessment.high,
  predictionConfidence: 0.91,
  capturedImagePath: imagePath,
  treeBounds: const TreeBounds(left: 1, top: 2, right: 3, bottom: 4),
);

void main() {
  group('PrefsEndpointProvider white-box parsing', () {
    test('trims and returns only http/https endpoints with a scheme', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.pairedServerUrlKey: ' https://dashboard.local:3000 ',
      });
      expect(
        await PrefsEndpointProvider().getEndpoint(),
        'https://dashboard.local:3000',
      );

      SharedPreferences.setMockInitialValues({
        AppConstants.pairedServerUrlKey: 'ftp://bad',
      });
      expect(await PrefsEndpointProvider().getEndpoint(), isNull);

      SharedPreferences.setMockInitialValues({
        AppConstants.pairedServerUrlKey: 'dashboard',
      });
      expect(await PrefsEndpointProvider().getEndpoint(), isNull);
    });
  });

  group('SyncClient white-box retry and error mapping', () {
    test(
      'responseToSyncError classifies auth, validation, server, and unknown statuses',
      () {
        final client = _client();

        expect(client.responseToSyncError(401, 'nope'), isA<SyncAuthError>());
        expect(client.responseToSyncError(403, 'nope'), isA<SyncAuthError>());
        expect(
          client.responseToSyncError(400, 'bad'),
          isA<SyncValidationError>(),
        );
        expect(
          client.responseToSyncError(422, 'bad'),
          isA<SyncValidationError>(),
        );
        expect(client.responseToSyncError(500, 'down'), isA<SyncServerError>());
        expect(
          client.responseToSyncError(302, 'redirect'),
          isA<SyncUnknownError>(),
        );
      },
    );

    test(
      'withRetry retries retryable SyncError with linear backoff delays',
      () async {
        final delays = <Duration>[];
        var attempts = 0;
        final client = _client(
          delayOverride: (duration) async {
            delays.add(duration);
          },
        );

        final value = await client.withRetry(() async {
          attempts++;
          if (attempts < 3) {
            throw const SyncServerError(503, 'temporary');
          }
          return 'ok';
        }, baseDelay: const Duration(milliseconds: 10));

        expect(value, 'ok');
        expect(attempts, 3);
        expect(delays, const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 20),
        ]);
      },
    );

    test('withRetry does not retry non-retryable validation errors', () async {
      var attempts = 0;
      final client = _client();

      await expectLater(
        client.withRetry(() async {
          attempts++;
          throw const SyncValidationError('bad payload');
        }),
        throwsA(isA<SyncValidationError>()),
      );
      expect(attempts, 1);
    });

    test(
      'withRetry retries socket and timeout failures up to maxAttempts',
      () async {
        var socketAttempts = 0;
        final client = _client();

        await expectLater(
          client.withRetry(
            () async {
              socketAttempts++;
              throw const SocketException('offline');
            },
            maxAttempts: 2,
            baseDelay: const Duration(milliseconds: 1),
          ),
          throwsA(isA<SocketException>()),
        );
        expect(socketAttempts, 2);

        var timeoutAttempts = 0;
        await expectLater(
          client.withRetry(
            () async {
              timeoutAttempts++;
              throw TimeoutException('slow');
            },
            maxAttempts: 2,
            baseDelay: const Duration(milliseconds: 1),
          ),
          throwsA(isA<TimeoutException>()),
        );
        expect(timeoutAttempts, 2);
      },
    );
  });

  group('SyncClient upload white-box payloads', () {
    test(
      'syncSingleScan preserves endpoint scheme/host/port and sends encoded image',
      () async {
        final http = _Http(const [
          ScanHttpResponse(200, '{}'),
          ScanHttpResponse(200, '{}'),
          ScanHttpResponse(200, '{}'),
        ]);
        final images = _Images();
        final client = _client(http: http, images: images);

        final id = await client.syncSingleScan(
          _scan('scan-1', imagePath: 'tree.jpg'),
        );

        expect(id, 'scan-1');
        expect(http.urls.map((u) => u.path), [
          '/api/devices',
          '/api/sessions',
          '/api/scans',
        ]);
        expect(http.urls.last.scheme, 'https');
        expect(http.urls.last.host, 'dashboard.test');
        expect(http.urls.last.port, 8443);
        expect(images.encoded, ['tree.jpg']);
        expect(http.bodies.last, contains('"scan_id":"server-scan-1"'));
        expect(http.bodies.last, contains('"imageBase64":"encoded-tree.jpg"'));
      },
    );

    test(
      'flushPendingScans maps timeout failures to each pending id',
      () async {
        final client = SyncClient(
          endpointProvider: _Endpoint('http://dashboard.test'),
          identityProvider: _Identity(),
          imageEncoder: _Images(),
          httpClient: _ThrowingTimeoutHttp(),
          delayOverride: (_) async {},
        );

        final result = await client.flushPendingScans([_scan('a'), _scan('b')]);

        expect(result.syncedIds, isEmpty);
        expect(result.failures, {'a': 'timeout', 'b': 'timeout'});
        expect(result.allSucceeded, isFalse);
      },
    );
  });

  group('ScanBridge white-box conversion', () {
    test(
      'scanFromRecent trims explicit ids and preserves bounds/sync fields',
      () {
        final recent = RecentTreeScan(
          scanId: 'recent-id',
          treeId: 'MG-01-123456',
          scannedAt: DateTime.utc(2026, 1, 2),
          tree: const MangroveTree(
            treeBounds: TreeBounds(left: 1, top: 2, right: 3, bottom: 4),
          ),
          predictionConfidence: 0.77,
          predictedAssessment: StabilityAssessment.moderate,
          capturedImagePath: '/tmp/tree.jpg',
          isSynced: true,
        );

        final scan = SyncClient.scanFromRecent(recent, id: '  explicit-id  ');

        expect(scan.id, 'explicit-id');
        expect(scan.serverScanId, 'explicit-id');
        expect(scan.assessment, StabilityAssessment.moderate);
        expect(scan.predictionConfidence, 0.77);
        expect(scan.capturedImagePath, '/tmp/tree.jpg');
        expect(scan.syncState, SyncState.synced);
        expect(scan.treeBounds?.left, 1);
      },
    );

    test('scanFromRecent falls back to effective id and low assessment', () {
      final recent = RecentTreeScan(
        treeId: 'MG-01-999999',
        scannedAt: DateTime.utc(2026, 1, 2),
        tree: const MangroveTree(),
      );

      final scan = SyncClient.scanFromRecent(recent, id: ' ');

      expect(scan.id, recent.effectiveScanId);
      expect(scan.assessment, StabilityAssessment.low);
      expect(scan.syncState, SyncState.pending);
    });

    test('recentFromScan mirrors domain scan fields for the UI model', () {
      final scan = _scan('scan-bridge');

      final recent = SyncClient.recentFromScan(scan);

      expect(recent.scanId, 'scan-bridge');
      expect(recent.treeId, scan.treeId);
      expect(recent.predictedAssessment, StabilityAssessment.high);
      expect(recent.predictionConfidence, 0.91);
      expect(recent.tree.treeBounds?.right, 3);
    });
  });

  group('SyncClient pingServer', () {
    test('returns true when the server answers 2xx', () async {
      final http = _Http(const [ScanHttpResponse(200, '{}')]);
      final client = _client(http: http);

      final connected = await client.pingServer();

      expect(connected, isTrue);
      expect(http.calls, 1);
      expect(http.urls.last.path, '/');
    });

    test('returns false when no server is paired', () async {
      final http = _Http(const []);
      final client = _client(http: http, endpoint: null);

      final connected = await client.pingServer();

      expect(connected, isFalse);
      expect(http.calls, 0);
    });

    test('returns false on a non-2xx response', () async {
      final http = _Http(const [ScanHttpResponse(503, 'down')]);
      final client = _client(http: http, delayOverride: (_) async {});

      final connected = await client.pingServer();

      expect(connected, isFalse);
    });
  });
}

class _ThrowingTimeoutHttp implements ScanHttpClient {
  var calls = 0;

  @override
  Future<ScanHttpResponse> postJson(
    Uri url, {
    required Map<String, String> headers,
    required String body,
  }) async {
    calls++;
    if (calls <= 2) return const ScanHttpResponse(200, '{}');
    throw TimeoutException('slow');
  }

  @override
  Future<ScanHttpResponse> getJson(
    Uri url, {
    required Map<String, String> headers,
  }) async {
    calls++;
    if (calls <= 2) return const ScanHttpResponse(200, '{}');
    throw TimeoutException('slow');
  }
}
