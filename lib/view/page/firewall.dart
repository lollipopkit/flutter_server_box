import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/server/firewall.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/service/ufw_manager.dart';

enum _Issue { unsupported, missing, needsRoot }

enum _Target { port, app }

/// The three kinds of traffic a rule can be for: to this host, from it, or
/// through it.
enum _Flow {
  incoming,
  outgoing,
  routed;

  String get label => switch (this) {
    incoming => l10n.firewallIncoming,
    outgoing => l10n.firewallOutgoing,
    routed => l10n.firewallRouted,
  };
}

enum _Protocol {
  any,
  tcp,
  udp;

  String? get value => this == any ? null : name;
}

/// A server's ufw: whether it is on, what it does by default, and its rules.
final class FirewallPage extends ConsumerStatefulWidget {
  const FirewallPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: FirewallPage.new,
    path: '/firewall',
  );

  @override
  ConsumerState<FirewallPage> createState() => _FirewallPageState();
}

final class _FirewallPageState extends ConsumerState<FirewallPage> {
  late final _provider = serverProvider(widget.args.spi.id);

  UfwSnapshot? _snapshot;
  bool _busy = false;

  /// Whether commands already run as root, as the probe found.
  bool _root = false;
  _Issue? _issue;
  String? _failure;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  void _rebuild(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final ready = snapshot != null && _issue == null && _failure == null;
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: l10n.firewall, down: widget.args.spi.name),
        actions: _buildActions(ready ? snapshot : null),
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
      floatingActionButton: ready
          ? FloatingActionButton(
              tooltip: l10n.firewallAddRule,
              onPressed: _busy ? null : () => _addRule(snapshot),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// --- Widget builders ---

extension on _FirewallPageState {
  List<Widget> _buildActions(UfwSnapshot? snapshot) {
    return [
      if (isDesktop)
        Btn.icon(
          text: libL10n.refresh,
          icon: const Icon(Icons.refresh, size: 18),
          onTap: _busy ? null : _refresh,
        ),
      ContextMenuButton(
        tooltip: libL10n.more,
        enabled: snapshot?.active == true && !_busy,
        actions: () => [
          ContextMenuAction(
            text: l10n.firewallReload,
            icon: Icons.sync,
            onTap: () => _run([UfwManager.reloadCommand]),
          ),
        ],
      ),
    ];
  }

  Widget _buildBody() {
    switch (_issue) {
      case _Issue.unsupported:
        return _issueBody(
          title: libL10n.unsupported,
          explain: l10n.firewallLinuxOnly,
          icon: Icons.not_interested,
        );
      case _Issue.missing:
        return _issueBody(
          title: libL10n.unsupported,
          explain: l10n.firewallUfwMissing,
          icon: Icons.shield_outlined,
        );
      case _Issue.needsRoot:
        return _issueBody(
          title: libL10n.fail,
          explain: l10n.firewallNeedsRoot,
          icon: Icons.lock_outline,
        );
      case null:
    }
    if (_failure case final failure?) {
      return _issueBody(
        title: libL10n.fail,
        detail: failure,
        icon: Icons.error_outline,
      );
    }
    final snapshot = _snapshot;
    if (snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 280, child: UIs.centerLoading)],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (_busy)
          const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2))
        else
          const SliverToBoxAdapter(child: SizedBox(height: 2)),
        SliverToBoxAdapter(child: _buildStatusCard(snapshot)),
        _buildRulesCard(snapshot),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  Widget _issueBody({
    required String title,
    required IconData icon,
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
            onRetry: _refresh,
          ),
        ),
      ],
    );
  }

  Widget _card(Widget child) {
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

  Widget _buildStatusCard(UfwSnapshot snapshot) {
    final scheme = Theme.of(context).colorScheme;
    final active = snapshot.active;
    final status = switch (active) {
      true => libL10n.active,
      false => libL10n.inactive,
      null => snapshot.statusLine ?? libL10n.unknown,
    };
    return _card(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 7, 11),
            child: Row(
              children: [
                Icon(
                  active == true ? Icons.shield : Icons.shield_outlined,
                  size: 26,
                  color: active == true ? Colors.green : UIs.textGrey.color,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        ['ufw', ?snapshot.version].join(' '),
                        style: UIs.text12Grey,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: active == true,
                  onChanged: _busy || active == null
                      ? null
                      : (on) => _setEnabled(snapshot, on),
                ),
              ],
            ),
          ),
          if (!snapshot.ipv6)
            _row(
              Text(l10n.firewallIpv6Off, style: UIs.text12Grey),
              null,
            ),
          Container(
            width: double.infinity,
            color: scheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: Text(
              l10n.firewallDefaultPolicy,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
          for (final (chain, label) in [
            (UfwChain.incoming, l10n.firewallIncoming),
            (UfwChain.outgoing, l10n.firewallOutgoing),
            (UfwChain.routed, l10n.firewallRouted),
          ])
            _row(
              Text(label),
              ContextMenuButton(
                tooltip: label,
                enabled: !_busy,
                actions: () => [
                  for (final policy in UfwPolicy.values)
                    ContextMenuAction(
                      text: policy.name,
                      checked: snapshot.policies[chain] == policy,
                      onTap: () => _setPolicy(snapshot, chain, policy),
                    ),
                ],
                child: ContextMenuButton.value(
                  Text(snapshot.policies[chain]?.name ?? libL10n.unknown),
                ),
              ),
            ),
          _row(
            Text(l10n.firewallLogging),
            ContextMenuButton(
              tooltip: l10n.firewallLogging,
              enabled: !_busy,
              actions: () => [
                for (final level in UfwLogLevel.values)
                  ContextMenuAction(
                    text: level.name,
                    checked: snapshot.logLevel == level,
                    onTap: () => _run([UfwManager.loggingCommand(level)]),
                  ),
              ],
              child: ContextMenuButton.value(
                Text(snapshot.logLevel?.name ?? libL10n.unknown),
              ),
            ),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _row(Widget title, Widget? trailing, {bool last = false}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.fromLTRB(13, 4, 7, 4),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: _hairline)),
      ),
      child: Row(
        children: [
          Expanded(child: title),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildRulesCard(UfwSnapshot snapshot) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rules = snapshot.rules;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.all(Radius.circular(13)),
        ),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                ),
                child: Text(
                  '${l10n.firewallRules} · ${rules.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (rules.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: CenterGreyTitle(libL10n.empty),
                ),
              )
            else
              SliverList.builder(
                itemCount: rules.length,
                itemBuilder: (_, index) => _buildRule(
                  snapshot,
                  rules[index],
                  last: index == rules.length - 1,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRule(UfwSnapshot snapshot, UfwRule rule, {required bool last}) {
    final scheme = Theme.of(context).colorScheme;
    final direction = rule.routed ? 'fwd' : rule.direction.token;
    final details = [
      l10n.firewallFromFmt(_endpointText(rule.from, rule.protocol)),
      if (rule.interfaceIn case final name?) 'in on $name',
      if (rule.interfaceOut case final name?) 'out on $name',
      if (rule.ipVersion != UfwIpVersion.both)
        rule.ipVersion == UfwIpVersion.v4 ? 'IPv4' : 'IPv6',
    ];
    return Container(
      key: ValueKey('ufw-rule:${rule.tuples.first}'),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: _hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(13, 9, 4, 9),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tag(
                  rule.action.name,
                  rule.action.color,
                  rule.action.color.withValues(alpha: 0.13),
                ),
                const SizedBox(height: 3),
                Text(direction, style: UIs.text11Grey),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _endpointText(rule.to, rule.protocol),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (rule.log case final log?)
                      _tag(
                        log.token,
                        scheme.onSurfaceVariant,
                        scheme.surfaceContainerHighest,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(details.join(' · '), style: _monoStyle),
                if (rule.comment case final comment?) ...[
                  const SizedBox(height: 2),
                  Text(comment, style: UIs.text12Grey),
                ],
              ],
            ),
          ),
          ContextMenuButton(
            tooltip: libL10n.more,
            enabled: !_busy,
            actions: () => [
              ContextMenuAction(
                text: libL10n.delete,
                icon: Icons.delete_outline,
                destructive: true,
                onTap: () => _deleteRule(snapshot, rule),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color foreground, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: foreground)),
    );
  }

  TextStyle get _monoStyle => TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    color: UIs.textGrey.color,
  );

  Color get _hairline =>
      Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35);
}

