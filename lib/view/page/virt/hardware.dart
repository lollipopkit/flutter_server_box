import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/virt/common.dart';
import 'package:server_box/view/widget/group_title.dart';

/// A guest's hardware, and changing it — the design's sectioned edit pane:
/// groups under a title and a rule, each saying on the right what it amounts
/// to, or that a change waits for the next start. Wide, an index of the
/// groups runs down the left.
///
/// Every value shown is what the next start gets. What the running guest has
/// instead is listed first, with a way to drop it where the host keeps such a
/// list (PVE); the guest view says so above its tabs, with a restart.
///
/// Steppers and the boot order are drafts, saved or dropped with the buttons
/// under them: one click is one step, not one change to the host. A device's
/// own switches — its network, its link, a CD-ROM's media — are one change
/// each, made as they are pressed.
class VirtHardwareView extends ConsumerStatefulWidget {
  const VirtHardwareView({
    super.key,
    required this.serverId,
    required this.guest,
    required this.caps,
  });

  final String serverId;
  final VirtGuest guest;
  final VirtCapabilities caps;

  @override
  ConsumerState<VirtHardwareView> createState() => _VirtHardwareViewState();
}

/// Where the index column appears: room for it beside the 600-wide pane.
const _indexFrom = 860.0;

/// How far a device's own rows sit in from its row.
const _indent = 26.0;

class _CpuDraft {
  const _CpuDraft(this.sockets, this.cores, this.online);

  final int sockets;
  final int cores;

  /// Null for all of them.
  final int? online;
}

class _MemDraft {
  const _MemDraft(this.mib, this.minMib, this.swapMib);

  final int mib;
  final int? minMib;
  final int? swapMib;
}

class _VirtHardwareViewState extends ConsumerState<VirtHardwareView> {
  _CpuDraft? _cpu;
  _MemDraft? _mem;

  /// The boot order being edited: every bootable device, and which of them
  /// are booted from.
  List<String>? _boot;
  Set<String> _bootOn = const {};

  /// Grown sizes not saved yet, by disk.
  final _grow = <String, int>{};

  /// Open device rows, by key; `config` for the configuration file.
  final _open = <String>{};

  /// The add block that is open: `disk` or `nic`.
  String? _adding;
  List<VirtStoragePool>? _addPools;
  VirtStoragePool? _addPool;
  int _addGib = 32;
  final _mount = TextEditingController(text: '/mnt/data');
  List<VirtNetwork>? _nets;
  VirtNetwork? _addNet;

