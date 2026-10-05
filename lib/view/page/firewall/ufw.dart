part of 'firewall.dart';

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

/// ufw: whether it is on, what it does by default, and its rules.
final class _UfwView extends ConsumerStatefulWidget {
  const _UfwView({super.key, required this.host});

  final _FirewallHost host;

  @override
  ConsumerState<_UfwView> createState() => _UfwViewState();
}

final class _UfwViewState extends ConsumerState<_UfwView>
    with _FirewallView<_UfwView> {
  UfwSnapshot? _snapshot;

  @override
  _FirewallHost get host => widget.host;

  @override
  void initState() {
    super.initState();
    Future.microtask(refresh);
  }

  @override
  Future<void> refresh() async {
    final snapshot = await read(
      ufwReadScript(),
      (output) => ufwParse(output: output),
    );
    if (snapshot != null && mounted) setState(() => _snapshot = snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final ready = snapshot != null && !needsRoot && failure == null;
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: l10n.firewall, down: host.spi.name),
        actions: _buildActions(ready ? snapshot : null),
      ),
      body: RefreshIndicator(onRefresh: refresh, child: _buildBody()),
      floatingActionButton: ready
          ? FloatingActionButton(
              tooltip: l10n.firewallAddRule,
              onPressed: busy ? null : () => _addRule(snapshot),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// --- Widget builders ---

extension on _UfwViewState {
  List<Widget> _buildActions(UfwSnapshot? snapshot) {
    return [
      ...switchAction(FirewallKind.ufw),
      if (isDesktop)
        Btn.icon(
          text: libL10n.refresh,
          icon: const Icon(Icons.refresh, size: 18),
          onTap: busy ? null : refresh,
        ),
      ContextMenuButton(
        tooltip: libL10n.more,
        enabled: snapshot?.active == true && !busy,
        actions: () => [
          ContextMenuAction(
            text: l10n.firewallReload,
            icon: Icons.sync,
            onTap: () => _make(snapshot!, const UfwChange.reload()),
          ),
        ],
      ),
    ];
  }

  Widget _buildBody() {
    if (issue() case final issue?) return issue;
    final snapshot = _snapshot;
    if (snapshot == null) return loading();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (busy)
          const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2))
        else
          const SliverToBoxAdapter(child: SizedBox(height: 2)),
        if (conflictBanner(FirewallKind.ufw, on: snapshot.active == true)
            case final banner?)
          SliverToBoxAdapter(child: banner),
        SliverToBoxAdapter(child: _buildStatusCard(snapshot)),
        _buildRulesCard(snapshot),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
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
    return card(
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
                  onChanged: busy || active == null
                      ? null
                      : (on) => _setEnabled(snapshot, on),
                ),
              ],
            ),
          ),
          if (!snapshot.ipv6)
            row(
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
            row(
              Text(label),
              ContextMenuButton(
                tooltip: label,
                enabled: !busy,
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
          row(
            Text(l10n.firewallLogging),
            ContextMenuButton(
              tooltip: l10n.firewallLogging,
              enabled: !busy,
              actions: () => [
                for (final level in UfwLogLevel.values)
                  ContextMenuAction(
                    text: level.name,
                    checked: snapshot.logLevel == level,
                    onTap: () =>
                        _make(snapshot, UfwChange.logging(level: level)),
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
        border: last ? null : Border(bottom: BorderSide(color: hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(13, 9, 4, 9),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tag(
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
                      tag(
                        log.token,
                        scheme.onSurfaceVariant,
                        scheme.surfaceContainerHighest,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(details.join(' · '), style: monoStyle),
                if (rule.comment case final comment?) ...[
                  const SizedBox(height: 2),
                  Text(comment, style: UIs.text12Grey),
                ],
              ],
            ),
          ),
          ContextMenuButton(
            tooltip: libL10n.more,
            enabled: !busy,
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
}

// --- Utils ---

extension on _UfwViewState {
  /// `22/tcp`, `10.0.0.1 99/udp`, `My App`, as `ufw status` writes them.
  String _endpointText(UfwEndpoint endpoint, String? protocol) {
    final parts = [
      ?endpoint.address,
      ?(endpoint.app ?? _portSpec(endpoint.port, protocol)),
    ];
    return parts.isEmpty ? l10n.firewallAnywhere : parts.join(' ');
  }

  /// A port as `ufw status` prints it: `22/tcp`, `25`.
  String? _portSpec(String? port, String? protocol) {
    if (port == null) return null;
    return protocol == null ? port : '$port/$protocol';
  }
}

// --- Actions ---

extension on _UfwViewState {
  /// Plans [change] against what is on screen, then makes it.
  Future<void> _make(
    UfwSnapshot snapshot,
    UfwChange change, {
    String? message,
  }) async {
    final plan = planOf(
      () => ufwPlan(
        snapshot: snapshot,
        change: change,
        accesses: host.accesses,
      ),
    );
    if (plan != null) await apply(plan, message: message);
  }

  Future<void> _setEnabled(UfwSnapshot snapshot, bool on) =>
      _make(snapshot, on ? const UfwChange.enable() : const UfwChange.disable());

  Future<void> _setPolicy(
    UfwSnapshot snapshot,
    UfwChain chain,
    UfwPolicy policy,
  ) => _make(snapshot, UfwChange.policy(chain: chain, policy: policy));

  Future<void> _deleteRule(UfwSnapshot snapshot, UfwRule rule) => _make(
    snapshot,
    UfwChange.deleteRule(tuples: rule.tuples),
    message: libL10n.delFmt(
      l10n.firewallRule,
      '${rule.action.name} ${_endpointText(rule.to, rule.protocol)}',
    ),
  );

  Future<void> _addRule(UfwSnapshot snapshot) async {
    final draft = await _showEditor(snapshot);
    if (draft == null || !mounted) return;
    await _make(snapshot, UfwChange.addRule(draft: draft));
  }
}

// --- Editor ---

extension on _UfwViewState {
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
    var app = snapshot.apps.firstOrNull?.name;
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
                              for (final name in snapshot.apps.map((a) => a.name))
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
      if (ufwValidateDraft(draft: draft) case final issue?) {
        Toast.error(draftIssueText(issue));
        continue;
      }
      return draft;
    }
    return null;
  }
}
