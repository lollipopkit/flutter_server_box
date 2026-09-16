import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/provider/services.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

final class ServiceDetailPageArgs {
  const ServiceDetailPageArgs({required this.spi, required this.unitKey});

  final Spi spi;

  /// [ServiceUnit.key]. A key rather than the unit, so the page shows what the
  /// latest listing says rather than what was true when it was opened.
  final String unitKey;
}

/// One unit, on a column too narrow to show it beside the list.
final class ServiceDetailPage extends StatelessWidget {
  const ServiceDetailPage({super.key, required this.args});

  final ServiceDetailPageArgs args;

  static const route = AppRouteArg<void, ServiceDetailPageArgs>(
    page: ServiceDetailPage.new,
    path: '/service_detail',
  );

  @override
  Widget build(BuildContext context) {
    return ServiceDetailView(spi: args.spi, unitKey: args.unitKey);
  }
}

/// A unit's state, why it is in it, its log, and what can be done to it.
///
/// The same view is a page of its own on a narrow column and a pane beside
/// the list on a wide one; [onClose] is what makes it the pane.
final class ServiceDetailView extends ConsumerStatefulWidget {
  const ServiceDetailView({
    super.key,
    required this.spi,
    required this.unitKey,
    this.onClose,
  });

  final Spi spi;
  final String unitKey;
  final VoidCallback? onClose;

  @override
  ConsumerState<ServiceDetailView> createState() => _ServiceDetailViewState();
}

final class _ServiceDetailViewState extends ConsumerState<ServiceDetailView> {
  late final _provider = servicesProvider(widget.spi);

  ServiceLog? _log;
  var _logLoading = false;

  /// What the log was last read for. Read again when the unit is a different
  /// one or its state moved: a restart is exactly when its last lines change.
  (String, ServiceState)? _logFor;

  bool get _pane => widget.onClose != null;

  void _rebuild(VoidCallback update) {
    if (mounted) setState(update);
  }

  ServiceUnit? _pick(ServicesState state) =>
      state.units.firstWhereOrNull((u) => u.key == widget.unitKey);

  @override
  void initState() {
    super.initState();
    ref.listenManual(_provider.select(_pick), (_, unit) {
      if (unit == null || _logFor == (unit.key, unit.state)) return;
      _logFor = (unit.key, unit.state);
      _loadLog(unit);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(_provider.select(_pick));
    final manager = ref.watch(_provider.select((state) => state.manager));

    final body = unit == null
        ? Center(child: CenterGreyTitle(libL10n.empty))
        : _pane
        ? _buildPaneBody(unit)
        : _buildPageBody(unit);
    if (_pane) return body;
    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(
          up: unit?.fullName ?? widget.unitKey,
          down: [widget.spi.name, ?manager?.displayName].join(' · '),
        ),
        actions: [if (unit != null) _buildMenu(unit)],
      ),
      body: body,
    );
  }
}

// --- Widget builders ---

