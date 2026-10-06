part of 'firewall.dart';

/// One item of a zone's list, and which configuration holds it.
typedef _Held<T> = ({T value, bool runtime, bool permanent});

/// firewalld: whether it runs, its zones, and what each lets in.
///
/// While it runs, a zone is shown as it is in force, with what only one of
/// the two configurations holds tagged; every change goes to both. While it
/// does not, the saved configuration is all there is, and changes go there.
final class _FirewalldView extends ConsumerStatefulWidget {
  const _FirewalldView({super.key, required this.host});

  final _FirewallHost host;

  @override
  ConsumerState<_FirewalldView> createState() => _FirewalldViewState();
}

final class _FirewalldViewState extends ConsumerState<_FirewalldView>
    with _FirewallView<_FirewalldView> {
  FirewalldSnapshot? _snapshot;

  /// The zone on screen.
  String? _zone;

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
      firewalldReadScript(),
      (output) => firewalldParse(output: output),
    );
    if (snapshot == null || !mounted) return;
    setState(() {
      _snapshot = snapshot;
      if (snapshot.zone(_zone ?? '') == null) _zone = _firstZone(snapshot);
    });
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
    );
  }
}

// --- Widget builders ---

extension on _FirewalldViewState {
  List<Widget> _buildActions(FirewalldSnapshot? snapshot) {
    final running = snapshot?.running ?? false;
    return [
      ...switchAction(FirewallKind.firewalld),
      if (isDesktop)
        Btn.icon(
          text: libL10n.refresh,
          icon: const Icon(Icons.refresh, size: 18),
          onTap: busy ? null : refresh,
        ),
      ContextMenuButton(
        tooltip: libL10n.more,
        enabled: snapshot != null && running && !busy,
        actions: () => [
          if (snapshot != null) ...[
            ContextMenuAction(
              text: l10n.firewallReload,
              icon: Icons.sync,
              onTap: () => _reload(snapshot),
            ),
            ContextMenuAction(
              text: l10n.firewallSaveRuntime,
              icon: Icons.save_outlined,
              onTap: () => _saveRuntime(snapshot),
            ),
          ],
        ],
      ),
    ];
  }