// --- Utils ---

extension on _FirewallPageState {
  /// `22/tcp`, `10.0.0.1 99/udp`, `My App`, as `ufw status` writes them.
  String _endpointText(UfwEndpoint endpoint, String? protocol) {
    final parts = [
      ?endpoint.address,
      ?(endpoint.app ?? UfwRule.portSpec(endpoint.port, protocol)),
    ];
    return parts.isEmpty ? l10n.firewallAnywhere : parts.join(' ');
  }

  /// The TCP ports this app reaches the server on, which a firewall change
  /// could shut it out of. None for this device.
  List<int> get _accessPorts {
    final spi = widget.args.spi;
    return {
      if (spi.sshOn case final ssh?) ssh.port,
      if (spi.monitorOn case final monitor?)
        if (Uri.tryParse(monitor.addr) case final uri? when uri.hasAuthority)
          uri.port,
    }.toList();
  }

  String _issueText(UfwDraftIssue issue) => switch (issue) {
    UfwDraftIssue.nothingMatched => l10n.firewallNothingMatched,
    UfwDraftIssue.invalidPort => l10n.firewallInvalidPort,
    UfwDraftIssue.tooManyPorts => l10n.firewallTooManyPorts,
    UfwDraftIssue.portsNeedProtocol => l10n.firewallPortsNeedProtocol,
    UfwDraftIssue.invalidAddress => l10n.firewallInvalidAddress,
    UfwDraftIssue.mixedIpVersions => l10n.firewallMixedIpVersions,
    UfwDraftIssue.invalidInterface => l10n.firewallInvalidInterface,
    UfwDraftIssue.invalidComment => l10n.firewallInvalidComment,
  };
}

