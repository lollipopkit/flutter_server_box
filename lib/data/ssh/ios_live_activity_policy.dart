/// What one iOS Live Activity sync should do.
enum IosLiveActivityAction {
  /// Push the current sessions, raising an activity if there is none.
  update,

  /// End whatever is up, and stand the refresh timer down.
  stop,
}

/// Chooses what to do with the Live Activity for the latest terminal state.
///
/// A function rather than two lines inside `_syncLatest`, for the same reason
/// as [decideAndroidSessionServiceAction]: everything around it is gated on
/// `isIOS`, which is false wherever the tests run, so the decision is only
/// reachable on a device. This is the part worth being sure of.
///
/// [enabled] failing reads exactly like having no sessions, which is the whole
/// of the switch. Not "leave it alone": an activity outlives the process that
/// raised it, so turning the switch off has to end the one already on the lock
/// screen rather than merely stop refreshing it — otherwise it stays there,
/// going stale, until the session ends or the user swipes it away.
IosLiveActivityAction decideIosLiveActivityAction({
  required bool hasSessions,
  required bool enabled,
}) {
  if (hasSessions && enabled) return IosLiveActivityAction.update;
  return IosLiveActivityAction.stop;
}
