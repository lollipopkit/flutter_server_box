final class TmuxRestoreState {
  final String? sessionName;
  final int? windowIndex;

  const TmuxRestoreState({this.sessionName, this.windowIndex});

  bool get hasSession => sessionName != null && sessionName!.isNotEmpty;
}

TmuxRestoreState resolveTmuxRestoreState({
  String? argsSession,
  int? argsWindow,
  String? restorableSession,
  int? restorableWindow,
}) {
  if (argsSession != null) {
    return TmuxRestoreState(
      sessionName: argsSession,
      windowIndex: argsWindow,
    );
  }

  if (restorableSession != null) {
    return TmuxRestoreState(
      sessionName: restorableSession,
      windowIndex: restorableWindow,
    );
  }

  return const TmuxRestoreState();
}
