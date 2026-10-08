part of 'page.dart';

/// What the programs in this terminal report, said as a notification while
/// the terminal is out of sight — see [ProgramStatusAlerts].
extension _ProgramStatus on SSHPageState {
  void _watchProgramStatus() {
    _sess.status.addListener(_programStatusListener);
  }

  void _unwatchProgramStatus() {
    _sess.status.removeListener(_programStatusListener);
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

  /// For the foreground notification and the Live Activity. Without the
  /// progress, and without a running program's message: either would make
  /// every step of it a platform call, and ActivityKit budgets updates.
  void _reportProgramToSessionManager() {
    final headline = _sess.status.headline;
    final report = headline?.report;
    final shown = headline == null || headline.state == ProgramState.idle
        ? null
        : TerminalStatusHeadline(
            state: headline.state,
            report: headline.state != ProgramState.working || report == null
                ? report
                : ProgramStatusReport(
                    state: report.state,
                    kind: report.kind,
                    title: report.title,
                  ),
          );
    TermSessionManager.updateProgram(
      _sessionId,
      shown?.state,
      shown?.describe(),
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
