final class TmuxRestoreState {
  final String? sessionName;
  final int? windowIndex;

  const TmuxRestoreState({this.sessionName, this.windowIndex});

  bool get hasSession => sessionName != null && sessionName!.isNotEmpty;
}
