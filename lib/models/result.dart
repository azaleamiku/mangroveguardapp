/// Result type for explicit success/failure handling.
/// Replaces exception-throwing with structured, typed results.
sealed class Result<T, E> {
  const Result();
}

class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ok<T, E> && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Err<T, E> && error == other.error;

  @override
  int get hashCode => error.hashCode;
}

extension ResultExtension<T, E> on Result<T, E> {
  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;

  T? get value => (this is Ok<T, E>) ? (this as Ok<T, E>).value : null;
  E? get error => (this is Err<T, E>) ? (this as Err<T, E>).error : null;

  R map<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) {
    return switch (this) {
      Ok(value: final v) => ok(v),
      Err(error: final e) => err(e),
    };
  }

  T unwrapOr(T fallback) {
    return switch (this) {
      Ok(value: final v) => v,
      Err() => fallback,
    };
  }
}

/// Detection-specific error types with user-facing messages.
sealed class DetectionError {
  const DetectionError();

  String get message;
}

class DetectionModelNotLoaded extends DetectionError {
  const DetectionModelNotLoaded();

  @override
  String get message =>
      'Detection model is not loaded. Please restart the scanner.';
}

class DetectionImageDecodeFailed extends DetectionError {
  final String reason;
  const DetectionImageDecodeFailed([this.reason = '']);

  @override
  String get message => reason.isNotEmpty
      ? 'Unable to decode image: $reason'
      : 'Unable to decode image.';
}

class DetectionInvalidTensorShape extends DetectionError {
  final String shape;
  const DetectionInvalidTensorShape(this.shape);

  @override
  String get message => 'Model input tensor has an unexpected shape: $shape';
}

class DetectionInferenceFailed extends DetectionError {
  final String reason;
  const DetectionInferenceFailed([this.reason = '']);

  @override
  String get message => reason.isNotEmpty
      ? 'Detection inference failed: $reason'
      : 'Detection inference failed.';
}

class DetectionNoResult extends DetectionError {
  const DetectionNoResult();

  @override
  String get message => 'No mangrove detected in this image.';
}

class DetectionUnknownError extends DetectionError {
  final String reason;
  const DetectionUnknownError(this.reason);

  @override
  String get message => reason.isNotEmpty
      ? 'Detection failed: $reason'
      : 'Detection failed unexpectedly.';
}
