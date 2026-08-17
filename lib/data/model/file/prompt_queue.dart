import 'dart:async';

/// Runs questions one at a time, in the order they were asked.
///
/// For the dialogs a transfer raises from its isolate. A server-to-server
/// transfer connects to two machines from one worker, and several transfers
/// can be running at once — so without this the dialogs stack, and what is on
/// top is not what the text underneath is describing.
///
/// That is worse than untidy for a host key. The question is "does this
/// fingerprint belong to that host", and stacking makes the user answer it
/// about the wrong one — accepting a key they never saw, for a machine they
/// were not asked about, at the exact moment the app is trying to tell them
/// something changed.
class PromptQueue {
  /// The one every transfer shares, because the screen is shared too.
  static final shared = PromptQueue();

  /// What the next question waits for.
  Future<void> _tail = Future.value();

  /// Runs [ask] once everything asked before it has been answered.
  ///
  /// Returns [ask]'s own result — the queue orders the questions and does not
  /// otherwise get between the caller and the answer.
  Future<T> add<T>(Future<T> Function() ask) {
    final result = _tail.then((_) => ask());
    // Chained on the result and off its error: one question that was refused,
    // or that threw, must not leave every later one waiting for ever.
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}