  Widget _buildBody() {
    if (issue() case final issue?) return issue;
    final snapshot = _snapshot;
    if (snapshot == null) return loading();
    final zone = snapshot.zone(_zone ?? '');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (busy)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        ?conflictBanner(FirewallKind.firewalld, on: snapshot.running),
        if (snapshot.panic)
          banner(
            Icons.block,
            l10n.firewallPanic,
            danger: true,
            actions: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => _make(snapshot, const FirewalldChange.panicOff()),
                child: Text(l10n.firewallPanicOff),
              ),
            ],
          ),
        if (!snapshot.running)
          banner(Icons.info_outline, l10n.firewallStoppedNote),
        ?_buildDriftBanner(snapshot),
        _buildStatusCard(snapshot),
        if (zone != null) ..._buildZone(snapshot, zone),
        const SizedBox(height: 40),
      ],
    );
  }

  /// Said while a reload or a boot would change what is in force — and
  /// louder where the change would shut this app out.
  Widget? _buildDriftBanner(FirewalldSnapshot snapshot) {
    if (!snapshot.drifted) return null;
    final shut = [
      for (final access in host.accesses)
        if (snapshot.shutByReload(access))
          access,
    ];
    return banner(
      Icons.sync_problem,
      [
        l10n.firewallDrift,
        for (final access in shut)
          l10n.firewallDriftLockoutFmt(_accessName(access)),
      ].join('\n'),
      danger: shut.isNotEmpty,
      actions: [
        TextButton(
          onPressed: busy ? null : () => _saveRuntime(snapshot),
          child: Text(l10n.firewallSaveRuntime),
        ),
        TextButton(
          onPressed: busy ? null : () => _reload(snapshot),
          child: Text(l10n.firewallReload),
        ),
      ],
    );
  }

  Widget _buildStatusCard(FirewalldSnapshot snapshot) {
    final running = snapshot.running;
    return card(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 7, 11),
            child: Row(
              children: [
                Icon(
                  running ? Icons.shield : Icons.shield_outlined,
                  size: 26,
                  color: running ? Colors.green : UIs.textGrey.color,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        running ? libL10n.running : libL10n.stopped,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        ['firewalld', ?snapshot.version].join(' '),
                        style: UIs.text12Grey,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: running,
                  onChanged: busy ? null : (on) => _setRunning(snapshot, on),
                ),
              ],
            ),
          ),
          row(
            Text(l10n.firewallDefaultZone),
            ContextMenuButton(
              tooltip: l10n.firewallDefaultZone,
              enabled: !busy,
              actions: () => [
                for (final zone in snapshot.zones)
                  ContextMenuAction(
                    text: zone.name,
                    checked: zone.name == snapshot.defaultZone,
                    onTap: () => _setDefaultZone(snapshot, zone.name),
                  ),
              ],
              child: ContextMenuButton.value(
                Text(snapshot.defaultZone ?? libL10n.unknown),
              ),
            ),
          ),
          row(
            Text(l10n.firewallZone),
            ContextMenuButton(
              tooltip: l10n.firewallZone,
              actions: () => [
                for (final zone in snapshot.zones)
                  ContextMenuAction(
                    text: zone.name,
                    note: _zoneTags(snapshot, zone).join(' · '),
                    checked: zone.name == _zone,
                    onTap: () => rebuild(() => _zone = zone.name),
                  ),
              ],
              child: ContextMenuButton.value(Text(_zone ?? '')),
            ),
            last: true,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildZone(FirewalldSnapshot snapshot, FirewalldZone zone) {
    final saved = snapshot.zone(zone.name, permanent: true);
    final runtime = snapshot.running ? zone : null;
    final tags = _zoneTags(snapshot, zone);
    return [
      card(
        Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
              child: Wrap(
                spacing: 7,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    zone.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  for (final t in tags) greyTag(t),
                ],
              ),
            ),
            row(
              Text(l10n.firewallTarget),
              ContextMenuButton(
                tooltip: l10n.firewallTarget,
                enabled: !busy,
                actions: () => [
                  for (final target in FirewalldTarget.values)
                    ContextMenuAction(
                      text: target.label,
                      checked: (saved ?? zone).target == target,
                      onTap: () => _setTarget(snapshot, zone.name, target),
                    ),
                ],
                child: ContextMenuButton.value(
                  Text((saved ?? zone).target.label),
                ),
              ),
            ),
            row(
              Text(l10n.firewallMasquerade),
              Switch(
                value: zone.masquerade,
                onChanged: busy
                    ? null
                    : (on) => _make(
                        snapshot,
                        FirewalldChange.masquerade(zone: zone.name, enabled: on),
                      ),
              ),
              last: true,
            ),
          ],
        ),
      ),
      _section<String>(
        title: l10n.firewallInterfaces,
        items: _held(runtime?.interfaces, saved?.interfaces ?? const []),
        text: (v) => v,
        onAdd: () => _addInterface(snapshot, zone.name),
        onRemove: (v) => _make(
          snapshot,
          FirewalldChange.removeInterface(zone: zone.name, iface: v),
          message: libL10n.delFmt(zone.name, v),
        ),
      ),
      _section<String>(
        title: l10n.firewallSources,
        items: _held(runtime?.sources, saved?.sources ?? const []),
        text: (v) => v,
        onAdd: () => _addSource(snapshot, zone.name),
        onRemove: (v) => _make(
          snapshot,
          FirewalldChange.remove(
            zone: zone.name,
            item: FirewalldItem.source,
            value: v,
          ),
          message: libL10n.delFmt(zone.name, v),
        ),
      ),
      _section<String>(
        title: l10n.firewallServices,
        items: _held(runtime?.services, saved?.services ?? const []),
        text: (v) => v,
        detail: (v) => snapshot.services[v]?.map((p) => p.spec).join(' '),
        onAdd: () => _addService(snapshot, zone),
        onRemove: (v) => _make(
          snapshot,
          FirewalldChange.remove(
            zone: zone.name,
            item: FirewalldItem.service,
            value: v,
          ),
          message: libL10n.delFmt(zone.name, v),
        ),
      ),
      _section<FirewalldPort>(
        title: l10n.firewallPorts,
        items: _held(runtime?.ports, saved?.ports ?? const []),
        text: (v) => v.spec,
        onAdd: () => _addPort(snapshot, zone.name),
        onRemove: (v) => _make(
          snapshot,
          FirewalldChange.remove(
            zone: zone.name,
            item: FirewalldItem.port,
            value: v.spec,
          ),
          message: libL10n.delFmt(zone.name, v.spec),
        ),
      ),
      _section<String>(
        title: l10n.firewallRichRules,
        items: _held(
          runtime?.richRules.map((r) => r.raw).toList(),
          saved?.richRules.map((r) => r.raw).toList() ?? const [],
        ),
        text: (v) => v,
        mono: true,
        onAdd: () => _addRichRule(snapshot, zone.name),
        onRemove: (v) => _make(
          snapshot,
          FirewalldChange.remove(
            zone: zone.name,
            item: FirewalldItem.richRule,
            value: v,
          ),
          message: libL10n.delFmt(zone.name, v),
        ),
      ),
      _section<String>(
        title: l10n.firewallForwardPorts,
        items: _held(runtime?.forwardPorts, saved?.forwardPorts ?? const []),
        text: (v) => v,
        mono: true,
        onAdd: () => _addForwardPort(snapshot, zone.name),
        onRemove: (v) => _make(
          snapshot,
          FirewalldChange.remove(
            zone: zone.name,
            item: FirewalldItem.forwardPort,
            value: v,
          ),
          message: libL10n.delFmt(zone.name, v),
        ),
      ),
    ];
  }

  Widget _section<T>({
    required String title,
    required List<_Held<T>> items,
    required String Function(T) text,
    required VoidCallback onAdd,
    required void Function(T) onRemove,
    String? Function(T)? detail,
    bool mono = false,
  }) {
    final running = _snapshot?.running ?? false;
    return card(
      Column(
        children: [
          sectionHeader(title, count: items.length, onAdd: onAdd),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(libL10n.empty, style: UIs.text12Grey),
            ),
          for (final (index, item) in items.indexed)
            Container(
              key: ValueKey('firewalld:$title:${text(item.value)}'),
              padding: const EdgeInsets.fromLTRB(13, 6, 4, 6),
              decoration: BoxDecoration(
                border: index == items.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: hairline)),
              ),
              child: Row(
                children: [
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
                              text(item.value),
                              style: mono
                                  ? const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    )
                                  : null,
                            ),
                            // Tagged only while there are two to differ.
                            if (running && !item.permanent)
                              tag(
                                l10n.firewallRuntimeOnly,
                                Colors.orange.shade900,
                                Colors.orange.withValues(alpha: 0.15),
                              ),
                            if (running && !item.runtime)
                              greyTag(l10n.firewallPermanentOnly),
                          ],
                        ),
                        if (detail?.call(item.value) case final d?
                            when d.isNotEmpty)
                          Text(d, style: monoStyle),
                      ],
                    ),
                  ),
                  Btn.icon(
                    text: libL10n.delete,
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onTap: busy ? null : () => onRemove(item.value),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// --- Utils ---

extension on _FirewalldViewState {
  /// The zone this app's connection is in, where that is known; else the
  /// default zone.
  String? _firstZone(FirewalldSnapshot s) {
    for (final access in host.accesses) {
      final zones = s.zonesFor(access);
      if (zones.length == 1) return zones.single.name;
    }
    return s.defaultZone ?? s.zones.firstOrNull?.name;
  }

  List<String> _zoneTags(FirewalldSnapshot s, FirewalldZone zone) => [
    if (zone.name == s.defaultZone) l10n.firewallDefaultTag,
    if (zone.active) libL10n.active,
    if (host.accesses.any((a) {
      final zones = s.zonesFor(a);
      return zones.length == 1 && zones.single.name == zone.name;
    }))
      l10n.firewallThisConnection,
  ];

  /// [runtime]'s items, then those only [permanent] has; each says which
  /// holds it. Stopped, there is only [permanent].
  List<_Held<T>> _held<T>(List<T>? runtime, List<T> permanent) => [
    if (runtime == null)
      for (final v in permanent) (value: v, runtime: false, permanent: true)
    else ...[
      for (final v in runtime)
        (value: v, runtime: true, permanent: permanent.contains(v)),
      for (final v in permanent)
        if (!runtime.contains(v)) (value: v, runtime: false, permanent: true),
    ],
  ];
}

// --- Actions ---

extension on _FirewalldViewState {
  /// Plans [change] against what is on screen, then makes it.
  Future<void> _make(
    FirewalldSnapshot s,
    FirewalldChange change, {
    String? message,
  }) async {
    final plan = planOf(
      () => firewalldPlan(snapshot: s, change: change, accesses: host.accesses),
    );
    if (plan != null) await apply(plan, message: message);
  }

  Future<void> _setRunning(FirewalldSnapshot s, bool on) => _make(
    s,
    on ? const FirewalldChange.start() : const FirewalldChange.stop(),
  );

  Future<void> _setDefaultZone(FirewalldSnapshot s, String zone) =>
      _make(s, FirewalldChange.defaultZone(zone: zone));

  Future<void> _setTarget(
    FirewalldSnapshot s,
    String zone,
    FirewalldTarget target,
  ) => _make(s, FirewalldChange.target(zone: zone, target: target));

  Future<void> _reload(FirewalldSnapshot s) =>
      _make(s, const FirewalldChange.reload());

  Future<void> _saveRuntime(FirewalldSnapshot s) =>
      _make(s, const FirewalldChange.runtimeToPermanent());

  /// Adds what the user types to one of [zone]'s lists.
  Future<void> _addTyped(
    FirewalldSnapshot s,
    String zone,
    FirewalldItem item, {
    required String title,
    required String label,
    required String hint,
    required IconData icon,
  }) async {
    final text = await askText(
      title: title,
      label: label,
      hint: hint,
      icon: icon,
    );
    if (text == null || !mounted) return;
    await _make(s, FirewalldChange.add(zone: zone, item: item, value: text));
  }

  Future<void> _addService(FirewalldSnapshot s, FirewalldZone zone) async {
    final name = await _pickService(s, zone);
    if (name == null || !mounted) return;
    await _make(
      s,
      FirewalldChange.add(
        zone: zone.name,
        item: FirewalldItem.service,
        value: name,
      ),
    );
  }

  Future<void> _addPort(FirewalldSnapshot s, String zone) => _addTyped(
    s,
    zone,
    FirewalldItem.port,
    title: l10n.firewallPorts,
    label: libL10n.port,
    hint: '8080/tcp, 6000-6010/udp',
    icon: Icons.numbers,
  );

  Future<void> _addSource(FirewalldSnapshot s, String zone) => _addTyped(
    s,
    zone,
    FirewalldItem.source,
    title: l10n.firewallSources,
    label: l10n.firewallFrom,
    hint: '192.168.1.0/24',
    icon: Icons.login,
  );

  /// Into this zone, and out of whichever had it.
  Future<void> _addInterface(FirewalldSnapshot s, String zone) async {
    final text = await askText(
      title: l10n.firewallInterfaces,
      label: l10n.firewallInterface,
      hint: 'eth0',
      icon: Icons.settings_ethernet,
    );
    if (text == null || !mounted) return;
    await _make(s, FirewalldChange.changeInterface(zone: zone, iface: text));
  }

  Future<void> _addRichRule(FirewalldSnapshot s, String zone) => _addTyped(
    s,
    zone,
    FirewalldItem.richRule,
    title: l10n.firewallRichRules,
    label: l10n.firewallRichRules,
    hint: 'rule family="ipv4" source address="192.0.2.0/24" '
        'service name="ssh" accept',
    icon: Icons.rule,
  );

  Future<void> _addForwardPort(FirewalldSnapshot s, String zone) => _addTyped(
    s,
    zone,
    FirewalldItem.forwardPort,
    title: l10n.firewallForwardPorts,
    label: l10n.firewallForwardPorts,
    hint: 'port=80:proto=tcp:toport=8080',
    icon: Icons.alt_route,
  );

  /// A service not yet in [zone], chosen from every one firewalld has,
  /// with a filter: there are two hundred of them.
  Future<String?> _pickService(FirewalldSnapshot s, FirewalldZone zone) async {
    final names = [
      for (final name in s.serviceNames)
        if (!zone.services.contains(name)) name,
    ];
    final ctrl = TextEditingController();
    var query = '';
    return context.showRoundDialog<String>(
      title: l10n.firewallServices,
      child: DisposeWith(
        notifiers: [ctrl],
        child: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 80).clamp(240.0, 440.0),
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final shown = [
                for (final name in names)
                  if (name.toLowerCase().contains(query)) name,
              ];
              return Column(
                children: [
                  Input(
                    controller: ctrl,
                    label: libL10n.search,
                    icon: Icons.search,
                    autoFocus: true,
                    suggestion: false,
                    onChanged: (v) =>
                        setDialogState(() => query = v.trim().toLowerCase()),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, index) {
                        final name = shown[index];
                        final ports = s.services[name]?.map((p) => p.spec).join(' ') ?? '';
                        return ListTile(
                          dense: true,
                          title: Text(name),
                          subtitle: ports.isEmpty
                              ? null
                              : Text(ports, style: monoStyle),
                          onTap: () => context.popDialog(name),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [Btn.cancel()],
    );
  }
}
