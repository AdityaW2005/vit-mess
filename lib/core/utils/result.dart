/// Why an operation failed. Views map this to a designed error state rather
/// than showing an exception string.
enum FailureKind {
  /// No connectivity, timeout, or a non-2xx response.
  network,

  /// The document was fetched but could not be understood.
  parse,

  /// Reading or writing local storage failed.
  storage,

  /// The user cancelled an interactive flow (e.g. the file picker).
  cancelled,

  /// A platform permission was refused.
  permission,

  /// Nothing cached and nothing bundled.
  empty,

  /// The action cannot run in this build — e.g. downloading when no menu
  /// server is configured. Not an error the student caused.
  unsupported,

  /// Anything not covered above.
  unknown,
}

/// A total, non-throwing outcome type.
///
/// Repositories return this so the ViewModel layer never has to catch.
sealed class Result<T> {
  const Result();

  /// Wraps a successful value.
  const factory Result.success(T value) = Success<T>;

  /// Wraps a failure.
  const factory Result.failure(
    String message, {
    FailureKind kind,
    Object? cause,
  }) = Failure<T>;

  /// True when this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// True when this is a [Failure].
  bool get isFailure => this is Failure<T>;

  /// The value if successful, otherwise `null`.
  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };

  /// The failure if unsuccessful, otherwise `null`.
  Failure<T>? get failureOrNull => switch (this) {
    Success<T>() => null,
    final Failure<T> failure => failure,
  };

  /// Folds both branches into a single value.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure<T> failure) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    final Failure<T> failure => onFailure(failure),
  };

  /// Maps a successful value, preserving any failure unchanged.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Success<R>(transform(value)),
    Failure<T>(:final message, :final kind, :final cause) => Failure<R>(
      message,
      kind: kind,
      cause: cause,
    ),
  };
}

/// A successful [Result].
final class Success<T> extends Result<T> {
  /// Creates a success carrying [value].
  const Success(this.value);

  /// The produced value.
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Success<T> &&
          runtimeType == other.runtimeType &&
          value == other.value);

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'Success<$T>($value)';
}

/// A failed [Result].
final class Failure<T> extends Result<T> {
  /// Creates a failure with a user-presentable [message].
  const Failure(this.message, {this.kind = FailureKind.unknown, this.cause});

  /// Plain-language description, safe to show to a student.
  final String message;

  /// Machine-readable category used to pick the right UI treatment.
  final FailureKind kind;

  /// The underlying error, kept for logging only. Never rendered.
  final Object? cause;

  /// Re-types this failure so it can be returned from a differently typed call.
  Failure<R> cast<R>() => Failure<R>(message, kind: kind, cause: cause);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure<T> &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          kind == other.kind);

  @override
  int get hashCode => Object.hash(runtimeType, message, kind);

  @override
  String toString() => 'Failure<$T>($kind: $message)';
}
