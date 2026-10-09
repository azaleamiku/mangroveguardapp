import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangroveguardapp/domain/scan.dart';
import 'package:mangroveguardapp/models/mangrove_tree.dart';
import 'package:mangroveguardapp/models/sync_error.dart';
import 'package:mangroveguardapp/services/sync_client.dart';
import 'package:mangroveguardapp/services/sync_dependencies.dart';

class _FakeEndpoint implements EndpointProvider {
  final String? endpoint;
  _FakeEndpoint(this.endpoint);
  @override
  Future<String?> getEndpoint() async => endpoint;
}

class _FakeIdentity implements DeviceIdentityProvider {
  @override
  Future<String> getOrCreateDeviceId() async => 'device-test';
  @override
  Future<String> getOrCreateSessionId() async => 'session-test';
  @override
  Future<String> getDeviceName() async => 'Test Device';
}

class _FakeImages implements ImageEncoder {
  @override
  Future<String?> encodeImage(String? imagePath) async => null;
}

class _ScriptedHttp implements ScanHttpClient {
  final List<ScanHttpResponse> script;
  final List<Uri> requestedUrls = [];
  int calls = 0;
  _ScriptedHttp(this.script);
  @override
  Future<ScanHttpResponse> postJson(Uri url,
      {required Map<String, String> headers, required String body}) async {
    requestedUrls.add(url);
    final response =
        calls < script.length ? script[calls] : script.last;
    calls++;
    return response;
  }
}

Scan _scan(String id) => Scan(
      id: id,
      serverScanId: id,
      treeId: 'MG-01-123456',
      scannedAt: DateTime.utc(2026, 1, 2),
      assessment: StabilityAssessment.moderate,
    );

SyncClient _client(_ScriptedHttp http, {String? endpoint, bool unpaired = false}) => SyncClient(
      endpointProvider: _FakeEndpoint(unpaired ? null : (endpoint ?? 'http://example.test')),
      identityProvider: _FakeIdentity(),
      imageEncoder: _FakeImages(),
      httpClient: http,
      delayOverride: (_) async {},
    );

void main() {
  group('SyncClient retry behavior', () {
    test('retries transient 500s then succeeds', () async {
      final http = _ScriptedHttp([
        const ScanHttpResponse(500, 'boom'),
        const ScanHttpResponse(500, 'boom'),
        const ScanHttpResponse(200, '{}'),
        const ScanHttpResponse(200, '{}'),
        const ScanHttpResponse(200, '{}'),
      ]);
      final client = _client(http);

      final id = await client.syncSingleScan(_scan('a'));

      expect(id, 'a');
      // register + session + 2 failed attempts + success
      expect(http.calls, 5);
    });

    test('does not retry validation errors', () async {
      final http = _ScriptedHttp([
        const ScanHttpResponse(200, '{}'), // register
        const ScanHttpResponse(200, '{}'), // session
        const ScanHttpResponse(400, 'bad scan'),
      ]);
      final client = _client(http);

      await expectLater(
        client.syncSingleScan(_scan('a')),
        throwsA(isA<SyncValidationError>()),
      );
      expect(http.calls, 3);
    });

    test('throws when no server is paired', () async {
      final http = _ScriptedHttp([]);
      final client = _client(http, unpaired: true);

      await expectLater(
        client.syncSingleScan(_scan('a')),
        throwsA(isA<SyncNotPairedError>()),
      );
      expect(http.calls, 0);
    });
  });

  group('flushPendingScans failure handling', () {
    test('records per-id failures instead of throwing', () async {
      final http = _ScriptedHttp([
        const ScanHttpResponse(200, '{}'), // register
        const ScanHttpResponse(200, '{}'), // session
        const ScanHttpResponse(500, 'down'),
        const ScanHttpResponse(500, 'down'),
        const ScanHttpResponse(500, 'down'),
      ]);
      final client = _client(http);

      final result =
          await client.flushPendingScans([_scan('a'), _scan('b')]);

      expect(result.syncedCount, 0);
      expect(result.failures.keys, containsAll(['a', 'b']));
      expect(result.allSucceeded, isFalse);
    });

    test('uses stable serverScanId in batch payload', () async {
      final http = _ScriptedHttp([
        const ScanHttpResponse(200, '{}'),
        const ScanHttpResponse(200, '{}'),
        const ScanHttpResponse(200, '{}'),
      ]);
      final client = _client(http);

      final result = await client.flushPendingScans([_scan('stable-1')]);

      expect(result.syncedIds, ['stable-1']);
      expect(http.requestedUrls.last.path, contains('batch'));
    });

    test('empty queue short-circuits without network', () async {
      final http = _ScriptedHttp([]);
      final client = _client(http);

      final result = await client.flushPendingScans(const []);

      expect(result.syncedCount, 0);
      expect(http.calls, 0);
    });
  });
}
