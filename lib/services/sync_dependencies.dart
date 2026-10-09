/// Injectable collaborators for the sync client.
///
/// Each abstraction has a production implementation (wiring the real
/// `SharedPreferences` / `DeviceInfoPlugin` / `HttpClient` / `File` APIs)
/// and a fake for tests. Previously `MonitoringSyncService` constructed all
/// of these inline as statics, making retry/offline paths untestable.
abstract class EndpointProvider {
  Future<String?> getEndpoint();
}

abstract class DeviceIdentityProvider {
  Future<String> getOrCreateDeviceId();
  Future<String> getOrCreateSessionId();
  Future<String> getDeviceName();
}

abstract class ImageEncoder {
  /// Returns base64 JPEG (max 1200px wide) or null when unavailable/too large.
  Future<String?> encodeImage(String? imagePath);
}

abstract class ScanHttpClient {
  Future<ScanHttpResponse> postJson(Uri url,
      {required Map<String, String> headers, required String body});
}

class ScanHttpResponse {
  final int statusCode;
  final String body;

  const ScanHttpResponse(this.statusCode, this.body);
}
