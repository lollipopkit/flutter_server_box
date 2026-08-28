/// What one serialized Android terminal-service sync should do.
enum AndroidSessionServiceAction { update, stop, none }

/// Chooses a single service transition for the latest terminal state.
///
/// An empty update is deliberately not an action: `updateSessions` starts a
/// foreground service when needed, so using it to say "nothing is running"
/// briefly starts and immediately stops that service. Android 16 can treat
/// that race as an unmet `startForegroundService` contract and kill the app.
AndroidSessionServiceAction decideAndroidSessionServiceAction({
  required bool wanted,
  required bool running,
  required bool backgrounded,
}) {
  if (wanted) return AndroidSessionServiceAction.update;
  if (running && !backgrounded) return AndroidSessionServiceAction.stop;
  return AndroidSessionServiceAction.none;
}
