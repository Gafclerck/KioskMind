import '../errors/failure.dart';

/// Outcome of an operation that can fail with a typed [Failure].
///
/// Used by the intent handlers of the voice module and by the use cases it
/// will call, so that a failure crosses layers without losing its type.
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failed<T> extends Result<T> {
  const Failed(this.failure);

  final Failure failure;
}
