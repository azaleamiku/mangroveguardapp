/// Sync-specific error types with user-facing messages and retry semantics.
sealed class SyncError {
  const SyncError();

  /// Human-readable message for logging/debugging.
  String get message;

  /// Whether this error should be retried (transient).
  bool get retryable => false;
}

class SyncNetworkError extends SyncError {
  final String reason;
  const SyncNetworkError(this.reason);

  @override
  String get message => 'Network error: $reason';

  @override
  bool get retryable => true;
}

class SyncTimeoutError extends SyncError {
  final String reason;
  const SyncTimeoutError([this.reason = 'Request timed out']);

  @override
  String get message => reason;

  @override
  bool get retryable => true;
}

class SyncServerError extends SyncError {
  final int statusCode;
  final String reason;
  const SyncServerError(this.statusCode, this.reason);

  @override
  String get message => 'Server error ($statusCode): $reason';

  @override
  bool get retryable => statusCode >= 500;
}

class SyncValidationError extends SyncError {
  final String reason;
  const SyncValidationError(this.reason);

  @override
  String get message => 'Invalid request: $reason';
}

class SyncAuthError extends SyncError {
  final String reason;
  const SyncAuthError(this.reason);

  @override
  String get message => 'Authentication failed: $reason';
}

class SyncUnknownError extends SyncError {
  final String reason;
  const SyncUnknownError(this.reason);

  @override
  String get message => 'Unknown error: $reason';
}

class SyncNotPairedError extends SyncError {
  const SyncNotPairedError();

  @override
  String get message => 'No paired server configured.';
}

class SyncImageError extends SyncError {
  final String reason;
  const SyncImageError(this.reason);

  @override
  String get message => 'Image preparation failed: $reason';
}
