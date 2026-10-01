part of 'firewall.dart';

/// What [FirewallPage] hands the page of one firewall.
final class _FirewallHost {
  const _FirewallHost({
    required this.spi,
    required this.probe,
    required this.accesses,
    required this.onSwitch,
  });

  final Spi spi;
  final FirewallProbeResult probe;

  /// What every change is checked against.
  final List<FirewallAccess> accesses;

  /// Shows the other firewall, where the server has both.
  final ValueChanged<FirewallKind> onSwitch;
}

/// What a change does to one way in: as it is, and as it would be.
///
/// [later] is about what is written down rather than what is in force:
/// firewalld's permanent configuration, which takes over at a reload or a
/// boot.
typedef _Effect = ({
  FirewallAccess access,
  FirewallReach before,
  FirewallReach after,
  bool later,
});

/// What both firewalls' pages share: running as root, asking before a
/// change, and the pieces they are drawn with.
mixin _FirewallView<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  _FirewallHost get host;

  bool busy = false;

  /// The user declined to give the sudo password the read needs.
  bool needsRoot = false;
  String? failure;

  /// Reads the firewall again.
  Future<void> refresh();

  /// [setState], for the extensions a page is split into.
  void rebuild(VoidCallback update) => setState(update);

  ServerNotifier get server => ref.read(serverProvider(host.spi.id).notifier);

  /// [script] as root, asking for the sudo password where it is needed.
  /// Null when the user declined to give one.
  Future<ExecResult?> privileged(ServerExec exec, String script) {
    return SudoPassword.retry(
      context,
      host.spi.id,
      label: host.spi.ssh?.user,
      attempt: (password) => PrivilegedExec.run(
        exec,
        script,
        isRoot: password == null && (host.probe.root || host.spi.isRoot),
        password: password,
      ),
      rejected: (r) => r.exitCode == kSudoPasswordRejected,
    );
  }

  /// Reads with [script] as root, into what [parse] makes of it. Null where
  /// that failed; [needsRoot] or [failure] then says why.
  Future<S?> read<S>(String script, S Function(String stdout) parse) async {
    if (!mounted || busy) return null;
    setState(() {
      busy = true;
      needsRoot = false;
      failure = null;
    });
    try {
      final exec = await server.ensureExec();
      if (!mounted) return null;
      final result = await privileged(exec, script);
      if (!mounted) return null;
      if (result == null) {
        setState(() => needsRoot = true);
        return null;
      }
      if (!result.succeeded) {
        final detail = result.combined.trim();
        setState(() => failure = detail.isEmpty ? libL10n.fail : detail);
        return null;
      }
      return parse(result.stdout);
    } catch (e, s) {
      Loggers.app.warning('Read firewall on ${host.spi.id}', e, s);
      if (mounted) setState(() => failure = '$e');
      return null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Runs [commands] as root, then reads the firewall again.
  Future<bool> run(List<String> commands) async {
    if (busy) return false;
    setState(() => busy = true);
    var ok = false;
    try {
      final exec = await server.ensureExec();
      if (!mounted) return false;
      final result = await privileged(exec, firewallScript(commands));
      if (result == null) return false;
      if (!result.succeeded) {
        if (mounted) {
          final detail = result.combined.trim();
          Toast.error(libL10n.fail, body: detail.isEmpty ? null : detail);
        }
      } else {
        ok = true;
      }
    } catch (e, s) {
      Loggers.app.warning('Change firewall on ${host.spi.id}', e, s);
      if (mounted) Toast.error('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
    // Read again after a failure too: a script stopped part way through has
    // still changed what it got to.
    await refresh();
    if (ok && mounted) Toast.success(libL10n.success);
    return ok;
  }

  /// [host]'s ways in, each with what [before] and [after] say of it.
  List<_Effect> effects(
    FirewallReach Function(FirewallAccess) before,
    FirewallReach Function(FirewallAccess) after, {
    bool later = false,
  }) => [
    for (final access in host.accesses)
      (
        access: access,
        before: before(access),
        after: after(access),
        later: later,
      ),
  ];

  /// Asks before [commands] run, showing them unless there is a [message]
  /// to say instead, and saying which way in a change would shut or narrow.
  ///
  /// [keepOpen] makes the commands that keep given ways in open; offered,
  /// and ticked where the way would surely be shut, when there is one. A
  /// change that still shuts one asks with a countdown, not a tap.
  ///
  /// Answers what to run — [keepOpen]'s commands first where ticked — or
  /// null.
  Future<List<String>?> confirm({
    required List<String> commands,
    String? message,
    List<String> notes = const [],
    bool destructive = false,
    List<_Effect> effects = const [],
    List<String> Function(List<FirewallAccess> accesses)? keepOpen,
  }) async {
    final worse = [
      for (final e in effects)
        if (e.after.worseThan(e.before)) e,
    ];
    final shut = [
      for (final e in worse)
        if (!e.after.admits) e.access,
    ];
    final rescue = keepOpen == null || shut.isEmpty ? null : keepOpen(shut);
    var keep =
        rescue != null && worse.any((e) => e.after == FirewallReach.blocked);
    final blocked = worse.any((e) => e.after == FirewallReach.blocked);
    final sure = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (context, setDialogState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message != null)
                Text(message)
              else
                SimpleMarkdown(data: '```shell\n${commands.join('\n')}\n```'),
              for (final note in notes) ...[
                UIs.height7,
                Text(note, style: UIs.text12Grey),
              ],
              for (final e in worse) ...[
                UIs.height13,
                Text(
                  _reachWarning(e.access, e.after, later: e.later),
                  style: e.after == FirewallReach.blocked
                      ? UIs.textRed
                      : TextStyle(color: Colors.orange.shade800),
                ),
              ],
              if (rescue != null) ...[
                UIs.height7,
                CheckboxListTile(
                  value: keep,
                  title: Text(l10n.firewallKeepAccess),
                  subtitle: Text(
                    rescue.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setDialogState(() => keep = value ?? false);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        Btn.cancel(),
        if (blocked)
          CountDownBtn(
            onTap: () => context.popDialog(true),
            text: libL10n.ok,
            afterColor: Colors.red,
          )
        else if (destructive)
          Btnx.okRed
        else
          Btn.ok(onTap: () => context.popDialog(true)),
      ],
    );
    if (sure != true || !mounted) return null;
    return [if (keep && rescue != null) ...rescue, ...commands];
  }

  String _reachWarning(
    FirewallAccess access,
    FirewallReach reach, {
    bool later = false,
  }) {
    final name = _accessName(access);
    return switch (reach) {
      FirewallReach.blocked when later => l10n.firewallDriftLockoutFmt(name),
      FirewallReach.blocked => l10n.firewallWillRefuseFmt(name),
      FirewallReach.unknown => l10n.firewallMayRefuseFmt(name),
      FirewallReach.limited => l10n.firewallRateLimitedFmt(name),
      FirewallReach.open => '',
    };
  }

  /// The backends this server has, as a bar button to switch between them.
  List<Widget> switchAction(FirewallKind current) {
    final kinds = host.probe.installed.keys.toList();
    if (kinds.length < 2) return const [];
    return [
      ContextMenuButton(
        tooltip: l10n.firewall,
        enabled: !busy,
        actions: () => [
          for (final kind in kinds)
            ContextMenuAction(
              text: kind.name,
              checked: kind == current,
              onTap: () => host.onSwitch(kind),
            ),
        ],
        child: ContextMenuButton.value(Text(current.name)),
      ),
    ];
  }

  /// Said above everything else while both firewalls are on: [self] as
  /// it was just read — it may have been switched on or off here since the
  /// probe — and the other as the probe found it.
  Widget? conflictBanner(FirewallKind self, {required bool on}) {
    final others = host.probe.installed.entries.where((e) => e.key != self);
    if (!on || !others.any((e) => e.value)) return null;
    return banner(Icons.warning_amber, l10n.firewallConflict, danger: true);
  }

  Widget banner(
    IconData icon,
    String text, {
    bool danger = false,
    List<Widget> actions = const [],
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fg = danger ? scheme.onErrorContainer : scheme.onTertiaryContainer;
    return Container(
      margin: const EdgeInsets.fromLTRB(13, 8, 13, 2),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
      decoration: BoxDecoration(
        color: danger ? scheme.errorContainer : scheme.tertiaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 9),
              Expanded(child: Text(text, style: TextStyle(color: fg))),
            ],
          ),
          if (actions.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(spacing: 7, children: actions),
            ),
        ],
      ),
    );
  }

  Widget card(Widget child) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(13, 8, 13, 2),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(13)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  /// A card's band: what it lists, and how many.
  Widget sectionHeader(String title, {int? count, VoidCallback? onAdd}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainer,
      padding: EdgeInsets.fromLTRB(13, onAdd == null ? 7 : 0, 4, onAdd == null ? 7 : 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null ? title : '$title · $count',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
          if (onAdd != null)
            Btn.icon(
              text: libL10n.add,
              icon: const Icon(Icons.add, size: 18),
              onTap: busy ? null : onAdd,
            ),
        ],
      ),
    );
  }

  Widget row(Widget title, Widget? trailing, {bool last = false}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.fromLTRB(13, 4, 7, 4),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        children: [
          Expanded(child: title),
          ?trailing,
        ],
      ),
    );
  }

  Widget tag(String text, Color foreground, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: foreground)),
    );
  }

  Widget greyTag(String text) {
    final scheme = Theme.of(context).colorScheme;
    return tag(text, scheme.onSurfaceVariant, scheme.surfaceContainerHighest);
  }

  TextStyle get monoStyle => TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    color: UIs.textGrey.color,
  );

  Color get hairline =>
      Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35);

  /// Every way the page can be when it is not drawing the firewall itself,
  /// or null when it is.
  Widget? issue() {
    if (needsRoot) {
      return _issueBody(
        context,
        title: libL10n.fail,
        explain: l10n.firewallNeedsRoot,
        icon: Icons.lock_outline,
        onRetry: refresh,
      );
    }
    if (failure case final failure?) {
      return _issueBody(
        context,
        title: libL10n.fail,
        detail: failure,
        icon: Icons.error_outline,
        onRetry: refresh,
      );
    }
    return null;
  }

  Widget loading() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: const [SizedBox(height: 280, child: UIs.centerLoading)],
  );

  /// One line of input, asked in a dialog; null when cancelled.
  Future<String?> askText({
    required String title,
    required String label,
    String? hint,
    IconData? icon,
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    final ok = await context.showRoundDialog<bool>(
      title: title,
      child: DisposeWith(
        notifiers: [ctrl],
        child: Input(
          controller: ctrl,
          label: label,
          hint: hint,
          icon: icon,
          autoFocus: true,
          suggestion: false,
          onSubmitted: (_) => context.popDialog(true),
        ),
      ),
      actions: Btnx.cancelOk,
    );
    final text = ctrl.text.trim();
    if (ok != true || text.isEmpty) return null;
    return text;
  }
}

/// `SSH 22`, `Monitor 3770`: a way in, as a warning names it.
String _accessName(FirewallAccess access) => switch (access.via) {
  FirewallAccessVia.ssh => 'SSH (TCP ${access.port})',
  FirewallAccessVia.monitor => 'Monitor (TCP ${access.port})',
};

Widget _issueBody(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Future<void> Function() onRetry,
  String? explain,
  String? detail,
}) {
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: PageIssueView(
          title: title,
          explain: explain,
          detail: detail,
          icon: icon,
          onRetry: onRetry,
        ),
      ),
    ],
  );
}