// --- Actions ---

extension on _FirewallPageState {
  Future<void> _refresh() async {
    if (!mounted || _busy) return;
    if (ref.read(_provider).status.system != SystemType.linux) {
      _rebuild(() {
        _issue = _Issue.unsupported;
        _failure = null;
        _snapshot = null;
      });
      return;
    }

    _rebuild(() {
      _busy = true;
      _issue = null;
      _failure = null;
    });
    try {
      final exec = await ref.read(_provider.notifier).ensureExec();
      final probe = await UfwManager.probe(exec);
      if (!mounted) return;
      if (!probe.installed) {
        _rebuild(() {
          _issue = _Issue.missing;
          _snapshot = null;
        });
        return;
      }
      _root = probe.root;
      final result = await _privileged(exec, UfwManager.readScript);
      if (!mounted) return;
      if (result == null) {
        _rebuild(() => _issue = _Issue.needsRoot);
        return;
      }
      if (!result.succeeded) {
        final detail = result.combined.trim();
        _rebuild(() => _failure = detail.isEmpty ? libL10n.fail : detail);
        return;
      }
      final snapshot = UfwManager.parse(result.stdout);
      if (mounted) _rebuild(() => _snapshot = snapshot);
    } catch (e, s) {
      Loggers.app.warning('Read ufw on ${widget.args.spi.id}', e, s);
      if (mounted) _rebuild(() => _failure = '$e');
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }

  /// [script] as root, asking for the sudo password where it is needed.
  /// Null when the user declined to give one.
  Future<ExecResult?> _privileged(ServerExec exec, String script) {
    return SudoPassword.retry(
      context,
      widget.args.spi.id,
      label: widget.args.spi.ssh?.user,
      attempt: (password) => PrivilegedExec.run(
        exec,
        script,
        isRoot: password == null && (_root || widget.args.spi.isRoot),
        password: password,
      ),
      rejected: (r) => r.exitCode == kSudoPasswordRejected,
    );
  }

  /// Runs [commands] as root, then reads ufw again.
  Future<bool> _run(List<String> commands) async {
    if (_busy) return false;
    _rebuild(() => _busy = true);
    var ok = false;
    try {
      final exec = await ref.read(_provider.notifier).ensureExec();
      if (!mounted) return false;
      final result = await _privileged(exec, UfwManager.script(commands));
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
      Loggers.app.warning('Change ufw on ${widget.args.spi.id}', e, s);
      if (mounted) Toast.error('$e');
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
    // Read again after a failure too: a script stopped part way through has
    // still changed what it got to.
    await _refresh();
    if (ok && mounted) Toast.success(libL10n.success);
    return ok;
  }

  Future<void> _setEnabled(UfwSnapshot snapshot, bool on) async {
    final commands = await _confirm(
      commands: [on ? UfwManager.enableCommand : UfwManager.disableCommand],
      // Turned off, the server takes everything; turned on, it may stop
      // taking this app.
      destructive: true,
      unreachable: on ? snapshot.unreachable(_accessPorts) : const [],
    );
    if (commands != null) await _run(commands);
  }

  Future<void> _setPolicy(
    UfwSnapshot snapshot,
    UfwChain chain,
    UfwPolicy policy,
  ) async {
    if (snapshot.policies[chain] == policy) return;
    final commands = await _confirm(
      commands: [UfwManager.policyCommand(chain, policy)],
      destructive: policy != UfwPolicy.allow,
      unreachable: snapshot.active == true && chain == UfwChain.incoming
          ? snapshot.unreachable(_accessPorts, incoming: policy)
          : const [],
    );
    if (commands != null) await _run(commands);
  }

  Future<void> _deleteRule(UfwSnapshot snapshot, UfwRule rule) async {
    final before = snapshot.unreachable(_accessPorts);
    final after = snapshot.unreachable(
      _accessPorts,
      rules: [...snapshot.rules]..remove(rule),
    );
    final commands = await _confirm(
      message: libL10n.delFmt(
        l10n.firewallRule,
        '${rule.action.name} ${_endpointText(rule.to, rule.protocol)}',
      ),
      commands: UfwManager.deleteCommands(rule),
      destructive: true,
      unreachable: snapshot.active == true
          ? after.where((port) => !before.contains(port)).toList()
          : const [],
    );
    if (commands != null) await _run(commands);
  }

  /// Asks before [commands] run, showing them unless there is a [message]
  /// to say instead. Answers what to run — [commands], after rules that let
  /// the [unreachable] ports in where the user kept that box ticked — or null.
  Future<List<String>?> _confirm({
    required List<String> commands,
    String? message,
    bool destructive = false,
    List<int> unreachable = const [],
  }) async {
    final ports = unreachable.join(', ');
    var allowFirst = unreachable.isNotEmpty;
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
              if (unreachable.isNotEmpty) ...[
                UIs.height13,
                Text(
                  l10n.firewallLockoutFmt(ports),
                  style: UIs.textRed,
                ),
                CheckboxListTile(
                  value: allowFirst,
                  title: Text(l10n.firewallAllowFirstFmt(ports)),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setDialogState(() => allowFirst = value ?? false);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: destructive ? Btnx.cancelRedOk : Btnx.cancelOk,
    );
    if (sure != true || !mounted) return null;
    return [
      if (allowFirst) ...unreachable.map(UfwManager.allowTcpCommand),
      ...commands,
    ];
  }

  Future<void> _addRule(UfwSnapshot snapshot) async {
    final draft = await _showEditor(snapshot);
    if (draft == null || !mounted) return;
    await _run([UfwManager.addCommand(draft)]);
  }
}

// --- Editor ---

extension on _FirewallPageState {
  Widget _dialogRow(String label, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          trailing,
        ],
      ),
    );
  }

