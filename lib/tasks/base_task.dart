import 'dart:async';

/// A blueprint for any task (Background or Foreground).
/// [P] is the Parameter type (Input).
/// [R] is the Return type (Output).
abstract class BaseTask<P, R> {
  /// Unique name for the task (Required for Background Scheduler)
  String get taskIdentifier;

  /// The logic to execute.
  /// MUST NOT reference UI, Context, or non-static global variables.
  FutureOr<R> execute(P params);
}