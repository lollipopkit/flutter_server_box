part of 'page.dart';

/// What the programs in this terminal report, said as a notification while
/// the terminal is out of sight — see [ProgramStatusAlerts].
extension _ProgramStatus on SSHPageState {
  void _watchProgramStatus() {
    _sess.status.addListener(_programStatusListener);
    // Turning alerts off takes the state off the lock screen now.
    Stores.setting.programStatusAlerts.listenable().addListener(
      _programStatusListener,
    );
  }

  /// What an adopted session already reports, for the session manager only:
  /// it is not news, so no alert.
  void _publishProgramStatus() => _reportProgramToSessionManager();

  void _unwatchProgramStatus() {
    _sess.status.removeListener(_programStatusListener);
    Stores.setting.programStatusAlerts.listenable().removeListener(
      _programStatusListener,
    );
    ProgramStatusAlerts.cancel(_sessionId, forget: true);
  }

  bool get _onScreen =>
      _isVisibleSessionPage &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void _onProgramStatus() {
    if (!mounted) return;
    _reportProgramToSessionManager();
    // Taken on screen too: what was watched as it happened is not news later.
    final alerts = _statusAlerts.take(_sess.status);
    if (!Stores.setting.programStatusAlerts.fetch()) return;
    if (_onScreen) {
      // Asked now, while there is someone to answer: a request from the
      // background is not shown on iOS.
      unawaited(ProgramStatusAlerts.prepare());
      return;
    }
    final alert = alerts.firstOrNull;
    if (alert == null) return;
    ProgramStatusAlerts.show(
      key: _sessionId,
      title: widget.args.source.label,
      body: _describeAlert(alert),
      reveal: _revealFromAlert,
    );
  }

  /// For the foreground notification and the Live Activity, which can be
  /// read without unlocking: the state in the app's own words, never the
  /// title or message a program sent. Nothing while alerts are off.
  void _reportProgramToSessionManager() {
    final headline = Stores.setting.programStatusAlerts.fetch()
        ? _sess.status.headline
        : null;
    final shown = headline == null || headline.state == ProgramState.idle
        ? null
        : TerminalStatusHeadline(
            state: headline.state,
            report: switch (headline.report?.kind) {
              final kind? => ProgramStatusReport(
                state: ProgramState.blocked,
                kind: kind,
              ),
              null => null,
            },
          );
    TermSessionManager.updateProgram(
      _sessionId,
      shown?.state,
      shown?.stateLabel,
    );
  }

  String _describeAlert(TerminalStatusAlert alert) {
    final (text, pane) = switch (alert) {
      RecordAlert(:final headline, :final pane) => (headline.describe(), pane),
      CommandAlert(:final exitCode, :final pane) => (
        exitCode == null || exitCode == 0
            ? l10n.programCommandSucceeded
            : l10n.programCommandFailed(exitCode),
        pane,
      ),
    };
    final where = pane == null ? null : tmuxPaneLabel(pane) ?? pane.value;
    return where == null ? text : '$where · $text';
  }

  /// The terminal is being looked at: its notification has said its piece.
  void _programStatusSeen() => ProgramStatusAlerts.cancel(_sessionId);

  void _revealFromAlert() {
    if (!mounted) return;
    if (!widget.args.notFromTab) {
      ref.read(homeTabRequestProvider.notifier).go(widget.args.homeTab);
    }
    widget.args.onReveal?.call();
  }
}