  Future<UfwRuleDraft?> _showEditor(UfwSnapshot snapshot) async {
    // What is typed, kept between dialogs: a draft the checks refuse opens
    // the editor again with it.
    var action = UfwAction.allow;
    var flow = _Flow.incoming;
    var protocol = _Protocol.tcp;
    var target = _Target.port;
    var app = snapshot.apps.firstOrNull;
    UfwLog? log;
    var port = '';
    var sourcePort = '';
    var from = '';
    var to = '';
    var interfaceIn = '';
    var interfaceOut = '';
    var comment = '';
    var prepend = false;

    while (mounted) {
      final portCtrl = TextEditingController(text: port);
      final sourcePortCtrl = TextEditingController(text: sourcePort);
      final fromCtrl = TextEditingController(text: from);
      final toCtrl = TextEditingController(text: to);
      final interfaceInCtrl = TextEditingController(text: interfaceIn);
      final interfaceOutCtrl = TextEditingController(text: interfaceOut);
      final commentCtrl = TextEditingController(text: comment);
      // Open again where something in it was filled, so a refused draft
      // shows what was refused.
      final moreOpen =
          log != null ||
          sourcePort.isNotEmpty ||
          interfaceIn.isNotEmpty ||
          interfaceOut.isNotEmpty;

      Widget interfaceInput(TextEditingController ctrl, String label) => Input(
        controller: ctrl,
        label: label,
        hint: 'eth0',
        icon: Icons.settings_ethernet,
        suggestion: false,
      );

      final submitted = await context.showRoundDialog<bool>(
        title: l10n.firewallAddRule,
        child: DisposeWith(
          notifiers: [
            portCtrl, sourcePortCtrl, fromCtrl, toCtrl, interfaceInCtrl, //
            interfaceOutCtrl, commentCtrl,
          ],
          // A width rather than a cap: the dialog sizes itself by asking its
          // content for an intrinsic width, which [SegmentedTabs] cannot
          // answer.
          child: SizedBox(
            width: (MediaQuery.sizeOf(context).width - 80).clamp(240.0, 520.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: StatefulBuilder(
                builder: (context, setDialogState) => SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SegmentedTabs<UfwAction>(
                        expand: true,
                        segments: [
                          for (final value in UfwAction.values)
                            SegmentedTab(value: value, label: value.name),
                        ],
                        selected: action,
                        onSelected: (v) => setDialogState(() => action = v),
                      ),
                      UIs.height13,
                      SegmentedTabs<_Flow>(
                        expand: true,
                        segments: [
                          for (final value in _Flow.values)
                            SegmentedTab(value: value, label: value.label),
                        ],
                        selected: flow,
                        onSelected: (v) => setDialogState(() => flow = v),
                      ),
                      if (snapshot.apps.isNotEmpty) ...[
                        UIs.height13,
                        SegmentedTabs<_Target>(
                          expand: true,
                          segments: [
                            SegmentedTab(
                              value: _Target.port,
                              label: libL10n.port,
                            ),
                            SegmentedTab(
                              value: _Target.app,
                              label: l10n.firewallAppProfile,
                            ),
                          ],
                          selected: target,
                          onSelected: (v) => setDialogState(() => target = v),
                        ),
                      ],
                      UIs.height7,
                      if (target == _Target.app)
                        _dialogRow(
                          l10n.firewallAppProfile,
                          ContextMenuButton(
                            tooltip: l10n.firewallAppProfile,
                            actions: () => [
                              for (final name in snapshot.apps)
                                ContextMenuAction(
                                  text: name,
                                  checked: name == app,
                                  onTap: () => setDialogState(() => app = name),
                                ),
                            ],
                            child: ContextMenuButton.value(Text(app ?? '')),
                          ),
                        )
                      else ...[
                        Input(
                          controller: portCtrl,
                          label: libL10n.port,
                          hint: '22, 80,443, 6000:6010',
                          icon: Icons.numbers,
                          suggestion: false,
                        ),
                        _dialogRow(
                          l10n.firewallProtocol,
                          SegmentedTabs<_Protocol>(
                            segments: [
                              for (final value in _Protocol.values)
                                SegmentedTab(value: value, label: value.name),
                            ],
                            selected: protocol,
                            onSelected: (v) =>
                                setDialogState(() => protocol = v),
                          ),
                        ),
                      ],
                      Input(
                        controller: fromCtrl,
                        label: l10n.firewallFrom,
                        hint: l10n.firewallAnywhere,
                        icon: Icons.login,
                        suggestion: false,
                      ),
                      Input(
                        controller: toCtrl,
                        label: l10n.firewallTo,
                        hint: l10n.firewallAnywhere,
                        icon: Icons.logout,
                        suggestion: false,
                      ),
                      ExpansionTile(
                        title: Text(l10n.firewallMoreOptions),
                        initiallyExpanded: moreOpen,
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        children: [
                          Input(
                            controller: sourcePortCtrl,
                            label: l10n.firewallSourcePort,
                            hint: l10n.firewallAnywhere,
                            icon: Icons.numbers,
                            suggestion: false,
                          ),
                          ...switch (flow) {
                            _Flow.incoming => [
                              interfaceInput(
                                interfaceInCtrl,
                                l10n.firewallInterface,
                              ),
                            ],
                            _Flow.outgoing => [
                              interfaceInput(
                                interfaceOutCtrl,
                                l10n.firewallInterface,
                              ),
                            ],
                            _Flow.routed => [
                              interfaceInput(
                                interfaceInCtrl,
                                l10n.firewallInterfaceIn,
                              ),
                              interfaceInput(
                                interfaceOutCtrl,
                                l10n.firewallInterfaceOut,
                              ),
                            ],
                          },
                          _dialogRow(
                            libL10n.log,
                            ContextMenuButton(
                              tooltip: libL10n.log,
                              actions: () => [
                                for (final value in [null, ...UfwLog.values])
                                  ContextMenuAction(
                                    text: value?.token ?? libL10n.none,
                                    checked: value == log,
                                    onTap: () =>
                                        setDialogState(() => log = value),
                                  ),
                              ],
                              child: ContextMenuButton.value(
                                Text(log?.token ?? libL10n.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Input(
                        controller: commentCtrl,
                        label: l10n.firewallComment,
                        icon: Icons.notes,
                      ),
                      SwitchListTile(
                        value: prepend,
                        title: Text(l10n.firewallPrepend),
                        onChanged: (v) => setDialogState(() => prepend = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: Btnx.cancelOk,
      );
      port = portCtrl.text;
      sourcePort = sourcePortCtrl.text;
      from = fromCtrl.text;
      to = toCtrl.text;
      interfaceIn = interfaceInCtrl.text;
      interfaceOut = interfaceOutCtrl.text;
      comment = commentCtrl.text;
      if (submitted != true || !mounted) return null;

      final draft = UfwRuleDraft(
        action: action,
        direction: flow == _Flow.outgoing
            ? UfwDirection.outgoing
            : UfwDirection.incoming,
        routed: flow == _Flow.routed,
        protocol: protocol.value,
        port: target == _Target.port ? port : '',
        sourcePort: sourcePort,
        app: target == _Target.app ? app : null,
        from: from,
        to: to,
        interfaceIn: interfaceIn,
        interfaceOut: interfaceOut,
        log: log,
        comment: comment,
        prepend: prepend,
      );
      if (UfwManager.validateDraft(draft) case final issue?) {
        Toast.error(_issueText(issue));
        continue;
      }
      return draft;
    }
    return null;
  }
}
