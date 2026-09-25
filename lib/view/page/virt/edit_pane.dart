part of 'hardware.dart';

/// Where the index column appears: room for it beside the 600-wide pane.
const _indexFrom = 860.0;

/// How far a device's own rows sit in from its row.
const _indent = 26.0;

/// The design's sectioned edit pane, as the Hardware and Settings views both
/// draw it: groups under a title and a rule, the rows the design has (a
/// field, a stepper, a switch, a device that opens), and every change made
/// through [_apply] against the one hardware read both views share — the
/// same pending changes, the same revision sent back, the same conflict.
mixin _EditPane<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  String get _serverId;
  VirtGuest get _guest;
  VirtCapabilities get _caps;

  /// Open device rows, by key; `config` for the configuration file.
  final _open = <String>{};
  final _groupKeys = <String, GlobalKey>{};

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(_serverId).notifier);

  VirtHardwareProvider get _provider =>
      virtHardwareProvider(_serverId, _guest.id);

  bool get _lxc => _guest.kind == VirtGuestKind.lxc;

  VirtHostKind? get _host => ref.read(virtHostProvider(_serverId)).kind;

  bool get _pve => _host == VirtHostKind.pve;

  /// The pane: [groupsOf]'s groups under their titles, with the index
  /// beside them where there is room, once the hardware is read.
  Widget _buildEditPane(
    List<_Group> Function(VirtHardware hw, bool busy) groupsOf,
  ) {
    final async = ref.watch(_provider);
    final busy = ref.watch(
      virtHostProvider(
        _serverId,
      ).select((s) => s.isBusy(_guest.id)),
    );
    final hw = async.value;
    if (async.error case final e?) return _buildError(e);
    if (hw == null) return const Center(child: SizedLoading.medium);
    final groups = groupsOf(hw, busy);
    return LayoutBuilder(
      builder: (context, cons) {
        final pane = RefreshIndicator(
          onRefresh: () => ref.refresh(_provider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 17),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final g in groups)
                        Column(
                          key: _groupKeys.putIfAbsent(g.key, GlobalKey.new),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GroupTitle(
                              g.title,
                              right: g.right.isEmpty ? null : g.right,
                              rightColor: g.warn ? StatePalette.warn : null,
                            ),
                            for (final r in g.rows)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: r,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        if (cons.maxWidth < _indexFrom || groups.length < 3) return pane;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 206, child: _buildIndex(groups)),
            const VerticalDivider(width: 1),
            Expanded(child: pane),
          ],
        );
      },
    );
  }

  Widget _buildIndex(List<_Group> groups) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
      children: [
        for (final g in groups)
          InkWell(
            key: ValueKey('hw:index:${g.key}'),
            borderRadius: BorderRadius.circular(13),
            onTap: () => _scrollTo(g.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          g.dot ??
                          (g.warn ? StatePalette.warn : ChartPalette.accent),
                    ),
                  ),
                  UIs.width7,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.title, style: UIs.text12Bold),
                        Text(
                          g.indexNote,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UIs.text11Grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The group's own list only: `Scrollable.ensureVisible` would move every
  /// scrollable above it too.
  void _scrollTo(String key) {
    final ctx = _groupKeys[key]?.currentContext;
    final object = ctx?.findRenderObject();
    if (ctx == null || object == null) return;
    Scrollable.maybeOf(ctx)?.position.ensureVisible(
      object,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildError(Object e) {
    return ListView(
      padding: const EdgeInsets.all(13),
      children: [
        VirtCard(
          icon: Icons.error_outline,
          title: e is VirtErr ? e.title : libL10n.error,
          trailing: Btn.icon(
            text: libL10n.retry,
            icon: const Icon(Icons.refresh, size: 18),
            onTap: () => ref.invalidate(_provider),
          ),
          children: [
            if (e is VirtErr)
              if (e.detail case final d?) Text(d, style: UIs.text12Grey)
              else UIs.placeholder
            else
              Text('$e', style: UIs.text12Grey),
          ],
        ),
      ],
    );
  }

  // --- Pending ---

  static const _cpuKeys = {
    'cpu', 'cores', 'sockets', 'vcpus', 'cpulimit', 'cpuunits', 'numa',
    'affinity',
  };
  static const _memKeys = {'memory', 'balloon', 'swap', 'shares'};
  static const _bootKeys = {'boot', 'bootdisk'};
  static const _settingsKeys = {
    'name', 'hostname', 'description', 'onboot', 'protection',
  };
  static final _nicKey = RegExp(
    r'^net\d+$|^([0-9a-f]{2}:){5}[0-9a-f]{2}$',
    caseSensitive: false,
  );
  static final _diskKey = RegExp(
    r'^((ide|sata|scsi|virtio|mp|unused|efidisk|tpmstate)\d+|rootfs|(vd|sd|hd|xvd)[a-z]+)$',
  );

  /// Which part of the pane a pending change is shown in: beside the field
  /// or device it changes, so what waits for a restart is read where it is
  /// set. A key none of them has — an option this app does not edit — is
  /// [_PendingPlace.other], shown with the configuration file.
  _PendingPlace _placeOf(VirtHardware hw, String key) {
    if (_cpuKeys.contains(key)) return _PendingPlace.cpu;
    if (_memKeys.contains(key)) return _PendingPlace.memory;
    if (_bootKeys.contains(key)) return _PendingPlace.boot;
    if (_settingsKeys.contains(key)) return _PendingPlace.settings;
    if (hw.nic(key) != null || _nicKey.hasMatch(key)) return _PendingPlace.nic;
    if (hw.disk(key) != null || _diskKey.hasMatch(key)) {
      return _PendingPlace.disk;
    }
    return _PendingPlace.other;
  }

  /// The pending changes [where] picks, one row each.
  List<Widget> _pendingRows(
    VirtHardware hw,
    bool busy,
    bool Function(VirtPendingField p) where, {
    bool indent = false,
  }) => [
    for (final p in hw.pending)
      if (where(p)) _pendingRow(hw, p, busy, indent: indent),
  ];

  /// One pending change: what the guest runs with now, what the next start
  /// gets, and — where the host keeps such a list (PVE) — dropping it.
  Widget _pendingRow(
    VirtHardware hw,
    VirtPendingField p,
    bool busy, {
    bool indent = false,
  }) {
    final value = p.delete
        ? '${p.current ?? ''} → ${libL10n.delete}'
        : '${p.current ?? '—'} → ${p.pending ?? '—'}';
    return _box(
      key: ValueKey('hw:pending:${p.key}'),
      indent: indent,
      color: StatePalette.warn.withValues(alpha: 0.1),
      padding: const EdgeInsets.fromLTRB(13, 5, 5, 5),
      child: Row(
        children: [
          _icon(Icons.schedule, color: StatePalette.warn),
          UIs.width13,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.key} · ${l10n.virtHwLater}',
                  style: UIs.text11.copyWith(color: StatePalette.warn),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: UIs.text12,
                ),
              ],
            ),
          ),
          if (_caps.hardwareRevert)
            Btn.icon(
              key: ValueKey('hw:revert:${p.key}'),
              text: l10n.virtHwRevert,
              icon: const Icon(Icons.undo, size: 17),
              onTap: busy ? null : () => _apply(hw, VirtHwRevert([p.key])),
            ),
        ],
      ),
    );
  }

  // --- Rows, as the design draws them ---

  Color get _rowColor =>
      Theme.of(context).cardTheme.color ??
      Theme.of(context).colorScheme.surfaceContainerLow;

  Widget _box({
    required Widget child,
    Key? key,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 13,
      vertical: 9,
    ),
    Color? color,
    VoidCallback? onTap,
    bool indent = false,
  }) {
    return Padding(
      key: key,
      padding: EdgeInsets.only(left: indent ? _indent : 0),
      child: Material(
        color: color ?? _rowColor,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _icon(IconData icon, {Color? color}) => Icon(
    icon,
    size: 19,
    color: color ?? Theme.of(context).colorScheme.outline,
  );

  Widget _field(
    IconData icon,
    String label,
    String value, {
    Key? key,
    bool mono = false,
    bool indent = false,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return _box(
      key: key,
      indent: indent,
      onTap: onTap,
      child: Row(
        children: [
          _icon(icon),
          UIs.width13,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: UIs.text11Grey),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: mono ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _step(
    IconData icon,
    String label,
    String value, {
    required String key,
    required VoidCallback? onDec,
    required VoidCallback? onInc,
    bool indent = false,
  }) {
    return _box(
      key: ValueKey('hw:step:$key'),
      indent: indent,
      padding: const EdgeInsets.fromLTRB(13, 5, 7, 5),
      child: Row(
        children: [
          _icon(icon),
          UIs.width13,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: UIs.text11Grey),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Btn.icon(
                    key: ValueKey('hw:step:$key:dec'),
                    text: l10n.virtHwLess,
                    icon: const Icon(Icons.remove, size: 17),
                    onTap: onDec,
                  ),
                  Btn.icon(
                    key: ValueKey('hw:step:$key:inc'),
                    text: l10n.virtHwMore,
                    icon: const Icon(Icons.add, size: 17),
                    onTap: onInc,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle(
    IconData icon,
    String label,
    bool value, {
    required String key,
    required ValueChanged<bool>? onChanged,
    String? note,
    bool indent = false,
  }) {
    return _box(
      key: ValueKey('hw:toggle:$key'),
      indent: indent,
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Row(
        children: [
          _icon(icon),
          UIs.width13,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: UIs.text13),
                if (note != null) Text(note, style: UIs.text11Grey),
              ],
            ),
          ),
          SwitchX(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _seg(
    IconData icon,
    String label,
    List<String> options,
    String? selected, {
    required String key,
    required ValueChanged<String>? onSelected,
    bool indent = false,
  }) {
    return _box(
      key: ValueKey('hw:seg:$key'),
      indent: indent,
      padding: const EdgeInsets.fromLTRB(13, 7, 7, 7),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 13,
        runSpacing: 7,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _icon(icon),
              UIs.width13,
              Text(label, style: UIs.text13),
            ],
          ),
          SegmentedTabs<String?>(
            selected: selected,
            onSelected: (v) {
              if (v != null && v != selected) onSelected?.call(v);
            },
            segments: [
              for (final o in options) SegmentedTab(value: o, label: o),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choice(List<_Choice> options, {bool indent = false}) {
    final scheme = Theme.of(context).colorScheme;
    return _box(
      indent: indent,
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          for (final o in options)
            Material(
              key: ValueKey(o.key),
              color: o.selected
                  ? scheme.secondaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: o.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Row(
                    children: [
                      _icon(
                        o.icon,
                        color: o.selected ? scheme.onSecondaryContainer : null,
                      ),
                      UIs.width13,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: UIs.text13.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (o.sub case final sub? when sub.isNotEmpty)
                              Text(sub, style: UIs.text11Grey),
                          ],
                        ),
                      ),
                      if (o.selected) const Icon(Icons.check, size: 17),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A notice among the rows, as the design's callout: a title, what it
  /// means, in the warning colour or the primary one.
  Widget _callout(
    String title,
    String body, {
    bool warn = true,
    bool indent = false,
    Key? key,
  }) {
    final color = warn ? StatePalette.warn : Theme.of(context).colorScheme.primary;
    return _box(
      key: key,
      indent: indent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warn ? Icons.warning_amber_rounded : Icons.info_outline, size: 19, color: color),
          UIs.width13,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: UIs.text13Bold.copyWith(color: color)),
                const SizedBox(height: 2),
                Text(body, style: UIs.text12Grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A device's row, which opens and closes its own rows under it.
  Widget _disc(
    String key,
    IconData icon,
    String label,
    String summary, {
    VoidCallback? onTap,
  }) {
    final open = _open.contains(key);
    final scheme = Theme.of(context).colorScheme;
    return _box(
      key: ValueKey('hw:disc:$key'),
      padding: const EdgeInsets.all(13),
      color: open ? scheme.surfaceContainerHigh : null,
      onTap:
          onTap ??
          () => setState(() => open ? _open.remove(key) : _open.add(key)),
      child: Row(
        children: [
          _icon(icon, color: open ? scheme.primary : null),
          UIs.width13,
          Text(label, style: UIs.text13.copyWith(fontWeight: FontWeight.w500)),
          UIs.width13,
          Expanded(
            child: Text(
              summary,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UIs.text12Grey,
            ),
          ),
          UIs.width7,
          Icon(
            open ? Icons.expand_less : Icons.expand_more,
            size: 17,
            color: scheme.outline,
          ),
        ],
      ),
    );
  }

  Widget _text(String text, {bool indent = false, bool error = false}) {
    return Padding(
      padding: EdgeInsets.only(left: (indent ? _indent : 0) + 13, right: 13),
      child: Text(
        text,
        style: error
            ? UIs.text12.copyWith(color: Theme.of(context).colorScheme.error)
            : UIs.text12Grey,
      ),
    );
  }

  /// A group with nothing more to it yet: what it is for, and the way to add.
  Widget _empty(
    String text,
    String action, {
    required String key,
    required VoidCallback? onTap,
    IconData icon = Icons.add,
  }) {
    return DashedBorder(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 7, 7, 7),
        child: Row(
          children: [
            Expanded(child: Text(text, style: UIs.text12Grey)),
            Btn.row(
              key: ValueKey(key),
              text: action,
              icon: Icon(icon, size: 17),
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(List<_Action> actions, {bool indent = false}) {
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: EdgeInsets.only(left: indent ? _indent : 0),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final a in actions)
            if (a.primary)
              Btn.elevated(
                key: a.key == null ? null : ValueKey<String>(a.key!),
                text: a.text,
                mainAxisSize: MainAxisSize.min,
                onTap: a.onTap,
              )
            else
              Btn.row(
                key: a.key == null ? null : ValueKey<String>(a.key!),
                text: a.text,
                icon: Icon(
                  a.icon ?? Icons.check,
                  size: 17,
                  color: a.danger ? error : null,
                ),
                textStyle: a.danger ? TextStyle(color: error) : null,
                onTap: a.onTap,
              ),
        ],
      ),
    );
  }

  /// One boot device: its place, what it is, and the arrows that move it.
  /// Tapped, it is booted from or not.
  Widget _reorder({
    required String key,
    required String ord,
    required bool first,
    required (IconData, String, String) device,
    required VoidCallback onToggle,
    required VoidCallback? onUp,
    required VoidCallback? onDown,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, summary) = device;
    return Opacity(
      opacity: ord == '–' ? 0.5 : 1,
      child: _box(
        key: ValueKey('hw:$key'),
        padding: const EdgeInsets.fromLTRB(13, 5, 7, 5),
        onTap: onToggle,
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 19),
              height: 19,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: first ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                ord,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: first ? scheme.onPrimary : null,
                ),
              ),
            ),
            UIs.width7,
            _icon(icon),
            UIs.width7,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: UIs.text13.copyWith(fontWeight: FontWeight.w500),
                  ),
                  if (summary.isNotEmpty)
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UIs.text11Grey,
                    ),
                ],
              ),
            ),
            Btn.icon(
              key: ValueKey('hw:$key:up'),
              text: l10n.virtHwMoveUp,
              icon: const Icon(Icons.arrow_upward, size: 17),
              onTap: onUp,
            ),
            Btn.icon(
              key: ValueKey('hw:$key:down'),
              text: l10n.virtHwMoveDown,
              icon: const Icon(Icons.arrow_downward, size: 17),
              onTap: onDown,
            ),
          ],
        ),
      ),
    );
  }

  String? _issueText(VirtHardware hw, VirtHwIssue? issue) {
    final hostCpus = hw.limits.hostCpus;
    final hostMib = switch (hw.limits.hostMemoryBytes) {
      final b? => b >> 20,
      null => null,
    };
    return switch (issue) {
      null => null,
      VirtHwIssue.cpuCount => l10n.virtHwIssueCpuCount(hostCpus ?? 4096),
      VirtHwIssue.cpuOnline => l10n.virtHwIssueCpuOnline,
      VirtHwIssue.memory => l10n.virtHwIssueMemory(
        virtHwMinMemoryMib,
        hostMib ?? 1 << 30,
      ),
      VirtHwIssue.memoryMin => l10n.virtHwIssueMemoryMin,
      VirtHwIssue.swap => l10n.virtHwIssueSwap,
      VirtHwIssue.diskShrink => l10n.virtHwIssueDiskShrink,
      VirtHwIssue.diskSize => l10n.virtHwIssueDiskSize,
      VirtHwIssue.storageSpace => l10n.virtHwIssueStorageSpace,
      VirtHwIssue.mountPoint => l10n.virtHwIssueMountPoint,
      VirtHwIssue.bootEmpty => l10n.virtHwIssueBootEmpty,
      VirtHwIssue.nameInvalid =>
        _pve ? l10n.virtCreateNameInvalidPve : l10n.virtCreateNameInvalidLibvirt,
      VirtHwIssue.nameRunning => l10n.virtSetRenameStopped,
      VirtHwIssue.description => l10n.virtSetIssueDescription(
        virtHwDescriptionMax,
      ),
      VirtHwIssue.mac => l10n.virtHwIssueMac,
      VirtHwIssue.stopFirst => l10n.virtHwIssueStopFirst,
      VirtHwIssue.storageMissing => l10n.virtHwIssueStorageMissing,
      VirtHwIssue.device => l10n.virtHwIssueDevice,
    };
  }

  /// Makes [change] and, when the host took it, drops the draft with
  /// [clear].
  Future<void> _save(
    VirtHardware hw,
    VirtHwChange change,
    void Function() clear,
  ) async {
    if (await _apply(hw, change) && mounted) {
      setState(clear);
    }
  }

  /// Makes [change], says what came of it, and reads the hardware again.
  /// True when the host took it.
  Future<bool> _apply(VirtHardware hw, VirtHwChange change) async {
    final issue = virtHwIssue(hw, change, host: _host);
    if (issue != null) {
      Toast.warn(_issueText(hw, issue) ?? libL10n.fail);
      return false;
    }
    final VirtHwOutcome outcome;
    try {
      outcome = await _notifier.changeHardware(_guest.id, hw, change);
    } on VirtErr catch (e) {
      if (e.type == VirtErrType.conflict) {
        Toast.warn(e.title, body: l10n.virtErrConflictTip);
      } else {
        Toast.error(e.title, body: e.detail);
      }
      if (mounted) ref.invalidate(_provider);
      return false;
    } catch (e, s) {
      Loggers.app.warning('Virtualization hardware', e, s);
      Toast.error(libL10n.fail, body: '$e');
      if (mounted) ref.invalidate(_provider);
      return false;
    }
    if (!mounted) return true;
    final before = {for (final p in hw.pending) p.key};
    VirtHardware? after;
    try {
      after = await ref.refresh(_provider.future);
    } catch (_) {
      // The view shows why it cannot read.
    }
    final waits =
        outcome.liveError != null ||
        (after?.pending.any((p) => !before.contains(p.key)) ?? false);
    if (outcome.volumeKept) {
      Toast.warn(l10n.virtHwVolumeKept);
    } else if (waits && change is! VirtHwRevert) {
      Toast.info(l10n.virtHwAppliesOnRestart, body: outcome.liveError);
    } else {
      Toast.success(libL10n.success);
    }
    return true;
  }
}

enum _PendingPlace { cpu, memory, disk, nic, boot, settings, other }

/// One group of the pane: its heading and rows, and its line in the index.
final class _Group {
  const _Group({
    required this.key,
    required this.title,
    required this.right,
    required this.warn,
    required this.indexNote,
    required this.rows,
    this.dot,
  });

  final String key;
  final String title;

  /// Beside the rule: what the group amounts to, or that it waits.
  final String right;

  /// [right] is a change waiting for the next start.
  final bool warn;
  final String indexNote;
  final List<Widget> rows;

  /// The index's dot, where the group's own colour says more than state
  /// does: red for the group that deletes.
  final Color? dot;
}

final class _Action {
  const _Action(
    this.text, {
    this.icon,
    this.key,
    this.primary = false,
    this.danger = false,
    required this.onTap,
  });

  final String text;
  final IconData? icon;
  final String? key;
  final bool primary;
  final bool danger;
  final VoidCallback? onTap;
}

final class _Choice {
  const _Choice({
    required this.key,
    required this.icon,
    required this.label,
    this.sub,
    required this.selected,
    required this.onTap,
  });

  final String key;
  final IconData icon;
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback? onTap;
}