  Future<List<VirtVolume>>? _isos;
  final _groupKeys = <String, GlobalKey>{};

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(widget.serverId).notifier);

  VirtHardwareProvider get _provider =>
      virtHardwareProvider(widget.serverId, widget.guest.id);

  bool get _lxc => widget.guest.kind == VirtGuestKind.lxc;

  bool get _pve =>
      ref.read(virtHostProvider(widget.serverId)).kind == VirtHostKind.pve;

  @override
  void initState() {
    super.initState();
    // Where a NIC can go: read once, for the NIC rows' network choice.
    final host = ref.read(virtHostProvider(widget.serverId)).kind;
    if (host != null) unawaited(_loadNets(host).catchError((Object _) {}));
  }

  @override
  void dispose() {
    _mount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_provider);
    final busy = ref.watch(
      virtHostProvider(
        widget.serverId,
      ).select((s) => s.isBusy(widget.guest.id)),
    );
    final hw = async.value;
    if (async.error case final e?) return _buildError(e);
    if (hw == null) return const Center(child: SizedLoading.medium);
    final groups = _groups(hw, busy);
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
                      color: g.warn ? StatePalette.warn : ChartPalette.accent,
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

  List<_Group> _groups(VirtHardware hw, bool busy) => [
    if (hw.pending.isNotEmpty) _pendingGroup(hw, busy),
    _cpuGroup(hw, busy),
    _memGroup(hw, busy),
    _diskGroup(hw, busy),
    _nicGroup(hw, busy),
    if (!_lxc && hw.disks.any((d) => d.kind == VirtHwDiskKind.cdrom))
      _cdromGroup(hw, busy),
    _bootGroup(hw, busy),
    _configGroup(hw),
  ];

  /// Whether a change to [keys] waits for the next start: the running guest
  /// has it pending.
  bool _waits(VirtHardware hw, Iterable<String> keys) =>
      hw.running && hw.pendingFor(keys);

  // --- Pending ---

  _Group _pendingGroup(VirtHardware hw, bool busy) {
    final revert = widget.caps.hardwareRevert;
    return _Group(
      key: 'pending',
      title: l10n.virtHwPendingTitle,
      right: '${hw.pending.length}',
      warn: true,
      indexNote: hw.pending.map((p) => p.key).join(', '),
      rows: [
        _text(l10n.virtHwPendingTip),
        for (final p in hw.pending)
          _field(
            Icons.schedule,
            p.key,
            p.delete
                ? '${p.current ?? ''} → ${libL10n.delete}'
                : '${p.current ?? '—'} → ${p.pending ?? '—'}',
            key: ValueKey('hw:pending:${p.key}'),
            trailing: revert
                ? Btn.icon(
                    key: ValueKey('hw:revert:${p.key}'),
                    text: l10n.virtHwRevert,
                    icon: const Icon(Icons.undo, size: 17),
                    onTap: busy
                        ? null
                        : () => _apply(hw, VirtHwRevert([p.key])),
                  )
                : null,
          ),
        if (revert && hw.pending.length > 1)
          _actions([
            _Action(
              l10n.virtHwRevertAll,
              icon: Icons.undo,
              key: 'hw:revert-all',
              onTap: busy
                  ? null
                  : () => _apply(
                      hw,
                      VirtHwRevert([for (final p in hw.pending) p.key]),
                    ),
            ),
          ]),
      ],
    );
  }

  // --- CPU ---

  _Group _cpuGroup(VirtHardware hw, bool busy) {
    final saved = _CpuDraft(hw.cpu.sockets, hw.cpu.cores, hw.cpu.online);
    final d = _cpu ?? saved;
    final threads = hw.cpu.threads;
    final total = d.sockets * d.cores * threads;
    final maxCpus = hw.limits.hostCpus ?? 4096;
    void edit(_CpuDraft next) => setState(() => _cpu = next);
    final changed =
        _cpu != null &&
        (d.sockets != saved.sockets ||
            d.cores != saved.cores ||
            d.online != saved.online);
    final waits = _waits(hw, const ['cpu', 'cores', 'sockets', 'vcpus']);
    final allocated = _allocated((g) => g.vcpu);
    return _Group(
      key: 'cpu',
      title: _lxc ? 'CPU' : l10n.virtHwProcessor,
      right: waits
          ? l10n.virtHwLater
          : l10n.virtHwHostCpus(hw.limits.hostCpus ?? 0, allocated),
      warn: waits,
      indexNote: _lxc ? '${hw.cpu.cores}' : '${hw.cpu.total} vCPU',
      rows: [
        if (_lxc)
          _step(
            Icons.developer_board,
            l10n.virtHwCores,
            '${d.cores}',
            key: 'cores',
            onDec: d.cores <= 1
                ? null
                : () => edit(_CpuDraft(1, d.cores - 1, null)),
            onInc: d.cores >= maxCpus
                ? null
                : () => edit(_CpuDraft(1, d.cores + 1, null)),
          )
        else ...[
          _step(
            Icons.developer_board,
            'vCPU',
            '$total',
            key: 'cores',
            onDec: d.cores <= 1
                ? null
                : () => edit(
                    _CpuDraft(
                      d.sockets,
                      d.cores - 1,
                      _clampOnline(d.online, d.sockets * (d.cores - 1) * threads),
                    ),
                  ),
            onInc: total + d.sockets * threads > maxCpus
                ? null
                : () => edit(_CpuDraft(d.sockets, d.cores + 1, d.online)),
          ),
          _step(
            Icons.view_module_outlined,
            l10n.virtHwSockets,
            '${d.sockets}',
            key: 'sockets',
            onDec: d.sockets <= 1
                ? null
                : () => edit(
                    _CpuDraft(
                      d.sockets - 1,
                      d.cores,
                      _clampOnline(d.online, (d.sockets - 1) * d.cores * threads),
                    ),
                  ),
            onInc: total + d.cores * threads > maxCpus
                ? null
                : () => edit(_CpuDraft(d.sockets + 1, d.cores, d.online)),
          ),
          _step(
            Icons.bolt_outlined,
            l10n.virtHwOnline,
            d.online == null ? '$total' : '${d.online} / $total',
            key: 'online',
            onDec: (d.online ?? total) <= 1
                ? null
                : () => edit(
                    _CpuDraft(d.sockets, d.cores, (d.online ?? total) - 1),
                  ),
            onInc: d.online == null
                ? null
                : () => edit(
                    _CpuDraft(
                      d.sockets,
                      d.cores,
                      d.online! + 1 >= total ? null : d.online! + 1,
                    ),
                  ),
          ),
          if (hw.cpuTypes.isNotEmpty || hw.cpu.type != null)
            _field(
              Icons.memory_outlined,
              l10n.virtHwModel,
              hw.cpu.type ?? l10n.virtHwCpuTypeDefault,
              key: const ValueKey('hw:cputype'),
              onTap: busy || hw.cpuTypes.isEmpty
                  ? null
                  : () => _pickCpuType(hw),
              trailing: hw.cpuTypes.isEmpty
                  ? null
                  : const Icon(Icons.chevron_right, size: 17),
            ),
          _field(
            Icons.grid_view,
            l10n.virtHwTopology,
            l10n.virtHwTopologyValue(d.sockets, d.cores, threads),
          ),
        ],
        if (changed)
          _actions([
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _cpu = null),
            ),
            _Action(
              libL10n.save,
              key: 'hw:cpu:save',
              primary: true,
              onTap: busy
                  ? null
                  : () => _save(
                      hw,
                      VirtHwSetCpu(
                        sockets: d.sockets,
                        cores: d.cores,
                        online: d.online,
                      ),
                      () => _cpu = null,
                    ),
            ),
          ]),
      ],
    );
  }

  static int? _clampOnline(int? online, int total) =>
      online == null || online >= total ? null : online;

  /// The sum of [of] over the host's guests: what is already given out.
  int _allocated(int? Function(VirtGuest g) of) {
    final guests =
        ref.read(virtHostProvider(widget.serverId)).data?.guests ??
        const <VirtGuest>[];
    return guests.fold(0, (sum, g) => sum + (of(g) ?? 0));
  }

  // --- Memory ---

  static String _mib(int mib) {
    if (mib < 1024) return '$mib MiB';
    final gib = mib / 1024;
    return '${gib.toStringAsFixed(mib % 1024 == 0 ? 0 : 1)} GiB';
  }

  /// A step of memory: a quarter of a GiB up to one, whole GiB above.
  static int _memStep(int mib, {required bool up}) =>
      mib < 1024 || (!up && mib == 1024) ? 256 : 1024;

  _Group _memGroup(VirtHardware hw, bool busy) {
    final saved = _MemDraft(
      hw.memory.mib,
      hw.memory.minMib,
      hw.memory.swapMib,
    );
    final d = _mem ?? saved;
    void edit(_MemDraft next) => setState(() => _mem = next);
    final changed =
        _mem != null &&
        (d.mib != saved.mib ||
            d.minMib != saved.minMib ||
            d.swapMib != saved.swapMib);
    final hostMib = switch (hw.limits.hostMemoryBytes) {
      final b? => b >> 20,
      null => null,
    };
    final waits = _waits(hw, const ['memory', 'balloon', 'swap']);
    final allocated = _allocated((g) => g.memBytes) >> 20;
    final used = ref.watch(
      virtHostProvider(
        widget.serverId,
      ).select((s) => s.statsOf(widget.guest.id)?.memUsed),
    );
    final pve = _pve;
    final current = d.minMib ?? d.mib;
    return _Group(
      key: 'mem',
      title: libL10n.memory,
      right: waits
          ? l10n.virtHwLater
          : hostMib == null
          ? ''
          : l10n.virtHwHostMem(_mib(hostMib), _mib(allocated)),
      warn: waits,
      indexNote: [
        _mib(hw.memory.mib),
        if (hw.memory.balloon && hw.memory.minMib != 0) 'balloon',
      ].join(' · '),
      rows: [
        _step(
          Icons.memory,
          libL10n.memory,
          _mib(d.mib),
          key: 'memory',
          onDec: d.mib - _memStep(d.mib, up: false) < virtHwMinMemoryMib
              ? null
              : () {
                  final mib = d.mib - _memStep(d.mib, up: false);
                  final min = d.minMib;
                  edit(
                    _MemDraft(
                      mib,
                      min != null && min > mib ? mib : min,
                      d.swapMib,
                    ),
                  );
                },
          onInc:
              hostMib != null && d.mib + _memStep(d.mib, up: true) > hostMib
              ? null
              : () => edit(
                  _MemDraft(
                    d.mib + _memStep(d.mib, up: true),
                    d.minMib,
                    d.swapMib,
                  ),
                ),
        ),
        if (hw.memory.balloon && pve)
          _toggle(
            Icons.compress,
            'virtio-balloon',
            d.minMib != 0,
            key: 'balloon',
            note: l10n.virtHwBalloonNote,
            onChanged: (on) => edit(
              _MemDraft(
                d.mib,
                on ? (hw.memory.minMib == 0 ? null : hw.memory.minMib) : 0,
                d.swapMib,
              ),
            ),
          ),
        // libvirt's balloon is a target the host sets rather than a floor: a
        // stepper for it rather than a switch.
        if (hw.memory.balloon && !pve)
          _step(
            Icons.compress,
            l10n.virtHwBalloonLibvirt,
            _mib(current),
            key: 'balloon',
            onDec: current <= 256
                ? null
                : () => edit(_MemDraft(d.mib, current - 256, d.swapMib)),
            onInc: current >= d.mib
                ? null
                : () {
                    final next = current + 256;
                    edit(
                      _MemDraft(d.mib, next >= d.mib ? null : next, d.swapMib),
                    );
                  },
          ),
        if (_lxc && d.swapMib != null)
          _step(
            Icons.swap_horiz,
            l10n.virtHwSwap,
            _mib(d.swapMib!),
            key: 'swap',
            onDec: d.swapMib! <= 0
                ? null
                : () => edit(
                    _MemDraft(
                      d.mib,
                      d.minMib,
                      (d.swapMib! - 512).clamp(0, 1 << 30),
                    ),
                  ),
            onInc: () => edit(_MemDraft(d.mib, d.minMib, d.swapMib! + 512)),
          ),
        if (hw.running && used != null)
          _field(Icons.data_usage, l10n.virtHwGuestUsed, used.bytes2Str),
        if (changed)
          _actions([
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _mem = null),
            ),
            _Action(
              libL10n.save,
              key: 'hw:memory:save',
              primary: true,
              onTap: busy
                  ? null
                  : () => _save(
                      hw,
                      VirtHwSetMemory(
                        mib: d.mib,
                        minMib: d.minMib,
                        swapMib: d.swapMib,
                      ),
                      () => _mem = null,
                    ),
            ),
          ]),
      ],
    );
  }

  // --- Disks ---

  _Group _diskGroup(VirtHardware hw, bool busy) {
    final disks = [
      for (final d in hw.disks)
        if (d.kind != VirtHwDiskKind.cdrom) d,
    ];
    final total = disks.fold(0, (s, d) => s + (d.size ?? 0));
    return _Group(
      key: 'disks',
      title: _lxc ? l10n.virtHwDisksLxc : libL10n.disk,
      right: l10n.virtHwTotal(total.bytes2Str),
      warn: _waits(hw, disks.map((d) => d.key)),
      indexNote: disks.isEmpty ? '—' : disks.map((d) => d.key).join(', '),
      rows: [
        for (final d in disks) ..._diskRows(hw, d, busy),
        if (_adding == 'disk')
          ..._addDiskRows(hw, busy)
        else
          _empty(
            _lxc ? l10n.virtHwMountFromPool : l10n.virtHwDiskHotplug,
            _lxc ? l10n.virtHwAddMount : l10n.virtHwAddDisk,
            key: 'hw:disk:add',
            onTap: busy ? null : () => _openAdd('disk'),
          ),
      ],
    );
  }

  List<Widget> _diskRows(VirtHardware hw, VirtHwDisk d, bool busy) {
    final size = d.size;
    final grown = _grow[d.key];
    final summary = [
      ?size?.bytes2Str,
      if (_lxc) ?d.mountPoint else ...[?d.format, ?d.bus],
    ].join(' · ');
    return [
      _disc(d.key, Icons.storage, d.key, summary),
      if (_open.contains(d.key)) ...[
        _field(
          Icons.folder_outlined,
          l10n.virtHwSource,
          d.source ?? '—',
          mono: true,
          indent: true,
        ),
        if (size != null)
          _step(
            Icons.straighten,
            libL10n.capacity,
            (grown ?? size).bytes2Str,
            key: 'grow:${d.key}',
            indent: true,
            onDec: grown == null || grown - (8 << 30) <= size
                ? (grown == null
                      ? null
                      : () => setState(() => _grow.remove(d.key)))
                : () => setState(() => _grow[d.key] = grown - (8 << 30)),
            onInc: () =>
                setState(() => _grow[d.key] = (grown ?? size) + (8 << 30)),
          ),
        _text(
          hw.running ? l10n.virtHwGrowNoteRunning : l10n.virtHwGrowNote,
          indent: true,
        ),
        _actions(indent: true, [
          if (grown != null) ...[
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _grow.remove(d.key)),
            ),
            _Action(
              l10n.virtHwGrow,
              key: 'hw:disk:${d.key}:grow',
              primary: true,
              onTap: busy
                  ? null
                  : () => _save(
                      hw,
                      VirtHwGrowDisk(key: d.key, bytes: grown),
                      () => _grow.remove(d.key),
                    ),
            ),
          ],
          // A container's root is its own.
          if (d.kind != VirtHwDiskKind.rootfs)
            _Action(
              l10n.virtHwDetach,
              key: 'hw:disk:${d.key}:detach',
              icon: Icons.link_off,
              danger: true,
              onTap: busy ? null : () => _removeDisk(hw, d),
            ),
        ]),
      ],
    ];
  }

  List<Widget> _addDiskRows(VirtHardware hw, bool busy) {
    final pools = _addPools;
    final pool = _addPool;
    final add = pool == null
        ? null
        : VirtHwAddDisk(
            storage: pool,
            gib: _addGib,
            mountPoint: _lxc ? _mount.text.trim() : null,
          );
    final issue = add == null ? null : _issueText(hw, virtHwIssue(hw, add));
    return [
      _disc(
        '__add',
        Icons.add_circle_outline,
        _lxc ? l10n.virtHwNewMount : l10n.virtHwNewDisk,
        l10n.virtHwPickPool,
        onTap: () => setState(() => _adding = null),
      ),
      if (pools == null)
        const Padding(
          padding: EdgeInsets.all(7),
          child: Center(child: SizedLoading.small),
        )
      else if (pools.isEmpty)
        _text(l10n.virtHwNoStorage, indent: true)
      else ...[
        _choice([
          for (final p in pools)
            _Choice(
              key: 'hw:disk:pool:${p.id}',
              icon: Icons.dns_outlined,
              label: p.name,
              sub: [
                p.type,
                if (p.available case final a?) l10n.virtHwFree(a.bytes2Str),
              ].join(' · '),
              selected: p.id == pool?.id,
              onTap: () => setState(() => _addPool = p),
            ),
        ], indent: true),
        _step(
          Icons.straighten,
          libL10n.capacity,
          '$_addGib GiB',
          key: 'add:size',
          indent: true,
          onDec: _addGib <= 8 ? null : () => setState(() => _addGib -= 8),
          onInc: () => setState(() => _addGib += 8),
        ),
        if (_lxc)
          Padding(
            padding: const EdgeInsets.only(left: _indent),
            child: Input(
              key: const ValueKey('hw:disk:mount'),
              controller: _mount,
              label: l10n.virtHwMountPoint,
              icon: Icons.folder_open,
              noWrap: true,
              suggestion: false,
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (hw.running) _text(l10n.virtHwHotplugNow, indent: true),
        if (issue != null) _text(issue, indent: true, error: true),
      ],
      _actions(indent: true, [
        _Action(
          libL10n.cancel,
          icon: Icons.close,
          onTap: () => setState(() => _adding = null),
        ),
        _Action(
          libL10n.add,
          key: 'hw:disk:add:ok',
          primary: true,
          onTap: busy || add == null || issue != null
              ? null
              : () => _save(hw, add, () => _adding = null),
        ),
      ]),
    ];
  }

  // --- Network ---

  _Group _nicGroup(VirtHardware hw, bool busy) {
    return _Group(
      key: 'nics',
      title: l10n.virtHwNics,
      right: '${hw.nics.length}',
      warn: _waits(hw, hw.nics.map((n) => n.key)),
      indexNote: hw.nics.isEmpty
          ? '—'
          : hw.nics.map((n) => n.source ?? n.key).join(', '),
      rows: [
        for (final (i, n) in hw.nics.indexed) ..._nicRows(hw, n, i, busy),
        if (_adding == 'nic')
          ..._addNicRows(hw, busy)
        else
          _empty(
            l10n.virtHwNicHotplug,
            l10n.virtHwAddNic,
            key: 'hw:nic:add',
            onTap: busy ? null : () => _openAdd('nic'),
          ),
      ],
    );
  }

  /// What a NIC is called: PVE's option, a container's interface, or
  /// libvirt's order among them.
  String _nicName(VirtHwNic n, int i) =>
      n.name ?? (n.key.startsWith('net') ? n.key : 'nic$i');

  List<Widget> _nicRows(VirtHardware hw, VirtHwNic n, int i, bool busy) {
    final editable =
        n.type == null || n.type == 'network' || n.type == 'bridge';
    final nets = _nets;
    return [
      _disc(
        n.key,
        Icons.lan_outlined,
        _nicName(n, i),
        [?n.model, ?n.source, if (!n.linkUp) l10n.virtHwLinkDown].join(' · '),
      ),
      if (_open.contains(n.key)) ...[
        if (editable && nets != null && nets.isNotEmpty)
          _seg(
            Icons.hub_outlined,
            libL10n.network,
            [for (final x in nets) x.name],
            n.source,
            key: 'nic:${n.key}:net',
            indent: true,
            onSelected: busy
                ? null
                : (name) => _apply(
                    hw,
                    VirtHwUpdateNic(
                      key: n.key,
                      network: nets.firstWhere((x) => x.name == name),
                      linkUp: n.linkUp,
                    ),
                  ),
          )
        else
          _field(
            Icons.hub_outlined,
            libL10n.network,
            n.source ?? '—',
            indent: true,
          ),
        if (n.mac case final mac?)
          _field(
            Icons.fingerprint,
            l10n.virtHwMac,
            mac,
            mono: true,
            indent: true,
          ),
        if (editable)
          _toggle(
            Icons.link,
            l10n.virtHwLinkUp,
            n.linkUp,
            key: 'nic:${n.key}:link',
            note: l10n.virtHwLinkNote,
            indent: true,
            onChanged: busy
                ? null
                : (up) => _apply(hw, VirtHwUpdateNic(key: n.key, linkUp: up)),
          ),
        if (n.firewall case final fw?)
          _toggle(
            Icons.local_fire_department_outlined,
            l10n.virtHwFirewall,
            fw,
            key: 'nic:${n.key}:firewall',
            indent: true,
            onChanged: busy
                ? null
                : (on) => _apply(
                    hw,
                    VirtHwUpdateNic(key: n.key, linkUp: n.linkUp, firewall: on),
                  ),
          ),
        _actions(indent: true, [
          _Action(
            l10n.virtHwRemove,
            key: 'hw:nic:${n.key}:remove',
            icon: Icons.delete_outline,
            danger: true,
            onTap: busy ? null : () => _removeNic(hw, n, _nicName(n, i)),
          ),
        ]),
      ],
    ];
  }

  List<Widget> _addNicRows(VirtHardware hw, bool busy) {
    final nets = _nets;
    final net = _addNet;
    return [
      _disc(
        '__add',
        Icons.add_circle_outline,
        l10n.virtHwNewNic,
        l10n.virtHwPickNet,
        onTap: () => setState(() => _adding = null),
      ),
      if (nets == null)
        const Padding(
          padding: EdgeInsets.all(7),
          child: Center(child: SizedLoading.small),
        )
      else if (nets.isEmpty)
        _text(l10n.virtHwNoNetworks, indent: true)
      else
        _seg(
          Icons.lan_outlined,
          libL10n.network,
          [for (final x in nets) x.name],
          net?.name,
          key: 'add:net',
          indent: true,
          onSelected: (name) =>
              setState(() => _addNet = nets.firstWhere((x) => x.name == name)),
        ),
      if (hw.running) _text(l10n.virtHwHotplugNow, indent: true),
      _actions(indent: true, [
        _Action(
          libL10n.cancel,
          icon: Icons.close,
          onTap: () => setState(() => _adding = null),
        ),
        _Action(
          libL10n.add,
          key: 'hw:nic:add:ok',
          primary: true,
          onTap: busy || net == null
              ? null
              : () =>
                    _save(hw, VirtHwAddNic(network: net), () => _adding = null),
        ),
      ]),
    ];
  }

  // --- CD-ROM ---

  _Group _cdromGroup(VirtHardware hw, bool busy) {
    final drives = [
      for (final d in hw.disks)
        if (d.kind == VirtHwDiskKind.cdrom) d,
    ];
    return _Group(
      key: 'cdrom',
      title: l10n.virtHwCdrom,
      right: '${drives.length}',
      warn: _waits(hw, drives.map((d) => d.key)),
      indexNote: drives
          .map((d) => d.source == null ? '—' : _baseName(d.source!))
          .join(', '),
      rows: [
        for (final d in drives) ...[
          _disc(
            d.key,
            Icons.album_outlined,
            '${d.key} · ${l10n.virtHwCdrom}',
            d.source == null ? l10n.virtHwNoMedia : _baseName(d.source!),
            onTap: () {
              setState(
                () => _open.contains(d.key)
                    ? _open.remove(d.key)
                    : _open.add(d.key),
              );
              _isos ??= _loadIsos();
            },
          ),
          if (_open.contains(d.key)) ...[
            FutureBuilder<List<VirtVolume>>(
              future: _isos,
              builder: (_, snap) {
                final isos = snap.data;
                if (isos == null) {
                  return const Padding(
                    padding: EdgeInsets.all(7),
                    child: Center(child: SizedLoading.small),
                  );
                }
                bool inDrive(VirtVolume v) =>
                    v.id == d.source || v.path == d.source;
                return _choice([
                  _Choice(
                    key: 'hw:media:none',
                    icon: Icons.block,
                    label: l10n.virtHwEmpty,
                    selected: d.source == null,
                    onTap: busy || d.source == null
                        ? null
                        : () => _apply(hw, VirtHwSetMedia(key: d.key)),
                  ),
                  for (final v in isos)
                    _Choice(
                      key: 'hw:media:${v.id}',
                      icon: Icons.album_outlined,
                      label: v.name,
                      sub: v.capacity?.bytes2Str,
                      selected: inDrive(v),
                      onTap: busy || inDrive(v)
                          ? null
                          : () => _apply(
                              hw,
                              VirtHwSetMedia(key: d.key, media: v),
                            ),
                    ),
                ], indent: true);
              },
            ),
            _actions(indent: true, [
              if (d.source != null)
                _Action(
                  l10n.virtHwEject,
                  key: 'hw:media:${d.key}:eject',
                  icon: Icons.eject,
                  onTap: busy
                      ? null
                      : () => _apply(hw, VirtHwSetMedia(key: d.key)),
                ),
              _Action(
                l10n.virtHwRemoveCdrom,
                key: 'hw:media:${d.key}:remove',
                icon: Icons.delete_outline,
                danger: true,
                onTap: busy ? null : () => _removeDisk(hw, d),
              ),
            ]),
          ],
        ],
      ],
    );
  }

  static String _baseName(String source) {
    final slash = source.lastIndexOf('/');
    return slash < 0 ? source : source.substring(slash + 1);
  }

  // --- Boot and start ---

  _Group _bootGroup(VirtHardware hw, bool busy) {
    final saved = hw.boot;
    final waits = _waits(hw, const ['boot', 'onboot']);
    final rows = <Widget>[
      _toggle(
        Icons.power_settings_new,
        l10n.virtHwAutostart,
        hw.autostart,
        key: 'autostart',
        note: _pve ? l10n.virtHwAutostartPve : 'virsh autostart',
        onChanged: busy ? null : (on) => _apply(hw, VirtHwSetAutostart(on)),
      ),
    ];
    if (saved != null) {
      final order = _boot ?? _bootDevices(hw);
      final on = _boot == null ? {...saved} : _bootOn;
      final picked = [
        for (final k in order)
          if (on.contains(k)) k,
      ];
      final changed = _boot != null && picked.join(',') != saved.join(',');
      void move(int i, int dir) {
        final list = [...order];
        final j = i + dir;
        final moved = list[i];
        list[i] = list[j];
        list[j] = moved;
        setState(() {
          _boot = list;
          _bootOn = on;
        });
      }

      rows.addAll([
        _text(l10n.virtHwBootOrder),
        for (final (i, k) in order.indexed)
          _reorder(
            key: 'boot:$k',
            ord: on.contains(k) ? '${picked.indexOf(k) + 1}' : '–',
            first: picked.isNotEmpty && picked.first == k,
            device: _bootDevice(hw, k),
            onToggle: () => setState(() {
              _boot = order;
              _bootOn = on.contains(k) ? ({...on}..remove(k)) : {...on, k};
            }),
            onUp: i == 0 ? null : () => move(i, -1),
            onDown: i == order.length - 1 ? null : () => move(i, 1),
          ),
        _text(l10n.virtHwBootTip),
        if (changed)
          _actions([
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _boot = null),
            ),
            _Action(
              libL10n.save,
              key: 'hw:boot:save',
              primary: true,
              onTap: busy || picked.isEmpty
                  ? null
                  : () => _save(hw, VirtHwSetBoot(picked), () => _boot = null),
            ),
          ]),
      ]);
    }
    return _Group(
      key: 'boot',
      title: saved == null ? libL10n.general : l10n.virtHwBoot,
      right: waits ? l10n.virtHwLater : '',
      warn: waits,
      indexNote: [
        if (saved != null && saved.isNotEmpty) saved.first,
        if (hw.autostart) l10n.virtHwAutostart,
      ].join(' · '),
      rows: rows,
    );
  }

  /// Every device a guest can boot from: the order's own first, the rest
  /// after it, off.
  List<String> _bootDevices(VirtHardware hw) {
    final boot = hw.boot ?? const [];
    return [
      ...boot,
      for (final d in hw.disks)
        if (d.kind == VirtHwDiskKind.disk || d.kind == VirtHwDiskKind.cdrom)
          if (!boot.contains(d.key)) d.key,
      for (final n in hw.nics)
        if (!boot.contains(n.key)) n.key,
    ];
  }

  (IconData, String, String) _bootDevice(VirtHardware hw, String key) {
    if (hw.disk(key) case final d?) {
      return d.kind == VirtHwDiskKind.cdrom
          ? (
              Icons.album_outlined,
              '$key · ${l10n.virtHwCdrom}',
              d.source == null ? l10n.virtHwNoMedia : _baseName(d.source!),
            )
          : (Icons.storage, '$key · ${libL10n.disk}', d.size?.bytes2Str ?? '');
    }
    if (hw.nic(key) case final n?) {
      return (
        Icons.lan_outlined,
        '${n.name ?? key} · ${libL10n.network}',
        n.source ?? '',
      );
    }
    return (Icons.help_outline, key, '');
  }

  // --- Configuration file ---

  _Group _configGroup(VirtHardware hw) {
    final g = widget.guest;
    final (name, path) = switch ((_pve, _lxc)) {
      (true, true) => ('pct config ${g.vmid}', '/etc/pve/lxc/${g.vmid}.conf'),
      (true, false) => (
        'qm config ${g.vmid}',
        '/etc/pve/qemu-server/${g.vmid}.conf',
      ),
      _ => ('virsh dumpxml ${g.name}', '/etc/libvirt/qemu/${g.name}.xml'),
    };
    final open = _open.contains('config');
    return _Group(
      key: 'config',
      title: l10n.virtHwConfigFile,
      right: '',
      warn: false,
      indexNote: _pve ? (_lxc ? 'pct config' : 'qm config') : 'dumpxml',
      rows: [
        _disc('config', Icons.code, name, open ? '' : path),
        if (open)
          Container(
            key: const ValueKey('hw:config:text'),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(13),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                hw.configText ?? '',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
      ],
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
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 7, 7, 7),
        child: Row(
          children: [
            Expanded(child: Text(text, style: UIs.text12Grey)),
            Btn.row(
              key: ValueKey(key),
              text: action,
              icon: const Icon(Icons.add, size: 17),
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
    };
  }
}

/// One group of the pane: its heading and rows, and its line in the index.
final class _Group {
  const _Group({
    required this.key,
    required this.title,
    required this.right,
    required this.warn,
    required this.indexNote,
    required this.rows,
  });

  final String key;
  final String title;

  /// Beside the rule: what the group amounts to, or that it waits.
  final String right;

  /// [right] is a change waiting for the next start.
  final bool warn;
  final String indexNote;
  final List<Widget> rows;
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

// --- Actions ---

extension _Actions on _VirtHardwareViewState {
  /// Makes [change] and, when the host took it, drops the draft with
  /// [clear].
  Future<void> _save(
    VirtHardware hw,
    VirtHwChange change,
    void Function() clear,
  ) async {
    if (await _apply(hw, change) && mounted) {
      // ignore: invalid_use_of_protected_member
      setState(clear);
    }
  }

  /// Makes [change], says what came of it, and reads the hardware again.
  /// True when the host took it.
  Future<bool> _apply(VirtHardware hw, VirtHwChange change) async {
    final issue = virtHwIssue(hw, change);
    if (issue != null) {
      Toast.warn(_issueText(hw, issue) ?? libL10n.fail);
      return false;
    }
    final VirtHwOutcome outcome;
    try {
      outcome = await _notifier.changeHardware(widget.guest.id, hw, change);
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

  /// Opens the add block for `disk` or `nic`, with what it offers read now.
  Future<void> _openAdd(String kind) async {
    // ignore: invalid_use_of_protected_member
    setState(() {
      _adding = kind;
      _addPools = null;
      _addPool = null;
      _addGib = 32;
      _addNet = _nets?.firstOrNull;
    });
    final host = ref.read(virtHostProvider(widget.serverId)).kind;
    if (host == null) return;
    try {
      if (kind == 'disk') {
        final pools = virtDiskStorages(
          await ref.read(virtStoragePoolsProvider(widget.serverId).future),
          host: host,
          kind: widget.guest.kind,
          node: widget.guest.node,
        );
        if (!mounted) return;
        // ignore: invalid_use_of_protected_member
        setState(() {
          _addPools = pools;
          _addPool = pools.firstOrNull;
        });
      } else if (_nets == null) {
        await _loadNets(host);
        if (!mounted) return;
        // ignore: invalid_use_of_protected_member
        setState(() => _addNet = _nets?.firstOrNull);
      }
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e) {
      Toast.error(libL10n.fail, body: '$e');
    }
  }

  Future<void> _loadNets(VirtHostKind host) async {
    final nets = virtCreateNetworks(
      await ref.read(virtNetworksProvider(widget.serverId).future),
      host: host,
      node: widget.guest.node,
    );
    if (!mounted) return;
    // ignore: invalid_use_of_protected_member
    setState(() => _nets = nets);
  }

  Future<List<VirtVolume>> _loadIsos() async {
    final host = ref.read(virtHostProvider(widget.serverId)).kind;
    if (host == null) return const [];
    final pools = await ref.read(
      virtStoragePoolsProvider(widget.serverId).future,
    );
    final lists = await Future.wait([
      for (final p in virtMediaStorages(
        pools,
        host: host,
        kind: VirtGuestKind.qemu,
        node: widget.guest.node,
      ))
        _notifier.volumes(p).catchError((Object _) => <VirtVolume>[]),
    ]);
    return [
      for (final list in lists)
        for (final v in list)
          if (virtIsMedia(v, VirtGuestKind.qemu)) v,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _pickCpuType(VirtHardware hw) async {
    final picked = await context.showRoundDialog<String>(
      title: l10n.virtHwModel,
      child: SizedBox(
        width: 400,
        height: 420,
        child: ListView(
          children: [
            for (final t in hw.cpuTypes)
              ListTile(
                key: ValueKey('hw:cputype:$t'),
                dense: true,
                title: Text(t, style: UIs.text13),
                selected: t == hw.cpu.type,
                onTap: () => context.popDialog(t),
              ),
          ],
        ),
      ),
      actions: [Btn.cancel()],
    );
    if (picked == null || picked == hw.cpu.type || !mounted) return;
    await _apply(
      hw,
      VirtHwSetCpu(
        sockets: hw.cpu.sockets,
        cores: hw.cpu.cores,
        online: hw.cpu.online,
        type: picked,
      ),
    );
  }

  Future<void> _removeDisk(VirtHardware hw, VirtHwDisk d) async {
    final cdrom = d.kind == VirtHwDiskKind.cdrom;
    var delete = false;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (context, setDialog) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.virtHwRemoveDiskAsk(d.key, widget.guest.name)),
            if (!cdrom && d.source != null)
              CheckboxListTile(
                key: const ValueKey('hw:disk:delete-volume'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: delete,
                title: Text(l10n.virtHwDeleteVolume),
                subtitle: Text(d.source!, style: UIs.text12Grey),
                onChanged: (v) => setDialog(() => delete = v ?? false),
              ),
          ],
        ),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    await _apply(hw, VirtHwRemoveDisk(key: d.key, deleteVolume: delete));
  }

  Future<void> _removeNic(VirtHardware hw, VirtHwNic n, String name) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.virtHwRemoveNicAsk(name, widget.guest.name)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    await _apply(hw, VirtHwRemoveNic(key: n.key));
  }
}