extension on _ServiceDetailViewState {
  Widget _buildPaneBody(ServiceUnit unit) {
    final scheme = Theme.of(context).colorScheme;
    final primary = _primaryActions(unit);
    final secondary = unit.actions
        .where((a) => !primary.contains(a) && a != ServiceAction.stop)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 17, 20, 17),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: ServiceStatusDot(unit: unit, size: 10),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.fullName,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 20,
                          ),
                        ),
                        if (unit.description case final description?)
                          Text(description, style: UIs.text13Grey),
                      ],
                    ),
                  ),
                  _buildMenu(unit),
                  Btn.icon(
                    text: libL10n.close,
                    icon: const Icon(Icons.close, size: 18),
                    onTap: widget.onClose,
                  ),
                ],
              ),
              if (primary.isNotEmpty) ...[
                const SizedBox(height: 13),
                Wrap(
                  spacing: 9,
                  runSpacing: 7,
                  children: [
                    for (final (index, action) in primary.indexed)
                      _actionButton(unit, action, filled: index == 0),
                  ],
                ),
              ],
              const SizedBox(height: 17),
              ?_buildProblem(unit),
              _buildTiles(unit, columns: 2),
              const SizedBox(height: 17),
              ?_buildLog(unit),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 7, 20, 17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 9,
                  runSpacing: 7,
                  children: [
                    for (final action in secondary)
                      FilledButton.tonalIcon(
                        onPressed: () => _run(unit, action),
                        icon: Icon(action.icon, size: 17),
                        label: Text(action.displayName),
                      ),
                    if (_definitionCommand(unit) case final command?)
                      FilledButton.tonalIcon(
                        onPressed: () => _openInTerminal(command),
                        icon: const Icon(Icons.description_outlined, size: 17),
                        label: Text(context.l10n.serviceUnitFile),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              if (unit.actions.contains(ServiceAction.stop))
                OutlinedButton.icon(
                  onPressed: () => _run(unit, ServiceAction.stop),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                  ),
                  icon: const Icon(Icons.stop, size: 17),
                  label: Text(ServiceAction.stop.displayName),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageBody(ServiceUnit unit) {
    final scheme = Theme.of(context).colorScheme;
    final primary = _primaryActions(unit);
    final secondary = unit.actions
        .where((a) => !primary.contains(a) && a != ServiceAction.stop)
        .toList();
    final definition = _definitionCommand(unit);
    return ListView(
      padding: const EdgeInsets.fromLTRB(13, 7, 13, 40),
      children: [
        _buildProblem(unit) ?? _buildStateLine(unit),
        if (primary.isNotEmpty) ...[
          Row(
            children: [
              for (final (index, action) in primary.indexed) ...[
                if (index > 0) const SizedBox(width: 9),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: _actionButton(unit, action, filled: index == 0),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 13),
        ],
        _buildTiles(unit, columns: 2),
        const SizedBox(height: 17),
        ?_buildLog(unit),
        if (definition != null)
          _linkTile(
            icon: Icons.description_outlined,
            label: context.l10n.serviceUnitFile,
            onTap: () => _openInTerminal(definition),
          ),
        for (final action in secondary)
          _linkTile(
            icon: action.icon,
            label: action.displayName,
            onTap: () => _run(unit, action),
          ),
        if (unit.actions.contains(ServiceAction.stop))
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _run(unit, ServiceAction.stop),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.stop, size: 17),
                label: Text(ServiceAction.stop.displayName),
              ),
            ),
          ),
      ],
    );
  }

  /// Why a failed unit stopped, where the eye lands first.
  Widget? _buildProblem(ServiceUnit unit) {
    if (unit.state != ServiceState.failed) return null;
    final scheme = Theme.of(context).colorScheme;
    final ago = switch (unit.since) {
      final since? => context.l10n.serviceStoppedAgo(
        ServiceUi.shortDuration(DateTime.now().difference(since)),
      ),
      null => null,
    };
    final logCommand = ref.read(_provider.notifier).logTerminalCommand(unit);
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.1),
          border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 19, color: scheme.error),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ServiceUi.problemLine(context, unit),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (ago != null)
                    Text(
                      [ago, ?unit.startup].join(' · '),
                      style: UIs.text12Grey,
                    ),
                ],
              ),
            ),
            if (_pane && logCommand != null)
              TextButton(
                onPressed: () => _openInTerminal(logCommand),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                child: Text(context.l10n.serviceFullJournal),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateLine(ServiceUnit unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          ServiceStatusDot(unit: unit),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              {
                ServiceUi.stateWord(unit),
                ?unit.subState,
                ?ServiceUi.timeLabel(context, unit),
              }.join(' · '),
              style: UIs.text13Grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiles(ServiceUnit unit, {required int columns}) {
    final tiles = [
      (context.l10n.serviceStartup, unit.startup ?? '—'),
      (context.l10n.serviceUnitType, unit.type.name),
      (context.l10n.serviceScope, ServiceUi.scopeLabel(unit.scope)),
      (
        libL10n.memory,
        unit.memoryBytes == null ? '—' : unit.memoryBytes!.bytes2Str,
      ),
    ];
    final scheme = Theme.of(context).colorScheme;
    Widget tile((String, String) data) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.$1, style: UIs.text12Grey),
          const SizedBox(height: 3),
          Text(
            data.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      if (i > 0) rows.add(const SizedBox(height: 9));
      rows.add(
        Row(
          children: [
            for (var j = i; j < i + columns; j++) ...[
              if (j > i) const SizedBox(width: 9),
              Expanded(child: j < tiles.length ? tile(tiles[j]) : UIs.placeholder),
            ],
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  /// Null where the manager keeps no log by unit: an empty box there would
  /// read as a unit that never said anything.
  Widget? _buildLog(ServiceUnit unit) {
    final log = _log;
    if (!_logLoading && log == null) return null;
    const lines = 5;
    final body = switch (log) {
      null => const SizedBox(height: 60, child: UIs.centerLoading),
      ServiceLog(unreadable: true) => Text(
        context.l10n.serviceJournalUnreadable,
        style: UIs.text12Grey,
      ),
      ServiceLog(lines: []) => Text(libL10n.empty, style: UIs.text12Grey),
      _ => SelectableText.rich(
        TextSpan(
          children: [
            for (final (index, line) in log.lines.indexed) ...[
              if (index > 0) const TextSpan(text: '\n'),
              if (line.time case final time?)
                TextSpan(
                  text: '$time ',
                  style: TextStyle(color: UIs.textGrey.color),
                ),
              TextSpan(text: line.text),
            ],
          ],
        ),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.6,
          color: Color(0xFFE5E1E2),
        ),
      ),
    };
    final title = _pane
        ? 'JOURNAL · ${context.l10n.serviceJournalRecent(lines)}'
        : 'JOURNAL';
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.66,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 7),
          // Always dark, like a terminal: these are lines a program wrote,
          // and they are read the way a terminal's are.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(9),
            ),
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _linkTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          leading: Icon(icon, size: 20),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right, size: 19),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _actionButton(
    ServiceUnit unit,
    ServiceAction action, {
    required bool filled,
  }) {
    final icon = Icon(action.icon, size: 17);
    final label = Text(action.displayName);
    void onPressed() => _run(unit, action);
    return filled
        ? FilledButton.icon(onPressed: onPressed, icon: icon, label: label)
        : OutlinedButton.icon(onPressed: onPressed, icon: icon, label: label);
  }

  Widget _buildMenu(ServiceUnit unit) =>
      ServiceUi.unitMenu(context, ref, widget.spi, unit);
}

// --- Utils ---

extension on _ServiceDetailViewState {
  /// Start where a unit is not running, Restart where it has failed or is.
  /// Stop is kept apart and at the other end, in red.
  List<ServiceAction> _primaryActions(ServiceUnit unit) => [
    for (final action in const [ServiceAction.restart, ServiceAction.start])
      if (unit.actions.contains(action)) action,
  ];

  String? _definitionCommand(ServiceUnit unit) =>
      ref.read(_provider.notifier).definitionTerminalCommand(unit);
}

// --- Actions ---

extension on _ServiceDetailViewState {
  Future<void> _loadLog(ServiceUnit unit) async {
    _rebuild(() => _logLoading = true);
    final log = await ref.read(_provider.notifier).recentLog(unit);
    if (!mounted || _logFor?.$1 != unit.key) return;
    _rebuild(() {
      _log = log;
      _logLoading = false;
    });
  }

  Future<void> _run(ServiceUnit unit, ServiceAction action) =>
      ServiceUi.runAction(context, ref, widget.spi, unit, action);

  void _openInTerminal(String command) =>
      ServiceUi.openInTerminal(context, widget.spi, command);
}

/// What the list and the detail view both draw and both do.
abstract final class ServiceUi {
  static const running = Color(0xFF22C55E);
  static const failed = Colors.red;
  static const transitioning = Colors.orange;
  static const idle = Colors.grey;

  static Color stateColor(ServiceState state) => switch (state) {
    ServiceState.running => running,
    ServiceState.failed => failed,
    ServiceState.starting || ServiceState.stopping => transitioning,
    ServiceState.stopped || ServiceState.unknown => idle,
  };

  /// systemd's words, as `systemctl` prints them, for every manager: they are
  /// what a user searches for and what a unit's own log says.
  static String stateWord(ServiceUnit unit) => switch (unit.state) {
    ServiceState.running => 'running',
    ServiceState.stopped => 'inactive',
    ServiceState.failed => 'failed',
    ServiceState.starting => 'activating',
    ServiceState.stopping => 'deactivating',
    ServiceState.unknown => 'unknown',
  };

  static String scopeLabel(ServiceScope scope) => switch (scope) {
    ServiceScope.system => libL10n.system,
    ServiceScope.user => libL10n.user,
  };

  /// `3 min`, `2 h`, `31 d`: short enough for a column, and units that read
  /// the same in every language this app ships.
  static String shortDuration(Duration duration) {
    final d = duration.abs();
    if (d.inDays > 0) return '${d.inDays} d';
    if (d.inHours > 0) return '${d.inHours} h';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }

  /// How long the unit has been as it is, or when a timer fires next. Null
  /// where the manager did not say.
  static String? timeLabel(BuildContext context, ServiceUnit unit) {
    final now = DateTime.now();
    if (unit.nextElapse case final next? when next.isAfter(now)) {
      return context.l10n.serviceNextIn(shortDuration(next.difference(now)));
    }
    final since = unit.since;
    if (since == null) {
      return unit.state == ServiceState.stopped ? 'inactive' : null;
    }
    final elapsed = shortDuration(now.difference(since));
    return switch (unit.state) {
      ServiceState.running => context.l10n.serviceUpFor(elapsed),
      ServiceState.failed => context.l10n.serviceDownFor(elapsed),
      ServiceState.starting || ServiceState.stopping => elapsed,
      ServiceState.stopped || ServiceState.unknown => 'inactive',
    };
  }

  /// `failed · exit-code · exit status 1`, `activating · start-pre`.
  static String problemLine(BuildContext context, ServiceUnit unit) {
    return [
      stateWord(unit),
      if (unit.state == ServiceState.failed) ?unit.result,
      if (unit.state != ServiceState.failed &&
          unit.subState != stateWord(unit))
        ?unit.subState,
      if (unit.exitStatus case final code?)
        context.l10n.serviceExitStatus('$code'),
    ].join(' · ');
  }

  /// A unit's actions, then what can be read about it in a terminal.
  static Widget unitMenu(
    BuildContext context,
    WidgetRef ref,
    Spi spi,
    ServiceUnit unit,
  ) {
    final notifier = ref.read(servicesProvider(spi).notifier);
    final log = notifier.logTerminalCommand(unit);
    final definition = notifier.definitionTerminalCommand(unit);
    return PopupMenuButton<VoidCallback>(
      tooltip: libL10n.more,
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (callback) => callback(),
      itemBuilder: (_) => [
        for (final action in unit.actions)
          PopupMenuItem(
            value: () => runAction(context, ref, spi, unit, action),
            child: menuRow(action.icon, action.displayName),
          ),
        if (unit.actions.isNotEmpty && (log != null || definition != null))
          const PopupMenuDivider(),
        if (log != null)
          PopupMenuItem(
            value: () => openInTerminal(context, spi, log),
            child: menuRow(Icons.receipt_long, context.l10n.serviceFullJournal),
          ),
        if (definition != null)
          PopupMenuItem(
            value: () => openInTerminal(context, spi, definition),
            child: menuRow(
              Icons.description_outlined,
              context.l10n.serviceUnitFile,
            ),
          ),
      ],
    );
  }

  static Widget menuRow(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
  );

  /// Runs [action] on [unit] here and reports how it went.
  ///
  /// One that can interrupt a working service shows the command and waits
  /// three seconds before it can be confirmed. A unit that needs root and an
  /// account without passwordless sudo gets the password prompt the users
  /// page uses, and a rejected password is not retried silently.
  static Future<void> runAction(
    BuildContext context,
    WidgetRef ref,
    Spi spi,
    ServiceUnit unit,
    ServiceAction action,
  ) async {
    final notifier = ref.read(servicesProvider(spi).notifier);
    final command = notifier.commandFor(unit, action);
    if (command == null) return;

    if (action.destructive) {
      final sure = await context.showRoundDialog<bool>(
        title: libL10n.attention,
        child: SimpleMarkdown(data: '```shell\n$command\n```'),
        actions: [
          Btn.cancel(),
          CountDownBtn(
            seconds: 3,
            onTap: () => context.popDialog(true),
            text: libL10n.ok,
            afterColor: Colors.red,
          ),
        ],
      );
      if (sure != true || !context.mounted) return;
    }

    // A restart waits for the unit to come up, which systemd allows 90 seconds
    // by default before it gives up on it.
    const timeout = Duration(seconds: 100);
    var (result, _) = await context.showLoadingDialog(
      fn: () => notifier.runAction(unit, action),
      timeout: timeout,
    );
    if (!context.mounted || result == null) return;

    if (result.exitCode == kSudoPasswordRejected) {
      final password = await context.showPwdDialog(
        title: libL10n.sudoPassword,
        label: spi.ssh?.user ?? '',
        id: '${spi.id}_sudo_services',
      );
      if (!context.mounted || password == null || password.isEmpty) return;
      (result, _) = await context.showLoadingDialog(
        fn: () => notifier.runAction(unit, action, password: password),
        timeout: timeout,
      );
      if (!context.mounted || result == null) return;
      if (result.exitCode == kSudoPasswordRejected) {
        Toast.error(libL10n.permissionDenied);
        return;
      }
    }

    if (result.succeeded) {
      Toast.success(libL10n.success);
    } else {
      final detail = result.combined.trim();
      Toast.error(libL10n.fail, body: detail.isEmpty ? null : detail);
    }
    // Refreshed either way: a failed restart still changed what the unit is.
    await notifier.getServices();
  }

  /// Opens a terminal running [command], for what is read rather than acted
  /// on: a whole log, a unit file. A command that needs root is prefixed with
  /// `sudo` there, where the terminal can ask for the password itself.
  static void openInTerminal(BuildContext context, Spi spi, String command) {
    SSHPage.route.go(
      context,
      SshPageArgs(
        source: ServerSource(spi),
        initCmd: command,
        notFromTab: true,
      ),
    );
  }
}

class ServiceStatusDot extends StatelessWidget {
  const ServiceStatusDot({super.key, required this.unit, this.size = 7});

  final ServiceUnit unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ServiceUi.stateColor(unit.state),
      ),
    );
  }
}
